function names = relataEdges()
%RELATAEDGES The names an undirected relation's ends are stored under.
%
%   NAMES = ndi.v2.relataEdges() is {'relatum_id', 'entity_id'}: the name
%   did-schema declares since [undirected ends are relata] (Jess Haley,
%   2026-11-01, did_v2_go_forward_class_audit.md) and the name before it. A
%   reader searches and reads both (ndi.v2.relata); a writer writes the one
%   the schema declares (did2.build.undirectedRelation asks the schema).
%
%   See also ndi.v2.relata.

names = {'relatum_id', 'entity_id'};
end
