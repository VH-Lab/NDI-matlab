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
%     3. THE EPOCH ANCHOR, BOTH WAYS. The bath assembler mints an
%        `epoch_bounded_reference` -- a class the signed time-reference decision
%        RETIRES (DID-schema/schemas/V_eta_time_reference_model_plan.md,
%        TEAM-SIGN-OFF [time_reference] 2026-08-08; migration table line 195
%        folds it into `relative_reference`, ids preserved). Step (5b) of
%        ndi.migrate.local (ndi.migrate.internal.epochAnchorFold) folds it.
%
%        WHY THESE TWO TESTS EXIST AT ALL, given that
%        tests/+ndi/+unittest/+migrate/TestEpochAnchorFold.m already has 27
%        methods over the same pass: EVERY BODY IN THAT FILE IS HAND-BUILT.
%        Its `anchorDoc` fixture is a TRANSCRIPTION of the emitter, and its own
%        docstring says so ("The body ndi.migrate.internal.stimulusBathToBath
%        mints under V_eta ... as it comes back out of a migrated did2.document's
%        toStruct()"). A transcription cannot catch the emitter moving: rename
%        the `epochid` block, move `epoch_clock`, or change the class version at
%        the mint site and all 27 stay green while production silently stops
%        folding. These two drive the REAL emitter through the REAL pipeline --
%        v1 sqlite -> converter deferral -> stimulusBathToBath -> v1_to_v2 ->
%        epochMint -> epochAnchorFold -> the V_eta database -- and assert on
%        what is IN that database.
%
%        The fold is CONDITIONAL, so both branches are pinned:
%          (a) with a `session` document in the batch, epochMint mints the
%              `epoch` and the anchor folds, base.id PRESERVED;
%          (b) without one, epochMint refuses (`skipped_no_session_document`),
%              the fold refuses (`refused_no_epoch_document`), and the RETIRED
%              CLASS IS WRITTEN TO THE DATABASE. (b) is not a hypothetical: it
%              is exactly the fixture testStimulusBathResolvesToDose has always
%              used, which is why the retirement looked complete while an
%              `epoch_bounded_reference` was reaching a database on every run of
%              this file.
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

        function testEpochAnchorFoldsToRelativeReferenceWithItsIdPreserved(testCase)
            % (a) WITH a `session` document. The whole chain, driven from the
            % real emitter: the bath is deferred, stimulusBathToBath mints the
            % pass-1 `epoch_bounded_reference`, epochMint mints the `epoch` for
            % the (base.session_id, epoch-id string) PAIR, and epochAnchorFold
            % upgrades the placeholder in place.
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            sessId  = 'aabb1122ccdd3344_5500000000000005';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeSessionDoc(sessId)), ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            result = runMigrate(testCase, bodies);
            assertNoDeferral(testCase, result);

            % --- DENOMINATORS FIRST, off the pass's own instrument ---------
            % Asserted BEFORE any class-name check so that "the fold did not
            % run" and "the fold ran and refused" are different failures.
            mint = result.secondPass.epochMint;
            verifyNotEmpty(testCase, mint, 'epochMint did not run at all');
            verifyEqual(testCase, mint.session_documents_seen, 1, ...
                ['the `session` document did not survive migration, so ' ...
                 'epochMint had nothing to anchor an `epoch` to. ' resultDiag(result)]);
            verifyEqual(testCase, mint.skipped_no_session_document, 0, ...
                resultDiag(result));

            fold = result.secondPass.epochAnchorFold;
            verifyNotEmpty(testCase, fold, ...
                ['the epoch anchor fold did not run; ndi.migrate.local warns ' ...
                 'and continues when it throws. ' resultDiag(result)]);
            verifyEqual(testCase, fold.anchors_seen, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_planned, 1, resultDiag(result));
            verifyEqual(testCase, fold.refused_total, 0, resultDiag(result));
            verifyEqual(testCase, fold.anchors_refolded, 1, resultDiag(result));
            verifyEqual(testCase, fold.refold_quarantined, 0, resultDiag(result));
            verifyTrue(testCase, fold.folded, resultDiag(result));
            % the accounting invariant, on the real corpus shape rather than a
            % hand-built one: there is no third bucket an anchor can vanish into
            verifyEqual(testCase, fold.anchors_seen, ...
                fold.anchors_planned + fold.refused_total);

            % --- the retired class is GONE from the database ---------------
            verifyFalse(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                ['a class the signed decision RETIRES was written to the ' ...
                 'destination database. ' resultDiag(result)]);
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'relative_reference'), ...
                resultDiag(result));
            verifyTrue(testCase, isfield(result.summary.by_class, 'epoch'), ...
                resultDiag(result));

            % --- THE ID IS PRESERVED (this is the orphan gate) -------------
            % A dissolution that changed ids produced 11,448 orphans in the Soph
            % corpus. The dose's `time_reference_1` edge was written by the
            % assembler in pass 1 and must still name the same document after
            % the fold has replaced its class.
            dose = findByClass(result.destination, 'dose_manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            anchorId = depValue(dose, 'time_reference_1');
            verifyNotEmpty(testCase, anchorId, resultDiag(result));

            ref = findByClass(result.destination, 'relative_reference');
            verifyNotEmpty(testCase, ref, resultDiag(result));
            verifyEqual(testCase, ref.base.id, anchorId, ...
                'the fold moved the anchor id; every time_reference_1 edge dangles');

            % and the whole graph still closes
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                'the fold produced orphans');

            % --- `relative_to` names the epoch epochMint actually minted ----
            epochDoc = findByClass(result.destination, 'epoch');
            verifyNotEmpty(testCase, epochDoc, resultDiag(result));
            verifyEqual(testCase, depValue(ref, 'relative_to'), epochDoc.base.id);
            % the pass-1 handle does not survive alongside its own resolution
            verifyEmpty(testCase, depValue(ref, 'element_id'));
            verifyFalse(testCase, isfield(ref, 'epochid'));
            verifyFalse(testCase, isfield(ref, 'epoch_bounded_reference'));

            % --- the signed value shape ------------------------------------
            verifyEqual(testCase, ref.relative_reference.value.relation.node, ...
                'time:intervalDuring');
            % the clock is READ THROUGH bodyResolver from the element_epoch
            % document above, not asserted by the anchor -- so this also pins
            % that the emitter -> fold clock hand-off survives the round trip.
            verifyEqual(testCase, ref.relative_reference.value.clock.name, ...
                'dev_local_time');
            % CHANGE 5 / decision C: the source states no offsets, so none are
            % invented, and with a single anchor the split-anchored interval
            % case (fork C) does not arise. NO start_anchor/end_anchor is built.
            verifyFalse(testCase, ...
                isfield(ref.relative_reference.value, 'start'));
            verifyFalse(testCase, ...
                isfield(ref.relative_reference.value, 'duration'));
        end

        function testWithoutASessionDocumentTheRetiredAnchorReachesTheDatabase(testCase)
            % (b) WITHOUT a `session` document -- the fixture this file has
            % always used. This is not a test of a hypothetical: it pins what
            % ACTUALLY HAPPENS to a minted `epoch_bounded_reference` when the
            % fold cannot resolve it, which is that ndi.migrate.local writes it
            % to the destination database as a retired class.
            %
            % It is deliberately NOT written as "the fold is broken": the
            % refusal is correct behaviour (DISCOVERY MODE -- a subset batch
            % need not carry the `session` document, and absence is not
            % evidence). A guess here would be a blank required `relative_to`,
            % which quarantines under the armed RequiredDependencies check.
            % What the test forbids is the refusal being SILENT.
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            result = runMigrate(testCase, bodies);
            assertNoDeferral(testCase, result);

            mint = result.secondPass.epochMint;
            verifyNotEmpty(testCase, mint, resultDiag(result));
            verifyEqual(testCase, mint.session_documents_seen, 0, resultDiag(result));
            verifyEqual(testCase, mint.skipped_no_session_document, 1, ...
                ['epochMint did not refuse for the reason this test pins. ' ...
                 resultDiag(result)]);

            fold = result.secondPass.epochAnchorFold;
            verifyNotEmpty(testCase, fold, resultDiag(result));
            % the anchor was SEEN -- the pass read it and declined; it did not
            % fail to notice it
            verifyEqual(testCase, fold.anchors_seen, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_planned, 0, resultDiag(result));
            verifyEqual(testCase, fold.refused_no_epoch_document, 1, ...
                resultDiag(result));
            verifyEqual(testCase, fold.refused_total, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_refolded, 0, resultDiag(result));
            verifyFalse(testCase, fold.folded, resultDiag(result));

            % THE FINDING, PINNED: the retired class is in the database.
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                ['a refused anchor must be left EXACTLY as it was; it is no ' ...
                 'longer in the migrated set. ' resultDiag(result)]);
            verifyFalse(testCase, ...
                isfield(result.summary.by_class, 'relative_reference'), ...
                ['an anchor was folded with no `epoch` to anchor to -- the ' ...
                 'guess this pass exists to refuse. ' resultDiag(result)]);
            verifyFalse(testCase, isfield(result.summary.by_class, 'epoch'), ...
                resultDiag(result));

            % A refusal is a no-op, not a loss: the edge still resolves, so the
            % un-folded state is not an orphan failure either.
            dose = findByClass(result.destination, 'dose_manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            anchor = findByClass(result.destination, 'epoch_bounded_reference');
            verifyNotEmpty(testCase, anchor, resultDiag(result));
            verifyEqual(testCase, anchor.base.id, ...
                depValue(dose, 'time_reference_1'));
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                resultDiag(result));
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

function body = makeSessionDoc(sessDocId)
%MAKESESSIONDOC The did_v1 `session` document, from the NDI template.
%   ndi.session.dir creates and PERSISTS one on first open, so a real migration
%   has it; this fixture had never carried one, which is why the epoch mint
%   silently refused here. Shape read from the writer's own template, NOT from a
%   DID-side schema (the ground-truth rule):
%
%     NDI-matlab src/ndi/ndi_common/database_documents/session.json
%       class_name "session", superclasses [base], depends_on [],
%       "session": { "reference": "" }
%
%   `session` has NO migrator -- it passes through as `session` (DID-schema
%   V_eta_coverage_ledger.md:71, "passes through as `session` (no migrator)";
%   persist) -- and V_eta/stable/session.json makes `reference` mustBeNonEmpty,
%   so it is populated rather than left blank.
%
%   NOTE base.id here is DELIBERATELY NOT base.session_id: ndi.document.m mints
%   base.id from a fresh ndi.ido() while ndi.session's newdocument sets
%   base.session_id separately, and epochMint INDEXES the session documents
%   rather than assuming the two strings are equal (epochMint.m, "the session
%   DOCUMENT's `base.id`, which is NOT the `base.session_id` its siblings
%   carry"). A fixture that made them equal would let a broken index pass.
body = struct();
body.document_class = struct('class_name', 'session', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {}, 'value', {});
body.base = struct('id', sessDocId, 'session_id', session(), ...
    'name', 'session', 'datestamp', datestamp());
body.session = struct('reference', 'exp_eta_1');
end

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
