function L = patchLayout(dataParentDir, options)
%PATCHLAYOUT Learn where the 12 E. coli patches sit in the acetate template's frame.
%
%   L = ndi.setup.conv.haley.patchLayout(DATAPARENTDIR) reads, under
%   DATAPARENTDIR/haley/ecoli, bacteria.mat (metaData, lawnAnalysis), the
%   extract (analyzeGFP_24-04-04.mat, with `template` from
%   ndi.setup.conv.haley.extractTemplates) and the patch masks (mask/<n>.png).
%   For every analysed fluorescence image of a `rectangle` plate in which all
%   12 patches were detected, it numbers the patches as the import does
%   (decision #62) and converts each centre into the acetate's own frame:
%   minus the template centre (stored [y x]), rotated by minus the template
%   angle, divided by the template scale (px/mm). The layout is each
%   patch's median position over those images. Nothing is written.
%
%   The angle's sign convention (regionprops Orientation, y down) is not
%   assumed: both signs are tried and the one whose positions agree best
%   across images is kept, and both spreads are printed.
%
%   It prints its denominator first (images considered, used, and why the
%   rest were not), then the 12 positions in mm with their spread, the
%   images with any patch more than 'OutlierMm' from its position, and a
%   JSON line for the spec. Decision #80.
%
%   L fields: positions (12 x 2 mm), spread (12 x 2: median and max
%   distance, mm), angleSign, imagesUsed, outliers (table), minSpacing (mm).
%
%   Options: 'OutlierMm' (default 0.5), 'ProfilesFile' (the extract;
%   default ecoli/analyzeGFP_24-04-04.mat).

arguments
    dataParentDir (1,:) char {mustBeFolder}
    options.OutlierMm (1,1) double = 0.5
    options.ProfilesFile (1,:) char = ''
end
e = fullfile(dataParentDir, 'haley', 'ecoli');
B = load(fullfile(e, 'bacteria.mat'), 'metaData', 'lawnAnalysis');
M = B.metaData;
A = B.lawnAnalysis;
pf = options.ProfilesFile;
if isempty(pf), pf = fullfile(e, 'analyzeGFP_24-04-04.mat'); end
X = load(pf, 'template');
T = X.template;

imgs = unique(A.imageNum);
nRows = arrayfun(@(i) sum(A.imageNum == i), imgs);
why = containers.Map({'not 12 lawnAnalysis rows', 'not a rectangle plate', 'no template', ...
    'no mask file', 'mask regions not 12', 'not numbered as a full image'}, {0, 0, 0, 0, 0, 0});
P = nan(12, 2, 0, 2);        % slot x [u v] x image x sign
used = [];
for i = 1:numel(imgs)
    n = imgs(i);
    if nRows(i) ~= 12, why('not 12 lawnAnalysis rows') = why('not 12 lawnAnalysis rows') + 1; continue; end
    r = find(M.imageNum == n, 1);
    if isempty(r) || ~strcmp(M.template{r}, 'rectangle')
        why('not a rectangle plate') = why('not a rectangle plate') + 1; continue;
    end
    t = find(T.imageNum == M.brightfieldImageNum(r), 1);
    if isempty(t), why('no template') = why('no template') + 1; continue; end
    f = fullfile(e, 'mask', sprintf('%04d.png', n));
    if ~isfile(f), why('no mask file') = why('no mask file') + 1; continue; end
    [~, k, c] = labelRegions(imread(f) > 0);
    if k ~= 12, why('mask regions not 12') = why('mask regions not 12') + 1; continue; end
    slot = matchFullImage(c, 12, 12);
    if isempty(slot), why('not numbered as a full image') = why('not numbered as a full image') + 1; continue; end
    dx = c(:, 1) - T.center(t, 2);
    dy = c(:, 2) - T.center(t, 1);
    for s = 1:2
        th = (3 - 2 * s) * T.angle(t) * pi / 180;          % +angle, then -angle
        u = ( cos(th) * dx + sin(th) * dy) / T.scale(t);
        v = (-sin(th) * dx + cos(th) * dy) / T.scale(t);
        P(slot, :, numel(used) + 1, s) = [u v];
    end
    used(end + 1) = n; %#ok<AGROW>
end
fprintf('DENOMINATOR: %d analysed image(s); %d used (12 patches, a rectangle plate, a template)\n', ...
    numel(imgs), numel(used));
k = keys(why);
for i = 1:numel(k)
    if why(k{i}) > 0, fprintf('  not used, %s: %d\n', k{i}, why(k{i})); end
end
if isempty(used)
    error('ndi:setup:conv:haley:noLayout', 'No image to learn the layout from.');
end

spreadOf = @(Q) squeeze(vecnorm(Q - median(Q, 3), 2, 2));     % 12 x images
d1 = spreadOf(P(:, :, :, 1));
d2 = spreadOf(P(:, :, :, 2));
fprintf('median distance from the layout: %.3f mm with +angle, %.3f mm with -angle\n', ...
    median(d1(:)), median(d2(:)));
s = 1 + (median(d2(:)) < median(d1(:)));
Q = P(:, :, :, s);
D = spreadOf(Q);
pos = median(Q, 3);
spread = [median(D, 2), max(D, [], 2)];
gaps = squareform_(pos);
L = struct('positions', pos, 'spread', spread, 'angleSign', 3 - 2 * s, ...
    'imagesUsed', used, 'minSpacing', min(gaps(gaps > 0)));

fprintf('angle sign kept: %+d; closest two patches %.2f mm apart\n', L.angleSign, L.minSpacing);
fprintf(' patch      x mm      y mm   median dev   max dev\n');
for j = 1:12
    fprintf('  %4d  %8.2f  %8.2f   %9.3f  %8.3f\n', j, pos(j, 1), pos(j, 2), spread(j, 1), spread(j, 2));
end
bad = find(any(D > options.OutlierMm, 1));
L.outliers = table(reshape(used(bad), [], 1), reshape(max(D(:, bad), [], 1), [], 1), ...
    'VariableNames', {'imageNum', 'maxDeviationMm'});
fprintf('%d image(s) with a patch more than %.2f mm from its position\n', numel(bad), options.OutlierMm);
if ~isempty(bad), disp(L.outliers); end
fprintf('spec: {"angle_sign": %d, "positions_mm": %s}\n', L.angleSign, ...
    jsonencode(round(pos, 3)));
end

function g = squareform_(p)
% pairwise distances between the rows of P
arguments
    p {mustBeNumeric}
end
n = size(p, 1);
g = zeros(n);
for a = 1:n
    for b = 1:n
        g(a, b) = norm(p(a, :) - p(b, :));
    end
end
end
