function ids = ensembleMembers(relations, docById, epochString)
%ENSEMBLEMEMBERS An ensemble's neurons for one epoch, in column order, read
%   from its `member_of` edges (the MIGRATED shape).
%
%   IDS = ndi.vintage.ensembleMembers(RELATIONS, DOCBYID, EPOCHSTRING)
%
%   RELATIONS is a cell of the directed_relation documents (ndi.document or
%   properties structs) whose parent is the ensemble's group entity; DOCBYID
%   maps an id to that document's properties struct ([] if absent). IDS is a
%   1-by-N cell of the member neuron ids for the epoch whose v1 id string is
%   EPOCHSTRING, ordered by the edge's `order` (0-based column index).
%
%   Decided by Jess Haley, 2026-10-22 [ensemble retired] (D2,
%   V_eta_ensemble_plan.md): the v1 per-epoch MAP document dissolves into
%   epoch-scoped `member_of` edges, child = the neuron, parent = the
%   ensemble, `order` = its column, `epoch_id` = the minted epoch entity
%   (ndi.migrate.internal.ensembleMembership). A relation is recognised as
%   `member_of` by its node RO:0002350 or its name ('member_of', or the
%   ontology label 'member of' of decision L1).
%
%   See also ndi.element.ensemble/neuronIds,
%            ndi.migrate.internal.ensembleMembership.

arguments
    relations
    docById (1,1) function_handle
    epochString (1,:) char
end

ids = {};
if isempty(relations); return; end
if ~iscell(relations); relations = {relations}; end
order = [];
for i = 1:numel(relations)
    p = relations{i};
    if isa(p, 'ndi.document') || isa(p, 'did.document'); p = p.document_properties; end
    if ~isstruct(p) || ~isfield(p, 'directed_relation'); continue; end
    r = p.directed_relation;
    if ~isMemberOf(r); continue; end
    epochId = firstEdge(p, 'epoch_id');
    if isempty(epochId); continue; end
    ep = docById(epochId);
    if isempty(ep) || ~isfield(ep, 'entity') || ~isfield(ep.entity, 'local_identifier') ...
            || ~strcmp(char(ep.entity.local_identifier), epochString)
        continue;
    end
    child = firstEdge(p, 'child_id');
    if isempty(child); continue; end
    o = numel(ids);
    if isfield(r, 'order') && ~isempty(r.order) && isnumeric(r.order)
        o = double(r.order(1));
    end
    ids{end+1} = child; %#ok<AGROW>
    order(end+1) = o; %#ok<AGROW>
end
[~, k] = sort(order);
ids = ids(k);
end

function tf = isMemberOf(r)
tf = false;
if ~isfield(r, 'relation') || ~isstruct(r.relation); return; end
node = ''; name = '';
if isfield(r.relation, 'node'); node = char(r.relation.node); end
if isfield(r.relation, 'name'); name = char(r.relation.name); end
tf = strcmp(node, 'RO:0002350') || any(strcmp(name, {'member_of', 'member of'}));
end

function v = firstEdge(p, name)
v = '';
if ~isfield(p, 'depends_on') || isempty(p.depends_on); return; end
deps = p.depends_on;
if isstruct(deps); deps = num2cell(deps); end
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name') || ~strcmp(char(d.name), name); continue; end
    if isfield(d, 'value') && ~isempty(d.value); v = char(d.value); return; end
    if isfield(d, 'document_id') && ~isempty(d.document_id); v = char(d.document_id); return; end
end
end
