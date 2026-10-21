function docs = sessionRecord(database, sessionId)
%SESSIONRECORD The document that records a session (or a dataset) itself.
%
%   DOCS = ndi.v2.sessionRecord(DATABASE, SESSIONID) returns, as a cell array
%   of ndi.document objects, the document(s) in DATABASE that record the
%   session SESSIONID. DATABASE is an ndi.database (searched without a session
%   scope), or an ndi.session whose id is SESSIONID, searched through
%   database_search (its `database` is not readable outside ndi.session and
%   ndi.dataset; the scope it adds holds of the record, whose session id is
%   its own id):
%     1. the `session` or `dataset` entity whose base.id IS SESSIONID (did-schema
%        V_eta_relation_inheritance_plan.md, 2026-10-20, a proposal built ahead
%        of signature: session_id is an edge, and the session or dataset entity
%        it points at has the session id as its own id; a dataset's documents
%        point at the dataset entity);
%     2. when there is none, every `session` document (v1, or a V2 `session`
%        entity) whose session id is SESSIONID: the only way to find it in a
%        v1 or migrated database, where the session document has an id of its
%        own.
%   Empty when neither finds one.
%
%   See also ndi.session.dir, ndi.dataset.dir, ndi.v2.sessionIdOf.

arguments
    database
    sessionId (1,:) char
end

if isa(database, 'ndi.session')
    search = @(q) database.database_search(q);
else
    search = @(q) database.search(q);
end
docs = search(ndi.query('base.id', 'exact_string', sessionId, ''));
docs = docs(cellfun(@(d) any(strcmp(ndi.v2.kindOf(d.document_properties), ...
    {'session', 'dataset'})), docs));
if ~isempty(docs)
    return;
end
docs = search(ndi.v2.isaQuery('session') & ...
    ndi.query('base.session_id', 'exact_string', sessionId, ''));
end
