classdef TestMigrateLocalEpsilon < matlab.unittest.TestCase
%TESTMIGRATELOCALEPSILON End-to-end V_epsilon migration of a stimulus_bath.
%
%   This is the real-session verification of the context-dependent
%   stimulus_bath -> bath migration (issue #782): the per-document DID
%   converter defers stimulus_bath with did2:convert:needsSessionContext,
%   and ndi.migrate.local's second pass must resolve it using the
%   session/element graph (ndi.migrate.internal.bodyResolver +
%   stimulusBathToBath). Synthetic unit tests cannot prove that the
%   assembled bath actually VALIDATES against the V_epsilon schema or that
%   the resolver reads the right subject/epoch from a live body set; this
%   test does, by building a small but complete v1 session on disk and
%   running ndi.migrate.local against it with Validate=true.
%
%   It is gated three ways and skips cleanly otherwise:
%     - mksqlite must be present (the v1 store is sqlite),
%     - NDI_TEST_EPSILON must be truthy, and
%     - DID_SCHEMA_PATH must point at a V_epsilon schema set.
%   Only the dedicated NDI V_epsilon CI job (which checks out the
%   TargetVersion-aware DID-matlab and assembles the V_epsilon schemas)
%   satisfies all three; run-tests.yml (stable DID-matlab, V_delta) and
%   test-vnext.yml (V_delta) skip it.

    properties
        SessionRoot
    end

    methods (TestClassSetup)
        function gate(testCase)
            if isempty(which('mksqlite'))
                assumeFail(testCase, 'mksqlite not on path; skipping.');
            end
            if ~epsilonEnabled()
                assumeFail(testCase, ...
                    ['NDI_TEST_EPSILON not truthy; skipping the V_epsilon ', ...
                     'stimulus_bath end-to-end migration test.']);
            end
            if isempty(getenv('DID_SCHEMA_PATH'))
                assumeFail(testCase, ...
                    'DID_SCHEMA_PATH unset; need a V_epsilon schema set.');
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
                'Validate', true, 'TargetVersion', 'V_epsilon', 'Backup', false);

            % The destination is the V_epsilon store (not V_delta).
            [~, dstName] = fileparts(result.destination);
            verifyEqual(testCase, dstName, 'V_epsilon');

            % The stimulus_bath must NOT be left deferred: resolveDeferred
            % should have consumed the needsSessionContext quarantine.
            for k = 1:numel(result.quarantine)
                verifyEmpty(testCase, ...
                    regexp(result.quarantine(k).reason, ...
                        'needsSessionContext|NDI layer', 'once'), ...
                    sprintf('stimulus_bath left deferred: %s', ...
                        result.quarantine(k).reason));
            end

            % The assembled bath + its epoch_bounded_reference must be
            % present in the migrated output (they validated).
            verifyTrue(testCase, isfield(result.summary.by_class, 'bath'), ...
                'no bath document was produced');
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                'no epoch_bounded_reference was produced');

            % The bath must carry the stimulator's subject + a time_reference.
            bathBody = findByClass(result.destination, 'bath');
            verifyNotEmpty(testCase, bathBody, 'bath not found in V_epsilon store');
            verifyEqual(testCase, depValue(bathBody, 'subject_id'), subjId);
            verifyNotEmpty(testCase, depValue(bathBody, 'time_reference_1'));

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

function tf = epsilonEnabled()
raw = lower(strtrim(getenv('NDI_TEST_EPSILON')));
tf = ismember(raw, {'1', 'true', 'yes', 'y', 'on'});
end
