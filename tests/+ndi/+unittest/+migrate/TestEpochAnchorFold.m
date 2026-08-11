classdef TestEpochAnchorFold < matlab.unittest.TestCase
%TESTEPOCHANCHORFOLD Unit tests for ndi.migrate.internal.epochAnchorFold, the
%   V_eta second pass that folds the NDI path's `epoch_bounded_reference`
%   placeholders into the signed `relative_reference`.
%
%   Pure struct logic: no database, no schema cache, no converter.
%
%   WHAT IS BEING PINNED, AND WHY EACH PIN EXISTS
%   ---------------------------------------------------------------------
%   * The class actually changes. `epoch_bounded_reference` is retired by
%     DID-schema/schemas/V_eta_time_reference_model_plan.md (TEAM-SIGN-OFF
%     [time_reference], 2026-08-08; migration table line 195), and until this
%     fold existed the NDI path minted it fully populated with nothing to
%     consume it -- `did2.convert.resolveSessionAnchors` matches exactly two
%     class names and neither is this one (resolveSessionAnchors.m:244-245).
%
%   * THE KEY IS THE PAIR (base.session_id, epoch-id string), never the string.
%     `testSameEpochStringInAnotherSessionDoesNotResolve` is the whole point:
%     an `epochid.epochid` string is REUSED ACROSS SESSIONS -- 142 of corpus B's
%     149 distinct ids, measured by did2.convert.epochMint -- so a string key
%     silently FUSES recordings from different animals. That is not a rare
%     edge case; it is almost the whole corpus.
%
%   * A refusal LEAVES THE DOCUMENT ALONE and is COUNTED. Every refusal path
%     has a test, and the accounting invariant test asserts that seen ==
%     planned + refused, so there is no third bucket an anchor can vanish into.
%
%   * NO BLANK REQUIRED EDGE, EVER. `relative_reference.relative_to` is
%     mustBeNonEmpty and the RequiredDependencies strict check is armed; the
%     fold only ever emits an edge it resolved from epochMint's index.
%
%   STATUS 2026-08-11: FIRST EXECUTION DONE. Authored without local MATLAB, and
%   the header below this one said "THESE TESTS HAVE NOT BEEN RUN" until
%   test-eta-migrate.yml run 31463051482 (af840428f) ran them.
%
%       DENOMINATOR: 27 Test methods in this file (`grep -c "function test"`,
%                    and the run's own dots agree: 3 + 7 + 10 + 7 = 27).
%                    26 passed, 1 failed, 0 incomplete, 0 filtered.
%
%   The one failure was the TEST being wrong, not the fold:
%
%       Verification failed in
%         TestEpochAnchorFold/testNonAnchorDocumentsAreInspectedButNot...
%       verifyEqual failed.  Actual 3, Expected 4.
%       ... TestEpochAnchorFold.m ... at 82
%
%   `oneFoldableAnchor` returns ONE document; the test adds two more and then
%   asserted a denominator of FOUR. Three is right. epochAnchorFold.m:219 sets
%   `documents_inspected = numel(migratedStructs)` unconditionally, before a
%   single body is read, which is what the denominator rule asks for -- no code
%   change was warranted and none was made. The literal is now tied to
%   numel(docs) and to `anchors_seen`, so an off-by-one in the fixture cannot
%   masquerade as a counter defect again. The distinction the test exists to
%   protect (inspected > anchors_seen; non-anchors land in the denominator and
%   in no anchor bucket) is asserted MORE tightly than before, not relaxed.
%
%   The other 26 methods ran green on that first execution. Read that narrowly:
%   this file and epochAnchorFold.m were written by the same author in the same
%   session, so green proves the pair is self-consistent and free of load/arity
%   faults -- not that the fold matches NDI ground truth. (This paragraph said
%   "21 of 22" when it was first written, counted from memory rather than from
%   the file. The correction is recorded rather than quietly overwritten because
%   the direction was the usual one: a made-up denominator that reads as
%   measured.)
%
%   Run with:  runtests('ndi.unittest.migrate.TestEpochAnchorFold')

    methods (Test)

        % ---------------- denominators ----------------------------------

        function testEmptyInputStillReportsItsDenominators(testCase)
            [plan, report] = ndi.migrate.internal.epochAnchorFold({});
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.epoch_index_rows, 0);
            testCase.verifyEqual(report.anchors_seen, 0);
            testCase.verifyEqual(report.anchors_planned, 0);
            testCase.verifyEqual(report.refused_total, 0);
            testCase.verifyFalse(report.changed);
        end

        function testDenominatorsCountWhatWasActuallyRead(testCase)
            [docs, idx] = oneFoldableAnchor();
            [~, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(report.documents_inspected, numel(docs));
            testCase.verifyEqual(report.epoch_index_rows, numel(idx));
            testCase.verifyEqual(report.epoch_index_pairs_usable, 1);
            testCase.verifyEqual(report.anchors_seen, 1);
        end

        function testSeenEqualsPlannedPlusRefused(testCase)
            % The instrument must account for every anchor it looked at. There
            % is no third bucket.
            [docs, idx] = mixedAnchors();
            [~, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(report.anchors_seen, ...
                report.anchors_planned + report.refused_total);
            testCase.verifyEqual(report.refused_total, ...
                report.refused_no_epoch_string ...
                + report.refused_no_session_id ...
                + report.refused_no_epoch_document ...
                + report.refused_clock_no_time ...
                + report.refused_clock_inherited ...
                + report.refused_clock_unknown);
        end

        function testNonAnchorDocumentsAreInspectedButNotCountedAsAnchors(testCase)
            % THE PROPERTY: "looked at nothing" and "looked and found no
            % anchors" must be DIFFERENT numbers, so the denominator has to
            % count documents this pass will not touch. It is asserted here as
            % a RELATION between the two counters, not as a bare literal --
            % the literal is what broke (see the correction note below).
            [docs, idx] = oneFoldableAnchor();      % one anchor, by its name
            nonAnchors = 2;
            docs{end+1} = migratedDoc('other_1', 'sess_09', 'dose_manipulation');
            docs{end+1} = migratedDoc('other_2', 'sess_09', 'subject');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);

            % DENOMINATOR: 1 anchor + 2 non-anchors = 3 documents in.
            testCase.verifyEqual(numel(docs), 1 + nonAnchors);
            testCase.verifyEqual(report.documents_inspected, numel(docs));
            testCase.verifyEqual(report.anchors_seen, 1);
            % the whole point: the 2 non-anchors are in the denominator and in
            % NEITHER anchor bucket.
            testCase.verifyEqual( ...
                report.documents_inspected - report.anchors_seen, nonAnchors);
            testCase.verifyEqual(numel(plan), 1);
        end

        % ---------------- the fold itself -------------------------------

        function testAnchorBecomesRelativeReference(testCase)
            [docs, idx] = oneFoldableAnchor();
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(numel(plan), 1);
            b = plan(1).body;
            testCase.verifyEqual(b.document_class.class_name, ...
                'relative_reference');
            testCase.verifyEqual(b.document_class.class_version, '2.0.0');
            testCase.verifyEqual(b.document_class.superclasses.class_name, ...
                'time_reference');
            testCase.verifyEqual(b.document_class.schema_version, 'V_eta');
            testCase.verifyEqual(report.anchors_planned, 1);
            testCase.verifyTrue(report.changed);
        end

        function testTheDocumentIdIsPreserved(testCase)
            % Every `time_reference_1` edge on the manipulation points here. If
            % the id moved, the fold would manufacture orphans -- the 11,448
            % failure the calculator dissolution produced.
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(plan(1).body.base.id, 'anchor_1');
            testCase.verifyEqual(plan(1).source_id, 'anchor_1');
        end

        function testRelativeToNamesTheMintedEpochDocument(testCase)
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            deps = plan(1).body.depends_on;
            testCase.verifyEqual(numel(deps), 1);
            testCase.verifyEqual(deps(1).name, 'relative_to');
            testCase.verifyEqual(deps(1).value, 'epoch_doc_A');
            testCase.verifyEqual(plan(1).epoch_document_id, 'epoch_doc_A');
        end

        function testTheRetiredElementEdgeIsReplacedNotKept(testCase)
            % `relative_reference` declares exactly one dependency. Keeping
            % `element_id` would be an undeclared edge on the new class.
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(depValue(plan(1).body, 'element_id'));
        end

        function testTheRetiredBlocksAreRemoved(testCase)
            % The old class block, the `epochid` mixin and the deprecated
            % root flag all go: a strict-fields check would reject the first
            % two on the new class, and CHANGE 2 of the signed walkthrough
            % deletes the third.
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            b = plan(1).body;
            testCase.verifyFalse(isfield(b, 'epoch_bounded_reference'));
            testCase.verifyFalse(isfield(b, 'epochid'));
            testCase.verifyFalse(isfield(b, 'time_reference'));
        end

        function testRelationIsDuringAsAnOwlTimeTerm(testCase)
            % 'during' is read from the coarse counterpart of this assembler
            % (resolveDeferredBaths.m:188,237 both write relation 'during'),
            % not picked; it maps to OWL-Time through the same vocabulary
            % resolveSessionAnchors uses.
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            rel = plan(1).body.relative_reference.value.relation;
            testCase.verifyEqual(rel.node, 'time:intervalDuring');
            testCase.verifyEqual(rel.name, 'intervalDuring');
        end

        function testNoStartAndNoDurationAreInvented(testCase)
            % The source document has no offsets, and the plan is explicit that
            % their ABSENCE is the imprecision. A reference carrying invented or
            % NaN metrics is the hollow document silentLoss exists to catch.
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            value = plan(1).body.relative_reference.value;
            testCase.verifyFalse(isfield(value, 'start'));
            testCase.verifyFalse(isfield(value, 'duration'));
        end

        function testTheSourceStructIsNotMutated(testCase)
            [docs, idx] = oneFoldableAnchor();
            ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(docs{1}.document_class.class_name, ...
                'epoch_bounded_reference');
            testCase.verifyTrue(isfield(docs{1}, 'epochid'));
        end

        % ---------------- THE PAIR KEY -----------------------------------

        function testSameEpochStringInAnotherSessionDoesNotResolve(testCase)
            % THE MEASUREMENT THIS TEST EXISTS FOR: `t00001` restarts in every
            % session directory (142 of corpus B's 149 distinct ids span more
            % than one session). Keying on the string alone would anchor this
            % anchor to another session's epoch -- a silent merge of recordings
            % from different animals.
            [docs, idx] = oneFoldableAnchor();
            idx(1).session_id = 'sess_OTHER';       % same string, other session
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_epoch_document, 1);
            testCase.verifyEqual(report.epoch_index_pairs_usable, 1);
        end

        function testTwoSessionsSharingAnEpochStringResolveSeparately(testCase)
            [docsA, idxA] = oneFoldableAnchor();
            docsB = {anchorDoc('anchor_2', 'sess_10', 't00001', 'dev_local_time')};
            idxB  = epochRow('sess_10', 't00001', 'epoch_doc_B');
            [plan, report] = ndi.migrate.internal.epochAnchorFold( ...
                [docsA, docsB], [idxA, idxB]);
            testCase.verifyEqual(numel(plan), 2);
            testCase.verifyEqual(report.anchors_planned, 2);
            byId = containers.Map({plan.source_id}, {plan.epoch_document_id});
            testCase.verifyEqual(byId('anchor_1'), 'epoch_doc_A');
            testCase.verifyEqual(byId('anchor_2'), 'epoch_doc_B');
        end

        function testAHalfKeyIndexRowIsNotUsable(testCase)
            [docs, idx] = oneFoldableAnchor();
            idx(1).epoch_document_id = '';
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.epoch_index_rows, 1);
            testCase.verifyEqual(report.epoch_index_pairs_usable, 0);
            testCase.verifyEqual(report.refused_no_epoch_document, 1);
        end

        % ---------------- the clock de-encoding (CHANGE 4) ---------------

        function testTheFourSignedClocksPassThrough(testCase)
            names = {'utc', 'dev_local_time', 'dev_global_time', ...
                     'exp_global_time'};
            for k = 1:numel(names)
                docs = {anchorDoc('anchor_1', 'sess_09', 't00001', names{k})};
                idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
                [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
                testCase.verifyEqual(numel(plan), 1, names{k});
                clk = plan(1).body.relative_reference.value.clock;
                testCase.verifyEqual(clk.name, names{k});
                % Nodes are STAGED EMPTY in the schema's own binding: no NDIC
                % identifier can be assigned, so none is invented.
                testCase.verifyEqual(clk.node, '');
                testCase.verifyEqual(report.clock_tolerance_applied, 0);
            end
        end

        function testApproxPrefixDeEncodesToAClockPlusAToleranceOnTheRoot(testCase)
            % The five seconds lives in a DOCSTRING in NDI
            % (+ndi/+time/clocktype.m:21,23,26), not in any field. Folding it
            % into a boolean would lose the magnitude; the plan de-encodes it to
            % data, on the ROOT, which is the placement the team corrected.
            pairs = { ...
                'approx_utc',             'utc'; ...
                'approx_dev_global_time', 'dev_global_time'; ...
                'approx_exp_global_time', 'exp_global_time'};
            for k = 1:size(pairs, 1)
                docs = {anchorDoc('anchor_1', 'sess_09', 't00001', pairs{k,1})};
                idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
                [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
                testCase.verifyEqual(numel(plan), 1, pairs{k,1});
                b = plan(1).body;
                testCase.verifyEqual( ...
                    b.relative_reference.value.clock.name, pairs{k,2});
                testCase.verifyEqual(b.time_reference.clock_tolerance.seconds, 5);
                testCase.verifyEqual(plan(1).clock_tolerance_seconds, 5);
                testCase.verifyEqual(report.clock_tolerance_applied, 1);
            end
        end

        function testToleranceCarriesNoInventedSourceProvenance(testCase)
            % The source wrote a clocktype NAME, not a number in a unit.
            % Filling a source slot would claim a provenance that does not
            % exist -- the distance_metadata assumed-shape error.
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'approx_utc')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            tol = plan(1).body.time_reference.clock_tolerance;
            testCase.verifyFalse(isfield(tol, 'source_unit'));
            testCase.verifyFalse(isfield(tol, 'source_value'));
        end

        function testAnEmptyClockFoldsWithoutOneAndIsCounted(testCase)
            % `epoch_clock` is mustBeNonEmpty on the source class so a validated
            % document cannot reach this branch -- which is exactly why it needs
            % a test: an unexercised branch is where a silent zero lives. There
            % is no timeline stated, so none is invented; the anchor still folds
            % (the `relation` is the whole assertion) and the omission is a
            % number rather than a silence.
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', '')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyFalse( ...
                isfield(plan(1).body.relative_reference.value, 'clock'));
            testCase.verifyEqual(report.planned_without_clock, 1);
            testCase.verifyEqual(report.refused_total, 0);
        end

        function testAnExactClockWritesNoToleranceBlockAtAll(testCase)
            [docs, idx] = oneFoldableAnchor();
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyFalse(isfield(plan(1).body, 'time_reference'));
        end

        % ---------------- the refusals ------------------------------------

        function testNoTimeClockIsRefusedNotTranslated(testCase)
            % NO TIMES => NO REFERENCE. 'no_time' is an epoch_clock asserting
            % "this thing keeps no time", never a timeline.
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'no_time')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_clock_no_time, 1);
        end

        function testInheritedClockIsRefusedNotGuessed(testCase)
            % The plan drops `inherited` because `relative_to` already IS that
            % pointer -- and marks the call ABSENCE-BASED. Refuse, do not map.
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'inherited')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_clock_inherited, 1);
        end

        function testAnUnrecognisedClockIsRefusedNotMappedToANeighbour(testCase)
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'wall_clock')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_clock_unknown, 1);
        end

        function testAMissingEpochStringIsRefused(testCase)
            docs = {anchorDoc('anchor_1', 'sess_09', '', 'dev_local_time')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_epoch_string, 1);
        end

        function testAMissingSessionIdIsRefusedBecauseHalfAKeyIsNotAKey(testCase)
            docs = {anchorDoc('anchor_1', '', 't00001', 'dev_local_time')};
            idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs, idx);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.refused_no_session_id, 1);
        end

        function testAnAbsentEpochDocumentIsRefusedNotInvented(testCase)
            % DISCOVERY MODE: a subset batch need not contain the `session`
            % document epochMint needs, so the epoch is simply not there.
            % Absence is not evidence, and a blank `relative_to` would
            % quarantine under the armed RequiredDependencies check.
            [docs, ~] = oneFoldableAnchor();
            [plan, report] = ndi.migrate.internal.epochAnchorFold(docs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.epoch_index_rows, 0);
            testCase.verifyEqual(report.refused_no_epoch_document, 1);
            testCase.verifyFalse(report.changed);
        end

        function testARefusedAnchorIsLeftExactlyAsItWas(testCase)
            % A refusal must be a no-op on the corpus, because the un-folded
            % state is the state the corpus is green in today.
            docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'no_time')};
            [plan, ~] = ndi.migrate.internal.epochAnchorFold(docs);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(docs{1}.document_class.class_name, ...
                'epoch_bounded_reference');
        end

    end
end

% ===================== fixtures ==========================================

function [docs, idx] = oneFoldableAnchor()
docs = {anchorDoc('anchor_1', 'sess_09', 't00001', 'dev_local_time')};
idx  = epochRow('sess_09', 't00001', 'epoch_doc_A');
end

function [docs, idx] = mixedAnchors()
% One of each outcome, so the accounting invariant is exercised across them.
docs = { ...
    anchorDoc('a_ok',        'sess_09', 't00001', 'dev_local_time'), ...
    anchorDoc('a_notime',    'sess_09', 't00001', 'no_time'), ...
    anchorDoc('a_inherited', 'sess_09', 't00001', 'inherited'), ...
    anchorDoc('a_unknown',   'sess_09', 't00001', 'wall_clock'), ...
    anchorDoc('a_nostring',  'sess_09', '',       'dev_local_time'), ...
    anchorDoc('a_nosession', '',        't00001', 'dev_local_time'), ...
    anchorDoc('a_noepoch',   'sess_99', 't00042', 'dev_local_time'), ...
    migratedDoc('not_an_anchor', 'sess_09', 'dose_manipulation')};
idx = epochRow('sess_09', 't00001', 'epoch_doc_A');
end

% ===================== fixture builders ==================================

function b = anchorDoc(id, sessionId, epochId, epochClock)
%ANCHORDOC The body ndi.migrate.internal.stimulusBathToBath mints under V_eta
%   (stimulusBathToBath.m, the mintReference block), as it comes back out of a
%   migrated did2.document's toStruct().
b = struct();
b.document_class = struct( ...
    'class_name', 'epoch_bounded_reference', 'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'time_reference', 'class_version', '1.0.0'), ...
        struct('class_name', 'epochid',        'class_version', '1.0.0')], ...
    'schema_version', 'V_eta');
b.depends_on = struct('name', 'element_id', 'value', 'stim_1');
b.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'migrated_stimulator_epoch_anchor', ...
    'datestamp', '2024-06-01T12:00:00.000Z');
b.time_reference = struct('is_approximate', false);
b.epochid = struct('epochid', epochId);
b.epoch_bounded_reference = struct('epoch_clock', epochClock);
end

function s = migratedDoc(id, sessionId, className)
s = struct();
s.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
s.depends_on = struct('name', {}, 'value', {});
s.base = struct('id', id, 'session_id', sessionId, ...
    'name', className, 'datestamp', '2024-06-01T12:00:00.000Z');
end

function row = epochRow(sessionId, localIdentifier, epochDocumentId)
%EPOCHROW One row of did2.convert.epochMint's published index
%   (`result.epoch_mint.epoch_index`). The field names are epochMint's, not
%   this test's -- epochMint.m:196-197.
row = struct('session_id', sessionId, ...
    'local_identifier', localIdentifier, ...
    'epoch_document_id', epochDocumentId);
end

% ===================== accessors =========================================

function v = depValue(body, name)
v = '';
if ~isfield(body, 'depends_on') || ~isstruct(body.depends_on)
    return;
end
for k = 1:numel(body.depends_on)
    d = body.depends_on(k);
    if ~isfield(d, 'name') || ~strcmp(d.name, name)
        continue;
    end
    if isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    end
    return;
end
end
