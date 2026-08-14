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
%     * DID_SCHEMA_PATH pointing at an ASSEMBLED V_eta schema set
%
%   WHAT "ASSEMBLED" MEANS, AND WHY THIS BLOCK USED TO BE WRONG
%   ----------------------------------------------------------
%   THIS DOCSTRING USED TO GIVE, AS ITS WORKED EXAMPLE,
%
%       setenv('DID_SCHEMA_PATH','~/did-schema/schemas/V_eta');
%
%   and that fails TWO ways at once. It is replaced rather than softened,
%   because it is an instruction people follow -- and one did, and lost a
%   session to it: 14 of 14 documents quarantined with `No schema file for
%   class "session"`, then `ndi.session.dir` errored on the same lookup.
%
%     1. `~` IS NOT EXPANDED. MATLAB's file functions do not resolve a
%        leading tilde -- `isfile('~/x')` is FALSE however real `~/x` is --
%        so the path stays literal and every lookup misses. The tell is a
%        message quoting the tilde straight back at you:
%            No schema file for class "session" at
%            ~/did-schema/schemas/V_eta/session.json
%        This function now expands it (localExpandTilde), for
%        DID_SCHEMA_PATH, 'SchemaRepo' and SESSIONPATH alike.
%
%     2. `schemas/V_eta` IS NOT A SCHEMA DIRECTORY. It holds `index.json`
%        and `topics.json` and nothing else; the classes live one level
%        down in the tier subdirectories. And the lookup is FLAT --
%        did2.schema.cache.getClass is
%            schemaFile = fullfile(obj.schemaPath, [className '.json']);
%        with no recursion and no tier search -- so pointing at the parent
%        finds nothing even once the tilde is expanded. Fixing only the
%        tilde changes the error message and not the outcome.
%
%   THREE TIERS, NOT TWO. `.github/workflows/test-code.yml` assembles
%   `stable` + `draft` + `deprecated` -- 243 files, no name collisions.
%   `deprecated/` is the one that gets left out and must not be: it holds
%   the v1 shapes that DELIBERATELY pass through unmodelled, and a
%   passthrough's whole contract is that the document reaches the validator
%   under its own class. Omitting the tier quarantines every one of them
%   (corpus run 31421715133 lost 4,563 `image_stack` documents that way).
%
%   By hand:
%       mkdir -p /tmp/eta-schemas
%       cp ~/did-schema/schemas/V_eta/stable/*.json     /tmp/eta-schemas/
%       cp ~/did-schema/schemas/V_eta/draft/*.json      /tmp/eta-schemas/
%       cp ~/did-schema/schemas/V_eta/deprecated/*.json /tmp/eta-schemas/
%       setenv('DID_SCHEMA_PATH','/tmp/eta-schemas');
%
%   Or let this function do it -- pass the CHECKOUT, not a tier:
%       veta_open_migrated_session('~/Downloads/amanda', ...
%           'SchemaRepo', '~/did-schema')
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
%       veta_open_migrated_session('~/Downloads/amanda', ...
%           'SchemaRepo', '~/did-schema')

arguments
    sessionPath (1,:) char
    options.Migrate (1,1) logical = true
    options.DryRun (1,1) logical = false
    options.Backup (1,1) logical = true
    options.SchemaRepo (1,:) char = ''
end

sessionPath = localExpandTilde(sessionPath);

fprintf('\n=== V_eta migrated-session walkthrough ===\n');
fprintf('session path: %s\n', sessionPath);

% ---- 0. the things that fail confusingly if they are missing ----------
if isempty(which('mksqlite'))
    error('veta:noMksqlite', ...
        'mksqlite is not on the path; neither database backend can open.');
end
% THE CHECK THIS FUNCTION USED TO SKIP. It asked only whether
% DID_SCHEMA_PATH was SET, warned if not, and then carried on -- so a path
% that was set and unusable sailed through the preconditions and failed 14
% documents later, inside the validator, in a message about a class name.
% An instrument that does not check its own precondition reports the
% symptom instead of the cause.
localPrepareSchemaPath(options.SchemaRepo);
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

function p = localExpandTilde(p)
%LOCALEXPANDTILDE Resolve a leading `~` the way a shell would.
%
%   MATLAB does not. `isfile('~/x')` is false however real `~/x` is, and
%   `fullfile` happily builds paths on top of a literal tilde, so a
%   tilde'd path fails LATE and quotes itself back in the error. Only a
%   LEADING tilde is meaningful; `~` elsewhere is an ordinary character.
%   `~user` is not expanded -- that needs the password database, and
%   silently resolving it to the WRONG home is worse than leaving it.
p = char(p);
if isempty(p) || p(1) ~= '~'
    return;
end
if numel(p) > 1 && p(2) ~= filesep && p(2) ~= '/'
    return;   % `~otheruser/...` -- not ours to guess
end
% HOME first, java second. `java.lang.System` is unavailable under
% -nojvm, which CI may well use, and an undefined-variable error out of a
% path helper is a worse failure than the one this function exists to fix.
home = getenv('HOME');
if isempty(home)
    home = getenv('USERPROFILE');   % Windows
end
if isempty(home) && usejava('jvm')
    home = char(java.lang.System.getProperty('user.home'));
end
if isempty(home)
    return;   % nothing to expand to; leave it and let the caller report
end
rest = p(2:end);
while ~isempty(rest) && (rest(1) == filesep || rest(1) == '/')
    rest(1) = [];
end
p = fullfile(home, rest);
end

function localPrepareSchemaPath(schemaRepo)
%LOCALPREPARESCHEMAPATH Make DID_SCHEMA_PATH usable, or say exactly why not.
%
%   Two jobs. If SCHEMAREPO is given, assemble the three tiers into one
%   flat directory and point DID_SCHEMA_PATH at it. Either way, PROVE the
%   resulting path can answer a lookup before anything is migrated.
%
%   The proof is a sentinel class. `session` is the right one: every
%   session has one, `ndi.session.dir` validates it on open, and it is the
%   class the broken-path failure surfaces on first.

SENTINEL = 'session';

if ~isempty(schemaRepo)
    repo = localExpandTilde(schemaRepo);
    root = fullfile(repo, 'schemas', 'V_eta');
    if ~isfolder(root)
        % Tolerate being handed schemas/V_eta itself rather than the checkout.
        if isfolder(fullfile(repo, 'stable'))
            root = repo;
        else
            error('veta:badSchemaRepo', ...
                ['SchemaRepo "%s" is neither a did-schema checkout (no ' ...
                 '%s) nor a schemas/V_eta directory (no stable/).'], ...
                repo, fullfile('schemas', 'V_eta'));
        end
    end
    tiers = {'stable', 'draft', 'deprecated'};
    dest = fullfile(tempdir, 'eta-schemas');
    if ~isfolder(dest); mkdir(dest); end
    copied = 0;
    for i = 1:numel(tiers)
        tierDir = fullfile(root, tiers{i});
        if ~isfolder(tierDir)
            error('veta:missingTier', ...
                ['Schema tier "%s" is missing from %s. All THREE tiers are ' ...
                 'part of the validation set -- deprecated/ holds the v1 ' ...
                 'shapes that pass through unmodelled, and omitting it ' ...
                 'quarantines every one of them.'], tiers{i}, root);
        end
        listing = dir(fullfile(tierDir, '*.json'));
        for k = 1:numel(listing)
            copyfile(fullfile(tierDir, listing(k).name), dest);
            copied = copied + 1;
        end
    end
    fprintf('  DENOMINATOR: assembled %d schema file(s) from %d tier(s) into %s\n', ...
        copied, numel(tiers), dest);
    setenv('DID_SCHEMA_PATH', dest);
end

raw = getenv('DID_SCHEMA_PATH');
if isempty(raw)
    error('veta:noSchemaPath', ...
        ['DID_SCHEMA_PATH is not set and no ''SchemaRepo'' was given, so ' ...
         'nothing can validate. Pass ''SchemaRepo'', ''/path/to/did-schema'' ' ...
         'and this function will assemble the tiers for you.']);
end

resolved = localExpandTilde(raw);
if ~strcmp(resolved, raw)
    % Do NOT leave the tilde in the environment: did2 reads this variable
    % directly and will not expand it either.
    setenv('DID_SCHEMA_PATH', resolved);
    fprintf(['  NOTE: DID_SCHEMA_PATH began with `~`, which MATLAB does NOT ' ...
             'expand.\n        Rewritten to %s\n'], resolved);
end

fprintf('  DID_SCHEMA_PATH : %s\n', resolved);

if ~isfolder(resolved)
    error('veta:schemaPathMissing', ...
        'DID_SCHEMA_PATH points at "%s", which is not a directory.', resolved);
end

sentinelFile = fullfile(resolved, [SENTINEL '.json']);
if isfile(sentinelFile)
    n = numel(dir(fullfile(resolved, '*.json')));
    fprintf('  DENOMINATOR: %d schema file(s) visible at DID_SCHEMA_PATH\n', n);
    return;
end

% It is a real directory and the lookup still cannot work. Say which of the
% two shapes it is, because the remedies differ.
if isfolder(fullfile(resolved, 'stable'))
    error('veta:schemaPathNotAssembled', ...
        ['DID_SCHEMA_PATH points at the V_eta ROOT ("%s"), not at an ' ...
         'assembled schema set. That directory holds index.json and ' ...
         'topics.json; the classes live in stable/, draft/ and ' ...
         'deprecated/. The lookup is FLAT -- did2.schema.cache.getClass ' ...
         'does fullfile(schemaPath, [className ''.json'']) with no ' ...
         'recursion -- so no class is findable from here.\n' ...
         'Fix: re-run with ''SchemaRepo'', ''<did-schema checkout>'', or ' ...
         'copy stable/*.json, draft/*.json and deprecated/*.json into one ' ...
         'directory and point DID_SCHEMA_PATH at that.'], resolved);
end

error('veta:schemaPathHasNoClasses', ...
    ['DID_SCHEMA_PATH ("%s") is a directory but has no %s.json in it, so ' ...
     'the very first class lookup will fail. It holds %d *.json file(s). ' ...
     'Point it at an assembled V_eta set (stable + draft + deprecated ' ...
     'flattened into one directory).'], ...
    resolved, SENTINEL, numel(dir(fullfile(resolved, '*.json'))));
end
