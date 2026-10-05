function [labeled, n, centroids] = labelRegions(mask)
%LABELREGIONS The connected regions of a logical MASK, numbered as bwlabel.
%
%   [LABELED, N, CENTROIDS] = labelRegions(MASK) numbers MASK's 8-connected
%   regions 1..N in the order bwlabel does (by each region's first pixel in
%   column-major order) without the Image Processing Toolbox. CENTROIDS is
%   N x 2, [x y] in pixels (column, row), as regionprops' Centroid.
%   Stage 10 part C, decision #62.

mask = logical(mask);
[h, w] = size(mask);
idx = find(mask);
n = 0;
labeled = zeros(h, w);
centroids = zeros(0, 2);
if isempty(idx)
    return;
end
node = zeros(h, w);
node(idx) = 1:numel(idx);
[r, c] = ind2sub([h w], idx);
s = []; t = [];
for d = [1 0; 0 1; 1 1; -1 1]'          % down, right, down-right, up-right
    rr = r + d(1); cc = c + d(2);
    ok = rr >= 1 & rr <= h & cc >= 1 & cc <= w;
    nb = zeros(size(idx));
    nb(ok) = node(sub2ind([h w], rr(ok), cc(ok)));
    keep = nb > 0;
    s = [s; node(idx(keep))]; %#ok<AGROW>
    t = [t; nb(keep)]; %#ok<AGROW>
end
comp = conncomp(graph(s, t, [], numel(idx)))';
n = max(comp);
first = accumarray(comp, idx, [n 1], @min);
[~, order] = sort(first);
rank = zeros(n, 1);
rank(order) = 1:n;
lab = rank(comp);
labeled(idx) = lab;
centroids = [accumarray(lab, c, [n 1], @mean), accumarray(lab, r, [n 1], @mean)];
end
