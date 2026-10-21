function result = import_V2(dataFolder, options)
%IMPORT_V2 A starter V2 (V_eta) importer: copy this folder to begin a new one.
%
%   RESULT = ndi.setup.conv.template.import_V2(DATAFOLDER) runs the import's
%   stages over the raw data in DATAFOLDER and returns what each stage built
%   and its report. Nothing is written unless 'Write' is true.
%
%   TO START A NEW IMPORT: copy +template to +<yourlab>, rename the package
%   in the error identifiers, start import_V2_decisions.md, and replace each
%   stage's private helper with your dataset's rules. Keep the runner. The
%   Haley import (ndi.setup.conv.haley.import_V2) is the full worked example;
%   this template is its shape with one example document per stage.
%
%   The stages, in their FIXED order (later stages read the ids earlier ones
%   made; each is a private helper beside this file):
%     1 sessions       the dataset entity and its studies (dataset level),
%                      then one session per data folder   sessionDocuments
%     2 entities       what each session is about           entityDocuments
%     3 acquisition    the recordings: epoch, time, the raw file by
%                      location                             acquisitionDocuments
%     4 manipulations  what was done to the entities        manipulationDocuments
%     5 observations   what was measured about them         observationDocuments
%     6 calculations   what was computed from the data      calculationDocuments
%   Every statement needs a time reference, so acquisition (which makes the
%   epochs and their times) comes before any statement. Run them one at a
%   time while building an import: pass the previous call's RESULT as
%   'Previous' and only the next stage in 'Stages'.
%
%   THE RULES THIS TEMPLATE ENCODES (from the Haley import's "Current rules"):
%     * Dataset-specific mapping lives in the SPEC (import_V2_spec.json): the
%       folder pattern, the source table and its columns, the term NAMES, the
%       units, the corrections. The code stays generic. The spec is optional:
%       without one the runner uses the defaults below (the template's own
%       example layout).
%     * Every choice is recorded in the DECISION LOG (import_V2_decisions.md),
%       with its reason, from day one; "Current rules" at its top.
%     * Terms are looked up BY NAME in DID-schema's term registry
%       (ndi.setup.V2.registeredTerm); no node is typed in code. The run
%       COLLECTS every unregistered term while it builds, and with 'Write'
%       writes nothing if there is one (error
%       ndi:setup:conv:template:unregisteredTerms, listing them all).
%     * Every stage returns a REPORT with its denominators: read, written,
%       skipped (each with why), errors (each with what), documents built.
%       On a normal run a row's error goes into the report and the stage goes
%       on; in test mode ('RunFolder', 'none') it is THROWN, so a test sees it.
%     * Source values are kept VERBATIM: `source_value`, `source_unit` as a
%       registered term (ndi.setup.V2.sourceUnit), a tolerance where the
%       source states one; a hand-written time is to the minute, approximate
%       with tolerance [60 60] s. A correction goes through ONE function
%       (applyCorrection), only while the source still reads its `was`, and
%       the document carries "Corrected from <was>: <reason>".
%     * Raw data is NEVER copied or written to: each recording's file is
%       recorded by location; sessions are written to their own folders under
%       'OutputRoot' (outside DATAFOLDER), and the dataset LINKS them (a
%       `linked_session` each, V_eta_linked_session_plan.md).
%     * The did-schema #88 shape only: one `entity` class, a statement's
%       method one block {term, parameters} (or a shared `method` document by
%       `method_id`), `included_in` for records, `session_id` an edge (the
%       session's own document id IS its session id).
%
%   Options:
%     'Spec'          the spec file (default: import_V2_spec.json beside this
%                     file; '' = none, the defaults alone)
%     'Stages'        which stages to run (default: all six), always run in
%                     the fixed order
%     'Previous'      a RESULT of an earlier call: its stages are kept and the
%                     ones named in 'Stages' are (re)built on top of it
%     'OutputRoot'    where the session folders and the dataset go (default:
%                     <DATAFOLDER>_V2 beside DATAFOLDER; never inside it)
%     'Write'         default false; true writes the dataset and its sessions
%     'Overwrite'     default false; true replaces folders already written
%     'Checksums'     default true: MD5 of every recording
%     'RunFolder'     with 'Write': where this run's record is kept (default
%                     <OutputRoot>/run_<yyyy-MM-dd_HHmmss>): import_log.txt
%                     (the console output) and import_report.mat (every
%                     stage report, the options, the error if it failed).
%                     'none' keeps no record and is TEST MODE: a row's error
%                     is thrown instead of reported.
%
%   RESULT fields: spec (the resolved spec), datasetSessionId, datasetDocuments,
%   sessions (table), entities / acquisition / manipulations / observations /
%   calculations (each with its documents per session and its id table),
%   reports (struct, one report per stage run), unregisteredTerms, and, with
%   'Write', write (the dataset's path, its check report and what was
%   written) and runFolder.
%
%   See also ndi.setup.conv.haley.import_V2, ndi.setup.V2.datasetMetadata,
%   ndi.setup.V2.createDataset, ndi.setup.V2.makeSessions.

arguments
    dataFolder (1,:) char {mustBeFolder}
    options.Spec (1,:) char = fullfile(fileparts(mfilename('fullpath')), 'import_V2_spec.json')
    options.Stages (1,:) string {mustBeMember(options.Stages, ["sessions", "entities", ...
        "acquisition", "manipulations", "observations", "calculations"])} = ...
        ["sessions", "entities", "acquisition", "manipulations", "observations", "calculations"]
    options.Previous (1,1) struct = struct()
    options.OutputRoot (1,:) char = ''
    options.Write (1,1) logical = false
    options.Overwrite (1,1) logical = false
    options.Checksums (1,1) logical = true
    options.RunFolder (1,:) char = ''
end

dataFolder = absolutePath(dataFolder);
if isempty(options.OutputRoot)
    [parent, name] = fileparts(dataFolder);
    options.OutputRoot = fullfile(parent, [name '_V2']);
end
options.OutputRoot = absolutePath(options.OutputRoot);
if startsWith([options.OutputRoot filesep], [dataFolder filesep])
    error('ndi:setup:conv:template:outputInData', ['''OutputRoot'' %s is inside the raw ' ...
        'data folder %s: an import never writes into the raw data.'], options.OutputRoot, dataFolder);
end

testMode = strcmp(options.RunFolder, 'none');
if ~options.Write || testMode
    result = runStages(dataFolder, options, testMode);
    return;
end

% With 'Write', the run keeps its own record: the console output and the
% reports, saved even when the run fails, with the error at the end.
runDir = options.RunFolder;
if isempty(runDir)
    runDir = fullfile(options.OutputRoot, ['run_' char(datetime('now'), 'yyyy-MM-dd_HHmmss')]);
end
if ~isfolder(runDir), mkdir(runDir); end
wasOn = strcmp(get(0, 'Diary'), 'on');
wasFile = get(0, 'DiaryFile');
diary off
diary(fullfile(runDir, 'import_log.txt'));
restore = onCleanup(@() restoreDiary(wasOn, wasFile)); %#ok<NASGU>
fprintf('run folder: %s\nstarted:    %s\n', runDir, char(datetime('now')));
failure = [];
try
    result = runStages(dataFolder, options, false);
catch failure
    fprintf('\n== the run FAILED ==\n%s\n', getReport(failure, 'extended', 'hyperlinks', 'off'));
    result = struct();
end
diary off
report = struct('finished', datetime('now'), 'options', options, ...
    'failed', ~isempty(failure), 'error', ''); %#ok<NASGU> (saved)
if ~isempty(failure), report.error = failure.message; end
for f = {'reports', 'unregisteredTerms', 'datasetSessionId', 'sessions', 'write'}
    if isfield(result, f{1}), report.(f{1}) = result.(f{1}); end
end
save(fullfile(runDir, 'import_report.mat'), 'report');
result.runFolder = runDir;
if ~isempty(failure)
    rethrow(failure);
end
end

% =============================================================================
function result = runStages(dataFolder, options, testMode)
% The stages, in their fixed order, then (with 'Write') the check and write.
arguments
    dataFolder (1,:) char
    options (1,1) struct
    testMode (1,1) logical
end
ndi.setup.V2.preflight();
result = options.Previous;
if ~isfield(result, 'reports'), result.reports = struct(); end
cfg = resolveSpec(options.Spec);
result.spec = cfg;

% Build with the term registry's error OFF and collection ON, so ONE run lists
% every unregistered term instead of stopping at the first; the list is
% checked before anything is written.
prevStrict = did2.schema.cache.strictMode('TermRegistry', false);
prevCollect = did2.build.unregisteredTerms('-collect', true);
did2.build.unregisteredTerms('-reset');
restore = onCleanup(@() restoreTerms(prevStrict, prevCollect)); %#ok<NASGU>

order = ["sessions", "entities", "acquisition", "manipulations", "observations", "calculations"];
for stage = order(ismember(order, options.Stages))
    fprintf('\n== stage %d: %s ==\n', find(order == stage), stage);
    switch stage
        case "sessions"
            out = sessionDocuments(dataFolder, cfg, options.OutputRoot, testMode);
            result.datasetSessionId = out.datasetSessionId;
            result.datasetDocuments = out.documents;
            result.ids = out.ids;
            result.sessions = out.sessions;
        case "entities"
            need(result, stage, "sessions");
            out = entityDocuments(result.sessions, cfg, testMode);
            result.entities = out;
        case "acquisition"
            need(result, stage, ["sessions", "entities"]);
            out = acquisitionDocuments(result.sessions, result.entities.ids, cfg, testMode, ...
                'Checksums', options.Checksums);
            result.acquisition = out;
        case "manipulations"
            need(result, stage, ["sessions", "entities"]);
            out = manipulationDocuments(result.sessions, result.entities.ids, cfg, testMode);
            result.manipulations = out;
        case "observations"
            need(result, stage, ["sessions", "entities", "acquisition"]);
            out = observationDocuments(result.sessions, result.entities.ids, ...
                result.acquisition.recordings, cfg, testMode);
            result.observations = out;
        case "calculations"
            need(result, stage, ["sessions", "entities", "acquisition"]);
            out = calculationDocuments(result.sessions, result.entities.ids, ...
                result.acquisition.recordings, cfg, testMode);
            result.calculations = out;
    end
    result.reports.(char(stage)) = out.report;
    printReport(out.report);
end

L = did2.build.unregisteredTerms();
result.unregisteredTerms = L;
fprintf('\nUNREGISTERED TERMS: %d distinct (name, node, field)\n', numel(L));
for k = 1:numel(L)
    fprintf('  %-40s %-20s %-40s x%d  %s\n', L(k).name, L(k).node, L(k).field, L(k).count, L(k).reason);
end
if ~isempty(L) && (options.Write || testMode)
    error('ndi:setup:conv:template:unregisteredTerms', ['%d term(s) are not in DID-schema''s ' ...
        'term registry (listed above); nothing was written. Correct the name in the spec, ' ...
        'or register the term ("Adding terms", Using_V2.md).'], numel(L));
end

if options.Write
    fprintf('\n== write ==\n');
    result.write = writeAll(result, options);
end
end

% =============================================================================
function need(result, stage, stages)
% A stage reads the ids the stages before it made: run them first, in this
% call or in the call whose RESULT is passed as 'Previous'.
arguments
    result (1,1) struct
    stage (1,1) string
    stages (1,:) string
end
missing = stages(~isfield(result, cellstr(stages)));
if ~isempty(missing)
    error('ndi:setup:conv:template:stageOrder', ['The %s stage needs the %s stage(s) ' ...
        'first: name them in ''Stages'', or pass the result that ran them as ''Previous''.'], ...
        stage, strjoin(missing, ', '));
end
end

% =============================================================================
function w = writeAll(result, options)
% The dataset folder holds the dataset-level documents and, per session, its
% `included_in` relations and a `linked_session` naming its folder; each
% session's own documents are written ONCE, to its own folder. The whole set
% is checked as one before anything is written (ndi.setup.V2.createDataset).
arguments
    result (1,1) struct
    options (1,1) struct
end
if ~isfield(result, 'sessions')
    error('ndi:setup:conv:template:stageOrder', ['Nothing to write: the sessions stage ' ...
        'has not run (name it in ''Stages'', or pass ''Previous'').']);
end
T = result.sessions;
n = height(T);
dsPath = fullfile(options.OutputRoot, 'dataset');
folders = [{dsPath}; T.path];
if ~options.Overwrite
    for k = 1:numel(folders)
        nd = fullfile(folders{k}, '.ndi');
        if isfolder(nd) && ~isempty([dir(fullfile(nd, '*.sqlite')); dir(fullfile(nd, '*.json'))])
            error('ndi:setup:conv:template:folderTaken', ['%s already holds an NDI database; ' ...
                'nothing was written. Pass ''Overwrite'', true to replace it.'], nd);
        end
    end
end
stageDocs = repmat({{}}, n, 1);
for f = {'entities', 'acquisition', 'manipulations', 'observations', 'calculations'}
    if ~isfield(result, f{1}), continue; end
    for k = 1:n
        stageDocs{k} = [stageDocs{k}, reshape(result.(f{1}).documents{k}, 1, [])];
    end
end
dsid = result.datasetSessionId;
sessDocs = cell(1, n);
external = {};
for k = 1:n
    sid = T.session_id{k};
    own = ndi.setup.V2.entityDocuments('session', struct('local_identifier', T.local_identifier{k}, ...
        'name', T.name{k}), struct(), 'SessionId', sid, 'Id', sid);
    studies = T.study_ids{k};
    for j = 1:numel(studies)
        own{end+1} = did2.build.directedRelation(sid, studies{j}, 'included_in', ...
            'SessionId', sid); %#ok<AGROW>
    end
    link = did2.build.document('linked_session', struct('path', ndi.v2.linkPath(T.path{k}, dsPath)), ...
        'SessionId', dsid, 'Edges', struct('entity_id', sid));
    sessDocs{k} = [own(2:end), {link}];
    external = [external, own(1), stageDocs{k}]; %#ok<AGROW>
end
name = '';
if isfield(result.spec.dataset, 'name'), name = char(result.spec.dataset.name); end
[~, check] = ndi.setup.V2.createDataset(dsPath, char(result.spec.write.dataset_reference), dsid, ...
    result.datasetDocuments, sessDocs, 'Name', name, 'Overwrite', options.Overwrite, ...
    'External', external, 'Progress', false, 'Strict', true);
Tw = T(:, {'local_identifier', 'path', 'name', 'session_id', 'session_doc_id'});
Tw.documents = stageDocs;
ndi.setup.V2.makeSessions(Tw, 'Overwrite', options.Overwrite);
ds = ndi.dataset.dir(dsPath);
[refs, ids] = ds.session_list();
fprintf('dataset %s: %d session(s) listed by ndi.dataset\n', ds.id(), numel(ids));
w = struct('path', dsPath, 'check', check, 'sessionReferences', {refs}, 'sessionIds', {ids}, ...
    'documents', numel(result.datasetDocuments) + sum(cellfun(@numel, sessDocs)) + numel(external));
end

% =============================================================================
function cfg = resolveSpec(file)
% The template's defaults (its own example layout), overlaid by every
% non-empty value in the spec file. A spec key starting with `_` is a comment
% (jsondecode renames it `x_...`) and is ignored.
arguments
    file (1,:) char
end
cfg = struct();
cfg.dataset = struct('name', 'Template dataset', ...
    'description', 'Written by ndi.setup.conv.template.import_V2.');
cfg.studies = {struct('key', 'study', 'name', 'Template study', ...
    'description', 'The one study of the template''s example data.')};
cfg.sessions = struct('folder_pattern', '^[^.]', 'name_format', 'Session %s', 'study', 'study');
cfg.entities = struct('table', 'subjects.csv', 'id_column', 'subject', 'type', 'organism');
cfg.acquisition = struct('file_column', 'recording', 'start_column', 'recorded_at', ...
    'start_format', 'yyyy-MM-dd''T''HH:mm:ss', 'duration_column', 'duration_s', ...
    'time_zone', 'UTC', 'leaf', 'intensity_observation', ...
    'variable', 'Imaging Signal Intensity', 'method', 'brightfield imaging', ...
    'format', 'MPEG-4', 'datum_type', 'uint8');
cfg.manipulations = struct('value_column', 'incubator_C', 'leaf', 'temperature_manipulation', ...
    'data_type', 'temperature', 'unit', 'C', 'scale', 1, 'tolerance', [], ...
    'variable', 'Environmental Temperature', 'method', 'incubation', ...
    'time_column', 'incubated_at', 'time_format', 'yyyy-MM-dd HH:mm', 'time_zone', 'UTC', ...
    'time_tolerance', [60 60]);
cfg.observations = struct('value_column', 'temperature_C', 'leaf', 'temperature_observation', ...
    'data_type', 'temperature', 'unit', 'C', 'scale', 1, 'tolerance', [], ...
    'variable', 'Environmental Temperature', 'method', 'Arithmetic Mean');
cfg.calculations = struct('value_column', 'diameter_mm', 'leaf', 'length_calculation', ...
    'data_type', 'length', 'unit', 'mm', 'scale', 0.001, 'tolerance', [], ...
    'variable', 'diameter', 'method', 'image segmentation');
cfg.corrections = {};
cfg.write = struct('dataset_reference', 'dataset');
if isempty(file)
    return;
end
spec = jsondecode(fileread(file));
for sec = reshape(fieldnames(spec), 1, [])
    s = sec{1};
    if startsWith(s, 'x_') || startsWith(s, '_'), continue; end
    v = spec.(s);
    if isstruct(v) && isscalar(v) && isfield(cfg, s) && isstruct(cfg.(s)) && isscalar(cfg.(s))
        for f = reshape(fieldnames(v), 1, [])
            if startsWith(f{1}, 'x_') || isempty(v.(f{1})), continue; end
            cfg.(s).(f{1}) = v.(f{1});
        end
    elseif ~isempty(v)
        cfg.(s) = v;
    end
end
end

function p = absolutePath(p)
arguments
    p (1,:) char
end
if ~startsWith(p, filesep) && isempty(regexp(p, '^[A-Za-z]:', 'once'))
    p = fullfile(pwd, p);
end
while numel(p) > 1 && any(p(end) == '/\')
    p = p(1:end-1);
end
end

function restoreTerms(prevStrict, prevCollect)
arguments
    prevStrict
    prevCollect
end
did2.schema.cache.strictMode('TermRegistry', prevStrict);
did2.build.unregisteredTerms('-collect', prevCollect);
end

function restoreDiary(wasOn, wasFile)
arguments
    wasOn (1,1) logical
    wasFile {mustBeText}
end
diary off
if wasOn
    diary(wasFile);
end
end
