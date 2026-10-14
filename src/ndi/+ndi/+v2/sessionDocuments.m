function docs = sessionDocuments(database, sessionId)
%SESSIONDOCUMENTS Every document of one session, as stored.
%
%   DOCS = ndi.v2.sessionDocuments(DATABASE, SESSIONID) returns the documents
%   of a V2 database (DATABASE, an ndi did2sqlite database) whose
%   base.session_id is SESSIONID: a cell array of property structs, read from
%   the did2 database itself, so each is exactly what is stored (the ndi read
%   path adds class blocks a copy must not carry). What
%   ndi.v2.copyDocuments copies when a session is ingested into a dataset or
%   moved out of one.
%
%   See also ndi.v2.copyDocuments, ndi.dataset.

arguments
    database (1,1) ndi.database.implementations.database.did2sqlite
    sessionId (1,:) char
end
q = ndi.database.implementations.database.did2sqlite.toDid2Query( ...
    ndi.query('base.session_id', 'exact_string', sessionId, ''));
found = database.db.search(q);
docs = cellfun(@(d) d.toStruct(), found, 'UniformOutput', false);
end
