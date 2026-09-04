classdef TestLevelTools < matlab.unittest.TestCase
    % TestLevelTools - tests for levelTable, chooseLevel and readViewportBase.
    %
    % These three exist so a viewer does not have to know how the ladder is
    % split across two document types, nor how to convert a rectangle from
    % the coordinates the data was acquired in to the bins of one level.
    % The assertions therefore concentrate on the two places that silently
    % go wrong: the join across documents, and the rounding at the edges.
    %
    % The fixture deliberately uses a non-zero origin and a non-square
    % extent, so a function that forgets to subtract the origin, or that
    % transposes width and height, fails rather than coincidentally agrees.

    properties
        testDir
        session
        subjectID
        pyr
        geneList
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            testCase.testDir = fullfile(fixture.Folder, 'gene_leveltools');
            if ~isfolder(testCase.testDir), mkdir(testCase.testDir); end
            ndi.test.helper.initializeMksqliteNoOutput()
            testCase.session = ndi.session.dir('gene_lt', testCase.testDir);

            sub = ndi.document('subject', 'base.session_id', testCase.session.id(), ...
                'subject.local_identifier', 'leveltools_subject@vhlab');
            testCase.session.database_add(sub);
            testCase.subjectID = sub.id();

            ids = arrayfun(@(k) sprintf('ENSL%04d',k), 1:4, 'UniformOutput', false);
            testCase.geneList = ndi.fun.doc.gene.makeGeneList(testCase.session, ...
                ids, {'a','b','c','d'});

            % Origin away from zero, and an extent that is wider than tall,
            % so an origin-blind or transposing implementation cannot pass.
            ox = 1000; oy = 2000;
            x = [ox+0; ox+5; ox+30; ox+31];
            y = [oy+0; oy+3; oy+10; oy+11];
            gi = [0; 1; 2; 3];
            c  = [2; 3; 5; 7];
            [testCase.pyr, ~] = ndi.fun.doc.gene.makePyramid(testCase.session, ...
                x, y, gi, c, testCase.geneList, 'binSizes', [1 2 4], 'grid', 2, ...
                'basePixelSize', [0.5 0.5], 'subjectID', testCase.subjectID);
        end
    end

    methods (Test)

        % ---------------- levelTable ----------------

        function testLevelTableHasOneRowPerLevelFinestFirst(testCase)
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            testCase.verifyEqual(height(T), 3, 'One row per bin size.');
            testCase.verifyEqual(T.binSize(:)', [1 2 4], ...
                'Levels must come back finest first.');
        end

        function testLevelTableJoinsBothDocuments(testCase)
            % The point of the function: geometry from the tiles documents
            % and the frame from the pyramid document, in one place.
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            p = testCase.pyr.document_properties.spatialGeneExpressionPyramid;

            testCase.verifyEqual(T.tileRows(:)', repmat(p.tile_rows,1,3), ...
                'Grid is constant across levels and comes from the pyramid doc.');
            testCase.verifyEqual(T.levelWidth(1), p.extent_x, ...
                'The finest level spans the full extent.');
            testCase.verifyEqual(T.levelHeight(1), p.extent_y);

            u = T.Properties.UserData;
            testCase.verifyEqual(u.originX, p.origin_x);
            testCase.verifyEqual(u.originY, p.origin_y);
            testCase.verifyEqual(u.extentX, p.extent_x);
            testCase.verifyEqual(u.extentY, p.extent_y);
        end

        function testLevelTableCoarserLevelsShrink(testCase)
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            testCase.verifyTrue(all(diff(T.levelWidth) <= 0), ...
                'Level width must not grow as bin size grows.');
            testCase.verifyTrue(all(diff(T.levelHeight) <= 0));
            testCase.verifyTrue(all(T.nTilesStored <= T.nTilesGrid), ...
                'A level cannot store more tiles than its grid holds.');
        end

        % ---------------- chooseLevel ----------------

        function testChooseLevelPicksCoarsestThatMeetsTarget(testCase)
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            rect = [1000 2000 32 16];      % 32 wide in source units

            % 32 source units across: bin1 gives 32 px, bin2 gives 16, bin4 gives 8.
            testCase.verifyEqual(ndi.fun.doc.gene.chooseLevel(T, rect, 32), 1);
            testCase.verifyEqual(ndi.fun.doc.gene.chooseLevel(T, rect, 16), 2);
            testCase.verifyEqual(ndi.fun.doc.gene.chooseLevel(T, rect, 8), 4);
        end

        function testChooseLevelReportsWhenItCannotMeetTheTarget(testCase)
            % Asking for more detail than exists is a legitimate request
            % with a definite answer, so it returns the finest level and
            % says it fell short rather than erroring.
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            [b, info] = ndi.fun.doc.gene.chooseLevel(T, [1000 2000 32 16], 100000);
            testCase.verifyEqual(b, 1, 'Falls back to the finest level.');
            testCase.verifyFalse(info.metTarget, ...
                'The caller must be able to tell the target was missed.');
        end

        function testChooseLevelRejectsAnEmptyRectangle(testCase)
            T = ndi.fun.doc.gene.levelTable(testCase.session, testCase.pyr);
            testCase.verifyError(@() ndi.fun.doc.gene.chooseLevel(T, [0 0 0 10], 16), ...
                'NDI:gene:chooseLevel:emptyRect');
        end

        % ---------------- readViewportBase ----------------

        function testBaseViewportSubtractsTheOrigin(testCase)
            % The whole reason the function exists. A rectangle at the
            % pyramid's own origin must read level pixel 0, not pixel 1000.
            [~, info] = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 1, [1000 2000 8 8], []);
            testCase.verifyEqual(info.rectLevel(1:2), [0 0], ...
                'A rect at the origin must map to level pixel (0,0).');
        end

        function testBaseViewportMatchesReadViewportOnTheSameRegion(testCase)
            % The two must agree where they overlap, or one of them is
            % doing the arithmetic differently.
            rectSource = [1000 2000 8 8];
            a = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 1, rectSource, []);
            b = ndi.fun.doc.gene.readViewport(testCase.session, ...
                testCase.pyr, 1, [0 0 8 8], []);
            testCase.verifyEqual(a, b, ...
                'Base and level viewports must agree on the same region.');
        end

        function testBaseViewportCoversRatherThanClipsTheRequest(testCase)
            % At bin 4, a request starting 2 source units in cannot land on
            % a bin edge. The result must include the requested region, so
            % the low edge floors -- never rounds toward the middle.
            [img, info] = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 4, [1002 2002 8 8], []);
            cov = info.rectSourceCovered;
            testCase.verifyLessThanOrEqual(cov(1), 1002, ...
                'Covered region must start at or before the request.');
            testCase.verifyLessThanOrEqual(cov(2), 2002);
            testCase.verifyGreaterThanOrEqual(cov(1)+cov(3), 1002+8, ...
                'Covered region must end at or after the request.');
            testCase.verifyGreaterThanOrEqual(cov(2)+cov(4), 2002+8);
            testCase.verifyEqual(size(img), [info.rectLevel(4) info.rectLevel(3)], ...
                'Image size must match the level rectangle it reports.');
        end

        function testBaseViewportEmptyRectMeansWholeExtent(testCase)
            [img, info] = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 1, [], []);
            p = testCase.pyr.document_properties.spatialGeneExpressionPyramid;
            testCase.verifyEqual(size(img), [p.extent_y p.extent_x], ...
                'An empty rect must mean the pyramid''s whole extent.');
            testCase.verifyEqual(info.rectSourceCovered(1:2), ...
                [p.origin_x p.origin_y]);
        end

        function testBaseViewportOffTheEdgeIsEmptyNotAnError(testCase)
            % A viewer pans off the edge routinely; that must not throw and
            % must not produce a negative-sized read.
            [img, info] = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 1, [900000 900000 10 10], []);
            testCase.verifyTrue(isempty(img) || all(size(img) == 0), ...
                'A rect entirely off the pyramid returns an empty image.');
            testCase.verifyEqual(info.rectLevel(3:4), [0 0]);
        end

        function testBaseViewportRejectsAnUnknownLevel(testCase)
            testCase.verifyError(@() ndi.fun.doc.gene.readViewportBase( ...
                testCase.session, testCase.pyr, 3, [1000 2000 8 8], []), ...
                'NDI:gene:readViewportBase:noSuchLevel');
        end

        function testBaseViewportConservesCountsAgainstExportRegion(testCase)
            % Reading the whole extent without density must total the same
            % as the raw counts that went in.
            img = ndi.fun.doc.gene.readViewportBase(testCase.session, ...
                testCase.pyr, 1, [], [], 'density', false);
            testCase.verifyEqual(sum(img(:)), 2+3+5+7, 'AbsTol', 1e-9, ...
                'Counts must survive a whole-extent base viewport read.');
        end

    end % methods (Test)
end % classdef
