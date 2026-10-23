function V = vocabNodes(kind, schemaPath)
%VOCABNODES How NDI names a relation, an entity type or a channel type, and the node each one is.
%
%   V = ndi.v2.vocabNodes(KIND) for KIND 'relation', 'entity_type' or
%   'channel_type' (SCHEMAPATH defaults to DID_SCHEMA_PATH). V has fields
%
%     handles      1xN cellstr, the names NDI's code uses: the snake_case
%                  relation and entity-type names the schema stored until
%                  2026-10-22 ('part_of', 'dataset'), and the v1 channel
%                  prefixes ('ai')
%     nodes        1xN cell, each handle's nodes (cellstr; the current node
%                  first, then nodes documents may still carry; {} when the
%                  term has no node, e.g. entity type `culture`)
%     nodeHandle   containers.Map node -> handle
%     nameHandle   containers.Map stored name -> handle: each handle, its
%                  aliases, and the name the schema's binding stores for its
%                  node (so a flipped name, "part of" or "Data Set", reads as
%                  the same handle)
%     storedName   containers.Map handle -> the name the schema currently
%                  stores for the handle's node ('' when the schema has none)
%     storedNode   containers.Map handle -> the node the schema's row holds
%                  ('' when it has none): a writer stores THIS node, so a
%                  node the schema replaces (derived_from: RO:0001000 ->
%                  prov:wasDerivedFrom) is followed with no change here
%     declared     true when the schema copy at SCHEMAPATH binds this vocabulary
%
%   WHY BY NODE. did-schema #88, Decided by Jess Haley, 2026-10-22 [vocabulary
%   nodes] L1/L2 (V_eta_relation_inheritance_plan.md): every relation name and
%   entity type has a node; a relation's (and an entity type's, a channel
%   type's) stored `name` becomes the ontology label, and code matches by node.
%   [registry holds nodes] (S1): the registry holds nodes only, no synonyms,
%   so the handle -> node table is NDI's own (this file, and
%   ndi.vintage.channelTypes for the channel prefixes), while the NAME a
%   writer stores is read from the schema's binding for that node. A writer
%   built with ndi.v2.vocabTerm and a reader built with ndi.v2.vocabHandle /
%   vocabIs / vocabQuery keep working on the day the schema flips the names,
%   with no change here.
%
%   The handle table is checked against the schema by
%   ndi.unittest.setup.V2.TestVocabNodes: every node the binding registry
%   holds is here, and every handle that is still the stored name has the
%   registry's node.
%
%   Read once per file (path, date, size); `clear ndi.v2.vocabNodes` drops it.
%
%   See also ndi.v2.vocabTerm, ndi.v2.vocabHandle, ndi.v2.vocabIs,
%   ndi.v2.vocabQuery, ndi.vintage.channelTypes.

arguments
    kind (1,:) char {mustBeMember(kind, {'relation', 'entity_type', 'channel_type'})}
    schemaPath = getenv('DID_SCHEMA_PATH')
end

persistent cache
if isempty(cache)
    cache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
[rows, key] = schemaRows(kind, schemaPath);
key = [kind '|' key];
if isKey(cache, key)
    V = cache(key);
    return;
end
[handles, nodes, aliases] = table(kind);
V = struct('handles', {handles}, 'nodes', {nodes}, ...
    'nodeHandle', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'nameHandle', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'storedName', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'storedNode', containers.Map('KeyType', 'char', 'ValueType', 'char'), ...
    'declared', ~isempty(rows));
for k = 1:numel(handles)
    for j = 1:numel(nodes{k})
        if ~isKey(V.nodeHandle, nodes{k}{j})
            V.nodeHandle(nodes{k}{j}) = handles{k};
        end
    end
    V.nameHandle(handles{k}) = handles{k};
    V.storedName(handles{k}) = '';
    V.storedNode(handles{k}) = '';
end
for k = 1:size(aliases, 1)
    V.nameHandle(aliases{k, 1}) = aliases{k, 2};
end
% the names the schema stores for each node: by node when it has one, else
% (a node-less row, e.g. entity type `culture`) by the name itself
for k = 1:size(rows, 1)
    node = rows{k, 1};
    name = rows{k, 2};
    h = '';
    if ~isempty(node) && isKey(V.nodeHandle, node)
        h = V.nodeHandle(node);
    elseif isKey(V.nameHandle, name)
        h = V.nameHandle(name);
    end
    if isempty(h)
        continue;
    end
    if ~isKey(V.nameHandle, name)
        V.nameHandle(name) = h;
    end
    if isempty(V.storedName(h))
        V.storedName(h) = name;
        V.storedNode(h) = node;
    end
end
cache(key) = V;
end

% -----------------------------------------------------------------------------
function [handles, nodes, aliases] = table(kind)
%TABLE NDI's handle -> nodes table; ALIASES {name, handle} for names that are
%   not handles (a retired name read as the relation that replaced it).
aliases = cell(0, 2);
switch kind
    case 'relation'
        % node per did-schema binding_registry_meta relation_bindings at
        % 152157d (Jess Haley 2026-10-22 [vocabulary nodes] K0-K5)
        T = {
            'part_of',            {'BFO:0000050'}
            'included_in',        {'schema:isPartOf'}
            % K1: RO:0001018 is obsolete in RO's 2026-09-04 release; documents
            % written before carry it
            'contained_in',       {'RO:0001025', 'RO:0001018'}
            'member_of',          {'RO:0002350'}
            % [derived from general] (Jess Haley 2026-10-22): the general PROV
            % "derived from" replaces RO:0001000; NDI reads both, and writes
            % the node the schema's row holds (ndi.v2.vocabTerm)
            'derived_from',       {'prov:wasDerivedFrom', 'RO:0001000'}
            % K5: sample_of, aliquot_of and passage_of are ONE relation, RO
            % "derives from part of"
            'sample_of',          {'ENVO:01003004'}
            'encountered',        {'RO:0002437'}
            'has_author',         {'schema:author'}
            'cites',              {'schema:citation'}
            'funded_by',          {'schema:funding'}
            'issued_by',          {'schema:funder'}
            'affiliated_with',    {'schema:affiliation'}
            'documented_by',      {'schema:subjectOf'}
            'has_custodian',      {'schema:maintainer'}
            'contributed_by',     {'schema:contributor'}
            'copyright_holder',   {'schema:copyrightHolder'}
            'alternative_of',     {'SIO:000497'}
            'input_data',         {'schema:isBasedOn'}
            'follows_protocol',   {'EMPTY:0000378'}
            'suborganization_of', {'schema:parentOrganization'}
            'instance_of',        {'EMPTY:0000382'}
            'awarded_to',         {'schema:fundedItem'}
            'orthologous_gene_mapping', {'EMPTY:0000386'}
            'gene_alias_mapping', {'EMPTY:0000381'}
            'paired_with',        {'EMPTY:0000380'}
            'same_as',            {'owl:sameAs'}
            'sold_by',            {'OBI:0000647'}
            'developed_by',       {'schema:producer'}
            'hosted_by',          {'schema:provider'}
            'distributed_as',     {'EMPTY:0000379'}
            'temporally_aligned_with', {}
            % retired, read only: v1 lineage the migrator wrote before #30
            % retired it (ndi.vintage.elementFields)
            'observes',           {}
            };
        aliases = {
            'aliquot_of',               'sample_of'   % K5, retired (0 writers)
            'passage_of',               'sample_of'   % K5, retired (0 writers)
            'orthologous gene mapping', 'orthologous_gene_mapping'
            'gene alias mapping',       'gene_alias_mapping'
            'temporally aligned with',  'temporally_aligned_with'
            };
    case 'entity_type'
        % node per did-schema binding_registry_meta entity_type_bindings at
        % 152157d (K0, L3)
        T = {
            'organism',     {'COB:0000022'}
            'culture',      {}
            'tissue',       {'UBERON:0000479'}
            'cell',         {'CL:0000000'}
            'group',        {'NCIT:C43359'}
            'device',       {'COB:0001300'}
            'material',     {'BFO:0000040'}
            'strain',       {'NCIT:C14419'}
            'product',      {'schema:Product'}
            'software',     {'IAO:0000010'}
            'person',       {'NCIT:C25190'}
            'organization', {'OBI:0000245'}
            'funding',      {'NCIT:C16644'}
            'dataset',      {'NCIT:C47824'}
            'study',        {'NCIT:C63536'}
            'publication',  {'IAO:0000311'}
            'protocol',     {'OBI:0000272'}
            'session',      {'NCIT:C67447'}
            'epoch',        {'EMPTY:0000383'}
            % retired (did-schema #88), read only
            'web_resource', {}
            };
    case 'channel_type'
        C = ndi.vintage.channelTypes();
        T = [C(:, 1), cellfun(@(n) {n}, C(:, 2), 'UniformOutput', false)];
end
handles = reshape(T(:, 1), 1, []);
nodes = reshape(T(:, 2), 1, []);
end

% -----------------------------------------------------------------------------
function [rows, key] = schemaRows(kind, schemaPath)
%SCHEMAROWS {node, name} per term the schema copy binds for KIND, and a cache
%   key naming the file read (its path, date and size).
rows = cell(0, 2);
key = 'none';
if isempty(schemaPath)
    return;
end
switch kind
    case 'channel_type'
        f = fullfile(char(schemaPath), 'acquisition_channels.json');
    otherwise
        f = fullfile(char(schemaPath), 'binding_registry_meta.json');
end
if ~isfile(f)
    return;
end
info = dir(f);
key = sprintf('%s|%.12g|%d', f, info.datenum, info.bytes);
try
    s = jsondecode(fileread(f));
    switch kind
        case 'relation'
            r = listOf(s, 'relation_bindings');
            for k = 1:numel(r)
                if isfield(r{k}, 'relation') && isstruct(r{k}.relation)
                    rows(end+1, :) = {strOf(r{k}.relation, 'node'), strOf(r{k}.relation, 'name')}; %#ok<AGROW>
                end
            end
        case 'entity_type'
            r = listOf(s, 'entity_type_bindings');
            for k = 1:numel(r)
                if isfield(r{k}, 'type')
                    rows(end+1, :) = {strOf(r{k}, 'node'), char(r{k}.type)}; %#ok<AGROW>
                end
            end
        case 'channel_type'
            v = channelBindingValues(s);
            for k = 1:numel(v)
                rows(end+1, :) = {strOf(v{k}, 'node'), strOf(v{k}, 'name')}; %#ok<AGROW>
            end
    end
catch
    rows = cell(0, 2);
end
end

function v = channelBindingValues(s)
% acquisition_channels.channels.type's binding values
v = {};
fs = listOf(s, 'fields');
for k = 1:numel(fs)
    if ~strcmp(strOf(fs{k}, 'name'), 'channels'), continue; end
    sub = listOf(fs{k}, 'fields');
    for j = 1:numel(sub)
        if strcmp(strOf(sub{j}, 'name'), 'type') && isfield(sub{j}, 'constraints') ...
                && isstruct(sub{j}.constraints) && isfield(sub{j}.constraints, 'binding') ...
                && isfield(sub{j}.constraints.binding, 'values')
            v = listOf(sub{j}.constraints.binding, 'values');
        end
    end
end
end

function c = listOf(s, f)
c = {};
if isstruct(s) && isfield(s, f)
    c = s.(f);
    if isstruct(c), c = num2cell(c); end
    if ~iscell(c), c = {}; end
end
end

function v = strOf(s, f)
v = '';
if isstruct(s) && isfield(s, f) && (ischar(s.(f)) || isstring(s.(f)))
    v = char(s.(f));
end
end
