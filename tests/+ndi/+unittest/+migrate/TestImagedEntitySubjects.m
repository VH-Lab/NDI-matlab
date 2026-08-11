classdef TestImagedEntitySubjects < matlab.unittest.TestCase
%TESTIMAGEDENTITYSUBJECTS Unit tests for the V_eta imaged-entity subject
%   resolver. Pure struct logic: no database, no schema, no converter.
%
%   ndi.migrate.internal.imagedEntitySubjects decides WHICH already-existing
%   subject a subject-less image is an image OF, by walking
%   image -> ontologyTableRow -> subject through the migrated-id graph a
%   single-document migrator cannot see. It returns a PLAN (the did_v1 body with
%   a `subject_id` dependency added, ready to re-fold) and an instrument REPORT.
%
%   THE FIXTURES ARE BUILT FROM WHAT THE WRITER EMITS, never from a template and
%   never from a DID-side schema -- the rule the ground-truth track exists to
%   enforce, and the mistake that hid the distance_metadata bug and made every
%   `ontology_image` document migrate to a husk.
%
%     THE IMAGE      +setup/+conv/+haley/doImport.m:789-794 (and :811-814,
%                    :827-830) --
%                        ndi.document('imageStack','imageStack',imageStack,
%                            'imageStack_parameters',imageStack_parameters)
%                        ...set_dependency_value('document_id',
%                                                imageTable.image_id{p})
%                    ONE edge, named `document_id`, and NO `subject_id`: that
%                    session creates no subject at all (every `subject_id` in
%                    doImport.m is at line 689 or earlier, the C. elegans half).
%
%     THE IMAGE ROW  doImport.m:747,757 --
%                        imageVariables = {'plateID','imageID',
%                                          'lawnGrowthDuration','exposureTime'}
%                        table2ontologyTableRowDocs(imageTable,
%                                          {'plateID','imageID'},...)
%                    NO `dependencyVariable` is passed, so the row's
%                    `depends_on` is empty and `plateID` stays an ordinary
%                    `data` cell (tableDocMaker.m:170-172 removes ONLY the
%                    dependency columns).
%
%     THE PLATE      did2.convert.resolveLawnPlateSubjects/makeSubject +
%     SUBJECT        plateHandle -- a bare `subject` whose local_identifier is
%                        sprintf('exp/%s/plate/%s', expId, plateId)
%                    with a FRESH id and no edge back to the row.
%
%   AND the cases that must NOT resolve, which are the whole point: a plate id
%   that exists in the OTHER session, a lawn subject that must not be mistaken
%   for its plate, a plural `document_id`, a referent absent from the batch, two
%   candidate subjects, and two routes that disagree. Every one of those leaves
%   the image exactly as pass 1 emitted it and is COUNTED -- because
%   `did2/+validate/references.m:90` skips empty edges, so a guessed attribution
%   would validate clean, satisfy every gate, and be wrong.
%
%   STATUS: authored WITHOUT local MATLAB -- `command -v matlab octave
%   octave-cli` finds nothing in the session that wrote this. THESE TESTS HAVE
%   NOT BEEN RUN HERE. CI is their first execution.
%
%   Run with:  runtests('ndi.unittest.migrate.TestImagedEntitySubjects')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef, as in
%   TestOntologyRowSubjects, TestStrainAssembly and TestPathSPromotion.

    methods (Test)

        % ---------------- denominators ----------------------------------

        function testEmptyInputStillReportsItsDenominators(testCase)
            % A zero over a zero denominator must read VACUOUS, not clean. The
            % report exists in full before anything is read.
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects({}, {});
            testCase.verifyEmpty(plan);
            testCase.verifyTrue(report.ran);
            testCase.verifyEqual(report.v1_bodies_inspected, 0);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.images_passthrough, 0);
            testCase.verifyEqual(report.subjects_indexed, 0);
            testCase.verifyEqual(report.plate_subjects_indexed, 0);
            testCase.verifyEqual(report.resolved, 0);
            testCase.verifyEqual(report.unresolved, 0);
            testCase.verifyFalse(report.changed);
        end

        function testEveryRefusalBucketExistsBeforeAnythingIsRead(testCase)
            % Operating rule 5: a bucket that appears only when it fires is a
            % counter that cannot report a zero. All of them must be declared.
            [~, report] = ndi.migrate.internal.imagedEntitySubjects({}, {});
            for f = refusalBuckets()
                testCase.verifyTrue(isfield(report, f{1}), ...
                    sprintf('report is missing the bucket "%s"', f{1}));
                testCase.verifyEqual(report.(f{1}), 0);
            end
        end

        function testDenominatorsCountWhatWasActuallyRead(testCase)
            [v1, mig] = ecoliPlate();
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.v1_bodies_inspected, numel(v1));
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            testCase.verifyEqual(report.v1_image_bodies, 1);
            testCase.verifyEqual(report.images_passthrough, 1);
            testCase.verifyEqual(report.image_stack_passthrough, 1);
            testCase.verifyEqual(report.table_rows_indexed, 1);
            testCase.verifyEqual(report.subjects_indexed, 1);
            testCase.verifyEqual(report.plate_subjects_indexed, 1);
        end

        function testResolvedPlusUnresolvedAccountsForEveryImageLookedAt(testCase)
            % The instrument must account for every image it inspected. An image
            % is either planned, deferred-and-counted, or explained; there is no
            % fourth bucket and no silent drop.
            [v1, mig] = mixedBatch();
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved + report.unresolved, ...
                report.v1_image_bodies - report.images_converted_in_pass_1);
            testCase.verifyEqual(report.resolved, ...
                report.resolved_via_row_edge + report.resolved_via_plate_handle);
            testCase.verifyEqual(report.images_planned, ...
                report.resolved - report.resolved_ontology_image_not_foldable);
            total = 0;
            for f = refusalBuckets()
                total = total + report.(f{1});
            end
            testCase.verifyEqual(report.unresolved, total);
        end

        function testDocumentsUnreadableAreCountedNotDropped(testCase)
            % silentLoss reported zeros for two days because unreadable
            % documents vanished from the denominator instead of the numerator.
            [v1, mig] = ecoliPlate();
            mig{end+1} = struct();          % readable as a struct, but empty
            mig{end+1} = '{not json';       % not decodable at all
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            testCase.verifyEqual(report.documents_unreadable, 2);
        end

        % ---------------- the E. coli chain, which is the whole job -------

        function testEcoliImageIsAttributedToItsPlateSubject(testCase)
            [v1, mig] = ecoliPlate();
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved, 1);
            testCase.verifyEqual(report.resolved_via_plate_handle, 1);
            testCase.verifyEqual(report.images_planned, 1);
            testCase.verifyTrue(report.changed);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).source_id, 'IMG1');
            testCase.verifyEqual(plan(1).subject_id, 'PLATESUBJ');
            testCase.verifyEqual(plan(1).route, 'plate_handle');
            testCase.verifyEqual(plan(1).row_id, 'IMGROW');
        end

        function testPlannedBodyCarriesTheSubjectEdge(testCase)
            [v1, mig] = ecoliPlate();
            plan = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(depVal(plan(1).body, 'subject_id'), 'PLATESUBJ');
        end

        function testPlannedBodyKeepsItsDocumentIdEdge(testCase)
            % LOAD-BEARING, not tidy. +migrators_j/image_stack.m carries the
            % source `document_id` onto the folded image_observation as
            % `ontology_table_row_id`, so the provenance back to the describing
            % row survives the fold ONLY if the edge is still on the body when it
            % is re-folded. Dropping it here would silently re-open the gap that
            % migrator was changed to close.
            [v1, mig] = ecoliPlate();
            plan = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(depVal(plan(1).body, 'document_id'), 'IMGROW');
        end

        function testNothingIsMintedByThisPass(testCase)
            % resolveLawnPlateSubjects ALREADY minted the plate subject and says
            % so ("NO IMAGE SUBJECT ... left exactly as pass 1 emitted them").
            % A second mint would put two subjects on one plate, both valid and
            % both referenced -- invisible to every gate. The function returns
            % exactly two outputs; there is no mint channel at all.
            testCase.verifyEqual( ...
                nargout('ndi.migrate.internal.imagedEntitySubjects'), 2);
            [v1, mig] = ecoliPlate();
            plan = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            for k = 1:numel(plan)
                testCase.verifyNotEqual(classOf(plan(k).body), 'subject');
            end
        end

        function testThreeStacksOfOnePlateShareOneSubject(testCase)
            % doImport.m:789/811/827 build image, mask and closest-patch stacks
            % from ONE photograph, all naming the same image row. They depict one
            % plate, so they must all land on one subject -- a subject per image
            % would assert that each photograph shows a different thing.
            [v1, mig] = ecoliPlate();
            v1{end+1} = imageStackBody('IMG2', 'IMGROW', 'S_ECOLI');
            v1{end+1} = imageStackBody('IMG3', 'IMGROW', 'S_ECOLI');
            mig{end+1} = imageStackPassthrough('IMG2', 'S_ECOLI');
            mig{end+1} = imageStackPassthrough('IMG3', 'S_ECOLI');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 3);
            testCase.verifyEqual(report.images_planned, 3);
            testCase.verifyEqual(report.distinct_subjects_attached, 1);
            testCase.verifyEqual(unique({plan.subject_id}), {'PLATESUBJ'});
        end

        % ---------------- the joins that must NOT fire --------------------

        function testPlateIdInAnotherSessionIsNotJoined(testCase)
            % THE COLLISION THIS EXISTS TO PREVENT. doImport.m:180 (behaviour)
            % and :729 (E. coli) both format plateID as num2str(...,'%.4i'), so
            % both emit '0001','0002',... over the same range, and both sessions
            % land in ONE ndi.dataset.dir. Only base.session_id tells them apart.
            % An unscoped join would attach C. elegans plates to E. coli images.
            [v1, mig] = ecoliPlate();
            mig = replaceSessionOfPlateSubject(mig, 'S_CELEGANS');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.resolved, 0);
            testCase.verifyEqual(report.unresolved_no_plate_subject, 1);
            testCase.verifyFalse(report.changed);
        end

        function testALawnSubjectIsNeverMistakenForItsPlate(testCase)
            % A patch handle is `exp/X/plate/Y/patch/Z`. It CONTAINS `/plate/Y`
            % but does not END with it, and only the tail identifies a plate.
            % Reading the handle anywhere but at the end would attribute every
            % plate photograph to one arbitrary lawn sitting on it.
            [v1, mig] = ecoliPlate();
            mig = setPlateSubjectHandle(mig, 'exp/0003/plate/0007/patch/0002');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.plate_subjects_indexed, 0);
            testCase.verifyEqual(report.unresolved_no_plate_subject, 1);
        end

        function testTwoSubjectsWithOnePlateHandleIsRefusedNotPicked(testCase)
            [v1, mig] = ecoliPlate();
            mig{end+1} = plateSubject('PLATESUBJ2', 'S_ECOLI', 'exp/0003/plate/0007');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.plate_subjects_indexed, 2);
            testCase.verifyEqual(report.unresolved_plate_subject_ambiguous, 1);
        end

        function testPlateHandleJoinCanBeDisabledAndTheImagesAreCountedNotHidden(testCase)
            [v1, mig] = ecoliPlate();
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig, ...
                'PlateHandleJoin', false);
            testCase.verifyEmpty(plan);
            testCase.verifyFalse(report.plate_handle_join_enabled);
            testCase.verifyEqual(report.unresolved, 1);
        end

        function testPlateHandleFormatIsPinnedToTheMintingPass(testCase)
            % A CROSS-REPOSITORY COUPLING, pinned so a change reddens a test
            % rather than only a counter. did2.convert.resolveLawnPlateSubjects/
            % plateHandle is sprintf('exp/%s/plate/%s', expId, plateId). If that
            % ever changes, this join matches nothing and every image is counted
            % under unresolved_no_plate_subject -- it fails CLOSED, never wrong,
            % but silently doing less. This test is the alarm.
            [v1, mig] = ecoliPlate();
            mig = setPlateSubjectHandle(mig, 'plate-0007');   % a plausible rename
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.plate_subjects_indexed, 0);
            testCase.verifyEqual(report.unresolved_no_plate_subject, 1);

            % ... and the documented format still resolves.
            mig = setPlateSubjectHandle(mig, 'exp/0003/plate/0007');
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved_via_plate_handle, 1);
        end

        function testBarePlateHandleAlsoResolves(testCase)
            % resolveLawnPlateSubjects documents a pair-handle fallback for the
            % C. elegans rows that have no expID (`plate/<id>/patch/<id>`), so
            % the plate-only form of it must resolve too.
            [v1, mig] = ecoliPlate();
            mig = setPlateSubjectHandle(mig, 'plate/0007');
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved_via_plate_handle, 1);
        end

        % ---------------- route 1, and the plural question ----------------

        function testRowEdgeNamingASubjectResolves(testCase)
            [v1, mig] = rowEdgeToSubject();
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(report.resolved_via_row_edge, 1);
            testCase.verifyEqual(plan(1).subject_id, 'REALSUBJ');
            testCase.verifyEqual(plan(1).route, 'row_edge');
        end

        function testRowEdgeNamingANonSubjectIsRefused(testCase)
            % The row's edge points at whatever the row describes, which need not
            % be a subject. Renaming it to `subject_id` would assert that a
            % metadata document is a physical thing.
            [v1, mig] = rowEdgeToSubject();
            mig = retargetRowEdge(mig, 'NOTASUBJ');
            mig{end+1} = plainDoc('NOTASUBJ', 'S_X', 'ontology_label');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_row_edge_not_a_subject, 1);
        end

        function testRowEdgeReferentAbsentFromBatchIsItsOwnBucket(testCase)
            % DISCOVERY MODE IS NOT PROOF OF ABSENCE. A subset batch need not
            % contain the referent, and jSessionAnchor's note that its orphans
            % were discovery-mode was correct. "Not here" and "here and wrong"
            % are different findings and must not share a bucket.
            [v1, mig] = rowEdgeToSubject();
            mig = retargetRowEdge(mig, 'NOWHERE');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_row_edge_missing, 1);
            testCase.verifyEqual(report.unresolved_row_edge_not_a_subject, 0);
        end

        function testPluralDocumentIdIsRefusedBecauseTheDataCannotDecideIt(testCase)
            % tableDocMaker.m:170-172 deletes the dependency columns from
            % varNames BEFORE names / variableNames / ontologyNodes / data are
            % built (:174-219), so `document_id_1..n` are ANONYMOUS: the row
            % keeps no record of which column produced which edge. The kinds
            % genuinely differ between writers, so picking one is a guess.
            [v1, mig] = rowEdgeToSubject();
            mig = makeRowEdgePlural(mig, {'REALSUBJ', 'OTHERSUBJ'});
            mig{end+1} = plainSubject('OTHERSUBJ', 'S_X');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.blocked_plural_document_id, 1);
            testCase.verifyEqual(report.resolved, 0);
        end

        function testTwoRoutesThatDisagreeLeaveTheImageAlone(testCase)
            % Conflict is not resolved by precedence -- the rule
            % ontologyRowSubjects sets. A disagreement is a finding, not a
            % tie-break.
            [v1, mig] = ecoliPlate();
            mig = addRowEdge(mig, 'IMGROW', 'REALSUBJ');
            mig{end+1} = plainSubject('REALSUBJ', 'S_ECOLI');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_conflicting_candidates, 1);
        end

        % ---------------- hop 1 refusals ----------------------------------

        function testImageWithNoTableRowEdgeIsCounted(testCase)
            [v1, mig] = ecoliPlate();
            v1{1} = stripDeps(v1{1});
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_no_table_row_edge, 1);
        end

        function testTableRowAbsentFromBatchIsItsOwnBucket(testCase)
            [v1, mig] = ecoliPlate();
            mig = dropDoc(mig, 'IMGROW');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_table_row_not_in_batch, 1);
        end

        function testImageEdgeNamingANonRowIsRefused(testCase)
            [v1, mig] = ecoliPlate();
            mig = dropDoc(mig, 'IMGROW');
            mig{end+1} = plainDoc('IMGROW', 'S_ECOLI', 'ontology_label');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_referent_not_a_table_row, 1);
        end

        % ---------------- populations that are not this pass's work -------

        function testImageThatPassOneAlreadyFoldedIsNotTouched(testCase)
            % A C. elegans behaviour imageStack (doImport.m:421-432) sets BOTH
            % document_id and subject_id, so pass 1 folded it and it is not in
            % the migrated set as an `image_stack` at all.
            [v1, mig] = ecoliPlate();
            mig = dropDoc(mig, 'IMG1');
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.images_converted_in_pass_1, 1);
            testCase.verifyEqual(report.images_passthrough, 0);
            testCase.verifyEqual(report.resolved, 0);
            testCase.verifyEqual(report.unresolved, 0);
        end

        function testOntologyImageResolvesButIsDeliberatelyNotPlanned(testCase)
            % +migrators_j/ontology_image.m tests `isVintageB` FIRST and returns
            % {preBody} before it ever looks for a subject, so re-folding one
            % with subject_id added takes the identical passthrough arm. Planning
            % it would make a pass that appears to work and does not. The count
            % is what says how much a DID-side vintage-B arm would be worth.
            [v1, mig] = ontologyImageOnPlate();
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.ontology_image_passthrough, 1);
            testCase.verifyEqual(report.resolved, 1);
            testCase.verifyEqual(report.resolved_ontology_image_not_foldable, 1);
            testCase.verifyEqual(report.images_planned, 0);
            testCase.verifyFalse(report.changed);
        end

        function testCamelCaseImageEdgeSpellingAlsoResolves(testCase)
            % universalRenames.m:308 skips `depends_on` wholesale, so a
            % dependency NAME arrives verbatim in its did_v1 spelling. The
            % template's edge is `ontologyTableRow_id`; V_eta's tombstone
            % declares `ontology_table_row_id`. Both must be read, or the edge is
            % silently dropped -- the failure mode `demo_ndi` is named for.
            [v1, mig] = ontologyImageOnPlate();
            v1{1} = renameDep(v1{1}, 'ontologyTableRow_id', 'ontology_table_row_id');
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved, 1);
        end

        % ---------------- the row-reading rule ----------------------------

        function testPlateIdIsFoundViaTheRowsOwnNameToShortNameMapping(testCase)
            % The ontology short name is NEVER guessed: the EMPTY table is not in
            % this repository, and a disposition that turns on an unverified
            % spelling is how `demo_ndi` went wrong. `names` and `variableNames`
            % are positionally paired by the writer (tableDocMaker.m:196,
            % :212-215) and `data`'s keys ARE the short names (:208), so the row
            % supplies its own mapping. Here the data key is deliberately NOT a
            % normalised form of the term, so only the pairing can find it.
            [v1, mig] = ecoliPlate();
            mig = setRowColumns(mig, 'IMGROW', ...
                'bacterial plate identifier,microscopy image identifier', ...
                'Xq7,Zz9', ...
                struct('Xq7', '0007', 'Zz9', '0004'));
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved_via_plate_handle, 1);
        end

        function testPlateIdIsAlsoFoundFromTheDataKeyAlone(testCase)
            % The fallback: a row whose `names` is empty still resolves off the
            % normalised data key, so a row written without the descriptive
            % fields is not silently unreadable.
            [v1, mig] = ecoliPlate();
            mig = setRowColumns(mig, 'IMGROW', '', '', ...
                struct('BacterialPlateIdentifier', '0007'));
            [~, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEqual(report.resolved_via_plate_handle, 1);
        end

        function testRowWithNoPlateColumnIsNotADefect(testCase)
            % Haley's patch and encounter tables describe patches and encounters.
            % A row that names no plate is left alone and counted; forcing an
            % attribution on it would be the distance_metadata mistake (a quiet
            % passthrough turned into a GATING orphan failure).
            [v1, mig] = ecoliPlate();
            mig = setRowColumns(mig, 'IMGROW', ...
                'microscopy image identifier', 'MicroscopyImageIdentifier', ...
                struct('MicroscopyImageIdentifier', '0004'));
            [plan, report] = ndi.migrate.internal.imagedEntitySubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_no_plate_identifier, 1);
        end

    end
end

% ===================== the buckets, in one place ==========================

function f = refusalBuckets()
f = {'unresolved_no_table_row_edge', ...
     'unresolved_table_row_not_in_batch', ...
     'unresolved_referent_not_a_table_row', ...
     'blocked_plural_document_id', ...
     'unresolved_row_edge_missing', ...
     'unresolved_row_edge_not_a_subject', ...
     'unresolved_no_plate_identifier', ...
     'unresolved_no_plate_subject', ...
     'unresolved_plate_subject_ambiguous', ...
     'unresolved_conflicting_candidates'};
end

% ===================== fixtures ===========================================

function [v1, mig] = ecoliPlate()
%ECOLIPLATE The real E. coli shape: one imageStack -> one image row -> one plate
%   subject already minted by resolveLawnPlateSubjects.
v1 = {imageStackBody('IMG1', 'IMGROW', 'S_ECOLI')};
mig = { ...
    imageStackPassthrough('IMG1', 'S_ECOLI'), ...
    imageRow('IMGROW', 'S_ECOLI', '0007', '0004'), ...
    plateSubject('PLATESUBJ', 'S_ECOLI', 'exp/0003/plate/0007')};
end

function [v1, mig] = ontologyImageOnPlate()
v1 = {ontologyImageBody('OIMG1', 'IMGROW', 'S_ECOLI')};
mig = { ...
    ontologyImagePassthrough('OIMG1', 'S_ECOLI'), ...
    imageRow('IMGROW', 'S_ECOLI', '0007', '0004'), ...
    plateSubject('PLATESUBJ', 'S_ECOLI', 'exp/0003/plate/0007')};
end

function [v1, mig] = rowEdgeToSubject()
%ROWEDGETOSUBJECT The shape tableDocMaker's `dependencyVariable` option
%   produces: the row names its referent by EDGE. No converter in the tree
%   passes that option today, which is exactly why it is fixtured rather than
%   assumed away.
row = imageRow('IMGROW', 'S_X', '', '0004');
row.depends_on = struct('name', 'document_id', 'document_id', 'REALSUBJ');
v1 = {imageStackBody('IMG1', 'IMGROW', 'S_X')};
mig = {imageStackPassthrough('IMG1', 'S_X'), row, plainSubject('REALSUBJ', 'S_X')};
end

function [v1, mig] = mixedBatch()
%MIXEDBATCH One of each outcome, so the accounting identity is exercised over a
%   batch rather than a single happy path.
[v1, mig] = ecoliPlate();

% resolvable via the row edge
v1{end+1}  = imageStackBody('IMG_E', 'ROW_E', 'S_X');
mig{end+1} = imageStackPassthrough('IMG_E', 'S_X');
rowE = imageRow('ROW_E', 'S_X', '', '0001');
rowE.depends_on = struct('name', 'document_id', 'document_id', 'REALSUBJ');
mig{end+1} = rowE;
mig{end+1} = plainSubject('REALSUBJ', 'S_X');

% no edge at all
v1{end+1}  = stripDeps(imageStackBody('IMG_N', '', 'S_X'));
mig{end+1} = imageStackPassthrough('IMG_N', 'S_X');

% row not in the batch
v1{end+1}  = imageStackBody('IMG_M', 'ROW_GONE', 'S_X');
mig{end+1} = imageStackPassthrough('IMG_M', 'S_X');

% already folded in pass 1
v1{end+1}  = imageStackBody('IMG_P', 'IMGROW', 'S_ECOLI');

% an ontology_image: resolves, deliberately not planned
v1{end+1}  = ontologyImageBody('OIMG', 'IMGROW', 'S_ECOLI');
mig{end+1} = ontologyImagePassthrough('OIMG', 'S_ECOLI');
end

% ===================== body builders ======================================

function b = imageStackBody(id, rowId, sessionId)
%IMAGESTACKBODY A did_v1 imageStack exactly as +setup/+conv/+haley/doImport.m
%   :789-794 writes it: ONE `document_id` edge naming the image row, and no
%   subject_id anywhere.
b = struct();
b.document_class = struct('class_name', 'imageStack', 'class_version', 1);
b.depends_on = struct('name', 'document_id', 'value', rowId);
b.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
b.imageStack = struct('label', 'bacterial lawn image', ...
    'formatOntology', 'NCIT:C70631');
b.imageStack_parameters = struct('dimension_order', 'YX', ...
    'dimension_labels', 'height,width', 'dimension_size', [1024 1024], ...
    'data_type', 'uint16');
end

function b = ontologyImageBody(id, rowId, sessionId)
%ONTOLOGYIMAGEBODY Vintage B, the only vintage that has ever existed: the
%   `ontologyTableRow_id` edge plus an ngrid block (imageDocMaker.m:121-131).
b = struct();
b.document_class = struct('class_name', 'ontologyImage', 'class_version', 1);
b.depends_on = struct('name', 'ontologyTableRow_id', 'value', rowId);
b.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
b.ontologyImage = struct('ontologyNodes', 'EMPTY:0000133');
b.ngrid = struct('data_type', 'uint16', 'data_size', [1024 1024]);
end

function s = imageStackPassthrough(id, sessionId)
%IMAGESTACKPASSTHROUGH What pass 1 leaves behind when the guard fires: the same
%   document, class_name snake_cased by universalRenames, id untouched.
s = struct();
s.document_class = struct('class_name', 'image_stack', 'class_version', '1.0.0');
s.depends_on = struct('name', 'document_id', 'document_id', 'IMGROW');
s.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
s.image_stack = struct('label', 'bacterial lawn image');
end

function s = ontologyImagePassthrough(id, sessionId)
s = struct();
s.document_class = struct('class_name', 'ontology_image', 'class_version', '1.0.0');
s.depends_on = struct('name', 'ontology_table_row_id', 'document_id', 'IMGROW');
s.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
s.ontology_image = struct('ontology_nodes', 'EMPTY:0000133');
end

function s = imageRow(id, sessionId, plateId, imageId)
%IMAGEROW The E. coli image row: doImport.m:747 imageVariables, mapped through
%   +setup/+conv/+haley/tableDoc_dictionary.json --
%       "plateID": "EMPTY:bacterial plate identifier"
%       "imageID": "EMPTY:microscopy image identifier"
%   -- and carrying NO depends_on, because doImport.m:757 passes no
%   `dependencyVariable` (tableDocMaker.m:225 therefore never runs).
s = struct();
s.document_class = struct('class_name', 'ontology_table_row', ...
    'class_version', '1.0.0');
s.depends_on = struct('name', {}, 'document_id', {});
s.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
data = struct();
names = {};
shorts = {};
if ~isempty(plateId)
    data.BacterialPlateIdentifier = plateId;
    names{end+1}  = 'bacterial plate identifier';
    shorts{end+1} = 'BacterialPlateIdentifier';
end
data.MicroscopyImageIdentifier = imageId;
names{end+1}  = 'microscopy image identifier';
shorts{end+1} = 'MicroscopyImageIdentifier';
s.ontology_table_row = struct( ...
    'names', strjoin(names, ','), ...
    'variable_names', strjoin(shorts, ','), ...
    'ontology_nodes', '', ...
    'data', data);
end

function s = plateSubject(id, sessionId, handle)
%PLATESUBJECT What did2.convert.resolveLawnPlateSubjects/makeSubject emits: a
%   bare subject with a FRESH id, no edges, and plateHandle() as its
%   local_identifier.
s = plainSubject(id, sessionId);
s.subject = struct('local_identifier', handle, ...
    'description', 'bacterial plate (a plate of lawns)');
end

function s = plainSubject(id, sessionId)
s = struct();
s.document_class = struct('class_name', 'subject', 'class_version', '3.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'));
s.depends_on = struct('name', {}, 'document_id', {});
s.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
s.subject = struct('local_identifier', ['lid_' id], 'description', '');
end

function s = plainDoc(id, sessionId, className)
s = struct();
s.document_class = struct('class_name', className, 'class_version', '1.0.0');
s.depends_on = struct('name', {}, 'document_id', {});
s.base = struct('id', id, 'session_id', sessionId, 'name', '', ...
    'datestamp', '2024-01-01T00:00:00.000Z');
end

% ===================== fixture mutators ===================================

function mig = replaceSessionOfPlateSubject(mig, sessionId)
for k = 1:numel(mig)
    if isfield(mig{k}, 'subject') && strcmp(mig{k}.base.id, 'PLATESUBJ')
        mig{k}.base.session_id = sessionId;
    end
end
end

function mig = setPlateSubjectHandle(mig, handle)
for k = 1:numel(mig)
    if isfield(mig{k}, 'subject') && strcmp(mig{k}.base.id, 'PLATESUBJ')
        mig{k}.subject.local_identifier = handle;
    end
end
end

function mig = setRowColumns(mig, rowId, names, shorts, data)
for k = 1:numel(mig)
    if strcmp(classOf(mig{k}), 'ontology_table_row') ...
            && strcmp(mig{k}.base.id, rowId)
        mig{k}.ontology_table_row = struct('names', names, ...
            'variable_names', shorts, 'ontology_nodes', '', 'data', data);
    end
end
end

function mig = retargetRowEdge(mig, target)
for k = 1:numel(mig)
    if strcmp(classOf(mig{k}), 'ontology_table_row')
        mig{k}.depends_on = struct('name', 'document_id', 'document_id', target);
    end
end
end

function mig = addRowEdge(mig, rowId, target)
for k = 1:numel(mig)
    if strcmp(classOf(mig{k}), 'ontology_table_row') ...
            && strcmp(mig{k}.base.id, rowId)
        mig{k}.depends_on = struct('name', 'document_id', 'document_id', target);
    end
end
end

function mig = makeRowEdgePlural(mig, targets)
for k = 1:numel(mig)
    if ~strcmp(classOf(mig{k}), 'ontology_table_row')
        continue;
    end
    deps = struct('name', {}, 'document_id', {});
    for j = 1:numel(targets)
        deps(j) = struct('name', sprintf('document_id_%d', j), ...
            'document_id', targets{j});
    end
    mig{k}.depends_on = deps;
end
end

function mig = dropDoc(mig, id)
keep = true(1, numel(mig));
for k = 1:numel(mig)
    if isfield(mig{k}, 'base') && strcmp(mig{k}.base.id, id)
        keep(k) = false;
    end
end
mig = mig(keep);
end

function b = stripDeps(b)
b.depends_on = struct('name', {}, 'value', {});
end

function b = renameDep(b, oldName, newName)
for k = 1:numel(b.depends_on)
    if strcmp(b.depends_on(k).name, oldName)
        b.depends_on(k).name = newName;
    end
end
end

% ===================== accessors ==========================================

function c = classOf(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isfield(s.document_class, 'class_name')
    c = char(s.document_class.class_name);
end
end

function v = depVal(b, name)
v = '';
if ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
for k = 1:numel(b.depends_on)
    if ~strcmp(b.depends_on(k).name, name)
        continue;
    end
    d = b.depends_on(k);
    if isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    elseif isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    end
    return;
end
end
