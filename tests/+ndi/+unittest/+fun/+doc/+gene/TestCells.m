classdef TestCells < matlab.unittest.TestCase
    % TestCells - tests for makeCells and the contour file pair.
    %
    % The assertions concentrate on the three things that go wrong
    % quietly: an identifier losing precision, a vertex wrapping because
    % it was stored in the wrong frame, and a cell with no contour
    % shifting every later row onto the wrong cell.

    properties
        testDir
        session
        subjectID
        pyr
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            f = testCase.applyFixture(TemporaryFolderFixture);
            testCase.testDir = fullfile(f.Folder, 'gene_cells');
            if ~isfolder(testCase.testDir), mkdir(testCase.testDir); end
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('gene_cells', testCase.testDir);

            sub = ndi.document('subject', 'base.session_id', testCase.session.id(), ...
                'subject.local_identifier', 'cells_subject@vhlab');
            testCase.session.database_add(sub);
            testCase.subjectID = sub.id();

            gl = ndi.fun.doc.gene.makeGeneList(testCase.session, {'E1','E2'}, {'a','b'});
            [testCase.pyr, ~] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                [1000;1005], [2000;2003], [0;1], [2;3], gl, ...
                'binSizes', 1, 'grid', 1, 'subjectID', testCase.subjectID);
        end
    end

    methods (Test)

        function testContoursRoundTripExactly(testCase)
            polys = { [0 0; 3 0; 3 4], [-5 -6; 7 8; 9 10; 11 12] };
            f = [tempname '.bin'];
            info = ndi.fun.doc.gene.writeContourFile(f, polys);
            testCase.verifyEqual(info.nVerticesTotal, 7);
            back = ndi.fun.doc.gene.readContourFile(f);
            testCase.verifyEqual(back{1}, polys{1});
            testCase.verifyEqual(back{2}, polys{2});
        end

        function testACellWithNoContourKeepsItsRow(testCase)
            % Dropping an empty polygon would shift every later cell's
            % contour onto the wrong cell, and nothing downstream would
            % notice.
            polys = { [0 0; 1 1; 2 0], zeros(0,2), [5 5; 6 6; 7 5] };
            f = [tempname '.bin'];
            ndi.fun.doc.gene.writeContourFile(f, polys);
            back = ndi.fun.doc.gene.readContourFile(f);
            testCase.verifyNumElements(back, 3);
            testCase.verifyTrue(isempty(back{2}));
            testCase.verifyEqual(back{3}, polys{3});
        end

        function testAbsoluteCoordinatesAreRefusedNotWrapped(testCase)
            % int16 holds +/-32767. Centroid-relative vertices fit easily;
            % absolute coordinates on a large chip would wrap silently.
            f = [tempname '.bin'];
            testCase.verifyError(@() ndi.fun.doc.gene.writeContourFile(f, ...
                { [40000 5; 40001 6; 40002 7] }), ...
                'NDI:gene:writeContourFile:range');
        end

        function testMakeCellsRoundTripsThroughReadCells(testCase)
            d = ndi.fun.doc.gene.makeCells(testCase.session, ...
                {'10093173156650','10093173156651'}, [1002;1030], [2003;2010], ...
                testCase.pyr, 'segmentationMethod','CellBin 1.0', ...
                'subjectID', testCase.subjectID);
            [T, info] = ndi.fun.doc.gene.readCells(testCase.session, d);
            testCase.verifyEqual(info.nCells, 2);
            testCase.verifyEqual(T.x(:)', [1002 1030]);
            testCase.verifyEqual(info.segmentationMethod, 'CellBin 1.0');
        end

        function testA14DigitIdSurvives(testCase)
            % Why cell_id is text on both sides: as a double it loses
            % precision and stops matching the source file it came from.
            d = ndi.fun.doc.gene.makeCells(testCase.session, ...
                {'10093173156650'}, 1002, 2003, testCase.pyr);
            T = ndi.fun.doc.gene.readCells(testCase.session, d);
            testCase.verifyEqual(T.cellID(1), "10093173156650");
        end

        function testCellIndexIsZeroBased(testCase)
            d = ndi.fun.doc.gene.makeCells(testCase.session, ...
                {'a','b','c'}, [1;2;3], [4;5;6], testCase.pyr);
            T = ndi.fun.doc.gene.readCells(testCase.session, d);
            testCase.verifyEqual(T.cellIndex(:)', [0 1 2]);
        end

        function testContoursAreStoredAndReadable(testCase)
            polys = { [-3 -4; 3 -4; 3 4], [-2 -2; 2 -2; 2 2; -2 2] };
            d = ndi.fun.doc.gene.makeCells(testCase.session, {'a','b'}, ...
                [1002;1030], [2003;2010], testCase.pyr, 'contours', polys);
            [~, info] = ndi.fun.doc.gene.readCells(testCase.session, d);
            testCase.verifyTrue(info.contoursPresent);

            bd = testCase.session.database_openbinarydoc(d, 'contours.bin');
            c = onCleanup(@() testCase.session.database_closebinarydoc(bd));
            back = ndi.fun.doc.gene.readContourFile(bd.fullpathfilename);
            clear c;
            testCase.verifyEqual(back{1}, polys{1});
            testCase.verifyEqual(back{2}, polys{2});
        end

        function testNoContoursLeavesTheFlagDown(testCase)
            d = ndi.fun.doc.gene.makeCells(testCase.session, {'a'}, 1, 2, testCase.pyr);
            [~, info] = ndi.fun.doc.gene.readCells(testCase.session, d);
            testCase.verifyFalse(info.contoursPresent);
        end

        function testMismatchedLengthsAreRefused(testCase)
            testCase.verifyError(@() ndi.fun.doc.gene.makeCells( ...
                testCase.session, {'a','b'}, 1, [2;3], testCase.pyr), ...
                'NDI:gene:makeCells:length');
            testCase.verifyError(@() ndi.fun.doc.gene.makeCells( ...
                testCase.session, {'a','b'}, [1;2], [3;4], testCase.pyr, ...
                'contours', { zeros(3,2) }), ...
                'NDI:gene:makeCells:contourLength');
        end

        function testThePyramidDependencyIsRecorded(testCase)
            % A cell table is meaningless without the frame it is in.
            d = ndi.fun.doc.gene.makeCells(testCase.session, {'a'}, 1, 2, testCase.pyr);
            testCase.verifyEqual(d.dependency_value('spatialGeneExpressionPyramid_id'), ...
                testCase.pyr.id());
        end

    end % methods (Test)
end % classdef
