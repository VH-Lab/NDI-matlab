function slot = matchFullImage(c, nDetected, nSubjects)
%MATCHFULLIMAGE SLOT(j) = the patch subject number of detected patch j, or [] when the
% image cannot be matched. 12: number as bwlabel numbers an ideal staggered
% grid (left to right; patches sharing a column, top to bottom). 1: itself.
arguments
    c {mustBeNumeric}
    nDetected (1,1) {mustBeNumeric}
    nSubjects (1,1) {mustBeNumeric}
end
slot = [];
if nDetected == 1 && nSubjects == 1
    slot = 1;
    return;
end
if nDetected ~= 12 || nSubjects ~= 12
    return;
end
% C: the detected patches' centroids, x and y in label order
% three rows of four, by y
[~, byY] = sort(c(:, 2));
rowOf = zeros(12, 1);
rowOf(byY) = repelem(1:3, 4);
gapY = diff(c(byY, 2));
if min(gapY([4 8])) <= max(gapY([1:3 5:7 9:11]))
    return;                                % the rows are not cleanly apart
end
% within each row, the step between neighbours
steps = [];
for r = 1:3
    steps = [steps; diff(sort(c(rowOf == r, 1)))]; %#ok<AGROW>
end
tol = median(steps) / 4;
% columns: patches whose x differ by less than a quarter step share one
[~, byX] = sort(c(:, 1));
col = zeros(12, 1);
col(byX(1)) = 1;
for i = 2:12
    col(byX(i)) = col(byX(i - 1)) + (c(byX(i), 1) - c(byX(i - 1), 1) >= tol);
end
if max(col) ~= 8
    return;                                % not the staggered 8-column layout
end
[~, order] = sortrows([col, c(:, 2)]);     % left to right, then top to bottom
slot = zeros(12, 1);
slot(order) = 1:12;
end
