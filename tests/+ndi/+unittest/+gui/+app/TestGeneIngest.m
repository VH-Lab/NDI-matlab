classdef TestGeneIngest < matlab.unittest.TestCase
    % TestGeneIngest - the model behind ndi.gui.app.GeneIngest.
    %
    % Everything asserted here runs with NO FIGURE. The app is built with
    % build=false and only its static, pure methods are exercised, so a
    % failure names a decision rather than a widget, and the suite runs on
    % a headless box.
    %
    % The assertions concentrate on the three things that would go wrong
    % quietly: a delete that silently orphans documents beneath a pyramid,
    % a confirmation screen that presents an INFERENCE as though it were a
    % fact, and an ingest that gets far enough to spend minutes reading
    % before discovering it cannot finish.
    %
    % ingestPlan is the reason this class can test the ingest path at all.
    % It is pure -- no session, no file, no database -- so every refusal
    % and every warning is reachable from two structs, and the slow part
    % stays behind runIngest where a headless suite need not go.

    properties
        session
        subjectID
        pyr
        cells
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'ingest');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('ingest', d);
            sub = ndi.document('subject', ...
                'subject.local_identifier', 'ingest@vhlab', ...
                'base.session_id', S.id());
            S.database_add(sub);
            testCase.subjectID = sub.id();
            gl = ndi.fun.doc.gene.makeGeneList(S, {'E1','E2'}, {'a','b'});
            testCase.pyr = ndi.fun.doc.gene.makePyramid(S, [1000;1005], [2000;2003], ...
                [0;1], [2;3], gl, 'subjectID', sub.id(), ...
                'binSizes', [1 2], 'grid', 1, 'label', 'opossum s1');
            testCase.cells = ndi.fun.doc.gene.makeCells(S, {'c0','c1'}, ...
                [1000;1002], [2000;2001], testCase.pyr);
            ndi.fun.doc.gene.makeCellTypeLabels(S, {'Pvalb','Astro'}, ...
                testCase.cells, 'isUnsupervised', false, ...
                'labelName', 'subclass_nn_column');
            ndi.fun.doc.gene.makeCellTypeLabels(S, {'0','1'}, testCase.cells, ...
                'labelName', 'leiden_res1.0');
            testCase.session = S;
        end
    end

    methods (Test)

        function testBuildsWithoutAFigure(testCase)
            % The model must construct headlessly, or none of the rest of
            % this class could run in CI.
            app = ndi.gui.app.GeneIngest(testCase.session, 'build', false);
            testCase.verifyClass(app, 'ndi.gui.app.GeneIngest');
        end

        function testListsPyramidsWithWhatTheyHave(testCase)
            rows = ndi.gui.app.GeneIngest.pyramidRows(testCase.session);
            testCase.verifyEqual(numel(rows), 1);
            testCase.verifyEqual(rows(1).label, 'opossum s1');
            testCase.verifyEqual(rows(1).nLevels, 2);       % binSizes [1 2]
            testCase.verifyEqual(rows(1).nCells, 1);
            testCase.verifyEqual(rows(1).nLabelSets, 2);
        end

        function testListsWhatAPyramidIsMissing(testCase)
            % The common question is not "what is here" but "what still
            % needs ingesting", and a pyramid with no cells looks exactly
            % like one with cells unless the list distinguishes them.
            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, {'E9'}, {'z'});
            % The subject is REAL here. makePyramid refuses an empty one --
            % the pyramid schema declares subject_id mustbenotempty -- so
            % passing '' never made a bare pyramid, it just errored. What
            % this test is about is a pyramid with no CELLS, which is a
            % different kind of bare.
            ndi.fun.doc.gene.makePyramid(testCase.session, 1, 1, 0, 1, gl, ...
                'subjectID', testCase.subjectID, ...
                'binSizes', 1, 'grid', 1, 'label', 'bare');
            rows = ndi.gui.app.GeneIngest.pyramidRows(testCase.session);
            bare = rows(strcmp({rows.label}, 'bare'));
            testCase.verifyEqual(bare.nCells, 0);
            testCase.verifyEqual(bare.nLabelSets, 0);
        end

        function testDeletionPlanReachesEveryDependent(testCase)
            % A delete that took the pyramid alone would leave the levels,
            % the cells and the labels all pointing at something gone.
            plan = ndi.gui.app.GeneIngest.deletionPlan(testCase.session, testCase.pyr);
            testCase.verifyEqual(numel(plan.tiles), 2);
            testCase.verifyEqual(numel(plan.cells), 1);
            testCase.verifyEqual(numel(plan.labels), 2);
            testCase.verifyEqual(plan.total, 6);    % 1 + 2 + 1 + 2
        end

        function testDeletionPlanReachesLabelsThroughCells(testCase)
            % Labels depend on the CELLS document, not on the pyramid, so
            % reaching them takes a second hop. A plan that queried only
            % the pyramid's dependents would miss them entirely and leave
            % them orphaned.
            plan = ndi.gui.app.GeneIngest.deletionPlan(testCase.session, testCase.pyr);
            names = cell(numel(plan.labels),1);
            for i = 1:numel(plan.labels)
                names{i} = plan.labels{i}.document_properties.cellTypeLabels.label_name;
            end
            testCase.verifyTrue(ismember('subclass_nn_column', names));
            testCase.verifyTrue(ismember('leiden_res1.0', names));
        end

        function testDeletionMessageNamesTheCounts(testCase)
            plan = ndi.gui.app.GeneIngest.deletionPlan(testCase.session, testCase.pyr);
            msg = ndi.gui.app.GeneIngest.deletionMessage(plan);
            testCase.verifyTrue(contains(msg, '6 document'));
            testCase.verifyTrue(contains(msg, '2 level'));
            testCase.verifyTrue(contains(msg, '2 label set'));
            testCase.verifyTrue(contains(msg, 'cannot be undone'));
        end

        function testContourFindingsCarryTheirEvidence(testCase)
            % The screen must show the inference AND the numbers behind it.
            % "centroid-relative" alone is an assertion; with the ratio and
            % the threshold it is a claim a human can check.
            meta = testCase.fakeCellbinMeta();
            items = ndi.gui.app.GeneIngest.contourFindings(meta);
            ref = items(strcmp({items.name}, 'Contour reference'));
            testCase.verifyEqual(ref.value, 'centroid');
            testCase.verifyTrue(contains(ref.evidence, '0.00019'));
            testCase.verifyTrue(contains(ref.evidence, 'detected'));
            testCase.verifyTrue(ref.overridable);
        end

        function testContourFindingsReportAbsence(testCase)
            meta = struct('contoursPresent', false);
            items = ndi.gui.app.GeneIngest.contourFindings(meta);
            testCase.verifyEqual(items(1).value, 'absent');
            testCase.verifyFalse(items(1).overridable);
        end

        function testLabelFindingsDistinguishTheTwoKinds(testCase)
            % The scientific point of the whole screen. A clustering and a
            % transferred cell type call look identical in a legend, so the
            % difference has to be stated where a human will read it.
            meta = testCase.fakeCellbinMeta();
            items = ndi.gui.app.GeneIngest.labelFindings(meta);
            testCase.verifyEqual(numel(items), 2);

            leiden = items(strcmp({items.name}, 'leiden'));
            testCase.verifyTrue(leiden.isUnsupervisedGuess);
            testCase.verifyTrue(contains(leiden.warning, 'not a cell type'));

            atlas = items(strcmp({items.name}, 'subclass_nn_column'));
            testCase.verifyFalse(atlas.isUnsupervisedGuess);
            testCase.verifyTrue(contains(atlas.warning, 'inference'));
        end

        function testGefSummaryReportsWhereTheExtentCameFrom(testCase)
            % Whether the extent came from the file's own attributes or was
            % derived from the data is exactly the kind of thing that is
            % invisible unless it is printed.
            meta = struct('nRecords', 120966551, 'box', [0 0 26459 26459], ...
                'chipSerial', 'SS200000135TL_D1', 'resolutionNm', 500, ...
                'root', '/geneExp/bin1', 'boxSource', 'attrs at /geneExp/bin1');
            s = ndi.gui.app.GeneIngest.summarizeGef(meta, cell(30434,1));
            testCase.verifyTrue(contains(s, '30434 genes'));
            testCase.verifyTrue(contains(s, '120,966,551'));
            testCase.verifyTrue(contains(s, '26460 x 26460'));
            testCase.verifyTrue(contains(s, 'attrs at /geneExp/bin1'));
        end

        function testGefSummarySaysWhenTheExtentIsNotYetKnown(testCase)
            % A probe reads no records, so a file with no extent attributes
            % has no extent yet -- readGEF returns an empty box. Printing
            % that as an extent would have indexed past the end of an empty
            % array; printing nothing would have looked like a 0x0 section.
            meta = struct('nRecords', 5, 'box', [], 'chipSerial', '', ...
                'resolutionNm', 500, 'root', '/geneExp/bin1', ...
                'boxSource', 'unknown (no attributes found and no records read)');
            s = ndi.gui.app.GeneIngest.summarizeGef(meta, {'E1'});
            testCase.verifyTrue(contains(s, 'not yet known'));
            testCase.verifyTrue(contains(s, '(none)'));    % no chip serial
        end

        % =============================================================
        % ingestPlan: refusals reached in milliseconds, not after the read
        % =============================================================

        function testPlanRefusesWithoutASubject(testCase)
            % The pyramid document declares subject_id mustbenotempty, and
            % the .gef records a chip rather than an animal. Discovering
            % this after the read would waste minutes and produce nothing.
            c = testCase.baseChoices();
            c.subjectID = '';
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1','E2'}, [], c);
            testCase.verifyEmpty(plan.steps);
            testCase.verifyTrue(any(contains(plan.errors, 'subject')));
        end

        function testPlanCollectsEveryErrorNotJustTheFirst(testCase)
            % A dialog that reports one problem per attempt turns a
            % two-field mistake into two rounds.
            c = testCase.baseChoices();
            c.subjectID = '';
            c.binSizes = [2 2 4];
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], c);
            testCase.verifyGreaterThanOrEqual(numel(plan.errors), 2);
        end

        function testPlanRefusesLabelsWithoutCells(testCase)
            % cellTypeLabels depends on the cells it labels; without them
            % the document cannot exist.
            c = testCase.baseChoices();
            c.importCells = false;
            c.labelSelections = struct('name','leiden','isUnsupervised',true);
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, testCase.fakeCellbinMeta(), c);
            testCase.verifyTrue(any(contains(plan.errors, 'cells were not')));
        end

        function testPlanRefusesALabelingTheFileDoesNotHave(testCase)
            c = testCase.baseChoices();
            c.importCells = true;
            c.labelSelections = struct('name','not_a_column','isUnsupervised',false);
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, testCase.fakeCellbinMeta(), c);
            testCase.verifyTrue(any(contains(plan.errors, 'not_a_column')));
        end

        function testPlanRefusesCellsWithNoCellbinFile(testCase)
            c = testCase.baseChoices();
            c.importCells = true;
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], c);
            testCase.verifyTrue(any(contains(plan.errors, 'no cellbin')));
        end

        function testPlanOrdersStepsByDependency(testCase)
            % The pyramid indexes the gene list, the cells are positioned
            % against the pyramid, and the labels name the cells. Any other
            % order creates a document whose dependency does not exist yet.
            c = testCase.baseChoices();
            c.importCells = true;
            c.labelSelections = struct( ...
                'name', {'leiden','subclass_nn_column'}, ...
                'isUnsupervised', {true, false});
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1','E2'}, testCase.fakeCellbinMeta(), c);
            testCase.verifyEmpty(plan.errors);
            testCase.verifyEqual({plan.steps.kind}, ...
                {'geneList','pyramid','cells','labels','labels'});
        end

        function testPlanWithoutCellbinStopsAtThePyramid(testCase)
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], testCase.baseChoices());
            testCase.verifyEqual({plan.steps.kind}, {'geneList','pyramid'});
        end

        function testPlanWarnsWhenGenesAreBeingLeftBehind(testCase)
            % maxGenes trims silently: the pyramid is missing genes and
            % nothing in it records that.
            meta = testCase.fakeGefMeta();
            meta.nGenesInFile = 30434;
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                meta, {'E1','E2'}, [], testCase.baseChoices());
            testCase.verifyTrue(any(contains(plan.warnings, '30434')));
        end

        function testPlanWarnsWhenAssemblyIsMissing(testCase)
            % Counts are not reproducible without the annotation they were
            % made against, and it cannot be recovered from the .gef.
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], testCase.baseChoices());
            testCase.verifyTrue(any(contains(plan.warnings, 'assembly')));
        end

        function testPlanWarnsWhenALabelingIsTakenAsACellTypeCall(testCase)
            % Storing a clustering as a cell type call is a scientific
            % error rather than a display one, so the choice is stated back.
            c = testCase.baseChoices();
            c.importCells = true;
            c.labelSelections = struct('name','subclass_nn_column', ...
                'isUnsupervised', false);
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, testCase.fakeCellbinMeta(), c);
            testCase.verifyEmpty(plan.errors);
            testCase.verifyTrue(any(contains(plan.warnings, 'scientific error')));
        end

        function testPlanWarnsWhenNoFullResolutionLevelIsStored(testCase)
            c = testCase.baseChoices();
            c.binSizes = [2 4 8];
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], c);
            testCase.verifyEmpty(plan.errors);        % legal, not fatal
            testCase.verifyTrue(any(contains(plan.warnings, 'full-resolution')));
        end

        function testPlanWarnsWhenTheExtentIsUnvalidated(testCase)
            meta = testCase.fakeGefMeta();
            meta.boxSource = 'attrs at /geneExp/bin1 (unvalidated: no records read)';
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                meta, {'E1'}, [], testCase.baseChoices());
            testCase.verifyTrue(any(contains(plan.warnings, 'no records have been checked')));
        end

        function testChoicesConvertResolutionToMicrometres(testCase)
            % The GEF's resolution attribute is in NANOMETRES and
            % basePixelSize is in micrometres. SAW's usual 500 nm becomes
            % 0.5, which is also makePyramid's default -- so getting this
            % wrong on a 500 nm chip looks exactly like the default.
            meta = testCase.fakeGefMeta();
            meta.resolutionNm = 715;
            c = ndi.gui.app.GeneIngest.ingestChoices(meta, []);
            testCase.verifyEqual(c.basePixelSize, [0.715 0.715]);
        end

        function testChoicesNeverGuessASubject(testCase)
            % A .gef records a chip, not an animal. Guessing would attach a
            % section to the wrong subject in a way nothing could detect.
            c = ndi.gui.app.GeneIngest.ingestChoices(testCase.fakeGefMeta(), []);
            testCase.verifyEmpty(c.subjectID);
        end

        function testChoicesPreselectNoLabeling(testCase)
            % The file does not say which labeling is a cell type call and
            % which is a clustering, so preselecting either would be the
            % heuristic this app exists to avoid.
            c = ndi.gui.app.GeneIngest.ingestChoices( ...
                testCase.fakeGefMeta(), testCase.fakeCellbinMeta());
            testCase.verifyTrue(c.importCells);
            testCase.verifyEmpty(c.labelSelections);
        end

        function testIngestMessageNamesTheStepsAndTheWarnings(testCase)
            c = testCase.baseChoices();
            c.importCells = true;
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, testCase.fakeCellbinMeta(), c);
            msg = ndi.gui.app.GeneIngest.ingestMessage(plan);
            testCase.verifyTrue(contains(msg, 'gene list'));
            testCase.verifyTrue(contains(msg, 'pyramid'));
            testCase.verifyTrue(contains(msg, 'cells'));
            testCase.verifyTrue(contains(msg, 'Worth knowing'));
            testCase.verifyTrue(contains(msg, 'takes minutes'));
        end

        function testIngestMessageOnARefusalSaysWhyNotWhatWouldHappen(testCase)
            c = testCase.baseChoices();
            c.subjectID = '';
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], c);
            msg = ndi.gui.app.GeneIngest.ingestMessage(plan);
            testCase.verifyTrue(contains(msg, 'cannot run yet'));
            testCase.verifyFalse(contains(msg, 'This creates'));
        end

        function testRunIngestRefusesAPlanThatDidNotValidate(testCase)
            % The last guard: nothing should reach the read with a plan the
            % pure layer already rejected.
            c = testCase.baseChoices();
            c.subjectID = '';
            plan = ndi.gui.app.GeneIngest.ingestPlan( ...
                testCase.fakeGefMeta(), {'E1'}, [], c);
            testCase.verifyError(@() ndi.gui.app.GeneIngest.runIngest( ...
                testCase.session, 'nofile.gef', '', plan), ...
                'NDI:GeneIngest:planHasErrors');
        end

        function testReadNotesReportClampedCounts(testCase)
            % Only reachable after every record has been read, so it is
            % reported afterwards rather than asked about beforehand. Those
            % pixels read LOW and nothing in the pyramid says so.
            meta = struct('nCountsClamped', 1234567, 'boxSource', 'data');
            notes = ndi.gui.app.GeneIngest.readNotes(meta, {'E1'});
            testCase.verifyTrue(any(contains(notes, '1,234,567')));
            testCase.verifyTrue(any(contains(notes, 'read low')));
        end

        function testReadNotesAreQuietWhenNothingIsWrong(testCase)
            meta = struct('nCountsClamped', 0, 'boxSource', 'data');
            notes = ndi.gui.app.GeneIngest.readNotes(meta, {'E1'});
            testCase.verifyEqual(numel(notes), 1);       % just the extent
            testCase.verifyTrue(contains(notes{1}, 'data'));
        end

    end

    methods (Access = private)
        function c = baseChoices(testCase)
            c = ndi.gui.app.GeneIngest.ingestChoices(testCase.fakeGefMeta(), []);
            c.subjectID = 'a_subject_id';
        end

        function meta = fakeGefMeta(~)
            % Shaped like ndr.format.stereoseq.readGEF's probeOnly meta.
            meta = struct('root', '/geneExp/bin1', ...
                'nGenesInFile', 2, 'nGenes', 2, 'nRecords', 120966551, ...
                'box', [0 0 26459 26459], 'boxSource', 'attrs at /geneExp/bin1', ...
                'resolutionNm', 500, 'chipSerial', 'SS200000135TL_D1', ...
                'nCountsClamped', 0);
        end

        function meta = fakeCellbinMeta(~)
            % Shaped like ndr.format.stereoseq.readCellBin's meta, with the
            % opossum numbers.
            meta = struct();
            meta.contoursPresent = true;
            meta.contourReference = 'centroid';
            meta.contourReferenceSource = 'detected';
            meta.relativeEvidence = struct('realVertexAbsMedian', 4, ...
                'centroidScale', 21500, 'ratio', 0.000186, 'threshold', 0.05);
            meta.padValue = 32767;
            meta.padFraction = 0.67;
            meta.verticesPerCell = [0 24 32];
            meta.raggedVertices = true;
            meta.nCells = 493126;
            meta.labelColumns = struct( ...
                'name', {'leiden', 'subclass_nn_column'}, ...
                'nCategories', {12, 3}, ...
                'isUnsupervisedGuess', {true, false});
        end
    end
end
