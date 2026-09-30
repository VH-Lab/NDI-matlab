function [session, docs] = createSession(path, reference, options)
%CREATESESSION Create a new NDI session whose database is V2 (did2).
%
%   [SESSION, DOCS] = ndi.setup.V2.createSession(PATH, REFERENCE) creates a
%   session in directory PATH, backed by a did2 database
%   (PATH/.ndi/V_eta.sqlite) instead of the legacy one, and opens it as an
%   ordinary ndi.session.dir. REFERENCE becomes the session's
%   `local_identifier` (the object's `reference` property).
%
%   WHY THIS EXISTS. ndi.session.dir can OPEN a V2 session -- it tries each
%   entry of the database hierarchy and `V_eta.sqlite` is entry 2 -- but it
%   can only CREATE a legacy one: only entry 1 (didsqlite) has creation code
%   (ndi.database.fun.databasehierarchyinit). This function does the creating
%   and leaves ndi.session.dir unchanged, so nothing that makes or opens a
%   legacy session behaves any differently (backwards compatible).
%
%   It writes exactly one document before opening, the V2 `session` document
%   built with did2.build, so that ndi.session.dir's own lookup (the oldest
%   `isa session` document) finds it and takes the session id and reference
%   from it.
%
%   Options:
%     'SessionId'   the session id (default: a new ndi.ido id)
%     'StudyIds'    cellstr: studies this session is `part_of` (a relation
%                   document each, stored in this session)
%     'Overwrite'   default false. When false, PATH must not already hold an
%                   NDI database of either kind. When true, an existing
%                   PATH/.ndi is DELETED first.
%
%   DOCS returns the documents written (the session document and any
%   relations), as structs.
%
%   Errors ndi:setup:V2:sessionExists when PATH already has a database and
%   'Overwrite' is false.
%
%   See also ndi.session.dir, did2.build.document, ndi.setup.conv.haley.import_V2.

arguments
    path (1,:) char {mustBeFolder}
    reference (1,:) char {mustBeNonzeroLengthText}
    options.SessionId (1,:) char = ''
    options.StudyIds = {}
    options.Overwrite (1,1) logical = false
end

ndiDir = fullfile(path, '.ndi');
if isfolder(ndiDir)
    existing = [dir(fullfile(ndiDir, '*.sqlite')); dir(fullfile(ndiDir, '*.json'))];
    if ~isempty(existing) && ~options.Overwrite
        error('ndi:setup:V2:sessionExists', ...
            ['%s already holds an NDI database (%s). Pass ''Overwrite'', true to ' ...
             'replace it.'], ndiDir, strjoin({existing.name}, ', '));
    end
    if options.Overwrite
        rmdir(ndiDir, 's');
    end
end
mkdir(ndiDir);

sid = options.SessionId;
if isempty(sid)
    sid = ndi.ido.unique_id();
end

docs = {did2.build.document('session', struct('local_identifier', reference), ...
    'SessionId', sid)};
studies = options.StudyIds;
if ischar(studies) || isstring(studies)
    studies = cellstr(studies);
end
for k = 1:numel(studies)
    docs{end+1} = did2.build.directedRelation(docs{1}.base.id, studies{k}, ...
        'part_of', 'SessionId', sid); %#ok<AGROW>
end

db = did2.database.sqlitedb(fullfile(ndiDir, ...
    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()));
db.add(cellfun(@(d) did2.document(d), docs, 'UniformOutput', false));
db.close();

session = ndi.session.dir(path);
if ~strcmp(session.id(), sid)
    error('ndi:setup:V2:sessionMismatch', ...
        'The session opened with id %s, not the id just written (%s).', session.id(), sid);
end
end
