function sid = sessionIdOf(doc)
%SESSIONIDOF The id of the session a document is stored with.
%
%   SID = ndi.v2.sessionIdOf(DOC) reads DOC's session id (DOC an
%   ndi.document, a did2.document or a property struct):
%     - its `base.session_id` FIELD, when it has one (a v1 document, and a
%       migrated V_eta document);
%     - otherwise its `session_id` EDGE (did-schema
%       V_eta_relation_inheritance_plan.md, 2026-10-20, a proposal built ahead
%       of signature: `base` has no session_id field and every document has a
%       required `session_id` edge to the session or dataset entity it is
%       stored with, whose base.id IS the session id).
%   '' when it has neither.
%
%   A query on `base.session_id` needs no change: against a did2 database DID
%   answers it from the field or the edge.
%
%   See also ndi.document/session_id.

arguments
    doc
end

p = ndi.v2.props(doc);
sid = '';
if isfield(p, 'base') && isstruct(p.base) && isfield(p.base, 'session_id')
    sid = char(p.base.session_id);
    return;
end
ids = ndi.v2.edgeIds(p, 'session_id');
if ~isempty(ids)
    sid = ids{1};
end
end
