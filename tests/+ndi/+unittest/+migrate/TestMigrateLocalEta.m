classdef TestMigrateLocalEta < matlab.unittest.TestCase
%TESTMIGRATELOCALETA End-to-end V_eta (Brainstorm J) migration of the two
%   session-context second-pass items, through ndi.migrate.local with
%   Validate=true so the assembled documents actually validate against the V_eta
%   schema set:
%
%     1. stimulus_bath -> dose_manipulation (D8 retired the bath family). The
%        per-document converter defers stimulus_bath; the V_eta second pass
%        (resolveDeferred -> stimulusBathToBath) assembles a dose_manipulation on
%        the stimulator's subject over its epoch.
%     2. stimulus_presentation -> visual_grating_manipulation (+ sampled_body).
%        There is no per-document migrator; resolveStimulusPresentations assembles
%        it from the recording graph (stimulus_response -> element -> subject).
%
%   Gated three ways, skips cleanly otherwise:
%     - mksqlite present (the v1 store is sqlite),
%     - NDI_TEST_ETA truthy, and
%     - DID_SCHEMA_PATH points at an assembled V_eta schema set.
%   The dedicated test-eta-migrate.yml e2e job satisfies all three; other
%   workflows skip it.

    properties
        SessionRoot
    end

    methods (TestClassSetup)
        function gate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~etaEnabled()
                assumeFail(testCase, 'NDI_TEST_ETA not truthy; skipping V_eta e2e.');
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, 'DID_SCHEMA_PATH unset; need a V_eta schema set.');
            end
        end
    end

    methods (TestMethodSetup)
        function makeFreshSession(testCase)
            testCase.SessionRoot = tempname();
            mkdir(testCase.SessionRoot);
            mkdir(fullfile(testCase.SessionRoot, '.ndi'));
        end
    end

    methods (TestMethodTeardown)
        function cleanupSession(testCase)
            try
                if isfolder(testCase.SessionRoot)
                    rmdir(testCase.SessionRoot, 's');
                end
            catch
            end
        end
    end

    methods (Test)

        function testStimulusBathResolvesToDose(testCase)
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            result = runMigrate(testCase, bodies);

            % no needsSessionContext deferral left behind
            assertNoDeferral(testCase, result);

            % the bath became a dose_manipulation (NOT the retired `bath`)
            verifyTrue(testCase, isfield(result.summary.by_class, 'dose_manipulation'), ...
                ['no dose_manipulation produced from stimulus_bath. ' resultDiag(result)]);
            verifyFalse(testCase, isfield(result.summary.by_class, 'bath'), ...
                'retired `bath` class leaked onto the V_eta path');

            dose = findByClass(result.destination, 'dose_manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            verifyEqual(testCase, depValue(dose, 'subject_id'), subjId);
            verifyNotEmpty(testCase, depValue(dose, 'time_reference_1'));
            % primary mixture chemical is the spine identity
            verifyEqual(testCase, dose.subject_statement.variable.name, 'muscimol');
        end

        function testStimulusPresentationBecomesGratingManipulation(testCase)
            subjId  = 'aabb1122ccdd3344_5500000000000010';
            recElem = 'aabb1122ccdd3344_5500000000000011';
            stimEl  = 'aabb1122ccdd3344_5500000000000012';
            presId  = 'aabb1122ccdd3344_5500000000000013';
            respId  = 'aabb1122ccdd3344_5500000000000014';
            bodies = { ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(makeStimulusPresentation(presId, stimEl))};
            result = runMigrate(testCase, bodies);

            % the presentation became a body-backed visual_grating_manipulation
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'visual_grating_manipulation'), ...
                ['no visual_grating_manipulation produced from stimulus_presentation. ' ...
                 resultDiag(result)]);
            verifyTrue(testCase, isfield(result.summary.by_class, 'sampled_body'), ...
                ['no sampled_body produced for the grating series. ' resultDiag(result)]);

            manip = findByClass(result.destination, 'visual_grating_manipulation');
            verifyNotEmpty(testCase, manip, resultDiag(result));
            verifyEqual(testCase, manip.base.id, presId);            % id preserved
            verifyEqual(testCase, depValue(manip, 'subject_id'), subjId);
            verifyEqual(testCase, manip.subject_statement.storage_mode, 'body');

            % the presentation itself is consumed (assembled away)
            verifyFalse(testCase, isfield(result.summary.by_class, 'stimulus_presentation'), ...
                'stimulus_presentation was not consumed by the second pass');
        end

    end
end

% ===================== run helper =========================================

function result = runMigrate(testCase, bodies)
srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
buildV1Sqlite(srcSqlite, bodies);
result = ndi.migrate.local(testCase.SessionRoot, ...
    'Validate', true, 'TargetVersion', 'V_eta', 'Backup', false);
[~, dstName] = fileparts(result.destination);
verifyEqual(testCase, dstName, 'V_eta');
end

function assertNoDeferral(testCase, result)
for k = 1:numel(result.quarantine)
    verifyEmpty(testCase, ...
        regexp(result.quarantine(k).reason, 'needsSessionContext|NDI layer', 'once'), ...
        sprintf('a document was left deferred: %s', result.quarantine(k).reason));
end
end

% ===================== v1 body builders (bath) ============================

function body = makeStimulatorElement(stimId, subjId)
body = struct();
body.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
body.base = struct('id', stimId, 'session_id', session(), ...
    'name', 'stimulator', 'datestamp', datestamp());
body.element = struct('ndi_element_class', 'ndi.element', 'name', 'stim', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);
end

function body = makeElementEpoch(stimId, epochId, clock)
body = struct();
body.document_class = struct('class_name', 'element_epoch', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {stimId});
body.base = struct('id', 'aabb1122ccdd3344_5500000000000003', ...
    'session_id', session(), 'name', 'stim_epoch', 'datestamp', datestamp());
body.epochid = struct('epochid', epochId);
body.element_epoch = struct('epoch_clock', clock, 't0_t1', [0 1]);
end

function body = makeStimulusBath(stimId, epochId)
body = struct();
body.document_class = struct('class_name', 'stimulus_bath', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
body.base = struct('id', 'aabb1122ccdd3344_5500000000000004', ...
    'session_id', session(), 'name', 'bath', 'datestamp', datestamp());
body.epochid = struct('epochid', epochId);
body.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');
end

% ===================== v1 body builders (presentation) ====================

function body = makeSubject(subjId)
body = struct();
body.document_class = struct('class_name', 'subject', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', subjId, 'session_id', session(), ...
    'name', 'animal', 'datestamp', datestamp());
body.subject = struct('local_identifier', 'animalA', 'description', '');
end

function body = makeRecordingElement(elemId, subjId)
body = struct();
body.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
body.base = struct('id', elemId, 'session_id', session(), ...
    'name', 'ctx', 'datestamp', datestamp());
body.element = struct('ndi_element_class', 'ndi.element', 'name', 'ctx', ...
    'reference', 1, 'type', 'lfp', 'direct', 1);
end

function body = makeStimulusResponse(respId, presId, elemId)
body = struct();
body.document_class = struct('class_name', 'stimulus_response', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = [ ...
    struct('name', 'stimulus_presentation_id', 'value', presId), ...
    struct('name', 'element_id',               'value', elemId)];
body.base = struct('id', respId, 'session_id', session(), ...
    'name', 'resp', 'datestamp', datestamp());
body.stimulus_response = struct('response_type', 'mean');
end

function body = makeStimulusPresentation(presId, stimEl)
s1 = gratingStim(45); s2 = gratingStim(90);
body = struct();
body.document_class = struct('class_name', 'stimulus_presentation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimEl});
body.base = struct('id', presId, 'session_id', session(), ...
    'name', 'sp', 'datestamp', datestamp());
body.stimulus_presentation = struct('presentation_order', [1 2], ...
    'presentation_time', [trialTime(0, 4) trialTime(5, 9)], 'stimuli', [s1 s2]);
end

function s = gratingStim(angle)
s = struct('parameters', struct('angle', angle, 'sFrequency', 0.5, ...
    'tFrequency', 2, 'contrast', 1, 'size', 30, 'isblank', 0));
end

function t = trialTime(onset, offset)
t = struct('onset', onset, 'offset', offset);
end

function s = session()
s = 'aabb1122ccdd3344_9900aabbccddeeff';
end

function d = datestamp()
d = '2024-06-01T12:00:00.000Z';
end

% ===================== inspection / sqlite helpers ========================

function body = findByClass(dstPath, className)
body = [];
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
for k = 1:numel(ids)
    doc = db.get(ids{k});
    if strcmp(doc.className(), className)
        body = doc.toStruct();
        return;
    end
end
end

function v = depValue(body, name)
v = '';
if isfield(body, 'depends_on') && isstruct(body.depends_on)
    for k = 1:numel(body.depends_on)
        d = body.depends_on(k);
        if isfield(d, 'name') && strcmp(d.name, name)
            if isfield(d, 'value'); v = d.value;
            elseif isfield(d, 'document_id'); v = d.document_id; end
            return;
        end
    end
end
end

function buildV1Sqlite(tmpFile, bodies)
dbid = mksqlite(0, 'open', tmpFile);
cleanup = onCleanup(@() mksqlite(dbid, 'close')); %#ok<NASGU>
mksqlite(dbid, ['CREATE TABLE docs (' ...
    'doc_id    TEXT    NOT NULL UNIQUE, ' ...
    'doc_idx   INTEGER NOT NULL UNIQUE, ' ...
    'json_code TEXT, ' ...
    'timestamp NUMERIC, ' ...
    'PRIMARY KEY(doc_idx AUTOINCREMENT))']);
for k = 1:numel(bodies)
    docId = sprintf('id_%04d', k);
    mksqlite(dbid, ...
        'INSERT INTO docs (doc_id, doc_idx, json_code, timestamp) VALUES (?, ?, ?, ?)', ...
        docId, k, bodies{k}, 0);
end
end

function tf = etaEnabled()
raw = lower(strtrim(getenv('NDI_TEST_ETA')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end

function s = resultDiag(result)
% Compact dump of what the migration actually produced, so a missing-doc
% failure names the migrated classes and every quarantine reason instead of
% just reporting `[]`.
byClass = '(none)';
if isfield(result, 'summary') && isfield(result.summary, 'by_class') ...
        && isstruct(result.summary.by_class)
    fns = fieldnames(result.summary.by_class);
    if ~isempty(fns); byClass = strjoin(fns(:)', ', '); end
end
reasons = {};
if isfield(result, 'quarantine')
    for k = 1:numel(result.quarantine)
        q = result.quarantine(k);
        cn = ''; rs = '';
        if isfield(q, 'class_name'); cn = char(q.class_name); end
        if isfield(q, 'reason');     rs = char(q.reason);     end
        reasons{end+1} = sprintf('[%s] %s', cn, rs); %#ok<AGROW>
    end
end
quar = '(none)';
if ~isempty(reasons); quar = strjoin(reasons, ' | '); end
s = sprintf('migrated by_class = {%s}; quarantine = {%s}', byClass, quar);
end
