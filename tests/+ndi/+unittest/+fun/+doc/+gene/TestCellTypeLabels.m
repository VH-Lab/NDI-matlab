classdef TestCellTypeLabels < matlab.unittest.TestCase
    % TestCellTypeLabels - makeCellTypeLabels.
    %
    % The assertions concentrate on what goes wrong quietly: a labeling
    % shifted against its cells, an unlabeled cell counted as a category,
    % and an unsupervised clustering recorded as though it were a cell
    % type call.

    properties
        session
        cells
    end

    methods (TestMethodSetup)
        function build(testCase)
            d = fullfile(tempname, 'labels');
            mkdir(d);
            testCase.addTeardown(@() rmdir(fileparts(d), 's'));
            S = ndi.session.dir('labels', d);
            sub = ndi.document('subject', ...
                'subject.local_identifier', 'labels@vhlab', ...
                'base.session_id', S.id());
            S.database_add(sub);
            gl = ndi.fun.doc.gene.makeGeneList(S, {'E1','E2'}, {'a','b'});
            pyr = ndi.fun.doc.gene.makePyramid(S, [1000;1005], [2000;2003], ...
                [0;1], [2;3], gl, 'subjectID', sub.id(), ...
                'binSizes', 1, 'grid', 1);
            testCase.session = S;
            testCase.cells = ndi.fun.doc.gene.makeCells(S, ...
                {'c0','c1','c2','c3'}, [1000;1002;1004;1006], ...
                [2000;2001;2002;2003], pyr);
        end
    end

    methods (Test)

        function testCountsAreComputedNotSupplied(testCase)
            d = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'Pvalb','L2/3 IT','Pvalb',''}, testCase.cells, ...
                'isUnsupervised', false);
            p = d.document_properties.cellTypeLabels;
            testCase.verifyEqual(p.n_cells, 4);
            % Two distinct categories; the empty string is UNLABELED, not a third.
            testCase.verifyEqual(p.n_categories, 2);
            testCase.verifyEqual(p.n_unlabeled, 1);
        end

        function testUnlabeledIsAStateNotAnError(testCase)
            % A labeling covering a quarter of the cells is legitimate.
            d = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'','','Astro',''}, testCase.cells);
            p = d.document_properties.cellTypeLabels;
            testCase.verifyEqual(p.n_unlabeled, 3);
            testCase.verifyEqual(p.n_categories, 1);
        end

        function testIsUnsupervisedDefaultsToTheSaferAssumption(testCase)
            % Default is "do not read biology into it".
            d = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'0','1','0','2'}, testCase.cells);
            testCase.verifyEqual(d.document_properties.cellTypeLabels.is_unsupervised, 1);
        end

        function testACellTypeCallMustSaySo(testCase)
            d = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'Pvalb','Astro','Pvalb','Astro'}, testCase.cells, ...
                'isUnsupervised', false, ...
                'labelName', 'subclass_nn_column', ...
                'taxonomyLevel', 'subclass', ...
                'assignmentMethod', 'nearest neighbour from dissociated atlas');
            p = d.document_properties.cellTypeLabels;
            testCase.verifyEqual(p.is_unsupervised, 0);
            testCase.verifyEqual(p.label_name, 'subclass_nn_column');
            testCase.verifyEqual(p.taxonomy_level, 'subclass');
            testCase.verifyTrue(contains(p.assignment_method, 'nearest neighbour'));
        end

        function testLengthMismatchIsRefused(testCase)
            % A shifted labeling gives every cell its neighbour's type.
            testCase.verifyError(@() ndi.fun.doc.gene.makeCellTypeLabels( ...
                testCase.session, {'a','b','c'}, testCase.cells), ...
                'NDI:gene:makeCellTypeLabels:length');
        end

        function testEmptyLabelsRefused(testCase)
            testCase.verifyError(@() ndi.fun.doc.gene.makeCellTypeLabels( ...
                testCase.session, {}, testCase.cells), ...
                'NDI:gene:makeCellTypeLabels:empty');
        end

        function testDependsOnTheCellsDocument(testCase)
            d = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'a','b','a','b'}, testCase.cells);
            testCase.verifyEqual(d.dependency_value('cells_document_id'), ...
                testCase.cells.id());
        end

        function testSeveralLabelingsCoexistOnOneSegmentation(testCase)
            % The reason labels are their own document.
            atlas = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'Pvalb','Astro','Pvalb','Astro'}, testCase.cells, ...
                'isUnsupervised', false, 'labelName', 'subclass_nn_column');
            leiden = ndi.fun.doc.gene.makeCellTypeLabels(testCase.session, ...
                {'0','1','0','2'}, testCase.cells, 'labelName', 'leiden_res1.0');
            testCase.verifyNotEqual(atlas.id(), leiden.id());
            testCase.verifyEqual(atlas.dependency_value('cells_document_id'), ...
                testCase.cells.id());
            testCase.verifyEqual(leiden.dependency_value('cells_document_id'), ...
                testCase.cells.id());
            testCase.verifyEqual( ...
                atlas.document_properties.cellTypeLabels.is_unsupervised, 0);
            testCase.verifyEqual( ...
                leiden.document_properties.cellTypeLabels.is_unsupervised, 1);
        end

    end
end
