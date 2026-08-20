classdef TestOntologyRowSubjects < matlab.unittest.TestCase
%TESTONTOLOGYROWSUBJECTS Unit tests for the V_eta ontologyTableRow subject
%   resolver (#53). Pure struct logic: no database, no schema, no converter.
%
%   ndi.migrate.internal.ontologyRowSubjects decides WHICH migrated `subject` a
%   passed-through `ontology_table_row` is about, using the migrated-id graph a
%   single-document migrator cannot see. It returns a PLAN (the did_v1 body with
%   a `subject_id` dependency added, ready to re-fold) and an instrument REPORT.
%
%   The fixtures reproduce the real writers, one per route:
%
%     ROUTE 1  `document_id` edge
%              +setup/+conv/+babu/import.m:380,383,386,389 pass
%              'DependencyVariable','SubjectDocumentIdentifier' (the only four
%              sites in the tree, each naming ONE column), and
%              +setup/+NDIMaker/tableDocMaker.m turns that column into
%              set_dependency_value('document_id', value).
%
%              THE FIXTURE IS BUILT AGAINST origin/main, DELIBERATELY, AND THE
%              TWO REFS DISAGREE. On origin/main the column is REMOVED from
%              `data` first (`tableDocMaker.m:172`,
%              `varNames(ismember(varNames,dependencyVariable)) = []`), so a
%              Babu row carries its subject as the EDGE ALONE -- and that is
%              the shape of every row already written. On this feature branch
%              `40dc9aa86` keeps the column, so a row written after it
%              satisfies routes 1 AND 2 with the same id. Do not "correct"
%              this comment against the working tree: grepping the branch for
%              the deleted line finds nothing, and the did_v1 truth ref is
%              origin/main. testAgreementBetweenRoutesResolves below covers
%              the post-repair shape.
%
%     ROUTE 2  a `SubjectDocumentIdentifier` cell in `data`
%              +setup/+conv/+haley/doImport.m:351 builds
%              wormTable(:,{'wormID','subjectName','subject_id'}) where
%              `subject_id` comes from subjectMaker.addSubjectsFromTable, and
%              +setup/+conv/+haley/tableDoc_dictionary.json maps
%              "subject_id": "EMPTY:subject document identifier".
%
%     ROUTE 3  a `SubjectLocalIdentifier` cell joined to
%              subject.local_identifier
%              +setup/+conv/+dabrowska/tableDoc_dictionary.json has NO document
%              identifier at all -- only "SubjectString": "EMPTY:Subject local
%              identifier" -- and doImport.m:442,446 pass no dependencyVariable.
%              The string is the subjectName that subjectMaker.m:258 wrote as
%              ndi.document('subject','subject.local_identifier', sName, ...).
%
%   AND the cases that must NOT resolve, which are the point of the pass:
%   a plate row with no subject column, an id that names a non-subject, an id
%   absent from the batch (discovery mode), an ambiguous local identifier, and
%   two routes that disagree. Every one of those leaves the row alone and is
%   counted -- because `did2/+validate/references.m:90` skips empty edges, so a
%   guessed edge would validate clean and mean nothing.
%
%   AND the two counters that answer questions which were UNMEASURED rather
%   than zero: `rows_with_plural_document_id` (the arity counter
%   V_eta_OPEN_WORK.md row #105 records as missing from all three
%   repositories) and the `data_cells_*` scale figures, which are the quantity
%   comparable to the 76,766 hollow statements this defect was first measured
%   at. Both are asserted to run for EVERY row in scope, resolved or not,
%   because a counter that only runs on one branch cannot report that
%   branch's zero.
%
%   STATUS: authored WITHOUT local MATLAB. These tests have NOT been run --
%   including the ones added with the counters.
%
%   Run with:  runtests('ndi.unittest.migrate.TestOntologyRowSubjects')
%
%   Fixtures/accessors are LOCAL FUNCTIONS below the classdef, as in
%   TestStrainAssembly and TestPathSPromotion.

    methods (Test)

        % ---------------- denominators ----------------------------------

        function testEmptyInputStillReportsItsDenominators(testCase)
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects({}, {});
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.v1_bodies_inspected, 0);
            testCase.verifyEqual(report.documents_inspected, 0);
            testCase.verifyEqual(report.rows_passthrough, 0);
            testCase.verifyEqual(report.subjects_indexed, 0);
            testCase.verifyFalse(report.changed);
        end

        function testDenominatorsCountWhatWasActuallyRead(testCase)
            [v1, mig] = haleyWorm();
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.v1_bodies_inspected, numel(v1));
            testCase.verifyEqual(report.documents_inspected, numel(mig));
            testCase.verifyEqual(report.subjects_indexed, 1);
            testCase.verifyEqual(report.rows_passthrough, 1);
            testCase.verifyEqual(report.v1_ontology_rows, 1);
        end

        function testResolvedPlusUnresolvedEqualsRowsInspected(testCase)
            % The instrument must account for every row it looked at. A row is
            % either planned or explained; there is no third bucket.
            [v1, mig] = mixedCorpus();
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.resolved + report.unresolved, ...
                report.rows_passthrough);
            testCase.verifyEqual(report.resolved, ...
                report.resolved_via_document_id_edge ...
                + report.resolved_via_subject_column ...
                + report.resolved_via_local_identifier);
            testCase.verifyEqual(report.unresolved, ...
                report.unresolved_no_candidate ...
                + report.unresolved_candidate_missing ...
                + report.unresolved_candidate_not_subject ...
                + report.unresolved_local_identifier_missing ...
                + report.unresolved_local_identifier_ambiguous ...
                + report.unresolved_conflicting_candidates ...
                + report.unresolved_edge_would_be_dropped);
        end

        % ---------------- route 1: the document_id edge ------------------

        function testDocumentIdEdgeResolvesWhenItNamesASubject(testCase)
            [v1, mig] = babuRow();
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).route, 'document_id_edge');
            testCase.verifyEqual(plan(1).subject_id, 'subj_babu');
            testCase.verifyEqual(plan(1).source_id, 'row_babu');
            testCase.verifyEqual(report.resolved_via_document_id_edge, 1);
            testCase.verifyTrue(report.changed);
        end

        function testNumberedDocumentIdEdgeIsRead(testCase)
            % tableDocMaker uses add_dependency_value_n when a row names more
            % than one referent, so the names become document_id_1, _2, ...
            % A single-name lookup would miss every non-scalar case.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct('name', 'document_id_1', 'value', 'subj_babu');
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).subject_id, 'subj_babu');
        end

        function testASecondEdgeThatWouldBeDroppedRefusesTheRow(testCase)
            % migrators_j's startStatement ASSIGNS depends_on = carrySubject(),
            % so an emitted statement carries subject_id and nothing else. A
            % second, non-subject referent would vanish on conversion -- which
            % is the discard ontology_label's migrator comment names. Refuse.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct( ...
                'name',  {'document_id_1', 'document_id_2'}, ...
                'value', {'subj_babu',     'plate_doc'});
            mig{end+1} = migratedDoc('plate_doc', 'sess_babu', 'ontology_table_row');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_edge_would_be_dropped, 1);
        end

        function testAnEmptyEdgeAlongsideASubjectColumnIsNotAnObstacle(testCase)
            % The template always ships depends_on document_id with value "",
            % so an EMPTY edge is the norm, not a stranded referent.
            [v1, mig] = haleyWorm();
            testCase.verifyEqual(depValue(v1{1}, 'document_id'), '');
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
        end

        function testEdgeNamingANonSubjectIsRefused(testCase)
            % The Haley imageStack rows point document_id at another table row.
            % Renaming that edge to subject_id would assert an image is a
            % subject -- the mistake the pass-1 comment refuses by name.
            [v1, mig] = babuRow();
            mig{2} = migratedDoc('subj_babu', 'sess_babu', 'ontology_table_row');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_candidate_not_subject, 1);
            testCase.verifyFalse(report.changed);
        end

        function testEdgeNamingAnAbsentDocumentIsRefusedNotGuessed(testCase)
            % DISCOVERY MODE: a subset batch need not contain the referent.
            % Absence is not evidence the subject does not exist -- so the row
            % is left alone and counted, never resolved to something else.
            [v1, mig] = babuRow();
            mig(2) = [];                      % drop the subject document
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_candidate_missing, 1);
            testCase.verifyEqual(report.subjects_indexed, 0);
        end

        function testElementDerivedSubjectResolvesLikeAnyOther(testCase)
            % THE RECURRING TRAP, pinned. `element_id` is NOT a dangling
            % non-subject edge: did2.convert.migrators_j.element promotes an
            % element to a subject with its id PRESERVED, so the id lands on a
            % `subject` in the migrated set and needs no special case.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct('name', 'document_id', 'value', 'elem_007');
            mig{2} = migratedSubject('elem_007', 'sess_babu', 'ctx_0007');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).subject_id, 'elem_007');
            testCase.verifyEqual(report.resolved_via_document_id_edge, 1);
        end

        % ---------------- route 2: the SubjectDocumentIdentifier cell ----

        function testSubjectDocumentIdentifierCellResolves(testCase)
            [v1, mig] = haleyWorm();
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).route, 'subject_column');
            testCase.verifyEqual(plan(1).subject_id, 'subj_worm');
            testCase.verifyEqual(report.resolved_via_subject_column, 1);
        end

        function testSnakeCaseDataKeyAlsoResolves(testCase)
            % universalRenames snake-cases only a block's IMMEDIATE field names
            % and `data` is nested, so the keys stay camelCase. The fallback is
            % pinned anyway, per the standing migrator lesson -- and because a
            % disposition that turns on a spelling is how `demo_ndi` went wrong.
            [v1, mig] = haleyWorm();
            blk = v1{1}.ontologyTableRow;
            blk.data = struct('subject_document_identifier', 'subj_worm');
            v1{1}.ontologyTableRow = blk;
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).subject_id, 'subj_worm');
        end

        % ---------------- route 3: the local-identifier string join ------

        function testUniqueLocalIdentifierJoinResolves(testCase)
            [v1, mig] = dabrowskaRow();
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).route, 'local_identifier');
            testCase.verifyEqual(plan(1).subject_id, 'subj_dab');
            testCase.verifyEqual(report.resolved_via_local_identifier, 1);
            testCase.verifyEqual(report.subject_local_ids_unique, 1);
        end

        function testAmbiguousLocalIdentifierIsRefused(testCase)
            % A string join is a weaker guarantee than an id, so two candidates
            % means no answer -- never the first one.
            [v1, mig] = dabrowskaRow();
            mig{end+1} = migratedSubject('subj_dab_twin', 'sess_dab', ...
                'A123_1@dabrowska-lab.rosalindfranklin.edu');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_local_identifier_ambiguous, 1);
            testCase.verifyEqual(report.subject_local_ids_unique, 0);
        end

        function testLocalIdentifierIsScopedToTheSession(testCase)
            % The same local identifier in a different session is NOT a match.
            [v1, mig] = dabrowskaRow();
            mig{2} = migratedSubject('subj_dab', 'sess_other', ...
                'A123_1@dabrowska-lab.rosalindfranklin.edu');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_local_identifier_missing, 1);
        end

        function testLocalIdentifierJoinCanBeDisabled(testCase)
            % Disabling the route must SHOW the affected rows as unresolved,
            % not omit them -- otherwise the switch would quietly change the
            % denominator instead of the answer.
            [v1, mig] = dabrowskaRow();
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig, ...
                'LocalIdentifierJoin', false);
            testCase.verifyEmpty(plan);
            testCase.verifyFalse(report.local_identifier_join_enabled);
            testCase.verifyEqual(report.unresolved, 1);
            testCase.verifyEqual(report.unresolved_no_candidate, 1);
            testCase.verifyEqual(report.rows_passthrough, 1);
        end

        % ---------------- the cases that must not resolve ----------------

        function testPlateRowWithNoSubjectColumnIsLeftAlone(testCase)
            % Haley's cultivation/behaviour plate rows describe a PLATE. They
            % have no subject and must not be given one.
            [v1, mig] = haleyPlate();
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_no_candidate, 1);
            testCase.verifyEqual(report.rows_passthrough, 1);
            testCase.verifyFalse(report.changed);
        end

        function testConflictingRoutesAreRefusedNotRanked(testCase)
            [v1, mig] = haleyWorm();
            v1{1}.depends_on = struct('name', 'document_id', 'value', 'subj_other');
            mig{end+1} = migratedSubject('subj_other', 'sess_jh', 'other');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_conflicting_candidates, 1);
        end

        function testRowConvertedInPassOneIsNotTouched(testCase)
            % A row a per-table map already migrated is no longer an
            % `ontology_table_row` in the migrated set (preserveSourceId moved
            % its id onto a statement), so it is out of scope and counted
            % separately -- not silently skipped.
            [v1, mig] = haleyWorm();
            mig{1} = migratedDoc('row_worm', 'sess_jh', 'velocity_observation');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.rows_converted_in_pass_1, 1);
            testCase.verifyEqual(report.rows_passthrough, 0);
            testCase.verifyEqual(report.v1_ontology_rows, 1);
        end

        function testAgreementBetweenRoutesResolves(testCase)
            % THE POST-REPAIR SHAPE. NDI `40dc9aa86` stopped tableDocMaker
            % deleting the dependency columns, so a Babu row written after it
            % carries the subject id BOTH as the `document_id` edge (route 1)
            % and as a `SubjectDocumentIdentifier` cell (route 2). Rows
            % already written carry the edge alone, so both shapes must keep
            % working -- which is why neither route is preferred.
            %
            % Two routes agreeing is NOT a conflict: resolveRowSubject
            % collects hits from every route and refuses only on
            % `unique(ids) > 1`.
            [v1, mig] = babuRow();
            v1{1}.ontologyTableRow.data.SubjectDocumentIdentifier = 'subj_babu';
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(plan(1).subject_id, 'subj_babu');
            testCase.verifyEqual(report.resolved, 1);
            testCase.verifyEqual(report.unresolved_conflicting_candidates, 0);
            % The edge is singular; agreement across routes must not be read
            % as arity.
            testCase.verifyEqual(report.rows_with_plural_document_id, 0);
            testCase.verifyEqual(report.document_id_edges_seen, 1);
        end

        % ---------------- arity and scale (the #105 counters) -------------

        function testArityAndScaleCountersExistOnAnEmptyBatch(testCase)
            % A counter that appears only when there is something to count
            % cannot report a zero. These must be present on 0 of 0.
            [~, report] = ndi.migrate.internal.ontologyRowSubjects({}, {});
            testCase.verifyEqual(report.document_id_edges_seen, 0);
            testCase.verifyEqual(report.rows_with_document_id_edge, 0);
            testCase.verifyEqual(report.rows_with_plural_document_id, 0);
            testCase.verifyEqual(report.data_cells_seen, 0);
            testCase.verifyEqual(report.data_cells_on_resolved_rows, 0);
            testCase.verifyEqual(report.data_cells_on_unresolved_rows, 0);
        end

        function testTheEmptyTemplateEdgeIsNotCountedAsAReferent(testCase)
            % ontologyTableRow.json ships depends_on document_id with value ""
            % on EVERY row, so counting empty edges would make every row in
            % every corpus look like it names something -- and the arity
            % counter would report the corpus size.
            [v1, mig] = haleyWorm();
            testCase.verifyEqual(depValue(v1{1}, 'document_id'), '');
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.document_id_edges_seen, 0);
            testCase.verifyEqual(report.rows_with_document_id_edge, 0);
            testCase.verifyEqual(report.rows_with_plural_document_id, 0);
        end

        function testASingleDocumentIdEdgeIsNotPlural(testCase)
            [v1, mig] = babuRow();
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.document_id_edges_seen, 1);
            testCase.verifyEqual(report.rows_with_document_id_edge, 1);
            testCase.verifyEqual(report.rows_with_plural_document_id, 0);
        end

        function testPluralDocumentIdIsCountedEvenWhenTheRowIsRefused(testCase)
            % THE COUNTER V_eta_OPEN_WORK.md row #105 records as missing from
            % all three repositories. Arity is a property of the ROW, not of
            % the outcome -- and a refused row is precisely the one whose
            % arity nobody could measure before, because
            % `resolved_via_document_id_edge` counts resolutions.
            %
            % No in-tree converter can write this shape: on origin/main
            % 'DependencyVariable' is passed at exactly four sites, all
            % +setup/+conv/+babu/import.m, each naming ONE column. So a
            % non-zero count in production means an OUT-OF-TREE writer, which
            % is the unmeasured population #105 names.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct( ...
                'name',  {'document_id_1', 'document_id_2'}, ...
                'value', {'subj_babu',     'plate_doc'});
            mig{end+1} = migratedDoc('plate_doc', 'sess_babu', 'ontology_table_row');
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEmpty(plan);
            testCase.verifyEqual(report.unresolved_edge_would_be_dropped, 1);
            testCase.verifyEqual(report.document_id_edges_seen, 2);
            testCase.verifyEqual(report.rows_with_plural_document_id, 1);
        end

        function testPluralDocumentIdIsCountedWhenTheRowResolves(testCase)
            % Two edges naming the SAME subject resolve (unique(ids) is 1) and
            % the arity is still 2. Deriving arity from the resolution would
            % report this row as singular.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct( ...
                'name',  {'document_id_1', 'document_id_2'}, ...
                'value', {'subj_babu',     'subj_babu'});
            [plan, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(plan), 1);
            testCase.verifyEqual(report.resolved_via_document_id_edge, 1);
            testCase.verifyEqual(report.document_id_edges_seen, 2);
            testCase.verifyEqual(report.rows_with_plural_document_id, 1);
        end

        function testDataCellsAccountForEveryRowInScope(testCase)
            % The scale invariant, the sibling of
            % testResolvedPlusUnresolvedEqualsRowsInspected: every cell counted
            % sits on a row that was either resolved or explained. No third
            % bucket.
            [v1, mig] = mixedCorpus();
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual( ...
                report.data_cells_on_resolved_rows ...
                + report.data_cells_on_unresolved_rows, ...
                report.data_cells_seen);
            testCase.verifyGreaterThan(report.data_cells_seen, 0);
        end

        function testUnresolvedRowsStillContributeTheirCells(testCase)
            % The point of the counter: the cells still NOT recovered. A plate
            % row resolves to nothing, and its columns must show up as
            % unresolved scale rather than vanishing from the instrument.
            [v1, mig] = haleyPlate();
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.unresolved_no_candidate, 1);
            testCase.verifyEqual(report.data_cells_seen, 4);
            testCase.verifyEqual(report.data_cells_on_unresolved_rows, 4);
            testCase.verifyEqual(report.data_cells_on_resolved_rows, 0);
        end

        function testDataCellCountIsColumnsNotStatements(testCase)
            % A cell is an UPPER BOUND on statements, never an estimate. This
            % counts COLUMNS; how many of them become statements is
            % did2.convert.migrators_j.ontology_table_row's migrateRow rule
            % ("One column -> one statement", then identity and empty columns
            % skipped), and that rule is deliberately NOT re-implemented here.
            % haleyWorm has three columns, so the counter says three whatever
            % the migrator would go on to emit.
            [v1, mig] = haleyWorm();
            testCase.verifyEqual( ...
                numel(fieldnames(v1{1}.ontologyTableRow.data)), 3);
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.data_cells_seen, 3);
            testCase.verifyEqual(report.data_cells_on_resolved_rows, 3);
        end

        function testRowsConvertedInPassOneContributeNoArityOrScale(testCase)
            % Both counters are scoped to the rows this pass can act on. A row
            % pass 1 already converted is out of scope and must not inflate
            % either denominator -- otherwise the scale figure would grow with
            % work already done.
            [v1, mig] = babuRow();
            mig{1} = migratedDoc('row_babu', 'sess_babu', 'velocity_observation');
            [~, report] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(report.rows_converted_in_pass_1, 1);
            testCase.verifyEqual(report.rows_passthrough, 0);
            testCase.verifyEqual(report.document_id_edges_seen, 0);
            testCase.verifyEqual(report.data_cells_seen, 0);
        end

        % ---------------- the injected dependency ------------------------

        function testInjectedEdgeUsesTheExistingValueKey(testCase)
            % A raw v1 body carries {name,value} (the template's own shape).
            [v1, mig] = babuRow();
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            deps = plan(1).body.depends_on;
            testCase.verifyTrue(any(strcmp({deps.name}, 'subject_id')));
            testCase.verifyEqual(depValue(plan(1).body, 'subject_id'), 'subj_babu');
            % the original edge is NOT removed or renamed: document_id points at
            % the document the row describes and remains true.
            testCase.verifyEqual(depValue(plan(1).body, 'document_id'), 'subj_babu');
        end

        function testInjectedEdgeMatchesADocumentIdFieldSchema(testCase)
            % The idempotent re-run path hands back bodies that already went
            % through universalRenames, i.e. {name,document_id}. Appending a
            % {name,value} struct to that array would error.
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct('name', 'document_id', 'document_id', 'subj_babu');
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            deps = plan(1).body.depends_on;
            testCase.verifyEqual(numel(deps), 2);
            testCase.verifyEqual(depValue(plan(1).body, 'subject_id'), 'subj_babu');
        end

        function testPreexistingEmptySubjectEdgeIsReplacedNotDuplicated(testCase)
            [v1, mig] = babuRow();
            v1{1}.depends_on = struct( ...
                'name',  {'document_id', 'subject_id'}, ...
                'value', {'subj_babu',   ''});
            [plan, ~] = ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            deps = plan(1).body.depends_on;
            testCase.verifyEqual(sum(strcmp({deps.name}, 'subject_id')), 1);
            testCase.verifyEqual(depValue(plan(1).body, 'subject_id'), 'subj_babu');
        end

        function testTheSourceBodyIsNotMutated(testCase)
            [v1, mig] = babuRow();
            before = numel(v1{1}.depends_on);
            ndi.migrate.internal.ontologyRowSubjects(v1, mig);
            testCase.verifyEqual(numel(v1{1}.depends_on), before);
        end

    end
end

% ===================== fixtures ==========================================

function [v1, mig] = babuRow()
% ROUTE 1. +setup/+conv/+babu/import.m:379 passes
% 'DependencyVariable','SubjectDocumentIdentifier', so tableDocMaker REMOVES
% that column from `data` and writes it as the `document_id` edge instead.
row = v1Row('row_babu', 'sess_babu', ...
    'CElegansChemotaxisAssayMeasurement_McCutcheonIndex,CElegansChemotaxisAssayMeasurement_MeanVelocity', ...
    struct('CElegansChemotaxisAssayMeasurement_McCutcheonIndex', 0.42, ...
           'CElegansChemotaxisAssayMeasurement_MeanVelocity', 0.13));
row.depends_on = struct('name', 'document_id', 'value', 'subj_babu');
v1 = {row};
mig = { ...
    migratedDoc('row_babu', 'sess_babu', 'ontology_table_row'), ...
    migratedSubject('subj_babu', 'sess_babu', 'worm_01')};
end

function [v1, mig] = haleyWorm()
% ROUTE 2. +setup/+conv/+haley/doImport.m:351 --
% wormTable(:,{'wormID','subjectName','subject_id'}); the dictionary maps
% subject_id -> "EMPTY:subject document identifier" -> SubjectDocumentIdentifier.
row = v1Row('row_worm', 'sess_jh', ...
    'SubjectIdentifier,SubjectLocalIdentifier,SubjectDocumentIdentifier', ...
    struct('SubjectIdentifier', '1017', ...
           'SubjectLocalIdentifier', 'worm_1017@haley', ...
           'SubjectDocumentIdentifier', 'subj_worm'));
row.depends_on = struct('name', 'document_id', 'value', '');
v1 = {row};
mig = { ...
    migratedDoc('row_worm', 'sess_jh', 'ontology_table_row'), ...
    migratedSubject('subj_worm', 'sess_jh', 'worm_1017@haley')};
end

function [v1, mig] = haleyPlate()
% A row that describes a bacterial PLATE. +setup/+conv/+haley/doImport.m:196
% -- expID / assayPhase / plateID / exclude / OD600 label / peptone flag /
% bacteriaStrain. There is no subject here and there must not be one.
row = v1Row('row_plate', 'sess_jh', ...
    'ExperimentSessionIdentifier,BacterialPlateIdentifier,BacterialStrainDocumentIdentifier,BacterialOD600Label', ...
    struct('ExperimentSessionIdentifier', 'exp01', ...
           'BacterialPlateIdentifier', '0901', ...
           'BacterialStrainDocumentIdentifier', 'strain_op50', ...
           'BacterialOD600Label', '10.00'));
row.depends_on = struct('name', 'document_id', 'value', '');
v1 = {row};
% A subject IS present in the batch -- the row simply does not name it.
mig = { ...
    migratedDoc('row_plate', 'sess_jh', 'ontology_table_row'), ...
    migratedDoc('strain_op50', 'sess_jh', 'strain'), ...
    migratedSubject('subj_unrelated', 'sess_jh', 'worm_9999@haley')};
end

function [v1, mig] = dabrowskaRow()
% ROUTE 3. +setup/+conv/+dabrowska/doImport.m:442 -- no dependencyVariable, and
% the dictionary's only subject column is
% "SubjectString": "EMPTY:Subject local identifier". The string is the
% subjectName subjectMaker.m:258 wrote as subject.local_identifier.
lid = 'A123_1@dabrowska-lab.rosalindfranklin.edu';
row = v1Row('row_dab', 'sess_dab', ...
    'SubjectLocalIdentifier,ElevatedPlusMaze_OpenArmTotalEntries,ElevatedPlusMaze_OpenArmTotalTime', ...
    struct('SubjectLocalIdentifier', lid, ...
           'ElevatedPlusMaze_OpenArmTotalEntries', 7, ...
           'ElevatedPlusMaze_OpenArmTotalTime', 42.5));
row.depends_on = struct('name', 'document_id', 'value', '');
v1 = {row};
mig = { ...
    migratedDoc('row_dab', 'sess_dab', 'ontology_table_row'), ...
    migratedSubject('subj_dab', 'sess_dab', lid)};
end

function [v1, mig] = mixedCorpus()
% One of each, so the accounting invariant is exercised across routes.
[v1a, miga] = babuRow();
[v1b, migb] = haleyWorm();
[v1c, migc] = haleyPlate();
[v1d, migd] = dabrowskaRow();
v1  = [v1a,  v1b,  v1c,  v1d];
mig = [miga, migb, migc, migd];
end

% ===================== fixture builders ==================================

function b = v1Row(id, sessionId, variableNames, data)
% A did_v1 ontologyTableRow body, in the template's own shape:
%   git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyTableRow.json
b = struct();
b.document_class = struct('class_name', 'ontologyTableRow', ...
    'class_version', '1', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1'}));
b.depends_on = struct('name', 'document_id', 'value', '');
b.base = struct('id', id, 'session_id', sessionId, ...
    'name', 'ontologyTableRow', 'datestamp', '2024-01-01T00:00:00.000Z');
b.ontologyTableRow = struct( ...
    'names', variableNames, ...
    'variableNames', variableNames, ...
    'ontologyNodes', variableNames, ...
    'data', data);
end

function s = migratedDoc(id, sessionId, className)
s = struct();
s.document_class = struct('class_name', className, 'class_version', '1.0.0', ...
    'superclasses', struct('class_name', {'base'}, 'class_version', {'1.0.0'}), ...
    'schema_version', 'V_eta');
s.depends_on = struct('name', {}, 'document_id', {});
s.base = struct('id', id, 'session_id', sessionId, ...
    'name', className, 'datestamp', '2024-01-01T00:00:00.000Z');
end

function s = migratedSubject(id, sessionId, localId)
s = migratedDoc(id, sessionId, 'subject');
s.subject = struct('local_identifier', localId, 'description', '');
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
    if isfield(d, 'document_id') && ~isempty(d.document_id)
        v = char(d.document_id);
    elseif isfield(d, 'value') && ~isempty(d.value)
        v = char(d.value);
    end
    return;
end
end
