function q = vocabQuery(field, kind, handles, schemaPath)
%VOCABQUERY A query matching a stored relation, entity type or channel type by node, or by any of its names.
%
%   Q = ndi.v2.vocabQuery(FIELD, KIND, HANDLES). FIELD is the dotted path of
%   the ontology_term field ('directed_relation.relation', 'entity.type');
%   HANDLES a handle or a cellstr of them. Q is the OR, over the handles, of
%
%     FIELD.node exact_string <the handle's node>         (each node it has)
%     FIELD.name exact_string <the handle>                (written before the
%                                                          nodes; v1 lineage)
%     FIELD.name exact_string <the name the schema binds> (the ontology label
%                                                          after the flip)
%     FIELD.name exact_string <each alias>                (aliquot_of, ...)
%
%   so a database search finds the documents whatever vintage of the name
%   they carry (Jess Haley 2026-10-22 [vocabulary nodes] L1/L2: code matches
%   by node; documents written before the nodes carry only a name).
%
%   See also ndi.v2.vocabIs, ndi.v2.vocabNodes.

arguments
    field (1,:) char
    kind (1,:) char
    handles {mustBeText}
    schemaPath = getenv('DID_SCHEMA_PATH')
end

V = ndi.v2.vocabNodes(kind, schemaPath);
handles = cellstr(handles);
nodes = {};
names = {};
for k = 1:numel(handles)
    h = handles{k};
    if isKey(V.nameHandle, h)
        h = V.nameHandle(h);
    end
    names{end+1} = h; %#ok<AGROW>
    i = find(strcmp(V.handles, h), 1);
    if isempty(i)
        continue;
    end
    nodes = [nodes, V.nodes{i}]; %#ok<AGROW>
    stored = V.storedName(h);
    if ~isempty(stored), names{end+1} = stored; end %#ok<AGROW>
    allNames = keys(V.nameHandle);
    for j = 1:numel(allNames)
        if strcmp(V.nameHandle(allNames{j}), h)
            names{end+1} = allNames{j}; %#ok<AGROW>
        end
    end
end
nodes = unique(nodes, 'stable');
names = unique(names, 'stable');
q = [];
for k = 1:numel(nodes)
    q = orq(q, ndi.query([field '.node'], 'exact_string', nodes{k}, ''));
end
for k = 1:numel(names)
    q = orq(q, ndi.query([field '.name'], 'exact_string', names{k}, ''));
end
end

function q = orq(q, r)
if isempty(q)
    q = r;
else
    q = q | r;
end
end
