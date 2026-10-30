function t = vocabTerm(kind, handle, schemaPath)
%VOCABTERM The {node, name} term a writer stores for a relation, an entity type or a channel type.
%
%   T = ndi.v2.vocabTerm(KIND, HANDLE) for KIND 'relation', 'entity_type' or
%   'channel_type' and HANDLE the name NDI's code uses ('part_of', 'group',
%   'ai'). T is the schema binding's row for that handle -- its node and the
%   name it stores (found by any node NDI knows for the handle, so a node the
%   schema replaces is followed: derived_from RO:0001000 -> prov:wasDerivedFrom,
%   Jess Haley 2026-10-22 [derived from general]); T.name is the name
%   the schema's binding stores for that node -- the snake_case name today,
%   the ontology label once the schema flips it (Jess Haley 2026-10-22
%   [vocabulary nodes] L1/L2) -- or HANDLE itself when the schema copy has no
%   binding for it (an older copy, or no DID_SCHEMA_PATH). A HANDLE NDI does
%   not know is returned as {'' , HANDLE}, which is what writers stored before.
%
%   CLOCKS (KIND 'clock'). Decided by Jess Haley, 2026-10-26 [clock terms
%   get nodes] (did-schema V_eta_go_forward_class_audit.md). While the
%   schema's clock rows still hold EMPTY nodes, T is the decided node from
%   ndi.v2.vocabNodes' table with the name the schema stores
%   ({EMPTY:0000403, 'dev_local_time'}); once did-schema fills the nodes, T is
%   the schema's row ({EMPTY:0000403, 'device local time'}). Writing the node
%   now cannot be refused: DID-matlab's binding check
%   (did2.schema.cache, bindingValueNotInSet) admits a value whose node is in
%   no member when its name is one.
%
%   HANDLE may be a cellstr; T is then a 1xN struct array.
%
%   Example:
%       rel = ndi.v2.vocabTerm('relation', 'member_of');
%       doc = did2.build.directedRelation(childId, groupId, rel, 'SessionId', sid);
%
%   See also ndi.v2.vocabNodes, ndi.v2.vocabHandle, ndi.v2.vocabIs.

arguments
    kind (1,:) char
    handle {mustBeText}
    schemaPath = getenv('DID_SCHEMA_PATH')
end

V = ndi.v2.vocabNodes(kind, schemaPath);
handle = cellstr(handle);
node = cell(size(handle));
name = cell(size(handle));
for k = 1:numel(handle)
    h = handle{k};
    if isKey(V.nameHandle, h)
        h = V.nameHandle(h);
    end
    i = find(strcmp(V.handles, h), 1);
    node{k} = '';
    name{k} = handle{k};
    if isempty(i)
        continue;
    end
    % the schema's row, when it has one: its node and its name (a node or
    % name the schema changes is followed); else NDI's own table
    stored = V.storedName(h);
    if ~isempty(stored)
        node{k} = V.storedNode(h);
        name{k} = stored;
        if isempty(node{k}) && strcmp(kind, 'clock') && ~isempty(V.nodes{i})
            % [clock terms get nodes]: the decided node, while the schema's
            % row is still empty
            node{k} = V.nodes{i}{1};
        end
    else
        if ~isempty(V.nodes{i})
            node{k} = V.nodes{i}{1};
        end
        name{k} = h;
    end
end
t = struct('node', reshape(node, 1, []), 'name', reshape(name, 1, []));
end
