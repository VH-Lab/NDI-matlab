function [s, cache] = wiredDeviceString(S, st, sysId, elId, cache)
%WIREDDEVICESTRING A migrated probe-map row's v1 devicestring, read from the
%   statement's system and its probe's wiring relation.
%
%   [S_OUT, CACHE] = ndi.vintage.wiredDeviceString(SESSION, ST, SYSID, ELID, CACHE)
%   gives 'vhspike2:ai11-14;di1' for the statement ST (an ndi.document),
%   its acquisition system SYSID and its probe ELID; CACHE is a struct whose
%   `doc` is a containers.Map of documents already read by id (as
%   ndi.vintage.ingestedEpochs keeps it; pass struct('doc', containers.Map())).
%   Decided by Jess Haley, 2026-11-01, did-schema
%   did_v2_go_forward_class_audit.md [probe wiring is a relation], [wiring
%   relation term].
%
% 'vhspike2:ai11-14;di1' from the statement's system and its probe's wiring
% relation: directed_relation `connected to` (RO:0002170), child the probe,
% parent the system, timed by the statement's anchor, one condition per
% channel type (variable the type's term, matrix its numbers). No relation:
% the system's name alone (the row named no channels).
s = '';
[sys, cache] = docById(S, sysId, cache);
if isempty(sys)
    return;
end
s = char(ndi.vintage.objectName(sys));
anchors = ndi.v2.edgeIds(st.document_properties, 'time_reference_id');
if isempty(anchors)
    return;
end
q = ndi.query('', 'isa', 'directed_relation', '') & ...
    ndi.query('', 'depends_on', 'child_id', elId) & ...
    ndi.query('', 'depends_on', 'parent_id', sysId) & ...
    ndi.v2.anyOf(cellfun(@(a) ndi.query('', 'depends_on', 'time_reference_id', a), ...
        anchors, 'UniformOutput', false));
rels = S.database_search(q);
groups = {};
for r = 1:numel(rels)
    p = rels{r}.document_properties;
    if ~isfield(p, 'directed_relation'), continue; end
    dr = p.directed_relation;
    if ~isfield(dr, 'relation') || ~isstruct(dr.relation) || ...
            ~strcmpi(char(dr.relation.node), 'RO:0002170')
        continue;
    end
    if ~isfield(dr, 'conditions') || isempty(dr.conditions), break; end
    cs = dr.conditions;
    if isstruct(cs), cs = num2cell(cs); end
    for g = 1:numel(cs)
        c = cs{g};
        if ~isstruct(c) || ~isfield(c, 'variable'), continue; end
        nums = [];
        if isfield(c, 'matrix'), nums = double(c.matrix(:)'); end
        groups{end+1} = [char(ndi.vintage.channelPrefix(c.variable)) ranges(nums)]; %#ok<AGROW>
    end
    break;   % one wiring per probe, rig and epoch
end
if ~isempty(groups)
    s = [s ':' strjoin(groups, ';')];
end
end

function [d, cache] = docById(S, id, cache)
d = [];
if isempty(id), return; end
if isKey(cache.doc, id)
    d = cache.doc(id);
    return;
end
r = S.database_search(ndi.query('base.id', 'exact_string', id, ''));
if ~isempty(r)
    d = r{1};
end
cache.doc(id) = d;
end

function t = ranges(n)
% [11 12 13 14 20] -> '11-14,20' (ndi.daq.daqsystemstring's own spelling)
t = '';
if isempty(n), return; end
n = n(:)';
parts = {};
i = 1;
while i <= numel(n)
    j = i;
    while j < numel(n) && n(j+1) == n(j) + 1
        j = j + 1;
    end
    if j > i
        parts{end+1} = sprintf('%d-%d', n(i), n(j)); %#ok<AGROW>
    else
        parts{end+1} = sprintf('%d', n(i)); %#ok<AGROW>
    end
    i = j + 1;
end
t = strjoin(parts, ',');
end
