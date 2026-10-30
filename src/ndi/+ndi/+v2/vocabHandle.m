function h = vocabHandle(kind, term, schemaPath)
%VOCABHANDLE The name NDI's code uses for a stored relation, entity type or channel type.
%
%   H = ndi.v2.vocabHandle(KIND, TERM) for KIND 'relation', 'entity_type',
%   'channel_type' or 'clock' (the ndi.time.clocktype string of a stored
%   value.clock: Jess Haley 2026-10-26 [clock terms get nodes]). TERM is what a document stores -- an ontology_term
%   ({node, name}) or a char name. H is NDI's handle for it ('part_of',
%   'dataset', 'ai'), found
%
%     1. BY NODE, when TERM has a node NDI knows (Jess Haley 2026-10-22
%        [vocabulary nodes] L1/L2: code matches by node), whatever name is
%        stored beside it;
%     2. else by NAME: a handle, an alias (a retired relation read as the one
%        that replaced it: aliquot_of -> sample_of), or the name the schema's
%        binding stores for a node (the ontology label after the flip);
%     3. else TERM's name itself, unchanged, so a vocabulary NDI does not know
%        compares exactly as it did before.
%
%   TERM may be a cell array or a struct array; H is then a cellstr of the
%   same number of elements. An empty TERM gives ''.
%
%   See also ndi.v2.vocabNodes, ndi.v2.vocabIs, ndi.v2.vocabTerm,
%   ndi.v2.vocabQuery.

arguments
    kind (1,:) char
    term = ''
    schemaPath = getenv('DID_SCHEMA_PATH')
end

V = ndi.v2.vocabNodes(kind, schemaPath);
if iscell(term)
    h = cellfun(@(x) one(V, x), term, 'UniformOutput', false);
elseif isstruct(term) && numel(term) > 1
    h = arrayfun(@(x) one(V, x), term, 'UniformOutput', false);
else
    h = one(V, term);
end
end

function h = one(V, term)
node = '';
name = '';
if isstruct(term)
    if isfield(term, 'node') && (ischar(term.node) || isstring(term.node))
        node = strtrim(char(term.node));
    end
    if isfield(term, 'name') && (ischar(term.name) || isstring(term.name))
        name = char(term.name);
    end
elseif ischar(term) || isstring(term)
    name = char(term);
end
if ~isempty(node) && isKey(V.nodeHandle, node)
    h = V.nodeHandle(node);
elseif ~isempty(name) && isKey(V.nameHandle, name)
    h = V.nameHandle(name);
else
    h = name;
end
end
