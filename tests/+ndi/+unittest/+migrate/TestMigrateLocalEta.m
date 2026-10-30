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
%     2. stimulus_presentation -> manipulation (value kind item) + method documents (did-schema #88).
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
%        BOTH bath fixtures here also carry the animal `subject`, and that is
%        not decoration -- it is a REPAIR the orphan assertion forced. The two
%        new tests assert `result.references.orphan_count == 0`, and on their
%        first execution (run 31504881214, c9eb31266) both reported ACTUAL 2,
%        in BOTH branches, i.e. invariant under the fold. Derived from the
%        migrators rather than guessed: `makeStimulatorElement` names
%        `subject_id = subjId`, and NO document with that id was in the batch,
%        so the two edges that carry it dangled --
%
%          did2.convert.migrators_j.element.m:164-166  lineageRelation writes
%              depends_on {child, PARENT}, parent = the specimen id
%          ndi.migrate.internal.stimulusBathToBath   dose_manipulation
%              subject_id = resolver.subjectOfElement(stimulator) = the same
%              specimen id
%
%        -- which is exactly 2, matches the count, and matches that run's
%        by_class {subject, term_assertion, directed_relation,
%        acquisition_epoch, epoch_bounded_reference, dose_manipulation} (3 v1
%        bodies in, 6 documents out, the `element` migrator contributing the
%        first three).
%
%        CONFIRMED. test-eta-migrate-e2e.yml run 31505752419 (21254481c):
%        "Running ndi.unittest.migrate.TestMigrateLocalEta ... Totals:
%        4 Passed, 0 Failed, 0 Incomplete. 5.5637 seconds testing time."
%        DENOMINATOR: 4 Test methods in this file, 4 collected, 4 run. The
%        derivation above is therefore load-bearing rather than plausible: the
%        only change between the 2-Failed run and this one is the animal
%        `subject` in the two bath fixtures. Read the green narrowly all the
%        same -- it says the graph closes on a 5-document fixture, not on a
%        corpus.
%
%        NOTE, AND IT IS A FINDING RATHER THAN A CHANGE:
%        `testStimulusBathResolvesToDose` still uses the subject-less fixture
%        and is GREEN, in the same run, with those same 2 orphans present. It
%        never asks about orphans. That test is deliberately left alone here --
%        the point is that the corpus gate's headline condition (0 quarantine
%        AND 0 orphans) had no representation at all in this file until now.
%
%   ---------------------------------------------------------------------
%   CLOSED 2026-08-11: EVERY Test METHOD IN THIS FILE NOW ASKS ABOUT ORPHANS.
%   ---------------------------------------------------------------------
%   The note above records a gap and then leaves it open, and a partially
%   represented invariant is the shape this project keeps paying for: two tests
%   asserting `orphan_count == 0` while two others run the same pipeline and
%   never ask reads, from the outside, as "the file checks orphans".
%
%       DENOMINATOR: 4 Test methods in this file.
%         2 already asserted result.references.orphan_count == 0
%             (testEpochAnchorFoldsToRelativeReferenceWithItsIdPreserved,
%              testWithoutASessionDocumentTheRetiredAnchorReachesTheDatabase)
%         2 did not, and both now do:
%             testStimulusBathResolvesToDose            -- FIXTURE REPAIRED
%             testStimulusPresentationBecomesGratingManipulation -- fixture
%                                                          already complete
%
%   testStimulusBathResolvesToDose is repaired THE SAME WAY its siblings were,
%   by adding the animal `subject` the two dangling edges name -- NOT by
%   lowering the assertion. Its fixture is now exactly the fixture
%   testWithoutASessionDocumentTheRetiredAnchorReachesTheDatabase already runs
%   ({subject, stimulator element, element_epoch, stimulus_bath}, no `session`
%   document), and that test asserted 0 orphans and passed in run 31505752419.
%   So the expected count is derived from a green sibling on the same four
%   bodies, not predicted.
%
%   testStimulusPresentationBecomesGratingManipulation already carried
%   `makeSubject(subjId)` and needed no fixture change -- only the question. Its
%   two elements both name that subject, so `element.m`'s lineageRelation
%   `parent` resolves; the presentation's id is PRESERVED onto the
%   visual_grating_manipulation (asserted three lines above the new check), so
%   the stimulus_response edge that names it resolves too. THAT IS A DERIVATION,
%   NOT A MEASUREMENT: nothing in this container can run it.
%
%   STATUS: WRITTEN WITHOUT RUNNING. `command -v matlab octave octave-cli`
%   returns nothing in the container these changes were written in, so CI was
%   their first execution.
%
%   CONFIRMED. test-eta-migrate-e2e.yml run 31509068344 (b7dfa47d4):
%       "Running ndi.unittest.migrate.TestMigrateLocalEta
%        ....
%        Done ndi.unittest.migrate.TestMigrateLocalEta
%        Totals:
%           4 Passed, 0 Failed, 0 Incomplete.
%           7.5842 seconds testing time."
%   DENOMINATOR: 4 Test methods in this file, 4 collected, 4 run, and all four
%   now assert orphan_count == 0. Read it narrowly, as before: it says the graph
%   closes on 4- and 5-document fixtures, not on a corpus.
%
%   RENAMED 2026-08-17: `testStimulusPresentationBecomesGratingManipulation`
%   is now `testStimulusPresentationBecomesATimedSequence`. The historical
%   notes above keep the old name ON PURPOSE -- they describe runs that really
%   happened under it, and rewriting them would falsify the record. The test
%   was INVERTED, not repaired: it asserted `visual_grating_manipulation`, the
%   shape V_eta_stimulus_model_plan.md supersedes, and went red the moment the
%   signed decomposition began working. See the note on the method itself.
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
            % did-schema #88 (VH-Lab/did-schema#88): the bath is a `manipulation`
            % whose value kind is `formulation`, about the specimen by
            % `entity_id`, its value the `formulation` document through
            % `value_id` -- not a dose (Jess Haley, 2026-10-21); the mixture's
            % chemicals are `chemical` documents. `dose_manipulation` and
            % `subject_statement` no longer exist.
            %
            % THE `session` DOCUMENT IS NOW NEEDED FOR THE GRAPH TO CLOSE. Under
            % #88 the session is an EDGE (`session_id`) on every document, not
            % a string in `base`, so a batch without the session document has
            % one dangling `session_id` per document: e2e run 39636971875 on
            % this fixture without it reported 11 orphans over 10 documents,
            % every one a `session_id` (or the session-anchored
            % `referent_id`) naming aabb1122ccdd3344_9900aabbccddeeff. The
            % animal `subject` is still needed for the reason the notes above
            % give.
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            sessId  = 'aabb1122ccdd3344_5500000000000005';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeSessionDoc(sessId)), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            result = runMigrate(testCase, bodies);

            % no needsSessionContext deferral left behind
            assertNoDeferral(testCase, result);

            % THE CORPUS GATE'S HEADLINE CONDITION
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                ['the graph does not close. ' resultDiag(result)]);

            % the bath became a dose manipulation (NOT the retired `bath`, and
            % not the pre-#88 `dose_manipulation`)
            verifyFalse(testCase, isfield(result.summary.by_class, 'bath'), ...
                'retired `bath` class leaked onto the V_eta path');
            verifyFalse(testCase, ...
                isfield(result.summary.by_class, 'dose_manipulation'), ...
                ['the pre-#88 class was written. ' resultDiag(result)]);
            for c = {'manipulation', 'formulation', 'chemical'}
                verifyTrue(testCase, isfield(result.summary.by_class, c{1}), ...
                    ['no `' c{1} '` produced from stimulus_bath. ' resultDiag(result)]);
            end

            dose = findByClass(result.destination, 'manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            verifyTrue(testCase, any(strcmp( ...
                {dose.document_class.superclasses.class_name}, 'formulation')), ...
                'the manipulation does not carry the `formulation` value kind');
            verifyFalse(testCase, isfield(dose, 'dose'), 'a bath is not a dose');
            % The fixture's bath location is CNS (uberon:0001017), an anatomical
            % region, not the generic bath: "Any statement about an anatomical
            % region of a subject ... targets that region's part entity (one per
            % subject and region, shared, type tissue, part_of the subject)"
            % (Jess Haley, 2026-10-21). So the bath is about the CNS part of
            % the animal, not the animal.
            part = findById(result.destination, depValue(dose, 'entity_id'));
            verifyNotEmpty(testCase, part, ['the bath names no part. ' resultDiag(result)]);
            if ~isempty(part)
                verifyEqual(testCase, part.document_class.class_name, 'entity');
                verifyTrue(testCase, ndi.v2.vocabIs('entity_type', part.entity.type, 'tissue'));
            end
            partOf = {};
            for r = findAllByClass(result.destination, 'directed_relation')
                rel = r{1};
                if ndi.v2.vocabIs('relation', rel.directed_relation.relation, 'part_of') ...
                        && strcmp(depValue(rel, 'child_id'), depValue(dose, 'entity_id'))
                    partOf{end+1} = depValue(rel, 'parent_id'); %#ok<AGROW>
                end
            end
            verifyEqual(testCase, partOf, {subjId}, 'the CNS part is part_of the animal');
            verifyEmpty(testCase, findTermObservation(result.destination, ...
                'anatomical location'), 'the promoted site observation is gone');
            verifyNotEmpty(testCase, depValue(dose, 'time_reference_id'));
            verifyEqual(testCase, depValue(dose, 'instrument_id'), stimId);
            formulation = findById(result.destination, depValue(dose, 'value_id'));
            verifyNotEmpty(testCase, formulation, ...
                ['the dose names no formulation in the database. ' resultDiag(result)]);
            verifyEqual(testCase, formulation.document_class.class_name, 'formulation');
            % [bath is two statements] / [bath solution minted] (Jess Haley,
            % 2026-10-26 / 2026-10-27, did-schema
            % V_eta_go_forward_class_audit.md): the variable is the general
            % bath-solution term, EMPTY:0000409, not the first mixture row
            verifyEqual(testCase, dose.statement.variable.node, 'EMPTY:0000409');
            verifyEqual(testCase, dose.statement.variable.name, 'bath solution');
            % muscimol now lives where the value is: the formulation's one
            % ingredient, a `chemical` document whose substance is muscimol
            if isempty(formulation); return; end
            ingredientId = depValue(formulation, 'ingredient_id');
            verifyNotEmpty(testCase, ingredientId, ...
                ['the formulation names no ingredient. ' resultDiag(result)]);
            chem = findById(result.destination, ingredientId);
            verifyNotEmpty(testCase, chem, ...
                ['the ingredient is not in the destination. ' resultDiag(result)]);
            if isempty(chem); return; end
            verifyEqual(testCase, chem.document_class.class_name, 'chemical');
            verifyEqual(testCase, chem.chemical.value.substance.name, 'muscimol');
            verifyEqual(testCase, chem.chemical.value.substance.node, 'chebi:6904');
        end

        function testEpochAnchorFoldsToRelativeReferenceWithItsIdPreserved(testCase)
            % (a) WITH a `session` document. The whole chain, driven from the
            % real emitter. did-schema #88: the bath assembler mints a VALID
            % `relative_time_reference` "during the session" (#88 has no
            % `epoch_bounded_reference` to hold an unresolved epoch), hands the
            % epoch string and clock to the fold, epochMint mints the `epoch`
            % entity for the (session, epoch-id string) PAIR, and
            % epochAnchorFold re-points the reference at that epoch IN PLACE.
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            sessId  = 'aabb1122ccdd3344_5500000000000005';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeSessionDoc(sessId)), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeStimulatorElement(stimId, subjId)), ...
                jsonencode(makeElementEpoch(stimId, epochId, 'dev_local_time')), ...
                jsonencode(makeStimulusBath(stimId, epochId))};
            result = runMigrate(testCase, bodies);
            assertNoDeferral(testCase, result);

            % --- DENOMINATORS FIRST, off the pass's own instrument ---------
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
            verifyEqual(testCase, fold.bath_anchors_seen, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_planned, 1, resultDiag(result));
            verifyEqual(testCase, fold.refused_total, 0, resultDiag(result));
            verifyEqual(testCase, fold.anchors_refolded, 1, resultDiag(result));
            verifyEqual(testCase, fold.refold_quarantined, 0, resultDiag(result));
            verifyTrue(testCase, fold.folded, resultDiag(result));
            verifyEqual(testCase, fold.anchors_seen, ...
                fold.anchors_planned + fold.refused_total);

            % --- no retired or pre-#88 time class reaches the database -----
            for c = {'epoch_bounded_reference', 'relative_reference'}
                verifyFalse(testCase, isfield(result.summary.by_class, c{1}), ...
                    ['`' c{1} '` was written to the destination. ' resultDiag(result)]);
            end
            verifyTrue(testCase, ...
                isfield(result.summary.by_class, 'relative_time_reference'), ...
                resultDiag(result));

            % --- THE ID IS PRESERVED (this is the orphan gate) -------------
            dose = findByClass(result.destination, 'manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            anchorId = depValue(dose, 'time_reference_id');
            verifyNotEmpty(testCase, anchorId, resultDiag(result));
            % SELECTED BY ID, NOT BY CLASS: epochMint also mints the epoch's
            % EXTENT references, so there is more than one
            % relative_time_reference here (see findById).
            ref = findById(result.destination, anchorId);
            verifyNotEmpty(testCase, ref, ['the anchor id the dose names is ' ...
                'not in the destination at all. ' resultDiag(result)]);
            verifyEqual(testCase, ref.document_class.class_name, ...
                'relative_time_reference', resultDiag(result));

            % and the whole graph still closes
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                ['the graph does not close. ' resultDiag(result)]);

            % --- `referent_id` names the epoch epochMint actually minted ---
            epochDoc = findEntity(result.destination, 'epoch');
            verifyNotEmpty(testCase, epochDoc, ['no `epoch` entity. ' resultDiag(result)]);
            if isempty(epochDoc); return; end
            verifyEqual(testCase, depValue(ref, 'referent_id'), epochDoc.base.id);
            verifyFalse(testCase, isfield(ref, 'epochid'));

            % --- the signed value shape ------------------------------------
            verifyEqual(testCase, ref.relative_time_reference.value.relation.node, ...
                'time:intervalDuring');
            % the clock is read from the element_epoch document above and
            % handed over by the bath assembler, so this pins that hand-off
            verifyEqual(testCase, ref.relative_time_reference.value.clock.name, ...
                'dev_local_time');
            % the source states no offsets, so none are invented
            verifyFalse(testCase, ...
                isfield(ref.relative_time_reference.value, 'start'));
            verifyFalse(testCase, ...
                isfield(ref.relative_time_reference.value, 'duration'));

            % --- THE UNTIED EXTENT KEEPS THE SESSION ANCHOR ---------------
            % [untied epochs keep the session anchor] (Jess Haley, 2026-10-26,
            % did-schema V_eta_go_forward_class_audit.md), amending [device
            % clocks on one epoch]: an element epoch that cannot be tied to an
            % acquisition system "is not carried when all of its extents come
            % from one untied source and agree: it keeps a session-anchored
            % time reference, using only the times the epoch states". This
            % fixture's element_epoch belongs to a stimulator with no
            % acquisition system and is the epoch's one source, so the
            % destination holds TWO relative_time_references: the folded
            % anchor, and the extent anchored on the session. (Inverts the
            % [device clocks on one epoch] version, which asserted the folded
            % anchor only and the source carried.)
            allRefs = findAllByClass(result.destination, 'relative_time_reference');
            verifyEqual(testCase, numel(allRefs), 2, ...
                ['expected the folded anchor and one session-anchored extent. ' ...
                 resultDiag(result)]);
            verifyEqual(testCase, mint.epoch_extent_refused_no_system, 1, resultDiag(result));
            verifyEqual(testCase, mint.epoch_extent_untied_session_anchored, 1, resultDiag(result));
            verifyEqual(testCase, mint.epoch_extent_carried_sources, 0, resultDiag(result));
            extent = {};
            for r = allRefs
                if ~strcmp(r{1}.base.id, anchorId); extent{end+1} = r{1}; end %#ok<AGROW>
            end
            verifyNumElements(testCase, extent, 1, resultDiag(result));
            if numel(extent) == 1
                verifyEqual(testCase, depValue(extent{1}, 'referent_id'), ...
                    depValue(epochDoc, 'session_id'), ...
                    'the untied extent is anchored on the session the epoch belongs to');
                clk = extent{1}.relative_time_reference.value.clock;
                if isstruct(clk); clk = clk.name; end
                verifyEqual(testCase, char(clk), 'dev_local_time', ...
                    'the extent keeps the clock the element_epoch states');
            end
        end

        function testWithoutASessionDocumentTheAnchorStaysOnTheSession(testCase)
            % (b) WITHOUT a `session` document. RENAMED from
            % testWithoutASessionDocumentTheRetiredAnchorReachesTheDatabase:
            % under did-schema #88 there is no retired class to reach the
            % database. The bath assembler mints a VALID
            % `relative_time_reference` "during the session" from the start, so
            % when epochMint refuses (no session document) and the fold
            % refuses (no epoch), the anchor stays exactly as minted.
            %
            % What the test still forbids is the refusal being SILENT.
            %
            % ORPHANS ARE EXPECTED HERE AND ARE ALL OF ONE KIND. Under #88 the
            % session is a `session_id` EDGE on every document, so a batch with
            % no session document leaves each of those edges, and the
            % session-anchored `referent_id`, naming a document not in the
            % batch -- the discovery-mode case (a subset batch need not carry
            % the session document). The assertion is that EVERY orphan names
            % the session id and nothing else dangles.
            stimId  = 'aabb1122ccdd3344_5500000000000002';
            subjId  = 'aabb1122ccdd3344_5500000000000001';
            epochId = 'epoch_t00001';
            bodies = { ...
                jsonencode(makeSubject(subjId)), ...
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
            % the anchor was SEEN -- the pass read it and declined
            verifyEqual(testCase, fold.anchors_seen, 1, resultDiag(result));
            verifyEqual(testCase, fold.bath_anchors_seen, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_planned, 0, resultDiag(result));
            verifyEqual(testCase, fold.refused_no_epoch_document, 1, ...
                resultDiag(result));
            verifyEqual(testCase, fold.refused_total, 1, resultDiag(result));
            verifyEqual(testCase, fold.anchors_refolded, 0, resultDiag(result));
            verifyFalse(testCase, fold.folded, resultDiag(result));

            verifyFalse(testCase, ...
                isfield(result.summary.by_class, 'epoch_bounded_reference'), ...
                resultDiag(result));
            verifyEmpty(testCase, findEntity(result.destination, 'epoch'), ...
                resultDiag(result));

            % A refusal is a no-op: the dose still names the anchor it was
            % minted with, and that anchor still says "during the session".
            dose = findByClass(result.destination, 'manipulation');
            verifyNotEmpty(testCase, dose, resultDiag(result));
            if isempty(dose); return; end
            anchor = findById(result.destination, depValue(dose, 'time_reference_id'));
            verifyNotEmpty(testCase, anchor, resultDiag(result));
            if isempty(anchor); return; end
            verifyEqual(testCase, anchor.document_class.class_name, ...
                'relative_time_reference');
            verifyEqual(testCase, depValue(anchor, 'referent_id'), session());

            o = result.references.orphans;
            verifyGreaterThan(testCase, numel(o), 0, resultDiag(result));
            for k = 1:numel(o)
                verifyEqual(testCase, charField(o(k), 'edge_document_id'), session(), ...
                    ['an orphan other than the absent session document. ' ...
                     resultDiag(result)]);
                verifyTrue(testCase, ismember(charField(o(k), 'edge_name'), ...
                    {'session_id', 'referent_id'}), resultDiag(result));
            end
        end

        function testAGratingPresentationFoldsWithItsUnreadKeysAsMethodParameters(testCase)
            % INVERTED 2026-10-29 from testAGratingPresentationIsCarriedAsV1.
            % Decided by Jess Haley, 2026-10-27 [unread stimulus parameters
            % are method parameters] ("Q6 yes", did-schema
            % V_eta_go_forward_class_audit.md): a periodicstim key gratingRecipe
            % does not read is a parameter entry on the grating's `method`, so
            % the generic stage no longer refuses a grating presentation for
            % it. With its epoch minted (the element_epoch below, as in
            % testAPresentationManipulationIsAnchoredToItsEpoch) it folds.
            subjId  = 'aabb1122ccdd3344_5500000000000030';
            recElem = 'aabb1122ccdd3344_5500000000000031';
            stimEl  = 'aabb1122ccdd3344_5500000000000032';
            presId  = 'aabb1122ccdd3344_5500000000000033';
            respId  = 'aabb1122ccdd3344_5500000000000034';
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeElementEpoch(stimEl, 't00001', 'dev_local_time')), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(makeGratingPresentation(presId, stimEl))};
            result = runMigrate(testCase, bodies);
            r = result.secondPass.stimulusSequence;
            verifyEqual(testCase, r.presentations_read, 1, resultDiag(result));
            verifyEqual(testCase, r.presentations_refused_unplaced, 0, resultDiag(result));
            verifyEqual(testCase, r.presentations_decomposed, 1, resultDiag(result));
            d = findById(result.destination, presId);
            verifyNotEmpty(testCase, d, resultDiag(result));
            if isempty(d); return; end
            verifyEqual(testCase, d.document_class.class_name, 'manipulation');
            % the two gratings' methods carry the keys gratingRecipe does not read
            methods = findAllByClass(result.destination, 'method');
            withUnread = 0;
            for k = 1:numel(methods)
                if ~isfield(methods{k}.method, 'parameters'); continue; end
                p = methods{k}.method.parameters;
                if isstruct(p); p = num2cell(p); end
                names = cellfun(@variableName, p, 'UniformOutput', false);
                if any(strcmp(names, 'orientation')) && any(strcmp(names, 'animation type')) ...
                        && any(strcmp(names, 'high colour'))
                    withUnread = withUnread + 1;
                end
            end
            verifyEqual(testCase, withUnread, 2, ['each grating''s method carries ' ...
                'its unread periodicstim keys. ' resultDiag(result)]);
            verifyEqual(testCase, result.references.orphan_count, 0, resultDiag(result));
        end

        function testARawV1OntologyLabelIsCarriedOnceUnderItsV1Name(testCase)
            % DID-matlab claude/phase2-label lists `ontologyLabel` in
            % did2.convert.rawV1Classes: pass 1 hands a label over as v1 wrote
            % it (class `ontologyLabel`), and the second pass finds it under
            % either name (ndi.migrate.internal.isOntologyLabelClass, #1076).
            % Built by the writer, +setup/+conv/+haley/doImport.m: a
            % behaviour imageStack (document_id AND subject_id, so pass 1
            % carries it, carry-052) and two labels, one on the stack (carried
            % with it, carry-064) and one on the subject (handed to the second
            % pass, which cannot make an observation of an entity, so it is
            % stored as its v1 source at the end). Each label is stored ONCE,
            % as v1, under its v1 class name; the final stamp counts each once
            % (a label pass 1 recorded twice was counted once changed and once
            % carried).
            subjId  = 'aabb1122ccdd3344_5500000000000040';
            rowId   = 'aabb1122ccdd3344_5500000000000041';
            stack = ndi.document('imageStack', 'imageStack', struct( ...
                'label', ['A video recording capturing the behavior of C. ' ...
                'elegans during an experimental assay.'], ...
                'formatOntology', 'NCIT:C190180'), ...
                'imageStack_parameters', struct('dimension_order', 'YXT', ...
                'dimension_labels', 'height,width,time', ...
                'dimension_size', [1024 1024 10797], ...
                'dimension_scale', [32.93 32.93 0.3334], ...
                'dimension_scale_units', 'micrometer,micrometer,second', ...
                'data_type', 'uint8', 'data_limits', [0 255], ...
                'timestamp', 738637.4600694445, 'clocktype', 'exp_global_time'));
            stack = stack.setproperties('base.session_id', session());
            stack = stack.set_dependency_value('document_id', rowId);
            stack = stack.set_dependency_value('subject_id', subjId);
            onStack = rawLabel(stack.id(), 'EMPTY:0000129');
            onSubject = rawLabel(subjId, 'EMPTY:0000131');
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(stack.document_properties), ...
                jsonencode(onStack.document_properties), ...
                jsonencode(onSubject.document_properties)};
            result = runMigrate(testCase, bodies);
            verifyEmpty(testCase, result.quarantine, resultDiag(result));
            for lab = {onStack, onSubject}
                d = findById(result.destination, lab{1}.id());
                verifyNotEmpty(testCase, d, resultDiag(result));
                if isempty(d); continue; end
                verifyEqual(testCase, d.document_class.class_name, 'ontologyLabel');
                verifyEqual(testCase, char(d.document_class.schema_version), 'did_v1');
                verifyEqual(testCase, d.ontologyLabel, ...
                    lab{1}.document_properties.ontologyLabel, 'the v1 block');
                verifyEqual(testCase, depValue(d, 'document_id'), ...
                    lab{1}.dependency_value('document_id'), 'the label''s only join');
            end
            verifyEqual(testCase, numel(findAllByClass(result.destination, 'ontologyLabel')), 2);
            verifyEmpty(testCase, findAllByClass(result.destination, 'ontology_label'));
            olab = result.secondPass.ontologyLabelSubjects;
            verifyGreaterThanOrEqual(testCase, olab.labels_passthrough, 1, ...
                'the second pass did not find the raw label');
            verifyEqual(testCase, olab.resolved, 0);
            % counted under either spelling: the class is the one pass 1
            % recorded, which was `ontology_label` before the switch (a run
            % against DID-matlab claude/phase2 at aa34109f printed "changed
            % later, by class: ontology_label 1" for this fixture: the
            % duplicate record)
            c = result.carriedAsV1;
            labels = {'ontologyLabel', 'ontology_label'};
            verifyEqual(testCase, classCount(c.carried_by_class, labels), 2, ...
                'each label is carried, once');
            verifyEqual(testCase, classCount(c.changed_by_class, labels), 0, ...
                'a label was also counted as changed: two pass-1 records for one document');
            verifyEqual(testCase, classCount(c.absent_by_class, labels), 0);
        end

        function testStimulusPresentationBecomesAnItemManipulation(testCase)
            % did-schema #88 (V_eta_method_plan.md, TEAM-SIGN-OFF [method]
            % 2026-10-21): a presentation that carries a sequence of gratings
            % becomes ONE `manipulation` (listing the `item`
            % value kind) whose `item_id` names one standalone `method`
            % document per distinct stimulus. `visual_grating`,
            % `timed_sequence_manipulation` and `visual_grating_manipulation`
            % are gone from the schema; this test was
            % testStimulusPresentationBecomesATimedSequence until then.
            %
            % THIS FIXTURE: two gratings (45 and 90), presentation_order [1 2],
            % two trial times inline -- so the onsets become a `time` key and
            % the ends `item.value.offset`, with no body.
            subjId  = 'aabb1122ccdd3344_5500000000000010';
            recElem = 'aabb1122ccdd3344_5500000000000011';
            stimEl  = 'aabb1122ccdd3344_5500000000000012';
            presId  = 'aabb1122ccdd3344_5500000000000013';
            respId  = 'aabb1122ccdd3344_5500000000000014';
            % The session document: on did-schema #88 every document's
            % `session_id` EDGE names the session entity, whose base.id IS
            % the session id (V_eta_relation_inheritance_plan.md), so without
            % one every edge in the graph dangles. It is also the referent of
            % the manipulation's "during the session" time reference.
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(makeStimulusPresentation(presId, stimEl))};
            result = runMigrate(testCase, bodies);

            manip = findById(result.destination, presId);
            verifyNotEmpty(testCase, manip, ...
                ['no document carries the presentation id. Read the run log ' ...
                 'for "Second-pass stimulus_presentation decomposition ' ...
                 'failed" FIRST: ndi.migrate.local wraps the pass in a ' ...
                 'try/catch, so a THROW and a REFUSAL both arrive here as an ' ...
                 'absence. ' resultDiag(result)]);
            verifyEqual(testCase, manip.document_class.class_name, 'manipulation', ...
                resultDiag(result));
            verifyTrue(testCase, any(strcmp( ...
                {manip.document_class.superclasses.class_name}, 'item')), ...
                'the manipulation does not list the `item` value kind');
            verifyEqual(testCase, depValue(manip, 'entity_id'), subjId);
            verifyEqual(testCase, depValue(manip, 'instrument_id'), stimEl);
            verifyEqual(testCase, manip.item.value.item(:)', [0 1]);
            % data_body plan AMENDMENT 6: one presentation dimension, the
            % onsets and ends its `onset time` / `offset time` covariates
            verifyFalse(testCase, isfield(manip.item.value, 'offset'));
            dims = ndi.v2.entries(manip.data.dimensions);
            verifyNumElements(testCase, dims, 1);
            verifyEqual(testCase, double(dims{1}.n), 2);
            covs = ndi.v2.entries(manip.data.covariates);
            names = cellfun(@(c) char(c.variable.name), covs, 'UniformOutput', false);
            on = covs{strcmp(names, 'onset time')};
            off = covs{strcmp(names, 'offset time')};
            verifyEqual(testCase, on.quantity.value(:)', [0 5]);
            verifyEqual(testCase, off.quantity.value(:)', [4 9]);
            tr = depValue(manip, 'time_reference_id');
            verifyNotEmpty(testCase, tr, ...
                ['the manipulation carries no time reference: the pass mints ' ...
                 '"during the session" against the session document. ' resultDiag(result)]);
            % [presentation anchored to its epoch] (Jess Haley, 2026-10-27):
            % this presentation names no epoch, so its anchor stays on the
            % session, and the pass says why
            ea = result.secondPass.stimulusSequence.epoch_anchor;
            verifyEqual(testCase, ea.manipulations_inspected, 1, resultDiag(result));
            verifyEqual(testCase, ea.no_epoch_string, 1, resultDiag(result));
            verifyEqual(testCase, ea.anchors_handed_over, 0, resultDiag(result));

            % TWO DISTINCT STIMULI, so dedup must not collapse them (two seeds).
            % UPDATED 2026-10-25: noise stimuli (see makeStimulusPresentation).
            methods = findAllByClass(result.destination, 'method');
            verifyEqual(testCase, numel(methods), 2, sprintf( ...
                ['%d method document(s) for a 2-stimulus sequence (two noise ' ...
                 'seeds). %s'], numel(methods), resultDiag(result)));
            for k = 1:numel(methods)
                verifyEqual(testCase, methods{k}.method.term.name, 'dense noise');
            end

            % none of the classes #88 deleted
            for gone = {'visual_grating', 'visual_grating_manipulation', ...
                    'timed_sequence', 'timed_sequence_manipulation'}
                verifyFalse(testCase, isfield(result.summary.by_class, gone{1}), ...
                    sprintf('%s was emitted; did-schema #88 deletes it. %s', ...
                    gone{1}, resultDiag(result)));
            end

            % the presentation itself is consumed (assembled away)
            verifyFalse(testCase, isfield(result.summary.by_class, 'stimulus_presentation'), ...
                'stimulus_presentation was not consumed by the second pass');

            % THE CORPUS GATE'S HEADLINE CONDITION. This test was the file's
            % other silent one: it runs the presentation assembler end to end
            % and never asked whether the graph it rebuilt still closes. That
            % matters most HERE, because this is the one path that CONSUMES a
            % document other documents point at -- the stimulus_presentation is
            % gone from by_class two lines above, and the only thing standing
            % between that and a dangling `stimulus_presentation_id` is the id
            % preservation asserted on manip.base.id. This turns that from an
            % argument into a check.
            verifyEqual(testCase, result.references.orphan_count, 0, ...
                ['the graph does not close. ' resultDiag(result)]);
        end

        function testAPresentationManipulationIsAnchoredToItsEpoch(testCase)
            % Decided by Jess Haley, 2026-10-27 [presentation anchored to its
            % epoch] (did-schema V_eta_go_forward_class_audit.md, option a): the
            % manipulation's time reference names the epoch entity of the
            % epoch the presentation was in. The pass anchors it "during the
            % session" first (the epoch is minted later, by epochMint), then
            % the epoch anchor fold re-points it, id preserved.
            subjId  = 'aabb1122ccdd3344_5500000000000010';
            recElem = 'aabb1122ccdd3344_5500000000000011';
            stimEl  = 'aabb1122ccdd3344_5500000000000012';
            presId  = 'aabb1122ccdd3344_5500000000000013';
            respId  = 'aabb1122ccdd3344_5500000000000014';
            pres = makeStimulusPresentation(presId, stimEl);
            pres.document_class.superclasses = [pres.document_class.superclasses, ...
                struct('class_name', 'epochid', 'class_version', '1.0.0')];
            pres.epochid = struct('epochid', 't00001');
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeElementEpoch(stimEl, 't00001', 'dev_local_time')), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(pres)};
            result = runMigrate(testCase, bodies);

            % --- denominators first ----------------------------------------
            ea = result.secondPass.stimulusSequence.epoch_anchor;
            verifyNotEmpty(testCase, ea, ['the stimulus pass reported no epoch ' ...
                'anchors (did it throw?). ' resultDiag(result)]);
            verifyEqual(testCase, ea.manipulations_inspected, 1, resultDiag(result));
            verifyEqual(testCase, ea.anchors_handed_over, 1, resultDiag(result));
            verifyEqual(testCase, ea.anchors_refolded, 1, resultDiag(result));
            verifyEqual(testCase, ea.anchors_left_on_session, 0, resultDiag(result));

            manip = findById(result.destination, presId);
            verifyNotEmpty(testCase, manip, resultDiag(result));
            if isempty(manip); return; end
            verifyEqual(testCase, manip.document_class.class_name, 'manipulation');
            tr = depValue(manip, 'time_reference_id');
            verifyNotEmpty(testCase, tr, resultDiag(result));
            ref = findById(result.destination, tr);
            verifyNotEmpty(testCase, ref, ['the anchor the manipulation names ' ...
                'is not in the destination. ' resultDiag(result)]);
            if isempty(ref); return; end
            verifyEqual(testCase, ref.document_class.class_name, 'relative_time_reference');

            % --- the referent is the epoch entity epochMint minted ---------
            epochDoc = findEntity(result.destination, 'epoch');
            verifyNotEmpty(testCase, epochDoc, ['no `epoch` entity. ' resultDiag(result)]);
            if isempty(epochDoc); return; end
            verifyEqual(testCase, depValue(ref, 'referent_id'), epochDoc.base.id, ...
                ['the presentation''s manipulation is not anchored to its ' ...
                 'epoch. ' resultDiag(result)]);
            % the stimulator's clock for that epoch (the element_epoch above)
            verifyEqual(testCase, ref.relative_time_reference.value.clock.name, ...
                'dev_local_time');

            verifyEqual(testCase, result.references.orphan_count, 0, ...
                ['the graph does not close. ' resultDiag(result)]);
        end

        function testAPresentationWhoseEpochIsNotMintedIsCarriedAsV1(testCase)
            % Decided by Jess Haley, 2026-10-27 [epoch-less presentations
            % carry]: no document but the presentation names epoch t00002, so
            % epochMint mints no epoch for it and the manipulation could not be
            % anchored to its epoch. The presentation is carried whole as v1
            % with register row carry-109, not written anchored to the session.
            subjId  = 'aabb1122ccdd3344_5500000000000010';
            recElem = 'aabb1122ccdd3344_5500000000000011';
            stimEl  = 'aabb1122ccdd3344_5500000000000012';
            presId  = 'aabb1122ccdd3344_5500000000000013';
            respId  = 'aabb1122ccdd3344_5500000000000014';
            pres = makeStimulusPresentation(presId, stimEl);
            pres.document_class.superclasses = [pres.document_class.superclasses, ...
                struct('class_name', 'epochid', 'class_version', '1.0.0')];
            pres.epochid = struct('epochid', 't00002');
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeElementEpoch(stimEl, 't00001', 'dev_local_time')), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(pres)};
            result = runMigrate(testCase, bodies);

            r = result.secondPass.stimulusSequence;
            verifyNotEmpty(testCase, r, resultDiag(result));
            verifyEqual(testCase, r.presentations_read, 1, resultDiag(result));
            verifyEqual(testCase, r.epoch_carried.total, 1, resultDiag(result));
            verifyEqual(testCase, r.epoch_carried.no_epoch_minted, 1, resultDiag(result));
            verifyEqual(testCase, r.presentations_decomposed, 0, resultDiag(result));
            verifyEqual(testCase, r.presentations_refused, 1, resultDiag(result));
            rows = r.carry_rows;
            hit = strcmp({rows.id}, presId);
            verifyEqual(testCase, sum(hit), 1, 'the carried presentation has no register row');
            if any(hit)
                verifyEqual(testCase, rows(find(hit, 1)).row, 'carry-109');
            end
            verifyEqual(testCase, r.epoch_anchor, [], ...
                'no manipulation was written, so no epoch anchor was handed over');

            % the presentation is in the destination whole, as v1
            doc = findById(result.destination, presId);
            verifyNotEmpty(testCase, doc, resultDiag(result));
            if isempty(doc); return; end
            verifyEqual(testCase, doc.document_class.class_name, 'stimulus_presentation');
            verifyEqual(testCase, doc.document_class.schema_version, 'did_v1');
            verifyEmpty(testCase, findAllByClass(result.destination, 'manipulation'), ...
                'a manipulation was written for the carried presentation');
            verifyEqual(testCase, result.secondPassErrors.total, 0, resultDiag(result));
        end

        function testPresentationTimesAreReadFromTheFileInTheStore(testCase)
            % Decided by Jess Haley, 2026-10-22 [presentation times from the
            % file] (did-schema V_eta_stimulus_response_model_plan.md): the
            % second pass reads each presentation's onsets and offsets from
            % the v1 presentation_time.bin, and the file stays attached to
            % the presentation's V2 document as its raw source.
            %
            % THIS FIXTURE is the current writer's shape: no inline
            % `presentation_time`, a `files` block naming the file, and the
            % bytes where the legacy backend put them on add,
            % <.ndi>/files/<uid>, written by the v1 writer's own function
            % (ndi.database.fun.write_presentation_time_structure, as
            % +ndi/+app/+stimulus/decoder.m calls it). The corpora carry no
            % binaries, so this is the only end-to-end proof that the pass
            % reaches the bytes.
            subjId  = 'aabb1122ccdd3344_5500000000000020';
            recElem = 'aabb1122ccdd3344_5500000000000021';
            stimEl  = 'aabb1122ccdd3344_5500000000000022';
            presId  = 'aabb1122ccdd3344_5500000000000023';
            respId  = 'aabb1122ccdd3344_5500000000000024';
            uid = 'aabb1122ccdd3344_77000000000000a1';
            pres = makeStimulusPresentation(presId, stimEl);
            pres.stimulus_presentation = rmfield(pres.stimulus_presentation, ...
                'presentation_time');
            pres.files = struct('file_list', {{'presentation_time.bin'}}, ...
                'file_info', struct('name', 'presentation_time.bin', ...
                'locations', struct('delete_original', 1, 'uid', uid, ...
                'location', '/a/path/on/the/author/computer/tmp123', ...
                'parameters', '', 'location_type', 'file', 'ingest', 1)));
            storeDir = fullfile(testCase.SessionRoot, '.ndi', 'files');
            mkdir(storeDir);
            pt = struct('clocktype', {'dev_local_time', 'dev_local_time'}, ...
                'stimopen', {0.5, 6.5}, 'onset', {1, 7}, 'offset', {3, 9}, ...
                'stimclose', {3.5, 9.5}, 'stimevents', {[1 1; 3 2], [7 1; 9 2]});
            ndi.database.fun.write_presentation_time_structure( ...
                fullfile(storeDir, uid), pt);
            bodies = { ...
                jsonencode(makeSessionDoc(session())), ...
                jsonencode(makeSubject(subjId)), ...
                jsonencode(makeRecordingElement(recElem, subjId)), ...
                jsonencode(makeStimulatorElement(stimEl, subjId)), ...
                jsonencode(makeStimulusResponse(respId, presId, recElem)), ...
                jsonencode(pres)};
            result = runMigrate(testCase, bodies);

            t = result.secondPass.stimulusSequence.timing;
            verifyEqual(testCase, t.presentations_folded, 1, resultDiag(result));
            verifyEqual(testCase, t.from_file, 1, ...
                'the times did not come from presentation_time.bin');
            verifyEqual(testCase, t.file_located, 1);
            manip = findById(result.destination, presId);
            verifyNotEmpty(testCase, manip, resultDiag(result));
            covs = ndi.v2.entries(manip.data.covariates);
            names = cellfun(@(c) char(c.variable.name), covs, 'UniformOutput', false);
            on = covs{strcmp(names, 'onset time')};
            off = covs{strcmp(names, 'offset time')};
            verifyEqual(testCase, on.quantity.value(:)', [1 7]);
            verifyEqual(testCase, char(on.variable.node), 'EMPTY:0000368');
            verifyEqual(testCase, off.quantity.value(:)', [3 9]);
            verifyEqual(testCase, char(off.variable.node), 'EMPTY:0000369');
            dims = ndi.v2.entries(manip.data.dimensions);
            verifyEqual(testCase, char(dims{1}.term.node), 'OBI:0000807');
            % the raw source stays attached, pointing at the bytes in the store
            verifyTrue(testCase, isfield(manip, 'files') && ...
                any(strcmp(cellstr(manip.files.file_list), 'presentation_time.bin')), ...
                'presentation_time.bin is no longer attached to the presentation');
            % the dimension-term census ([covariate details] 5.4): measured,
            % and this presentation's dimension has its node
            dt = result.secondPass.dimensionTerms;
            verifyTrue(testCase, isstruct(dt), 'the dimension-term census did not run');
            verifyGreaterThanOrEqual(testCase, dt.dimensions_written, 1);
            verifyEqual(testCase, result.references.orphan_count, 0, resultDiag(result));
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
% The stimulator probe as NDI writes it: `ndi_element_class` is the class
% probetype2object.json maps type `stimulator` to,
% ndi.probe.timeseries.stimulator. [element types have no default] (Jess
% Haley, 2026-10-26, did-schema V_eta_go_forward_class_audit.md): "A
% registered probe type ... is a `device` ONLY when the element's
% `ndi_element_class` is `ndi.probe.*` ... Any other type, or a probe type on
% a non-probe class, is carried as v1". With the old 'ndi.element' the
% stimulator was carried (carry-063) and, by [dependents of a carried document
% carry], its element_epoch too, so no untied extent reached epochMint.
% base.name is '' because ndi.element/newdocument sets element.* only and
% never writes one; [element name kept apart, base.name carried] (Jess Haley,
% 2026-10-30, did-schema V_eta_go_forward_class_audit.md; DID-matlab #299,
% carry-149) carries an element whose base.name is non-empty, and with it,
% by [dependents of a carried document carry], its epoch and presentations.
body = struct();
body.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
body.base = struct('id', stimId, 'session_id', session(), ...
    'name', '', 'datestamp', datestamp());
body.element = struct('ndi_element_class', 'ndi.probe.timeseries.stimulator', 'name', 'stim', ...
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
% base.name '' as ndi.element/newdocument writes it (see makeStimulatorElement;
% a non-empty one is carry-149).
body = struct();
body.document_class = struct('class_name', 'element', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'subject_id'}, 'value', {subjId});
body.base = struct('id', elemId, 'session_id', session(), ...
    'name', '', 'datestamp', datestamp());
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
% TWO NOISE STIMULI (stochasticgridstim, every parameter an entry). Written
% when [generic stage is lossless] (Jess Haley, 2026-10-25) left a grating
% presentation as v1; since [unread stimulus parameters are method parameters]
% (2026-10-27) a grating folds too (makeGratingPresentation /
% testAGratingPresentationFoldsWithItsUnreadKeysAsMethodParameters).
s1 = noiseStim(1); s2 = noiseStim(2);
body = struct();
body.document_class = struct('class_name', 'stimulus_presentation', 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
body.depends_on = struct('name', {'stimulus_element_id'}, 'value', {stimEl});
body.base = struct('id', presId, 'session_id', session(), ...
    'name', 'sp', 'datestamp', datestamp());
body.stimulus_presentation = struct('presentation_order', [1 2], ...
    'presentation_time', [trialTime(0, 4) trialTime(5, 9)], 'stimuli', [s1 s2]);
end

function body = makeGratingPresentation(presId, stimEl)
%MAKEGRATINGPRESENTATION The two-grating presentation (45 and 90 degrees).
body = makeStimulusPresentation(presId, stimEl);
body.stimulus_presentation.stimuli = [gratingStim(45) gratingStim(90)];
% the epoch string every real presentation carries (stimulus_presentation.json
% lists `epochid` as a superclass): the v1 document is carried as it stands,
% so it must be one its tombstone accepts
body.document_class.superclasses = [body.document_class.superclasses, ...
    struct('class_name', 'epochid', 'class_version', '1.0.0')];
body.epochid = struct('epochid', 't00001');
end

function s = noiseStim(seed)
%NOISESTIM A NewStim stochasticgridstim parameter set (the required fields of
%   verifystochasticgridstim.m); only randState varies.
s = struct('parameters', struct( ...
    'BG', [128 128 128], 'N', 100, 'angle', 0, ...
    'dispprefs', {{'BGpretime', 0, 'BGposttime', 0}}, ...
    'dist', [1 1], 'fps', 15, 'pixSize', [50 50], ...
    'randState', [seed 0.6704957765200832 0.08449867537860833], ...
    'rect', [0 0 800 600], 'values', [0 0 0; 255 255 255]));
end

function s = gratingStim(angle)
%GRATINGSTIM A real periodicstim parameter set (imageType 2, sine, drifting):
%   the second pass recognises the NewStim class by the required-field set its
%   verifyperiodicstim.m checks (Jess Haley, 2026-10-21), so a loose
%   {angle, sFrequency, tFrequency} struct is no longer a grating. Fields as
%   on the 20211116 225-stimulus oridir run; only `angle` varies here.
s = struct('parameters', struct( ...
    'imageType', 2, 'animType', 4, 'flickerType', 0, ...
    'angle', angle, ...
    'chromhigh', [255 255 255], 'chromlow', [0 0 0], ...
    'sFrequency', 0.5, 'sPhaseShift', 0, 'distance', 57, ...
    'tFrequency', 2, 'barWidth', 0.5, ...
    'rect', [0 0 800 600], 'nCycles', 1, 'contrast', 1, ...
    'background', 0.5, 'backdrop', 0.5, 'barColor', 1, ...
    'nSmoothPixels', 2, 'fixedDur', 0, 'windowShape', 0, 'loops', 0, ...
    'dispprefs', {{'BGposttime', 3}}));
end

function t = trialTime(onset, offset)
t = struct('onset', onset, 'offset', offset);
end

function s = session()
s = 'aabb1122ccdd3344_9900aabbccddeeff';
end

function n = variableName(e)
% a method parameter entry's variable: a term {node, name} or a label {name}
n = '';
if isstruct(e) && isfield(e, 'variable')
    v = e.variable;
    if isstruct(v) && isfield(v, 'name'); n = char(v(1).name);
    elseif ischar(v) || isstring(v); n = char(v); end
end
end

function d = rawLabel(targetId, node)
% +setup/+conv/+haley/doImport.m: ndi.document('ontologyLabel', 'ontologyLabel',
% struct('ontologyNode', ...)) + session.newdocument, then
% set_dependency_value('document_id', ...)
d = ndi.document('ontologyLabel', 'ontologyLabel', struct('ontologyNode', node));
d = d.setproperties('base.session_id', session());
d = d.set_dependency_value('document_id', targetId);
end

function n = classCount(byClass, classNames)
% the summed count for CLASSNAMES (a cellstr) in a {class_name, count} struct
% array; 0 when absent
n = 0;
if ~isstruct(byClass) || isempty(byClass) || ~isfield(byClass, 'class_name')
    return;
end
hit = ismember({byClass.class_name}, classNames);
if any(hit)
    n = sum([byClass(hit).count]);
end
end

function d = datestamp()
d = '2024-06-01T12:00:00.000Z';
end

% ===================== inspection / sqlite helpers ========================

function body = findById(dstPath, wantId)
%FINDBYID The document with this base.id, or [] -- the unambiguous lookup.
%   findByClass below returns the FIRST document of a class, which is fine while
%   a class has one instance. Once epochMint began minting epoch EXTENT
%   references there are several `relative_reference` documents per run and
%   "the first one" is whatever sqlite returns, so a test that means a SPECIFIC
%   document has to name it. Use this whenever the document under test is
%   identified by an EDGE rather than by its class.
body = [];
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
for k = 1:numel(ids)
    doc = db.get(ids{k});
    s = doc.toStruct();
    if isfield(s, 'base') && isfield(s.base, 'id') && strcmp(s.base.id, wantId)
        body = s;
        return;
    end
end
end

function body = findEntity(dstPath, typeName)
%FINDENTITY The first did-schema #88 `entity` whose `type.name` is typeName.
body = [];
for b = findAllByClass(dstPath, 'entity')
    s = b{1};
    if isfield(s, 'entity') && isfield(s.entity, 'type') ...
            && isstruct(s.entity.type) && isfield(s.entity.type, 'name') ...
            && ndi.v2.vocabIs('entity_type', s.entity.type, typeName)
        body = s;
        return;
    end
end
end

function bodies = findAllByClass(dstPath, className)
%FINDALLBYCLASS Every document of a class, so a COUNT can be asserted.
%   findByClass answers "is there one"; this answers "how many, and which".
bodies = {};
db = did2.database.sqlitedb(dstPath);
cleanup = onCleanup(@() db.close()); %#ok<NASGU>
ids = db.allIds();
for k = 1:numel(ids)
    doc = db.get(ids{k});
    if strcmp(doc.className(), className)
        bodies{end+1} = doc.toStruct(); %#ok<AGROW>
    end
end
end

function body = findTermObservation(dstPath, variableName)
% the first term observation whose variable is VARIABLENAME ([] when none):
% its label, or -- for the registered anatomy variables -- its node, so a
% site written as NCIT:C13717 "Anatomic Site" is found by 'anatomical location'
body = [];
nodes = struct('anatomical_location', 'NCIT:C13717', ...
    'anatomical_structure', 'UBERON:0000061');
key = strrep(variableName, ' ', '_');
for d = findAllByClass(dstPath, 'observation')
    x = d{1};
    if ~(isfield(x, 'statement') && isfield(x.statement, 'variable')); continue; end
    v = x.statement.variable;
    byNode = isfield(nodes, key) && isfield(v, 'node') && strcmpi(v.node, nodes.(key));
    if byNode || strcmp(v.name, variableName)
        body = x;
        return;
    end
end
end

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
% ORPHANS BY NAME, not by count. A bare `orphan_count = 2` says the graph does
% not close and nothing else; the three fields did2.validate.references already
% records -- which document, which edge, which missing target -- are what turns
% that into something actionable, and they were being thrown away at the point
% of failure. Printed unconditionally so a PASSING diagnostic (0 orphans) and a
% failing one are the same shape.
orph = '(none)';
if isfield(result, 'references') && isstruct(result.references) ...
        && isfield(result.references, 'orphans')
    rows = {};
    for k = 1:numel(result.references.orphans)
        o = result.references.orphans(k);
        rows{end+1} = sprintf('%s(%s).%s -> %s', ...
            charField(o, 'doc_class'), charField(o, 'doc_id'), ...
            charField(o, 'edge_name'), charField(o, 'edge_document_id')); %#ok<AGROW>
    end
    if ~isempty(rows); orph = strjoin(rows, ' | '); end
end
s = sprintf(['migrated by_class = {%s}; quarantine = {%s}; ' ...
    'orphans (%d of %d edges examined over %d docs) = {%s}'], ...
    byClass, quar, orphanCount(result), edgesExamined(result), ...
    totalDocs(result), orph);
end

function n = orphanCount(result)
n = -1;
if isfield(result, 'references') && isfield(result.references, 'orphan_count')
    n = result.references.orphan_count;
end
end

function n = edgesExamined(result)
n = -1;
if isfield(result, 'references') && isfield(result.references, 'edges_examined')
    n = result.references.edges_examined;
end
end

function n = totalDocs(result)
n = -1;
if isfield(result, 'references') && isfield(result.references, 'total_docs')
    n = result.references.total_docs;
end
end

function v = charField(s, name)
v = '';
if isstruct(s) && isfield(s, name) && (ischar(s.(name)) || isstring(s.(name)))
    v = char(s.(name));
end
end
