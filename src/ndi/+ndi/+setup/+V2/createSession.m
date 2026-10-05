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
%     'Name'        the session's display name (session.name)
%     'Description' free text about the session (session.description)
%     'StudyIds'    cellstr: studies this session is `part_of` (a relation
%                   document each, stored in this session)
%     'SessionDocId' base.id of the session document (default: a new id).
%                   Given when other documents must point at the session
%                   document before it exists (a time reference's referent).
%     'TimeReferenceId' the session's own time reference
%                   (session.time_reference_id), e.g. its UTC extent
%     'Documents'   cell array of further documents (structs, built with the
%                   same SessionId) written in the same transaction, before
%                   the session is opened
%     'Overwrite'   default false. When false, PATH must not already hold an
%                   NDI database of either kind. When true, an existing
%                   PATH/.ndi is DELETED first.
%     'BatchSize', 'Validate', 'Progress'  passed to
%                   ndi.setup.V2.writeDocuments (defaults 2000, true, false)
%
%   DOCS returns the documents written (the session document, any relations
%   and 'Documents'), as structs.
%
%   Errors ndi:setup:V2:sessionExists when PATH already has a database and
%   'Overwrite' is false.
%
%   See also ndi.session.dir, did2.build.document, ndi.setup.conv.haley.import_V2.

arguments
    path (1,:) char {mustBeFolder}
    reference (1,:) char {mustBeNonzeroLengthText}
    options.SessionId (1,:) char = ''
    options.Name (1,:) char = ''
    options.Description (1,:) char = ''
    options.StudyIds = {}
    options.SessionDocId (1,:) char = ''
    options.TimeReferenceId (1,:) char = ''
    options.Documents = {}
    options.Overwrite (1,1) logical = false
    options.BatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.Validate (1,1) logical = true
    options.Progress (1,1) logical = false
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

fields = struct('local_identifier', reference);
if ~isempty(options.Name)
    fields.name = options.Name;
end
if ~isempty(options.Description)
    fields.description = options.Description;
end
args = {'SessionId', sid};
if ~isempty(options.SessionDocId)
    args = [args, {'Id', options.SessionDocId}];
end
if ~isempty(options.TimeReferenceId)
    args = [args, {'Edges', struct('time_reference_id', options.TimeReferenceId)}];
end
docs = {did2.build.document('session', fields, args{:})};
studies = options.StudyIds;
if ischar(studies) || isstring(studies)
    studies = cellstr(studies);
end
for k = 1:numel(studies)
    docs{end+1} = did2.build.directedRelation(docs{1}.base.id, studies{k}, ...
        'part_of', 'SessionId', sid); %#ok<AGROW>
end

docs = [docs, reshape(options.Documents, 1, [])];
for k = 1:numel(docs)
    if ~strcmp(docs{k}.base.session_id, sid)
        error('ndi:setup:V2:wrongSession', ...
            'Document %d (%s) has session_id %s, not this session''s %s.', ...
            k, docs{k}.document_class.class_name, docs{k}.base.session_id, sid);
    end
end

ndi.setup.V2.writeDocuments(fullfile(ndiDir, ...
    ndi.database.implementations.database.did2sqlite.DEFAULTFILENAME()), docs, ...
    'BatchSize', options.BatchSize, 'Validate', options.Validate, ...
    'Progress', options.Progress, 'Label', [reference ' documents']);

% ndi.session.dir scopes EVERY search to its session id (ndi.session/
% database_search ANDs base.session_id), and on a one-argument open it takes
% that id from .ndi/unique_reference.txt -- or, if the file is absent, makes a
% provisional random one, which then finds nothing and fails "Could not load
% the REFERENCE field". So the two files ndi.session.dir itself writes are
% written here first (CI run 36752118828 found this).
vlt.file.str2text(fullfile(ndiDir, 'unique_reference.txt'), sid);
vlt.file.str2text(fullfile(ndiDir, 'reference.txt'), reference);

session = ndi.session.dir(path);
if ~strcmp(session.id(), sid)
    error('ndi:setup:V2:sessionMismatch', ...
        'The session opened with id %s, not the id just written (%s).', session.id(), sid);
end
end
