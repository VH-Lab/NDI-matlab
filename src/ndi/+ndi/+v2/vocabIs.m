function tf = vocabIs(kind, term, handles, schemaPath)
%VOCABIS True when a stored relation, entity type or channel type is one of HANDLES, compared by node.
%
%   TF = ndi.v2.vocabIs(KIND, TERM, HANDLES). TERM is what a document stores
%   ({node, name} or a name); HANDLES a handle or a cellstr of them
%   ('member_of', {'organism', 'culture'}). The comparison is by node where
%   TERM has one (Jess Haley 2026-10-22 [vocabulary nodes] L1/L2), so it holds
%   whether the stored name is the snake_case handle or the ontology label.
%   A cell TERM gives a logical array of its size.
%
%   See also ndi.v2.vocabHandle, ndi.v2.vocabQuery.

arguments
    kind (1,:) char
    term
    handles {mustBeText}
    schemaPath = getenv('DID_SCHEMA_PATH')
end

handles = cellstr(handles);
% a handle the caller names by an alias (aliquot_of) means its relation
V = ndi.v2.vocabNodes(kind, schemaPath);
for k = 1:numel(handles)
    if isKey(V.nameHandle, handles{k})
        handles{k} = V.nameHandle(handles{k});
    end
end
h = ndi.v2.vocabHandle(kind, term, schemaPath);
if iscell(h)
    tf = cellfun(@(x) any(strcmp(x, handles)), h);
else
    tf = any(strcmp(h, handles));
end
end
