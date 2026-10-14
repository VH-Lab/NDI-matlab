function [slot, why] = matchGridPatches(c, nSubjects)
%MATCHGRIDPATCHES Place detected E. coli patches on the 12-patch staggered grid.
%
%   [SLOT, WHY] = ndi.setup.conv.haley.matchGridPatches(C, NSUBJECTS) takes
%   the centroids C (N x 2, [x y] pixels, N <= 12) of the patches detected
%   in one image of a `rectangle` plate and returns SLOT(j), the patch
%   subject number of detected patch j, numbered as the import numbers a
%   full image (decision #62: left to right; patches sharing a column, top
%   to bottom). SLOT is [] and WHY says why when the placement is not
%   certain. Decision #80.
%
%   THE GRID (measured on plate 124, Jess 2026-10-14): three rows ~500 px
%   apart; rows 1 and 3 at four positions one step (~575 px) apart; row 2
%   half a step to the right of them -- 8 columns. A patch is placed by its
%   row (the two largest gaps in y split the rows) and its column (its x in
%   half steps, fitted to all detected patches), and the placement is kept
%   only when it is the ONLY one consistent with the grid:
%     - three rows, cleanly apart (each gap between rows > 3x any gap
%       within a row), at most 4 patches per row;
%     - every x within 0.3 half steps of a grid column, rows 1 and 3 on one
%       parity of column and row 2 on the other;
%     - exactly one way to lay the 4-position rows over the detected
%       columns (with a patch missing at the end of a row, two may fit);
%     - no two detected patches on one position.

slot = [];
why = '';
n = size(c, 1);
if nSubjects ~= 12
    why = sprintf('the plate has %d patch subjects, not 12', nSubjects);
    return;
end
if n < 3 || n > 12
    why = sprintf('%d detected patches', n);
    return;
end

% rows: the two largest gaps in y
[ys, byY] = sort(c(:, 2));
gaps = diff(ys);
[g, gi] = sort(gaps, 'descend');
cuts = sort(gi(1:2));
within = gaps;
within(cuts) = [];
if ~isempty(within) && min(g(1:2)) <= 3 * max(within)
    why = 'the rows are not cleanly apart';
    return;
end
row = zeros(n, 1);
row(byY(1:cuts(1))) = 1;
row(byY(cuts(1) + 1:cuts(2))) = 2;
row(byY(cuts(2) + 1:end)) = 3;
if any(accumarray(row, 1, [3 1]) > 4) || any(accumarray(row, 1, [3 1]) == 0)
    why = 'a row holds no patch or more than 4';
    return;
end

% the step: neighbours within a row (a missing patch makes a double step)
d = [];
for r = 1:3
    d = [d; diff(sort(c(row == r, 1)))]; %#ok<AGROW>
end
if isempty(d) || min(d) <= 0
    why = 'no two patches share a row';
    return;
end
step = median(d(d < 1.5 * min(d)));

% columns in half steps, then refit origin and half step to all patches
h = round((c(:, 1) - min(c(:, 1))) / (step / 2));
if numel(unique(h)) >= 2
    fit = polyfit(h, c(:, 1), 1);
    hx = (c(:, 1) - fit(2)) / fit(1);
else
    hx = h;
end
h = round(hx);
if any(abs(hx - h) > 0.3)
    why = 'a patch lies between grid columns';
    return;
end
p13 = unique(mod(h(row ~= 2), 2));
p2 = unique(mod(h(row == 2), 2));
if numel(p13) > 1 || numel(p2) > 1 || (~isempty(p13) && ~isempty(p2) && p13 == p2)
    why = 'the rows are not staggered by half a step';
    return;
end

% lay the grid: rows 1 and 3 at s, s+2, s+4, s+6; row 2 at t, ..., t+6, t = s +/- 1
h13 = h(row ~= 2);
h2 = h(row == 2);
fits = zeros(0, 2);
for s = (max(h13) - 6):min(h13)
    if mod(s - h13(1), 2) ~= 0, continue; end
    for t = [s - 1, s + 1]
        if all(h2 >= t & h2 <= t + 6)
            fits(end + 1, :) = [s, t]; %#ok<AGROW>
        end
    end
end
if size(fits, 1) ~= 1
    why = sprintf('%d ways to lay the grid over the detected patches', size(fits, 1));
    return;
end
s = fits(1); t = fits(2);

% the 12 positions, numbered left to right and top to bottom
pos = [ones(4, 1), s + (0:2:6)'; 2 * ones(4, 1), t + (0:2:6)'; 3 * ones(4, 1), s + (0:2:6)'];
[~, order] = sortrows([pos(:, 2), pos(:, 1)]);
number = zeros(12, 1);
number(order) = 1:12;
slot = zeros(n, 1);
for j = 1:n
    k = find(pos(:, 1) == row(j) & pos(:, 2) == h(j));
    slot(j) = number(k);
end
if numel(unique(slot)) ~= n
    slot = [];
    why = 'two detected patches on one grid position';
end
end
