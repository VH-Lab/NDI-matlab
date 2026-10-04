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
