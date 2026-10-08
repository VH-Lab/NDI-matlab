function S = stays(container, ids, side, cache)
%STAYS The contained_in relations of some subjects, with when each held.
%
%   S = ndi.v2.stays(CONTAINER, IDS, SIDE, CACHE) reads the directed
%   relations named `contained_in` whose SIDE end ('child' or 'parent') is
%   one of the ids IDS, and resolves their time references in batches
%   (ndi.v2.timesOf, CACHE shared). S is a struct array, one entry per
%   relation:
%     id            the relation document's id
%     child, parent the subject that was contained, and its container
%     distributive  the relation holds of each member of a group child
%     start, end    when the stay began and ended (UTC datetimes)
%     tol, end_tol  [minus plus] seconds of the start and of the end
%     decided       true when both ends are known: a stay with no time, or
%                   with no end, or known only as a bound on its anchor
%                   ('before the seeding') cannot be compared with anything
%
%   Used by ndi.subject for context (V_eta tenet T17): a container's
%   interactions reach what it contained only while it was contained.
%
%   See also ndi.v2.overlaps, ndi.v2.timesOf.

if nargin < 4 || ~isa(cache, 'containers.Map')
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
ids = unique(cellstr(ids), 'stable');
S = struct('id', {}, 'child', {}, 'parent', {}, 'distributive', {}, 'start', {}, ...
    'end', {}, 'tol', {}, 'end_tol', {}, 'decided', {});
if isempty(ids), return; end
edge = [char(side) '_id'];
docs = {};
for c = 1:200:numel(ids)
    part = ids(c:min(c + 199, numel(ids)));
    q = ndi.v2.anyOf(cellfun(@(i) ndi.query('', 'depends_on', edge, i), part, 'UniformOutput', false));
    docs = [docs, reshape(container.database_search(ndi.query('', 'isa', 'directed_relation', '') & q), 1, [])]; %#ok<AGROW>
end
refs = {};
keep = false(1, numel(docs));
for i = 1:numel(docs)
    p = ndi.v2.props(docs{i});
    keep(i) = strcmp(ndi.v2.termName(ndi.v2.blockOf(p, 'directed_relation', 'relation', '')), 'contained_in');
    if keep(i), refs = [refs, ndi.v2.edgeIds(p, 'time_reference_id')]; end %#ok<AGROW>
end
docs = docs(keep);
times = containers.Map('KeyType', 'char', 'ValueType', 'any');
if ~isempty(refs), times = ndi.v2.timesOf(container, unique(refs), cache); end
for i = 1:numel(docs)
    p = ndi.v2.props(docs{i});
    child = ndi.v2.edgeIds(p, 'child_id');
    parent = ndi.v2.edgeIds(p, 'parent_id');
    if isempty(child) || isempty(parent), continue; end
    d = ndi.v2.blockOf(p, 'directed_relation', 'distributive', false);
    e = struct('id', char(p.base.id), 'child', child{1}, 'parent', parent{1}, ...
        'distributive', ~isempty(d) && (islogical(d) || isnumeric(d)) && logical(d(1)), ...
        'start', NaT('TimeZone', 'UTC'), 'end', NaT('TimeZone', 'UTC'), ...
        'tol', [0 0], 'end_tol', [0 0], 'decided', false);
    r = ndi.v2.edgeIds(p, 'time_reference_id');
    for k = 1:numel(r)
        if ~isKey(times, r{k}), continue; end
        t = times(r{k});
        if isnat(t.start) || isnat(t.end) || strcmp(t.resolved_by, 'relation'), continue; end
        e.start = t.start; e.end = t.end;
        e.tol = zeroNaN(t.tolerance); e.end_tol = zeroNaN(t.end_tolerance);
        e.decided = true;
        break;
    end
    S(end+1) = e; %#ok<AGROW>
end
end

function t = zeroNaN(t)
% [minus plus] seconds, 0 where unknown
if isempty(t), t = [0 0]; end
if isscalar(t), t = [t t]; end
t(isnan(t)) = 0;
end
