function q = anyOf(qs)
%ANYOF The OR of the ndi.query objects in cell array QS, as a balanced tree.
%
%   Q = ndi.v2.anyOf(QS) nests log2(N) deep rather than N, which keeps the
%   SQL and the in-memory recheck shallow for a few hundred ids. Callers
%   keep N to about 200 per search.

while numel(qs) > 1
    n = floor(numel(qs) / 2);
    nx = cell(1, ceil(numel(qs) / 2));
    for i = 1:n, nx{i} = qs{2*i - 1} | qs{2*i}; end
    if mod(numel(qs), 2), nx{end} = qs{end}; end
    qs = nx;
end
q = qs{1};
end
