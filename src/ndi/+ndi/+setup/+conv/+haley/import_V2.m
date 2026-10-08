function result = import_V2(dataParentDir, options)
%IMPORT_V2 Import the Haley C. elegans / E. coli foraging dataset as V2 (V_eta).
%
%   RESULT = ndi.setup.conv.haley.import_V2(DATAPARENTDIR) runs the import's
%   stages over the raw data in DATAPARENTDIR/haley and returns what each
%   stage produced. It is being built one stage at a time with the dataset's
%   owner, and is meant to be the canonical example of a V2 import (and the
%   basis of a GUI importer): every choice it makes is recorded, with its
%   reason, in import_V2_decisions.md next to this file.
%
%   The stages, in order (decision log, "Stage order"):
%     A. dataset, once
%        0  discover       list the source files; skip earlier import output
%        1  profile        describe tables (ndi.setup.V2.profileTable, on demand)
%        2  metadata       dataset, people, organizations, funding, publication,
%                          software, products, strains, chemicals, recipes,
%                          instruments -- from import_V2_spec.json (sources:
%                          the eLife paper, WormBook, the lab's Benchling
%                          protocols) -- and the seeding suspensions, one set
%                          per seeding day, from the source tables
%                          (ndi.setup.conv.haley.seedingSuspensions)
%     B. per study (E. coli first); per day:
%        3  sessions       the studies (from the spec; decision #50), then one
%                          session per experiment day, part_of its study
%        4  subjects       plates, patches, worm cohorts, worms, acclimation
%                          and food deprivation plates; each with its type
%        5  acquisition    camera/microscope, one epoch per recording
%        6  relations      patch part_of plate; worm member_of its cohort;
%                          cohort contained_in its acclimation, food
%                          deprivation and assay plates (with when)
%        7  assertions     species and strain of each cohort and seeded
%                          patch; exclusion tags on plates
%        8  manipulations  pouring and seeding each plate, its moves
%                          between cold room, room temperature and
%                          incubator; each cohort's transfers and food
%                          deprivation
%        9  observations   each filmed assay plate's ambient temperature
%                          and relative humidity, read by the temperature
%                          probe over its recordings
%        10 calculations   part A: each behaviour video's coordinate system,
%                          arena / reference mark / lawn masks, nearest-patch
%                          map and lawn clip registration fit, as the lab's
%                          analysis package computed them (decision #60);
%                          part B: each worm's per-frame position, speed,
%                          distance to the nearest patch edge and nearest
%                          patch, per body part and video (decision #61);
%                          part C: each analysed E. coli image's patch mask
%                          and each detected patch's profile values, on its
%                          patch subject (decision #62)
%        11 encounters     each worm's patch encounters (celegans/encounter.mat):
%                          an encounter-onset list and the per-encounter
%                          values keyed by it (decision #63)
%     C. dataset-wide, once
%        12 density        the E. coli border amplitude fits, each about a
%                          group of patches, and each C. elegans worm's
%                          per-encounter estimates from them (decision #65;
%                          needs the E. coli session and the C. elegans
%                          sessions in the same run)
%        13 dataset        check & write the dataset: ONE V2 database holding
%                          the dataset-level documents (stage 2's, the
%                          studies, stage 12's fits) and every selected
%                          session, ingested (ndi.setup.V2.createDataset;
%                          decision #66); opens as an ndi.dataset.dir
%
%   Nothing is written unless 'Write' is true: by default RESULT holds what
%   each stage WOULD create, for inspection. With 'Write', each selected
%   session is created under 'OutputRoot' with its V2 database holding the
%   session and, when stages 4 and 5 ran, its subjects, acquisition systems,
%   epochs and recordings (ndi.setup.conv.haley.sessionDocuments). The
%   session folder holds only .ndi/: each recording's document records where
%   its raw file is, and NDI finds it there (ndi.file.navigator.bodies);
%   nothing is linked, copied or written next to the raw data. The
%   dataset-level documents of
%   stage 2 (instruments included) are not written yet (stage 13), so a
%   recording's instrument_id names a document outside the session.
%
%   Options:
%     'Spec'              path to the spec (default: import_V2_spec.json here)
%     'Stages'            which stages to run (default: all implemented)
%     'OutputRoot'        where session directories go (default:
%                         <DATAPARENTDIR>/haley_V2; the raw data is never
%                         written to, decision 21)
%     'Sessions'          local_identifiers of the sessions to import (default:
%                         all), e.g. "concentration_0002"
%     'Write'             default false; true creates the sessions
%     'Checksums'         default true: MD5 of every recording written
%     'Overwrite'         default false; true replaces existing sessions
%     'ReadVideos'        default true: opens each lawn clip (VideoReader) to
%                         read its length (stage 5), and on 'Write' each
%                         video for its pixel format; false skips both
%                         (videos are then assumed 8-bit)
%     'DatasetSessionId'  session id for dataset-level documents (default: a
%                         new id)
%     'DatasetFolder'     where stage 13 writes the dataset (default:
%                         <OutputRoot>/dataset)
%     'DatasetReference'  the dataset's local_identifier (default 'haley')
%     'EcoliProfilesFile' analyzeGFP's workspace (profile curves, background
%                         fits; decision #64), wherever it is kept (default:
%                         <DATAPARENTDIR>/haley/ecoli/analyzeGFP_24-04-04.mat)
%     'SessionFolders'    default true: also write each session to its own
%                         folder (a working copy; the dataset holds them all).
%                         false writes only the dataset, about half the time
%     'WriteBatchSize'    documents per write batch (default 2000); progress
%                         is printed per batch, and shown in a
%                         ProgressBarWindow when MATLAB has a display
%     'ValidateOnWrite'   default false: every document was validated when
%                         did2.build built it, so the database does not
%                         validate it again on insert; true repeats it
%
%     'RunFolder'         with 'Write': where this run's record is kept
%                         (default: <OutputRoot>/run_<yyyy-MM-dd_HHmmss>);
%                         'none' keeps none. It holds import_log.txt (the
%                         whole console output, a diary), import_report.mat
%                         (`report`: the dataset check, the sessions, the
%                         checks, the density fits, the timing; not the
%                         documents) and skipped.txt (every reported skip
%                         and check line). Written even when the run fails,
%                         with the error at the end of the log.
%
%   With 'Write', every folder to be written (the dataset's and, with
%   'SessionFolders', each session's) is checked before anything is built
%   or written: one that already holds an NDI database is an error unless
%   'Overwrite' is true.
%
%   doImport.m, the original V1 import, is unchanged.
%
%   See also ndi.setup.V2.discover, ndi.setup.V2.datasetMetadata.

arguments
    dataParentDir (1,:) char {mustBeFolder} = fullfile(userpath, 'data')
    options.Spec (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'import_V2_spec.json')
    options.Stages (1,:) string = ["discover", "metadata", "sessions", "subjects", "acquisition", "relations", "assertions", "manipulations", "observations", "calculations", "encounters", "density", "dataset"]
    options.OutputRoot (1,:) char = ''
    options.Sessions (1,:) string = string.empty(1, 0)
    options.Write (1,1) logical = false
    options.Checksums (1,1) logical = true
    options.Overwrite (1,1) logical = false
    options.DatasetSessionId (1,:) char = ''
    options.ReadVideos (1,1) logical = true
    options.DatasetFolder (1,:) char = ''
    options.DatasetReference (1,:) char = 'haley'
    options.SessionFolders (1,1) logical = true
    options.EcoliProfilesFile (1,:) char = ''
    options.WriteBatchSize (1,1) double {mustBePositive, mustBeInteger} = 2000
    options.ValidateOnWrite (1,1) logical = false
    options.RunFolder (1,:) char = ''
end

% With 'Write', the run keeps its own record (log, report, skipped list) in a
% run folder beside the dataset: this outer call sets it up and runs the
% import itself as an inner call with RunFolder 'none'.
if options.Write && ~strcmp(options.RunFolder, 'none')
    result = recordedRun(dataParentDir, options);
    return;
end

% Check the requirements up front, so a missing one is reported with its fix
% rather than as "Unable to resolve the name 'did2.build.label'" mid-stage.
if any(ismember(options.Stages, ["metadata", "sessions"]))
    ndi.setup.V2.preflight();
end

result = struct();
sid = options.DatasetSessionId;
if isempty(sid)
    sid = did.ido.unique_id();
end
result.datasetSessionId = sid;
% One dataset document id for the whole run: stage 2 builds the dataset with
% it and stage 3's studies are part_of it, whichever stages run.
result.datasetId = ndi.ido.unique_id();

if any(options.Stages == "discover")
    fprintf('\n== stage 0: discover ==\n');
    result.files = ndi.setup.V2.discover(fullfile(dataParentDir, 'haley'));
end

if any(options.Stages == "metadata")
    fprintf('\n== stage 2: dataset metadata ==\n');
    spec = jsondecode(fileread(options.Spec));
    % The seeding suspensions (stage 8 part B, decision #57) come from the
    % source tables, not the spec, but are dataset-level formulations like the
    % spec's: built here with them, after the strains and diluents they name.
    if isfield(spec, 'seeding')
        [result.suspensions, result.suspensionChecks] = ...
            ndi.setup.conv.haley.seedingSuspensions(dataParentDir, spec);
        f = spec.formulations;
        if isstruct(f), f = num2cell(f); end
        spec.formulations = [reshape(f, 1, []), result.suspensions.entries];
    end
    result.metadata = ndi.setup.V2.datasetMetadata(spec, sid, ...
        'DatasetId', result.datasetId, 'Studies', "exclude");
    fprintf('DENOMINATOR: %d document(s) built from %s\n', ...
        numel(result.metadata.documents), options.Spec);
    disp(result.metadata.census);
    u = result.metadata.unrepresented;
    fprintf('spec content with NO place in V2 (recorded here, not in the documents): %d\n', numel(u));
    for k = 1:numel(u)
        fprintf('  %-12s %-20s %-16s %s\n', u(k).kind, u(k).key, u(k).field, u(k).why);
    end
end

if any(options.Stages == "sessions")
    fprintf('\n== stage 3: sessions ==\n');
    spec = jsondecode(fileread(options.Spec));
    % the studies first: they group the sessions (each spec study's
    % source_folder / source_condition picks its days), so they are minted
    % here, beside them (decision #50). Dataset-level documents, like stage 2's.
    result.studies = ndi.setup.V2.datasetMetadata(spec, sid, ...
        'DatasetId', result.datasetId, 'Studies', "only");
    fprintf('DENOMINATOR: %d study document(s) and %d relation(s) built from %s\n', ...
        sum(strcmp(result.studies.census.class, 'study') .* result.studies.census.count), ...
        sum(strcmp(result.studies.census.class, 'directed_relation') .* result.studies.census.count), ...
        options.Spec);
    [result.sessions, result.sessionChecks] = ndi.setup.conv.haley.sessionList(dataParentDir, spec, ...
        'StudyIds', result.studies.ids, 'OutputRoot', options.OutputRoot);
    allSessions = result.sessions;
    if ~isempty(options.Sessions)
        unknown = setdiff(options.Sessions, string(result.sessions.local_identifier));
        if ~isempty(unknown)
            error('ndi:setup:conv:haley:unknownSession', 'No session %s.', strjoin(unknown, ', '));
        end
        result.sessions = result.sessions(ismember(result.sessions.local_identifier, ...
            cellstr(options.Sessions)), :);
        fprintf('%d session(s) selected by ''Sessions''\n', height(result.sessions));
    end
    disp(result.sessions(:, {'local_identifier', 'study_key', 'date', 'include'}));
end

if any(options.Stages == "subjects")
    fprintf('\n== stage 4: subjects ==\n');
    if ~isfield(result, 'sessions')
        error('ndi:setup:conv:haley:needSessions', ...
            'The subjects stage needs the sessions stage: include "sessions" in ''Stages''.');
    end
    % Listed against EVERY session, then narrowed: with 'Sessions', a plate
    % of an unselected day would otherwise read as having no session.
    spec = jsondecode(fileread(options.Spec));
    corrections = {};
    if isfield(spec, 'corrections'), corrections = spec.corrections; end
    [result.subjects, result.subjectChecks] = ndi.setup.conv.haley.subjectList( ...
        dataParentDir, allSessions, 'Corrections', corrections);
    result.subjects = result.subjects(ismember(result.subjects.session, ...
        result.sessions.local_identifier), :);
    if height(result.subjects) > 0
        disp(groupsummary(result.subjects, {'folder', 'kind'}));
    end
    if ~options.Write
        fprintf('(not written: pass ''Write'', true)\n');
    end
end

if any(options.Stages == "acquisition")
    fprintf('\n== stage 5: acquisition ==\n');
    if ~isfield(result, 'sessions')
        error('ndi:setup:conv:haley:needSessions', ...
            'The acquisition stage needs the sessions stage: include "sessions" in ''Stages''.');
    end
    [result.recordings, result.recordingChecks] = ndi.setup.conv.haley.recordingList( ...
        dataParentDir, result.sessions, 'ReadVideos', options.ReadVideos);
    if height(result.recordings) > 0
        disp(groupsummary(result.recordings, {'kind', 'system'}));
    end
    if ~options.Write
        fprintf('(not written: pass ''Write'', true)\n');
    end
end

if any(options.Stages == "relations")
    fprintf('\n== stage 6: relations ==\n');
    if ~isfield(result, 'subjects') || ~isfield(result, 'recordings')
        error('ndi:setup:conv:haley:needSubjects', ['The relations stage needs the ' ...
            'subjects and acquisition stages: include "subjects" and "acquisition" in ''Stages''.']);
    end
    if ~options.Write
        fprintf('(built with the session documents: pass ''Write'', true)\n');
    end
end

if any(options.Stages == "assertions")
    fprintf('\n== stage 7: assertions ==\n');
    if ~isfield(result, 'subjects')
        error('ndi:setup:conv:haley:needSubjects', ['The assertions stage needs the ' ...
            'subjects stage: include "subjects" in ''Stages''.']);
    end
    if ~options.Write
        fprintf('(built with the session documents: pass ''Write'', true)\n');
    end
end

if options.Write && isfield(result, 'sessions')
    fprintf('\n== write ==\n');
    result = writeSessions(result, dataParentDir, options);
end
end

function result = recordedRun(dataParentDir, options)
% Run the import with its console output, report and skipped list kept in
% the run folder; the diary that was on before (if any) is restored.
runDir = options.RunFolder;
if isempty(runDir)
    outRoot = options.OutputRoot;
    if isempty(outRoot), outRoot = fullfile(dataParentDir, 'haley_V2'); end
    runDir = fullfile(outRoot, ['run_' char(datetime('now'), 'yyyy-MM-dd_HHmmss')]);
end
if ~isfolder(runDir), mkdir(runDir); end
logFile = fullfile(runDir, 'import_log.txt');
wasOn = strcmp(get(0, 'Diary'), 'on');
wasFile = get(0, 'DiaryFile');
diary off
diary(logFile);
restore = onCleanup(@() restoreDiary(wasOn, wasFile));
fprintf('run folder: %s\nstarted:    %s\n', runDir, char(datetime('now')));
t0 = tic;
inner = options;
inner.RunFolder = 'none';
args = namedargs2cell(inner);
failure = [];
try
    result = ndi.setup.conv.haley.import_V2(dataParentDir, args{:});
catch failure
    fprintf('\n== the run FAILED ==\n%s\n', getReport(failure, 'extended', 'hyperlinks', 'off'));
    result = struct();
end
elapsed = toc(t0);
fprintf('\nimport took %s\nrun folder: %s\n', char(duration(0, 0, round(elapsed))), runDir);
diary off
report = runReport(result, options, elapsed, failure);   %#ok<NASGU> (saved)
save(fullfile(runDir, 'import_report.mat'), 'report');
writeSkipped(logFile, fullfile(runDir, 'skipped.txt'));
result.runFolder = runDir;
if ~isempty(failure)
    rethrow(failure);
end
end

function restoreDiary(wasOn, wasFile)
diary off
if wasOn
    diary(wasFile);
end
end

function report = runReport(result, options, elapsed, failure)
% what the run decided and checked, without its documents (small to save)
report = struct('finished', datetime('now'), 'seconds', elapsed, 'failed', ~isempty(failure), ...
    'error', '', 'options', options);
if ~isempty(failure), report.error = failure.message; end
for f = {'datasetSessionId', 'datasetId', 'dataset', 'sessions', 'subjectChecks', ...
        'suspensionChecks', 'recordingChecks'}
    if isfield(result, f{1}), report.(f{1}) = result.(f{1}); end
end
if isfield(result, 'density')
    d = result.density;
    report.density = struct();
    for f = {'fits', 'counts', 'checks', 'skipped'}
        if isfield(d, f{1}), report.density.(f{1}) = d.(f{1}); end
    end
end
end

function writeSkipped(logFile, outFile)
% every reported skip and check line of the log, under the stage or session
% header it came after
lines = splitlines(string(fileread(logFile)));
keep = strings(0, 1);
inChecks = false;
for k = 1:numel(lines)
    t = strtrim(lines(k));
    if startsWith(t, "CHECKS")
        inChecks = true;
        keep(end+1, 1) = lines(k); %#ok<AGROW>
    elseif inChecks && startsWith(lines(k), "  ") && t ~= ""
        keep(end+1, 1) = lines(k); %#ok<AGROW>
    else
        inChecks = false;
        if startsWith(t, "== ") || startsWith(t, "-- session ") || startsWith(t, "skipped:") ...
                || contains(t, "disagrees:")
            keep(end+1, 1) = lines(k); %#ok<AGROW>
        end
    end
end
writelines(keep, outFile);
end

function result = writeSessions(result, dataParentDir, options)
% One V2 session per selected row: its documents first, then its files.
% Subjects carry a display name (decision #42), which needs did-schema #80.
schema = getenv('DID_SCHEMA_PATH');
subjectFile = fullfile(schema, 'subject.json');
if isfield(result, 'subjects') && isfile(subjectFile)
    if ~ndi.setup.V2.schemaHasField('subject', 'name')
        error('ndi:setup:conv:haley:oldSchema', ...
            ['The V2 schema in %s has no subject.name (did-schema PR #80, merged ' ...
             '2026-10-01). Update did-schema to main and copy its V_eta schemas ' ...
             'there again; nothing was written.'], schema);
    end
end
T = result.sessions;
n = height(T);
checkFoldersFree(T, dataParentDir, options);
T.session_id = arrayfun(@(~) ndi.ido.unique_id(), (1:n)', 'UniformOutput', false);
T.session_doc_id = arrayfun(@(~) ndi.ido.unique_id(), (1:n)', 'UniformOutput', false);
T.time_reference_id = repmat({''}, n, 1);
T.documents = repmat({{}}, n, 1);
built = cell(n, 1);
instrumentIds = containers.Map();
if isfield(result, 'metadata')
    instrumentIds = result.metadata.ids;
end
if isfield(result, 'subjects') && isfield(result, 'recordings')
    % building every session's documents (stages 6-11) is the longest part of
    % a run before the write: a bar and a line per session
    buildBar = []; tag = 'build sessions';
    try
        buildBar = ndi.gui.component.ProgressBarWindow('NDI V2 import', 'GrabMostRecent', true);
        buildBar.setTimeout(hours(12));
        buildBar.addBar('Label', sprintf('Building %d session(s)', n), 'Tag', tag, 'Auto', true);
    catch
        buildBar = [];
    end
    tBuild = tic;
    for k = 1:n
        fprintf('\n-- session %d of %d: %s --\n', k, n, T.local_identifier{k});
        built{k} = ndi.setup.conv.haley.sessionDocuments(dataParentDir, T(k, :), ...
            result.subjects, result.recordings, 'InstrumentIds', instrumentIds, ...
            'Checksums', options.Checksums, 'ReadVideos', options.ReadVideos);
        if any(options.Stages == "relations")
            spec = jsondecode(fileread(options.Spec));
            protocol = struct();
            if isfield(spec, 'transfer_protocol'), protocol = spec.transfer_protocol; end
            rel = ndi.setup.conv.haley.relationDocuments(T(k, :), result.subjects, ...
                result.recordings, built{k}.subjectIds, 'Protocol', protocol);
            built{k}.documents = [built{k}.documents, rel.documents];
            built{k}.relations = rel;
            c = rel.counts;
            fprintf(['%s relations: %d patch part_of plate; %d worm member_of cohort; ' ...
                'cohort contained_in: %d assay plate, %d acclimation plate, ' ...
                '%d food deprivation plate\n'], T.local_identifier{k}, ...
                c.patch_part_of_plate, c.worm_member_of_cohort, c.cohort_in_assay_plate, ...
                c.cohort_in_acclimation_plate, c.cohort_in_food_deprivation_plate);
            for j = 1:numel(rel.skipped)
                fprintf('  skipped: %s\n', rel.skipped{j});
            end
        end
        if any(options.Stages == "assertions")
            spec = jsondecode(fileread(options.Spec));
            strains = struct([]);
            if isfield(spec, 'strains'), strains = spec.strains; end
            as = ndi.setup.conv.haley.assertionDocuments(T(k, :), result.subjects, ...
                built{k}.subjectIds, 'Strains', strains, 'StrainIds', instrumentIds);
            built{k}.documents = [built{k}.documents, as.documents];
            built{k}.assertions = as;
            c = as.counts;
            fprintf(['%s assertions: cohort %d species, %d strain, %d sex; patch %d species, ' ...
                '%d strain; %d plate(s) excluded\n'], T.local_identifier{k}, c.cohort_species, ...
                c.cohort_strain, c.cohort_sex, c.patch_species, c.patch_strain, c.plate_excluded);
            for j = 1:numel(as.skipped)
                fprintf('  skipped: %s\n', as.skipped{j});
            end
        end
        if any(options.Stages == "manipulations") && isfield(built{k}, 'relations')
            spec = jsondecode(fileread(options.Spec));
            index = table();
            if isfield(result, 'suspensions'), index = result.suspensions.index; end
            ma = ndi.setup.conv.haley.manipulationDocuments(T(k, :), result.subjects, ...
                built{k}.subjectIds, 'Preparation', spec.preparation, ...
                'Seeding', spec.seeding, 'Ids', instrumentIds, 'Names', namesOf(spec), ...
                'Suspensions', index, 'Relations', built{k}.relations, ...
                'HandTolerance', reshape(double(spec.transfer_protocol.hand_written_tolerance_seconds), 1, 2));
            built{k}.documents = [built{k}.documents, ma.documents];
            built{k}.manipulations = ma;
            c = ma.counts;
            fprintf(['%s manipulations: %d pour, %d patch seeding, %d acclimation plate ' ...
                'seeding, %d temperature, %d transfer, %d food deprivation; ' ...
                '%d developmental stage observation(s)\n'], ...
                T.local_identifier{k}, c.pour, c.seed_patch, c.seed_acclimation_plate, ...
                c.temperature, c.transfer, c.food_deprivation, c.developmental_stage);
            for j = 1:numel(ma.skipped)
                fprintf('  skipped: %s\n', ma.skipped{j});
            end
        elseif any(options.Stages == "manipulations")
            fprintf('%s: the manipulations stage needs the relations stage (it shares their times)\n', ...
                T.local_identifier{k});
        end
        if any(options.Stages == "observations")
            spec = jsondecode(fileread(options.Spec));
            probe = '';
            if isKey(instrumentIds, spec.environment.instrument)
                probe = instrumentIds(spec.environment.instrument);
            end
            ob = ndi.setup.conv.haley.observationDocuments(T(k, :), result.recordings, ...
                built{k}.subjectIds, 'Environment', spec.environment, 'InstrumentId', probe, ...
                'RecordingRefs', built{k}.recordingRefs);
            built{k}.documents = [built{k}.documents, ob.documents];
            built{k}.observations = ob;
            fprintf('%s observations: %d temperature, %d humidity\n', T.local_identifier{k}, ...
                ob.counts.temperature, ob.counts.humidity);
            for j = 1:numel(ob.skipped)
                fprintf('  skipped: %s\n', ob.skipped{j});
            end
        end
        if any(options.Stages == "calculations")
            run = struct('SoftwareId', '', 'InterpreterId', '', 'OperatingSystemId', '');
            keys = {'haley_analysis', 'matlab', 'macos'};
            names = fieldnames(run);
            for j = 1:numel(keys)
                if isKey(instrumentIds, keys{j}), run.(names{j}) = instrumentIds(keys{j}); end
            end
            ge = ndi.setup.conv.haley.geometryDocuments(dataParentDir, T(k, :), result.recordings, ...
                built{k}.subjectIds, 'RecordingStatements', built{k}.recordingStatements, ...
                'RecordingRefs', built{k}.recordingRefs, 'SoftwareId', run.SoftwareId, ...
                'InterpreterId', run.InterpreterId, 'OperatingSystemId', run.OperatingSystemId);
            built{k}.documents = [built{k}.documents, ge.documents];
            built{k}.geometry = ge;
            c = ge.counts;
            fprintf(['%s calculations: %d coordinate system, %d arena, %d reference mark, ' ...
                '%d lawn mask, %d nearest patch, %d registration\n'], T.local_identifier{k}, ...
                c.coordinate_system, c.arena, c.reference_mark, c.lawn, c.nearest_patch, c.registration);
            for j = 1:numel(ge.skipped)
                fprintf('  skipped: %s\n', ge.skipped{j});
            end
            tr = ndi.setup.conv.haley.trackDocuments(dataParentDir, T(k, :), result.recordings, ...
                built{k}.subjectIds, 'Geometry', ge.byEpoch, ...
                'RecordingStatements', built{k}.recordingStatements, ...
                'RecordingRefs', built{k}.recordingRefs, 'SoftwareId', run.SoftwareId, ...
                'InterpreterId', run.InterpreterId, 'OperatingSystemId', run.OperatingSystemId);
            built{k}.documents = [built{k}.documents, tr.documents];
            built{k}.tracks = tr;
            c = tr.counts;
            fprintf(['%s tracks: %d position, %d speed, %d distance to patch edge, ' ...
                '%d nearest patch\n'], T.local_identifier{k}, c.position, c.speed, ...
                c.patch_edge_distance, c.nearest_patch);
            for j = 1:numel(tr.skipped)
                fprintf('  skipped: %s\n', tr.skipped{j});
            end
            ec = ndi.setup.conv.haley.ecoliDocuments(dataParentDir, T(k, :), result.recordings, ...
                built{k}.subjectIds, 'RecordingStatements', built{k}.recordingStatements, ...
                'RecordingRefs', built{k}.recordingRefs, 'SoftwareId', run.SoftwareId, ...
                'InterpreterId', run.InterpreterId, 'OperatingSystemId', run.OperatingSystemId, ...
                'ProfilesFile', options.EcoliProfilesFile);
            built{k}.documents = [built{k}.documents, ec.documents];
            built{k}.ecoli = ec;
            c = ec.counts;
            if c.mask > 0 || c.normalised_image > 0
                fprintf(['%s E. coli: %d normalised image(s), %d background fit(s), %d mask, ' ...
                    '%d image(s) matched to patch subjects, %d not; %d per-patch value(s), ' ...
                    '%d profile curve(s), %d nearest patch\n'], T.local_identifier{k}, ...
                    c.normalised_image, c.background_fit, c.mask, c.matched_images, ...
                    c.unmatched_images, c.patch_values, c.profiles, c.nearest_patch);
            end
            for j = 1:numel(ec.skipped)
                fprintf('  skipped: %s\n', ec.skipped{j});
            end
        end
        if any(options.Stages == "encounters") && isfield(built{k}, 'tracks')
            windows = containers.Map();
            if isfield(built{k}, 'observations'), windows = built{k}.observations.windows; end
            en = ndi.setup.conv.haley.encounterDocuments(dataParentDir, T(k, :), result.recordings, ...
                built{k}.subjectIds, 'Tracks', built{k}.tracks.byWorm, 'PlateWindows', windows, ...
                'RecordingRefs', built{k}.recordingRefs, 'SoftwareId', run.SoftwareId, ...
                'InterpreterId', run.InterpreterId, 'OperatingSystemId', run.OperatingSystemId);
            built{k}.documents = [built{k}.documents, en.documents];
            built{k}.encounters = en;
            c = en.counts;
            fprintf('%s encounters: %d worm(s), %d encounter(s), %d document(s)\n', ...
                T.local_identifier{k}, c.worms, c.encounters, c.documents);
            for j = 1:numel(en.skipped)
                fprintf('  skipped: %s\n', en.skipped{j});
            end
        elseif any(options.Stages == "encounters")
            fprintf('%s: the encounters stage needs the calculations stage (its tracks)\n', ...
                T.local_identifier{k});
        end
        T.documents{k} = built{k}.documents;
        T.time_reference_id{k} = built{k}.timeReferenceId;
        classes = cellfun(@(d) d.document_class.class_name, built{k}.documents, ...
            'UniformOutput', false);
        fprintf('%s: %d document(s) built\n', T.local_identifier{k}, numel(classes));
        disp(groupsummary(table(classes(:), 'VariableNames', {'class'}), 'class'));
        for j = 1:numel(built{k}.skipped)
            fprintf('  skipped: %s\n', built{k}.skipped{j});
        end
        el = toc(tBuild);
        fprintf('-- %d of %d session(s) built, %s elapsed, ~%s left --\n', k, n, ...
            char(duration(0, 0, round(el))), char(duration(0, 0, round(el / k * (n - k)))));
        if ~isempty(buildBar)
            try buildBar.updateBar(tag, k / n); catch, end
        end
    end
    if any(options.Stages == "density")
        fprintf('\n== stage 12: density ==\n');
        run = struct('SoftwareId', '', 'InterpreterId', '', 'OperatingSystemId', '');
        keys = {'haley_analysis', 'matlab', 'macos'};
        names = fieldnames(run);
        for j = 1:numel(keys)
            if isKey(instrumentIds, keys{j}), run.(names{j}) = instrumentIds(keys{j}); end
        end
        de = ndi.setup.conv.haley.densityDocuments(dataParentDir, T, built, ...
            'DatasetSessionId', result.datasetSessionId, 'SoftwareId', run.SoftwareId, ...
            'InterpreterId', run.InterpreterId, 'OperatingSystemId', run.OperatingSystemId);
        for k = 1:n
            T.documents{k} = [T.documents{k}, de.sessionDocuments{k}];
        end
        result.density = de;
        c = de.counts;
        fprintf(['density: %d fit(s) about %d group(s) of %d patch membership(s), %d input ' ...
            'value(s); %d refit(s) checked; %d worm(s), %d estimate document(s), %d encounter ' ...
            'value(s) checked (dataset-level documents: written at stage 13)\n'], c.fits, ...
            c.groups, c.members, c.inputs, c.refit_checked, c.worms, c.estimates, c.encounters_checked);
        for j = 1:numel(de.checks.refitDisagrees)
            fprintf('  refit disagrees: %s\n', de.checks.refitDisagrees{j});
        end
        for j = 1:numel(de.checks.encounterDisagrees)
            fprintf('  encounter disagrees: %s\n', de.checks.encounterDisagrees{j});
        end
        for j = 1:numel(de.skipped)
            fprintf('  skipped: %s\n', de.skipped{j});
        end
    end
else
    fprintf('(stages 4 and 5 did not run: writing the sessions alone)\n');
end
if any(options.Stages == "dataset")
    fprintf('\n== stage 13: check & write the dataset ==\n');
    result.dataset = writeDataset(result, T, dataParentDir, options);
end
if options.SessionFolders
    fprintf('\n== session folders ==\n');
    [T, result.sessionObjects] = ndi.setup.V2.makeSessions(T, 'Overwrite', options.Overwrite, ...
        'Validate', options.ValidateOnWrite, 'Progress', true, 'BatchSize', options.WriteBatchSize);
end
result.sessions = removevars(T, 'documents');
result.written = built;
end

function path = datasetPath(dataParentDir, options)
outRoot = options.OutputRoot;
if isempty(outRoot), outRoot = fullfile(dataParentDir, 'haley_V2'); end
path = options.DatasetFolder;
if isempty(path), path = fullfile(outRoot, 'dataset'); end
end

function checkFoldersFree(T, dataParentDir, options)
% Every folder this run will write, checked before anything is built, so an
% occupied one stops the run at its start rather than after a long write.
if options.Overwrite, return; end
folders = {};
if any(options.Stages == "dataset")
    folders{end+1} = datasetPath(dataParentDir, options);
end
if options.SessionFolders
    folders = [folders, reshape(cellstr(T.path), 1, [])];
end
taken = {};
for k = 1:numel(folders)
    ndiDir = fullfile(folders{k}, '.ndi');
    if isfolder(ndiDir) && ~isempty([dir(fullfile(ndiDir, '*.sqlite')); dir(fullfile(ndiDir, '*.json'))])
        taken{end+1} = ndiDir; %#ok<AGROW>
    end
end
if ~isempty(taken)
    error('ndi:setup:conv:haley:foldersTaken', ...
        ['%d of %d folder(s) to be written already hold an NDI database; nothing was ' ...
         'built or written. Pass ''Overwrite'', true to replace them, or move them:\n  %s'], ...
        numel(taken), numel(folders), strjoin(taken, '\n  '));
end
end

function out = writeDataset(result, T, dataParentDir, options)
% Stage 13 (decision #66): every document of this run in ONE V2 database.
path = datasetPath(dataParentDir, options);
dsDocs = {};
for f = {'metadata', 'studies'}
    if isfield(result, f{1}), dsDocs = [dsDocs, reshape(result.(f{1}).documents, 1, [])]; end %#ok<AGROW>
end
if isfield(result, 'density'), dsDocs = [dsDocs, result.density.datasetDocuments]; end
name = '';
isDataset = cellfun(@(d) strcmp(ndi.setup.V2.kindOf(d), 'dataset'), dsDocs);
if any(isDataset)
    ds = dsDocs{find(isDataset, 1)};
    [~, blk] = ndi.setup.V2.kindOf(ds);   % `entity` since 2026-10-08
    if isfield(ds.(blk), 'name'), name = char(ds.(blk).name); end
end
if ~any(isDataset)
    fprintf('  no dataset document (the metadata stage did not run): sessions cannot be part of it\n');
end
sessDocs = cell(1, height(T));
for k = 1:height(T)
    own = sessionOwn(T(k, :));
    d = [own, reshape(T.documents{k}, 1, [])];
    if options.SessionFolders
        d = keepOriginals(d);     % the session folders, written next, ingest the same files
    end
    sessDocs{k} = d;
end
[ds, report] = ndi.setup.V2.createDataset(path, options.DatasetReference, ...
    result.datasetSessionId, dsDocs, sessDocs, 'Name', name, 'Overwrite', options.Overwrite, ...
    'Validate', options.ValidateOnWrite, 'BatchSize', options.WriteBatchSize);
[refs, ids] = ds.session_list();
fprintf('dataset %s at %s: %d session(s) listed by ndi.dataset\n', ds.id(), path, numel(ids));
disp(report.documents.byClass);
if height(report.edges.dangling) > 0
    fprintf('  DANGLING EDGES (an edge naming no document in the dataset):\n');
    disp(report.edges.dangling);
end
for j = 1:numel(report.duplicateIds)
    fprintf('  id repeated: %s\n', report.duplicateIds{j});
end
for j = 1:numel(report.sessions.notInDataset)
    fprintf('  session not part_of a study of the dataset: %s\n', report.sessions.notInDataset{j});
end
out = struct('path', path, 'id', ds.id(), 'report', report, 'sessionReferences', {refs}, ...
    'sessionIds', {ids});
end

function docs = sessionOwn(row)
% the session document and its study relations, exactly as createSession
% writes them into a session folder (same ids where createSession is given them)
f = struct('local_identifier', char(row.local_identifier{1}));
vars = row.Properties.VariableNames;
if ismember('name', vars) && ~isempty(row.name{1}), f.name = char(row.name{1}); end
if ismember('description', vars) && ~isempty(row.description{1}), f.description = char(row.description{1}); end
sid = char(row.session_id{1});
edges = struct();
if ~isempty(row.time_reference_id{1})
    edges.time_reference_id = row.time_reference_id{1};
end
docs = ndi.setup.V2.entityDocuments('session', f, edges, 'SessionId', sid, ...
    'Id', char(row.session_doc_id{1}));
if ismember('study_ids', vars)
    studies = row.study_ids{1};
    if ischar(studies) || isstring(studies), studies = cellstr(studies); end
    for k = 1:numel(studies)
        docs{end+1} = did2.build.directedRelation(docs{1}.base.id, studies{k}, ...
            'part_of', 'SessionId', sid); %#ok<AGROW>
    end
end
end

function docs = keepOriginals(docs)
% a copy of DOCS whose ingested files are not deleted once copied
for i = 1:numel(docs)
    d = docs{i};
    if ~isfield(d, 'files') || ~isfield(d.files, 'file_info') || isempty(d.files.file_info)
        continue;
    end
    fi = d.files.file_info;
    for a = 1:numel(fi)
        for b = 1:numel(fi(a).locations)
            fi(a).locations(b).delete_original = 0;
        end
    end
    d.files.file_info = fi;
    docs{i} = d;
end
end

function m = namesOf(spec)
% formulation and strain keys -> the names a dose's variable reads as
m = containers.Map();
for f = {'formulations', 'strains'}
    if ~isfield(spec, f{1}), continue; end
    e = spec.(f{1});
    if isstruct(e), e = num2cell(e); end
    for k = 1:numel(e)
        x = e{k};
        if isfield(x, 'type') && ~isempty(x.type)
            m(x.key) = char(x.type);
        elseif isfield(x, 'name') && ~isempty(x.name)
            m(x.key) = char(x.name);
        end
    end
end
end
