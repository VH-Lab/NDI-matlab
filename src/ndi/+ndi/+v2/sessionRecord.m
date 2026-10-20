function docs = sessionRecord(database, sessionId)
%SESSIONRECORD The document that records a session (or a dataset) itself.
%
%   DOCS = ndi.v2.sessionRecord(DATABASE, SESSIONID) returns, as a cell array
%   of ndi.document objects, the document(s) in DATABASE (an ndi.database,
%   searched without a session scope) that record the session SESSIONID:
%     1. the `session` or `dataset` entity whose base.id IS SESSIONID (did-schema
%        V_eta_relation_inheritance_plan.md, 2026-10-20, a proposal built ahead
%        of signature: session_id is an edge, and the session or dataset entity
%        it points at has the session id as its own id; a dataset's documents
%        point at the dataset entity);
%     2. when there is none, every `session` document (v1, or a V2 `session`
%        entity) whose session id is SESSIONID: the only way to find it on
%        did-schema main and in a v1 database, where the session document has
%        an id of its own.
%   Empty when neither finds one.
%
%   See also ndi.session.dir, ndi.dataset.dir, ndi.v2.sessionIdOf.

arguments
    database
    sessionId (1,:) char
end

docs = database.search(ndi.query('base.id', 'exact_string', sessionId, ''));
docs = docs(cellfun(@(d) any(strcmp(ndi.v2.kindOf(d.document_properties), ...
    {'session', 'dataset'})), docs));
if ~isempty(docs)
    return;
end
docs = database.search(ndi.v2.isaQuery('session') & ...
    ndi.query('base.session_id', 'exact_string', sessionId, ''));
end
