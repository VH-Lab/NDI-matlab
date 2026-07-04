classdef TestMigrateLocalZeta < matlab.unittest.TestCase
%TESTMIGRATELOCALZETA End-to-end V_zeta (Brainstorm I) migration of a stimulus_bath.
%
%   Real-session verification of the context-dependent stimulus_bath -> bath
%   migration under Brainstorm I (issue #782): the per-document DID converter
%   defers stimulus_bath with did2:convert:needsSessionContext, and
%   ndi.migrate.local's second pass resolves it using the session/element graph
%   (ndi.migrate.internal.bodyResolver + stimulusBathToBath). This test builds a
%   small but complete v1 session on disk and runs ndi.migrate.local against it
%   with TargetVersion='V_zeta', Validate=true, so the assembled bath actually
%   validates against the V_zeta schema.
%
%   The V_zeta difference from the E test: a bath is a subject_interaction, so
%   the assembled bath carries the spine `subject_interaction.variable` (the
%   primary mixture chemical) in addition to subject_id + time_reference.
%
%   Gated three ways, skips cleanly otherwise:
%     - mksqlite must be present (the v1 store is sqlite),
%     - NDI_TEST_ZETA must be truthy, and
%     - DID_SCHEMA_PATH must point at a V_zeta schema set.
%   Only the dedicated NDI V_zeta CI job (which checks out the
%   TargetVersion-aware DID-matlab and assembles the V_zeta schemas) satisfies
%   all three; other workflows skip it.

    properties
        SessionRoot
    end

    methods (TestClassSetup)
        function gate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~zetaEnabled()
                assumeFail(testCase, ...
                    ['NDI_TEST_ZETA not truthy; skipping the V_zeta ', ...
                     'stimulus_bath end-to-end migration test.']);
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, ...
                    'DID_SCHEMA_PATH unset; need a V_zeta schema set.');
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

        function testStimulusBathResolvesToBath(testCase)
            subjId = 'aabb1122ccdd3344_5500000000000001';
            stimId = 'aabb1122ccdd3344_5500000000000002';
            epochId = 'epoch_t00001';

            bodies = { ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            srcSqlite = fullfile(testCase.SessionRoot, '.ndi', 'did-sqlite.sqlite');
            buildV1Sqlite(srcSqlite, bodies);

            result = ndi.migrate.local(testCase.SessionRoot, ...
                'Validate', true, 'TargetVersion', 'V_zeta', 'Backup', false);

            % The destination is the V_zeta store (not V_delta).
            [~, dstName] = fileparts(result.destination);
            verifyEqual(testCase, dstName, 'V_zeta');

            % The stimulus_bath must NOT be left deferred: resolveDeferred
            % should have consumed the needsSessionContext quarantine.
            for k = 1:numel(result.quarantine)
                verifyEmpty(testCase, ...
                    regexp(result.quarantine(k).reason, ...
                        'needsSessionContext|NDI layer', 'once'), ...
                    sprintf('stimulus_bath left deferred: %s', ...
                        result.quarantine(k).reason));
            end

            % The assembled bath + its epoch_bounded_reference must be present
            % in the migrated output (they validated).
            verifyTrue(testCase, isfield(result.summary.by_class, 'bath'), ...
                'no bath document was produced');
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                'no epoch_bounded_reference was produced');

            % The bath must carry the stimulator's subject + a time_reference.
            bathBody = findByClass(result.destination, 'bath');
            verifyNotEmpty(testCase, bathBody, 'bath not found in V_zeta store');
            verifyEqual(testCase, depValue(bathBody, 'subject_id'), subjId);
            verifyNotEmpty(testCase, depValue(bathBody, 'time_reference_1'));

            % Brainstorm I: identity is on the spine. The primary chemical
            % (muscimol) is the `variable`.
            verifyTrue(testCase, isfield(bathBody, 'subject_interaction'), ...
                'bath missing the subject_interaction spine block');
            verifyEqual(testCase, ...
                bathBody.subject_interaction.variable.name, 'muscimol');

            % The epoch reference must carry the stimulator's epoch + clock.
            refBody = findByClass(result.destination, 'epoch_bounded_reference');
            verifyNotEmpty(testCase, refBody);
            verifyEqual(testCase, refBody.epochid.epochid, epochId);
            verifyEqual(testCase, ...
                refBody.epoch_bounded_reference.epoch_clock, 'dev_local_time');
        end

    end
end

% ===================== v1 body builders ===================================

function body = makeStimulatorElement(stimId, subjId)
body = struct();
body.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
body.base = struct('id', stimId, ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'stimulator', 'datestamp', '2024-06-01T12:00:00.000Z');
body.element = struct('ndi_element_class', 'ndi.element', 'name', 'stim', ...
    'reference', 1, 'type', 'stimulator', 'direct', 0);
end

function body = makeElementEpoch(stimId, epochId, clock)
body = struct();
body.document_class = struct('class_name', 'element_epoch', ...
    'class_version', '1.0.0', 'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'element_id'}, 'value', {stimId});
body.base = struct('id', 'aabb1122ccdd3344_5500000000000003', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'stim_epoch', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', epochId);
body.element_epoch = struct('epoch_clock', clock, 't0_t1', [0 1]);
end

function body = makeStimulusBath(stimId, epochId)
body = struct();
body.document_class = struct('class_name', 'stimulus_bath', ...
    'class_version', '1.0.0', 'superclasses', [ ...
        struct('class_name', 'base',    'class_version', '1.0.0'), ...
        struct('class_name', 'epochid', 'class_version', '1.0.0')]);
body.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimId});
body.base = struct('id', 'aabb1122ccdd3344_5500000000000004', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name', 'bath', 'datestamp', '2024-06-01T12:00:00.000Z');
body.epochid = struct('epochid', epochId);
body.stimulus_bath = struct( ...
    'location', struct('ontologyNode', 'uberon:0001017', 'name', 'CNS'), ...
    'mixture_table', 'chebi:6904,muscimol,5,,mg/ml');
end

% ===================== inspection helpers =================================

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

% ===================== sqlite + gate helpers ==============================

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

function tf = zetaEnabled()
raw = lower(strtrim(getenv('NDI_TEST_ZETA')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end
