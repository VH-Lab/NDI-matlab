function c = closest(word, candidates)
%CLOSEST The candidate nearest to WORD, for a "did you mean", or '' when none is near.
%
%   C = ndi.v2.closest(WORD, CANDIDATES) compares WORD with each candidate
%   ignoring case, by edit distance (the single-character insertions,
%   deletions and substitutions that turn one into the other), and returns
%   the nearest one when it is within max(1, min(3, floor(length/4))) edits
%   of WORD -- 'stran' -> 'strain', 'Caenorhabdiits elegans' ->
%   'Caenorhabditis elegans' -- and '' otherwise (or when WORD is itself one
%   of them).

c = '';
candidates = cellstr(candidates);
if isempty(candidates) || isempty(word), return; end
w = lower(char(word));
if any(strcmpi(candidates, w)), return; end
limit = max(1, min(3, floor(numel(w) / 4)));
best = Inf;
for k = 1:numel(candidates)
    d = editDistance(w, lower(candidates{k}));
    if d < best
        best = d;
        c = candidates{k};
    end
end
if best > limit, c = ''; end
end

function d = editDistance(a, b)
m = numel(a); n = numel(b);
prev = 0:n;
for i = 1:m
    cur = [i, zeros(1, n)];
    for j = 1:n
        cur(j + 1) = min([prev(j + 1) + 1, cur(j) + 1, prev(j) + (a(i) ~= b(j))]);
    end
    prev = cur;
end
d = prev(end);
end
