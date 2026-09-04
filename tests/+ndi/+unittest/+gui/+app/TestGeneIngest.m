classdef TestGeneIngest < matlab.unittest.TestCase
    % TestGeneIngest - the model behind ndi.gui.app.GeneIngest.
    %
    % Everything asserted here runs with NO FIGURE. The app is built with
    % build=false and only its static, pure methods are exercised, so a
    % failure names a decision rather than a widget, and the suite runs on
    % a headless box.
    %
    % The assertions concentrate on the two things that would go wrong
    % quietly: a delete that silently orphans documents beneath a pyramid,
    % and a confirmation screen that presents an INFERENCE as though it
    % were a fact.

    properties
        session
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
            ndi.fun.doc.gene.makePyramid(testCase.session, 1, 1, 0, 1, gl, ...
                'subjectID', '', 'binSizes', 1, 'grid', 1, 'label', 'bare');
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

    end

    methods (Access = private)
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
            meta.labelColumns = struct( ...
                'name', {'leiden', 'subclass_nn_column'}, ...
                'nCategories', {12, 3}, ...
                'isUnsupervisedGuess', {true, false});
        end
    end
end
