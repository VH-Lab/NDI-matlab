function [sessionId, docs] = makeV1Session(folder, reference, docs, options)
%MAKEV1SESSION Write a v1 (did-sqlite) session folder on disk, for tests.
%
%   [SESSIONID, DOCS] = ndi.unittest.session.makeV1Session(FOLDER, REFERENCE)
%   [SESSIONID, DOCS] = ndi.unittest.session.makeV1Session(FOLDER, REFERENCE, DOCS)
%   [...] = ndi.unittest.session.makeV1Session(..., 'ObjectType', 'dataset')
%
%   Builds, in FOLDER/.ndi, what NDI before the V2 line wrote for a session:
%   a legacy did database (did-sqlite.sqlite, branch 'a') holding a v1
%   `session` document whose session.reference is REFERENCE, plus the v1
%   documents DOCS (a cell array of ndi.document; each is given the session
%   id), and the reference.txt / unique_reference.txt files. With
%   'ObjectType', 'dataset' the folder is marked as a dataset.
%
%   NDI on the V2 line cannot write such a folder itself: a new session gets
%   a V2 database ([V2 branch writes V2 only]) and a v1 database is opened
%   read-only ([v1 database read-only on the v2 line]), Decided by Jess Haley,
%   2026-11-03, did-schema did_v2_go_forward_class_audit.md. So the fixture
%   writes the legacy database directly, with did.implementations.sqlitedb,
%   the store ndi.database.implementations.database.didsqlite reads.
%
%   SESSIONID is the session id; DOCS is every document written, the session
%   document first.

arguments
    folder (1,:) char
    reference (1,:) char
    docs cell = {}
    options.ObjectType (1,:) char {mustBeMember(options.ObjectType, {'session', 'dataset'})} = 'session'
end

ndiDir = fullfile(folder, '.ndi');
if ~isfolder(ndiDir)
    mkdir(ndiDir);
end
sessionId = ndi.ido.unique_id();
sessionDoc = ndi.document('session', 'session.reference', reference, ...
    'base.session_id', sessionId);
for i = 1:numel(docs)
    docs{i} = docs{i}.set_session_id(sessionId);
end
docs = [{sessionDoc}, reshape(docs, 1, [])];

db = did.implementations.sqlitedb(fullfile(ndiDir, ...
    ndi.database.implementations.database.didsqlite.FILENAME()));
db.add_branch('a');
db.add_docs(docs, 'a');
clear db

vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), reference);
vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), sessionId);
vlt.file.str2text(fullfile(ndiDir, ndi.session.dir.objecttypemarkerfilename()), ...
    options.ObjectType);
end
