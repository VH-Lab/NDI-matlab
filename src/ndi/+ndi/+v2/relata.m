function ids = relata(p)
%RELATA The ends of an undirected relation, under either name of its edge.
%
%   IDS = ndi.v2.relata(P) returns the document ids an `undirected_relation`
%   document's ends name (a row cellstr): its `relatum_id` edges, then any
%   `entity_id` edges. did-schema renamed the ends from `entity_id` to
%   `relatum_id` and let each be an entity, a statement or a standalone value
%   (did_v2_go_forward_class_audit.md, Jess Haley 2026-11-01 [undirected
%   relation widened], [undirected ends are relata]); a document written
%   before the rename still names them `entity_id`, so readers take both until
%   the schema and the writers drop it. P is a document's properties
%   (ndi.v2.props).
%
%   See also ndi.v2.relataEdges, ndi.v2.sameAs.

arguments
    p
end

ids = {};
for e = ndi.v2.relataEdges()
    ids = [ids, ndi.v2.edgeIds(p, e{1})]; %#ok<AGROW>
end
end
