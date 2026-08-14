function veta_open_migrated_session(sessionPath, options)
%VETA_OPEN_MIGRATED_SESSION Migrate a session to V_eta, open it, show the objects.
%
%   veta_open_migrated_session(SESSIONPATH)
%   veta_open_migrated_session(SESSIONPATH, 'DryRun', true)
%   veta_open_migrated_session(SESSIONPATH, 'Migrate', false)   % open only
%
%   A hand-run walkthrough of the whole V_eta read path, in the order a
%   user hits it: migrate, open, then turn documents into NDI objects.
%   Everything it prints is read back through the ordinary object API --
%   `daqsystem_load`, `getelements`, `s.syncgraph` -- not off the database
%   directly, because "the documents are correct" and "MATLAB can use
%   them" are different claims and only the second one is interesting
%   here.
%
%   BEFORE YOU RUN IT
%   -----------------
%     * NDI-matlab, DID-matlab and did-schema all on the V_eta branch
%     * mksqlite on the path
%     * DID_SCHEMA_PATH pointing at the assembled V_eta schema set
%       (stable + draft), e.g.
%           setenv('DID_SCHEMA_PATH','/path/to/did-schema/schemas/V_eta')
%
%   WHAT IT DOES NOT DO
%   -------------------
%   It does not read signal. `readtimeseries` needs the session's raw data
%   files; the published corpus zips (PRED, 20211116, Dab, Soph) are
%   document-only -- 0 non-JSON files in all four -- so on those it would
%   have nothing to open. Run this on a real session directory to get
%   past that.
%
%   NOTHING IS DESTROYED. `ndi.migrate.local` writes `<TargetVersion>.sqlite`
%   BESIDE the original database and leaves `did-sqlite.sqlite` untouched;
%   'Backup', true is passed by default on top of that.
%
%   Example:
%       setenv('DID_SCHEMA_PATH','~/did-schema/schemas/V_eta');
%       veta_open_migrated_session('~/Documents/mysession')

arguments
    sessionPath (1,:) char
    options.Migrate (1,1) logical = true
    options.DryRun (1,1) logical = false
    options.Backup (1,1) logical = true
end

fprintf('\n=== V_eta migrated-session walkthrough ===\n');
fprintf('session path: %s\n', sessionPath);

% ---- 0. the things that fail confusingly if they are missing ----------
if isempty(which('mksqlite'))
    error('veta:noMksqlite', ...
        'mksqlite is not on the path; neither database backend can open.');
end
if isempty(getenv('DID_SCHEMA_PATH'))
    warning('veta:noSchemaPath', ...
        ['DID_SCHEMA_PATH is not set. Validation during migration will ' ...
         'not find the V_eta schemas.']);
end
ndiDir = fullfile(sessionPath, '.ndi');
if ~isfolder(ndiDir)
    error('veta:notASession', '%s has no .ndi directory.', ndiDir);
end
% THE ONE FILE WHOSE ABSENCE PRODUCES A CONFUSING ERROR. ndi.session.dir
% reads it to decide WHICH session this is, and `database_search` ANDs
% base.session_id into every query -- so without it the session lookup
% matches nothing and dir.m fails on the reference.txt fallback with a
% message that says nothing about the real cause.
if ~isfile(fullfile(ndiDir, 'unique_reference.txt'))
    warning('veta:noUniqueReference', ...
        ['%s has no unique_reference.txt. ndi.session.dir will mint a ' ...
         'fresh id, match no session document, and error on the ' ...
         'reference.txt fallback. Every real session has this file; ' ...
         'synthetic fixtures often do not.'], ndiDir);
end

% ---- 1. migrate -------------------------------------------------------
if options.Migrate
    fprintf('\n--- 1. migrating to V_eta ---\n');
    result = ndi.migrate.local(sessionPath, ...
        'TargetVersion', 'V_eta', ...
        'Validate', true, ...
        'DryRun', options.DryRun, ...
        'Backup', options.Backup);
    fprintf('  destination      : %s\n', result.destination);
    fprintf('  wrote destination: %d\n', result.wroteDestination);
    fprintf('  documents seen   : %d\n', result.summary.total);
    fprintf('  quarantined      : %d\n', numel(result.quarantine));
    fprintf('  dangling edges   : %d (of %d examined)\n', ...
        result.references.orphan_count, result.references.edges_examined);
    if ~isempty(result.quarantine)
        fprintf('  *** quarantine is NOT empty; the reads below may be partial\n');
        for i = 1:min(5, numel(result.quarantine))
            fprintf('      %s: %s\n', result.quarantine(i).class_name, ...
                result.quarantine(i).reason);
        end
    end
    if options.DryRun
        fprintf('\nDryRun: nothing was written, so there is no V_eta database to open.\n');
        return;
    end
else
    fprintf('\n--- 1. migration SKIPPED (Migrate=false) ---\n');
end

% ---- 2. open ----------------------------------------------------------
fprintf('\n--- 2. opening through ndi.session.dir ---\n');
s = ndi.session.dir(sessionPath);
fprintf('  session object   : %s\n', class(s));
fprintf('  reference        : %s\n', s.reference);
fprintf('  id               : %s\n', s.id());

% WHICH backend answered. The session's own `database` property is not
% publicly readable, so the selection is re-run through the same function
% ndi.session.dir calls. A `didsqlite` here means the LEGACY database was
% opened and everything below describes pre-migration data.
db = ndi.database.fun.opendatabase(ndiDir, s.id());
fprintf('  database backend : %s\n', class(db));
if ~isa(db, 'ndi.database.implementations.database.did2sqlite')
    fprintf('  *** NOT a did2sqlite -- this is the PRE-migration database.\n');
end

% ---- 3. the objects ---------------------------------------------------
fprintf('\n--- 3. daq systems ---\n');
devs = s.daqsystem_load();
if isempty(devs); devs = {}; elseif ~iscell(devs); devs = {devs}; end
fprintf('  DENOMINATOR: %d daq system(s)\n', numel(devs));
for i = 1:numel(devs)
    d = devs{i};
    fprintf('   [%d] %-22s %s\n', i, d.name, class(d));
    fprintf('        reader    : %s\n', class(d.daqreader));
    fprintf('        navigator : %s\n', class(d.filenavigator));
    mdr = d.daqmetadatareader;
    fprintf('        metadata  : %d reader(s)\n', numel(mdr));
end

fprintf('\n--- 4. subjects and elements ---\n');
subs = s.database_search(ndi.query('','isa','subject',''));
fprintf('  DENOMINATOR: %d `subject` document(s) in the database\n', numel(subs));
fprintf('  NOTE: after migration this INCLUDES the apparatus. V_eta makes\n');
fprintf('        every identifiable thing a subject, so probes are subjects\n');
fprintf('        too -- an animal + 2 probes reads as 3 here.\n');

els = s.getelements();
if isempty(els); els = {}; elseif ~iscell(els); els = {els}; end
fprintf('  DENOMINATOR: %d element(s) rebuilt as objects\n', numel(els));
for i = 1:numel(els)
    e = els{i};
    fprintf('   [%d] %-22s %s\n', i, e.name, class(e));
    fprintf('        type      : %s   reference: %s\n', ...
        e.type, num2str(e.reference));
    fprintf('        direct    : %d   subject_id: %s\n', ...
        e.direct, shortId(e.subject_id));
end

fprintf('\n--- 5. syncgraph ---\n');
if isempty(s.syncgraph)
    fprintf('  no syncgraph object\n');
else
    fprintf('  %s with %d rule(s)\n', class(s.syncgraph), numel(s.syncgraph.rules));
    % A syncgraph that was NOT found comes back freshly built with ZERO
    % rules and no error, so the rule count is what separates "loaded"
    % from "silently replaced by an empty one".
    for i = 1:numel(s.syncgraph.rules)
        fprintf('   [%d] %s\n', i, class(s.syncgraph.rules{i}));
    end
    if isempty(s.syncgraph.rules)
        fprintf('  *** zero rules. If this session HAS a syncrule, the\n');
        fprintf('      syncgraph was not found and was rebuilt empty.\n');
    end
end

fprintf('\n--- 6. what this did NOT check ---\n');
fprintf('  readtimeseries: needs the raw data files. Not attempted here.\n');
fprintf('  Only the classes this session happens to hold were exercised.\n');
fprintf('\n=== done ===\n\n');
end

function s = shortId(x)
if isempty(x); s = '<none>'; return; end
x = char(x);
if numel(x) > 12; s = [x(1:12) '...']; else; s = x; end
end
