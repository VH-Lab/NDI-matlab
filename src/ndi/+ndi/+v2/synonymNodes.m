function nodes = synonymNodes(patterns)
%SYNONYMNODES The registered terms that go by a name: their label or a synonym.
%
%   NODES = ndi.v2.synonymNodes(PATTERNS): PATTERNS is a text pattern or a
%   cell array of them ('*' a wildcard, ndi.v2.matchTerm). NODES are the
%   nodes of the terms in DID-schema's term registry (did2.schema.termIndex;
%   tenet T19) one of whose names -- the ontology's label or a synonym,
%   ndi.v2.synonyms: ndi.ontology.lookup, kept on disk -- matches a pattern.
%   So 'meter' finds om:metre (OM's English alternative label) and 'mean'
%   finds NCIT:C53319 Arithmetic Mean, although a document stores 'metre'
%   and 'Arithmetic Mean'.
%
%   {} when the schema in use has no term registry (a migrated V_eta schema) or
%   DID-matlab has no did2.schema.termIndex. The registry is what makes this
%   cheap: it lists every vocabulary term a dataset can hold, so nothing is
%   read from the database to find candidates.
%
%   See also ndi.v2.synonyms, ndi.v2.searchStatements, ndi.term.

arguments
    patterns
end

nodes = {};
patterns = cellstr(patterns);
if isempty(patterns) || isempty(which('did2.schema.termIndex'))
    return;
end
ix = did2.schema.termIndex();
if ~ix.present
    return;
end
entries = values(ix.byNode);
for k = 1:numel(entries)
    node = entries{k}.node;
    names = ndi.v2.synonyms(node);
    if any(cellfun(@(n) ndi.v2.matchTerm(n, patterns), names))
        nodes{end+1} = node; %#ok<AGROW>
    end
end
end
