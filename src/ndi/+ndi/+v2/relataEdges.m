function names = relataEdges()
%RELATAEDGES The names an undirected relation's ends are stored under.
%
%   NAMES = ndi.v2.relataEdges() is {'relatum_id'}: the name did-schema
%   declares since [undirected ends are relata] (Jess Haley, 2026-11-01,
%   did_v2_go_forward_class_audit.md). The old name, `entity_id`, is no longer
%   searched or read: the readers took both names, did-schema renamed the
%   edge, and the code then dropped `entity_id` (the decision's last step).
%   A writer writes `relatum_id` (did2.build.undirectedRelation).
%
%   See also ndi.v2.relata.

names = {'relatum_id'};
end
