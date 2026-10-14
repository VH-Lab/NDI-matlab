function T = showPatchMatch(dataParentDir, imageNums)
%SHOWPATCHMATCH Draw E. coli images with each detected patch's matched patch number.
%
%   T = ndi.setup.conv.haley.showPatchMatch(DATAPARENTDIR, IMAGENUMS) opens,
%   for each image number, its patch mask (DATAPARENTDIR/haley/ecoli/mask/
%   <n>.png) in a figure and writes on each detected patch, in red, the
%   patch number the import gives it: by position on a full image (decision
%   #62), else by the nearest patch position of the acetate template
%   registered on the image's brightfield image (decision #80). The 12
%   template positions are drawn as yellow circles with their numbers, so
%   an undetected patch's place shows. Nothing is written.
%
%   It reads bacteria.mat (metaData), the extract (ecoli/analyzeGFP_24-04-04
%   .mat, with `template` from extractTemplates) and the spec's
%   `ecoli_patch_layout`.
%
%   T: one row per image -- imageNum, detected, method ('full image',
%   'template' or ''), missing (patch numbers with no detected patch), why
%   (when not matched).
%
%   Example:
%     ndi.setup.conv.haley.showPatchMatch('/Users/me/data', [3626 3627]);

arguments
    dataParentDir (1,:) char {mustBeFolder}
    imageNums (1,:) double
end
e = fullfile(dataParentDir, 'haley', 'ecoli');
B = load(fullfile(e, 'bacteria.mat'), 'metaData');
M = B.metaData;
X = load(fullfile(e, 'analyzeGFP_24-04-04.mat'), 'template');
TPL = X.template;
spec = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'import_V2_spec.json')));
layout = spec.ecoli_patch_layout;
pos = reshape(layout.positions_mm, [], 2);

rows = {};
for n = imageNums
    f = fullfile(e, 'mask', sprintf('%04d.png', n));
    if ~isfile(f)
        rows(end+1, :) = {n, 0, '', '', 'no mask file'}; %#ok<AGROW>
        continue;
    end
    m = imread(f) > 0;
    [~, k, c] = labelRegions(m);
    slot = matchFullImage(c, k, 12);
    method = 'full image';
    why = '';
    r = find(M.imageNum == n, 1);
    t = [];
    if ~isempty(r)
        t = find(TPL.imageNum == M.brightfieldImageNum(r), 1);
    end
    if isempty(slot)
        method = 'template';
        if isempty(t)
            why = 'no template registered on its brightfield image';
        else
            [slot, why] = ndi.setup.conv.haley.matchTemplatePatches(c, TPL.center(t, :), ...
                TPL.angle(t), TPL.scale(t), layout);
        end
        if isempty(slot), method = ''; end
    end
    missing = '';
    if ~isempty(slot), missing = mat2str(setdiff(1:12, slot)); end
    rows(end+1, :) = {n, k, method, missing, why}; %#ok<AGROW>

    figure('Name', sprintf('image %d', n));
    imagesc(m); axis image; colormap(gray); hold on;
    if ~isempty(t)
        % the template positions in this image: the inverse of
        % matchTemplatePatches' transform
        th = layout.angle_sign * TPL.angle(t) * pi / 180;
        u = pos(:, 1) * TPL.scale(t);
        v = pos(:, 2) * TPL.scale(t);
        px = TPL.center(t, 2) + cos(th) * u - sin(th) * v;
        py = TPL.center(t, 1) + sin(th) * u + cos(th) * v;
        plot(px, py, 'yo', 'MarkerSize', 22, 'LineWidth', 1.5);
        for j = 1:12
            text(px(j) + 40, py(j) - 40, sprintf('%d', j), 'Color', 'y', 'FontSize', 11);
        end
    end
    for j = 1:k
        label = '?';
        if ~isempty(slot), label = sprintf('%d', slot(j)); end
        text(c(j, 1), c(j, 2), label, 'Color', 'r', 'FontSize', 18, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
    end
    if isempty(slot)
        title(sprintf('image %d: %d detected; not matched: %s', n, k, why));
    else
        title(sprintf('image %d: %d detected; %s; missing %s', n, k, method, missing));
    end
    hold off;
end
T = cell2table(rows, 'VariableNames', {'imageNum', 'detected', 'method', 'missing', 'why'});
end
