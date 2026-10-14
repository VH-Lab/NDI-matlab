function T = timesOf(container, refIds, cache)
%TIMESOF Many time references, read and resolved together.
%
%   T = ndi.v2.timesOf(CONTAINER, REFIDS) returns a containers.Map, time
%   reference id -> the struct ndi.v2.timeOf gives, for each id found. The
%   references, what they are relative to, and those documents' own time
%   references are fetched level by level in batches (ndi.v2.getDocuments)
%   before anything is resolved, and each anchor is resolved once however
%   many references point at it: a thousand references relative to one
%   session cost one lookup of the session. CACHE (a containers.Map, made
%   when not given) keeps documents and results for later calls.
%
%   See also ndi.v2.timeOf.

if nargin < 3 || ~isa(cache, 'containers.Map')
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
refIds = unique(cellstr(refIds), 'stable');
T = containers.Map('KeyType', 'char', 'ValueType', 'any');
% prefetch: the references, then what they point at, then those documents'
% time references, up to timeOf's 8 levels
todo = refIds;
for level = 1:8
    if isempty(todo), break; end
    got = ndi.v2.getDocuments(container, todo, cache);
    next = {};
    for k = 1:numel(todo)
        if ~isKey(got, todo{k}), continue; end
        p = ndi.v2.props(got(todo{k}));
        next = [next, ndi.v2.edgeIds(p, 'referent_id'), ndi.v2.edgeIds(p, 'time_reference_id')]; %#ok<AGROW>
    end
    next = unique(next, 'stable');
    todo = next(~cellfun(@(i) isKey(cache, ['doc:' i]), next));
end
for k = 1:numel(refIds)
    key = ['doc:' refIds{k}];
    if ~isKey(cache, key), continue; end
    if isKey(cache, ['time:' refIds{k}])
        T(refIds{k}) = cache(['time:' refIds{k}]);
    else
        r = ndi.v2.timeOf(container, cache(key), 0, cache);
        cache(['time:' refIds{k}]) = r;
        T(refIds{k}) = r;
    end
end
end
