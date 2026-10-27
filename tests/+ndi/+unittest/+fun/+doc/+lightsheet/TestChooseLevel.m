classdef TestChooseLevel < matlab.unittest.TestCase
    % TestChooseLevel - pure per-axis voxel-size level picker.
    %
    % chooseLevel is called by any reader that wants the coarsest level
    % whose voxel size still meets a target; a viewport at 12 um/pixel
    % has no business decoding a chunk at 0.5 um/pixel. Pure function
    % over the level table, no session needed.

    methods (Static)
        function levels = fourLevelPyramid()
            % A 4-level dyadic ladder at 0.5, 1, 2, 4 um.
            levels(1) = struct('level', 0, 'voxel_size', [0.5 0.5 0.5]);
            levels(2) = struct('level', 1, 'voxel_size', [1.0 1.0 1.0]);
            levels(3) = struct('level', 2, 'voxel_size', [2.0 2.0 2.0]);
            levels(4) = struct('level', 3, 'voxel_size', [4.0 4.0 4.0]);
        end

        function levels = tiedLevels(emptyFirst)
            % Level 0 (two chunks) and two level-1 rows that tie on voxel
            % size: a max level that stores a chunk and a mean level that
            % stores none (a level written with materializeChunks off, or
            % the file-less sampled_body of [compression block and empty
            % levels]). EMPTYFIRST puts the empty one first of the two.
            L0 = struct('level', 0, 'voxel_size', [0.5 0.5 0.5], ...
                'n_chunks_stored', 2, 'id', 'lvl_0');
            Lmax = struct('level', 1, 'voxel_size', [1 1 1], ...
                'n_chunks_stored', 1, 'id', 'lvl_1_max');
            Lmean = struct('level', 1, 'voxel_size', [1 1 1], ...
                'n_chunks_stored', 0, 'id', 'lvl_1_mean');
            if emptyFirst
                levels = [L0, Lmean, Lmax];
            else
                levels = [L0, Lmax, Lmean];
            end
        end

        function t = fourLevelTable()
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            vs = arrayfun(@(l) l.voxel_size, L, 'UniformOutput', false).';
            level = arrayfun(@(l) l.level, L).';
            t = table(level, vs, 'VariableNames', {'level','voxel_size'});
        end
    end

    methods (Test)

        function testScalarTargetPicksCoarsestMeeting(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(L, 2.0);
            % coarsest level with all axes <= 2 um is level 2 (2 um/axis)
            testCase.verifyEqual(idx, 2);
            testCase.verifyEqual(row.voxel_size, [2 2 2]);
        end

        function testScalarTargetPickerBetweenLevels(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            % target 1.5 um: level 1 (1 um) fits, level 2 (2 um) does not
            idx = ndi.fun.doc.lightsheet.chooseLevel(L, 1.5);
            testCase.verifyEqual(idx, 1);
        end

        function testTargetFinerThanEveryLevelReturnsFinest(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            % target 0.1 um: no level meets it; the coarsest that does
            % NOT exist, so bestK stays at the initial finest level.
            idx = ndi.fun.doc.lightsheet.chooseLevel(L, 0.1);
            testCase.verifyEqual(idx, 0);
        end

        function testTargetCoarserThanEveryLevelReturnsCoarsest(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            idx = ndi.fun.doc.lightsheet.chooseLevel(L, 1000);
            testCase.verifyEqual(idx, 3);
        end

        function testPerAxisTarget(testCase)
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            % permitted per-axis: [1, 3, 3] -- level 1 fits (1,1,1),
            % level 2 fails on the first axis (2 > 1).
            idx = ndi.fun.doc.lightsheet.chooseLevel(L, [1 3 3]);
            testCase.verifyEqual(idx, 1);
        end

        function testTableInput(testCase)
            t = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelTable();
            idx = ndi.fun.doc.lightsheet.chooseLevel(t, 2.0);
            testCase.verifyEqual(idx, 2);
        end

        function testTableInputReturnsRowNotStruct(testCase)
            t = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelTable();
            [~, row] = ndi.fun.doc.lightsheet.chooseLevel(t, 2.0);
            testCase.verifyClass(row, 'table');
            testCase.verifyEqual(height(row), 1);
        end

        function testAnEmptyLevelLosesATie(testCase)
            % [chooseLevel skips empty levels] (Jess Haley, 2026-10-26):
            % before it, the tie went to whichever row came last
            for emptyFirst = [false true]
                L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.tiedLevels(emptyFirst);
                [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(L, 4);
                testCase.verifyEqual(idx, 1);
                testCase.verifyEqual(row.id, 'lvl_1_max', ...
                    sprintf('the level that stores bytes (empty level first: %d)', emptyFirst));
            end
        end

        function testAnEmptyLevelLosesATieInATable(testCase)
            % levelTable's shape: voxel_size a cell column
            t = table([0; 1; 1], {[0.5 0.5 0.5]; [1 1 1]; [1 1 1]}, [2; 1; 0], ...
                {'lvl_0'; 'lvl_1_max'; 'lvl_1_mean'}, ...
                'VariableNames', {'level', 'voxel_size', 'n_chunks_stored', 'id'});
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(t, 4);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(row.id{1}, 'lvl_1_max');
        end

        function testAnEmptyLevelIsNeverChosen(testCase)
            % no tie: the only level-1 row stores nothing, so a 4 um target
            % gets level 0, the coarsest level that holds bytes
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.tiedLevels(false);
            L = L([1 3]);
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(L, 4);
            testCase.verifyEqual(idx, 0);
            testCase.verifyEqual(row.id, 'lvl_0');
        end

        function testEveryLevelEmptyChoosesAsBefore(testCase)
            % nothing stores bytes: the choice is made over every level,
            % so the caller still gets a level (and its metadata) back
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.tiedLevels(false);
            [L.n_chunks_stored] = deal(0);
            [idx, row] = ndi.fun.doc.lightsheet.chooseLevel(L, 4);
            testCase.verifyEqual(idx, 1);
            testCase.verifyEqual(row.id, 'lvl_1_mean', 'the last tied row, as before');
        end

        function testEmptyLevelsErrors(testCase)
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.chooseLevel( ...
                    struct('level',{},'voxel_size',{}), 1.0), ...
                'NDI:lightsheet:chooseLevel:emptyLevels');
        end

        function testTargetShorterThanVoxelUsesShorterAxes(testCase)
            % A 3-D level with a scalar target checks every axis; a
            % 3-D level with a 2-D target checks the first two axes
            % only. Documents the behavior that a reader passing a
            % 2-D XY target against a ZYX level compares X and Y and
            % ignores Z.
            L = ndi.unittest.fun.doc.lightsheet.TestChooseLevel.fourLevelPyramid();
            idx = ndi.fun.doc.lightsheet.chooseLevel(L, [2 2]);
            testCase.verifyEqual(idx, 2);
        end
    end
end
