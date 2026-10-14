function T = showPatchMatch(dataParentDir, imageNums)
%SHOWPATCHMATCH Draw E. coli images with each detected patch's matched patch number.
%
%   T = ndi.setup.conv.haley.showPatchMatch(DATAPARENTDIR, IMAGENUMS) opens,
%   for each image number, its patch mask (DATAPARENTDIR/haley/ecoli/mask/
%   <n>.png) in a figure and writes on each detected patch the patch number
%   the import gives it: by position on a full image (decision #62), on the
%   fitted grid when patches are missing (ndi.setup.conv.haley.
%   matchGridPatches, decision #80); the title lists the patch numbers no
%   patch was found at. It is for checking the matching by eye; nothing is
%   written.
%
%   T: one row per image -- imageNum, detected, matched (logical), missing
%   (the patch numbers with no detected patch), why (when not matched).
%
%   Example:
%     ndi.setup.conv.haley.showPatchMatch('/Users/me/data', [3626 3627]);

arguments
    dataParentDir (1,:) char {mustBeFolder}
    imageNums (1,:) double
end
e = fullfile(dataParentDir, 'haley', 'ecoli');
rows = {};
for n = imageNums
    f = fullfile(e, 'mask', sprintf('%04d.png', n));
    if ~isfile(f)
        rows(end+1, :) = {n, 0, false, '', 'no mask file'}; %#ok<AGROW>
        continue;
    end
    m = imread(f) > 0;
    [~, k, c] = labelRegions(m);
    [slot, why] = ndi.setup.conv.haley.matchGridPatches(c, 12);
    missing = '';
    if ~isempty(slot)
        missing = mat2str(setdiff(1:12, slot));
    end
    rows(end+1, :) = {n, k, ~isempty(slot), missing, why}; %#ok<AGROW>

    figure('Name', sprintf('image %d', n));
    imagesc(m); axis image; colormap(gray); hold on;
    title(sprintf('image %d: %d patch(es) detected; %s', n, k, ...
        ternary(isempty(slot), ['not matched: ' why], ['missing ' missing])));
    for j = 1:k
        label = '?';
        if ~isempty(slot), label = sprintf('%d', slot(j)); end
        text(c(j, 1), c(j, 2), label, 'Color', 'r', 'FontSize', 18, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
    end
    hold off;
end
T = cell2table(rows, 'VariableNames', {'imageNum', 'detected', 'matched', 'missing', 'why'});
end

function v = ternary(tf, a, b)
if tf, v = a; else, v = b; end
end
