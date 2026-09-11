classdef TestChooseTileShape < matlab.unittest.TestCase
    % TestChooseTileShape - byte-budgeted chunk sizer.
    %
    % Verifies chooseTileShape hits a byte budget with tiles that are
    % isotropic in world space, clamps to level shape at coarse levels,
    % keeps non-spatial axes at 1, and falls back gracefully when voxel
    % size is missing.

    methods (Test)

        function testIsotropicUint16HitsBudget(testCase)
            % 8 MB uncompressed, uint16, isotropic 1 um -> ~161^3.
            budget = 8 * 2^20;
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', budget);
            testCase.verifyEqual(numel(c), 3);
            % Each side within 5% of the cube root of voxelsPerTile.
            expectedSide = (budget / 2)^(1/3);
            testCase.verifyLessThan(abs(c(1) - expectedSide) / expectedSide, 0.05);
            testCase.verifyEqual(c(1), c(2));
            testCase.verifyEqual(c(2), c(3));
            % Bytes within 20% of the budget.
            bytes = prod(c) * 2;
            testCase.verifyGreaterThan(bytes, 0.8 * budget);
            testCase.verifyLessThan(bytes, 1.2 * budget);
        end

        function testAnisotropicVoxelProducesWorldCube(testCase)
            % 1 um XY, 5 um Z -> chunk_z * 5 == chunk_x * 1 (approx).
            budget = 8 * 2^20;
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [5 1 1], 'uint16', budget);
            worldZ = c(1) * 5;
            worldY = c(2) * 1;
            worldX = c(3) * 1;
            testCase.verifyLessThan(abs(worldZ - worldY) / worldY, 0.05);
            testCase.verifyLessThan(abs(worldX - worldY) / worldY, 0.05);
            testCase.verifyLessThan(c(1), c(2));  % thin Z
            % Bytes still near budget.
            bytes = prod(c) * 2;
            testCase.verifyGreaterThan(bytes, 0.7 * budget);
            testCase.verifyLessThan(bytes, 1.3 * budget);
        end

        function testChannelAxisStaysOne(testCase)
            % 4D czyx: c is not spatial and must stay 1.
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [3 1200 2000 2000], 'czyx', [1 1 1 1], 'uint16', 8 * 2^20);
            testCase.verifyEqual(c(1), 1);
            testCase.verifyGreaterThan(c(2), 1);
        end

        function testTimeAxisStaysOne(testCase)
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [10 3 1200 2000 2000], 'tczyx', [1 1 1 1 1], 'uint16', 8 * 2^20);
            testCase.verifyEqual(c(1), 1);
            testCase.verifyEqual(c(2), 1);
        end

        function testClampToShapeAtCoarseLevel(testCase)
            % A level whose spatial shape is already smaller than a
            % naive cube: one whole chunk, no larger than the shape.
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [32 32 32], 'zyx', [1 1 1], 'uint16', 8 * 2^20);
            testCase.verifyEqual(c, [32 32 32]);
        end

        function testUint8BudgetGivesLargerTile(testCase)
            % Halving bytes-per-voxel doubles voxel count.
            budget = 8 * 2^20;
            c16 = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', budget);
            c8 = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint8', budget);
            testCase.verifyGreaterThan(prod(c8), prod(c16));
            % Ratio approx 2 (uint16 half the voxels of uint8).
            testCase.verifyLessThan(abs(prod(c8) / prod(c16) - 2) / 2, 0.1);
        end

        function testFloat32BudgetGivesSmallerTile(testCase)
            budget = 8 * 2^20;
            c16 = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', budget);
            cf = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'float32', budget);
            testCase.verifyLessThan(prod(cf), prod(c16));
        end

        function testNumpyDtypeStringWorks(testCase)
            % Endian-prefixed forms ('<u2', '>f4') should be accepted.
            budget = 8 * 2^20;
            cA = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], '<u2', budget);
            cB = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', budget);
            testCase.verifyEqual(cA, cB);
        end

        function testMissingVoxelSizeFallsBack(testCase)
            % Zeros on spatial axes -> isotropic voxel-space fallback.
            budget = 8 * 2^20;
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [0 0 0], 'uint16', budget);
            % Fell back to iso -> cube of ~161.
            expectedSide = (budget / 2)^(1/3);
            testCase.verifyLessThan(abs(c(1) - expectedSide) / expectedSide, 0.05);
            testCase.verifyEqual(c(1), c(2));
            testCase.verifyEqual(c(2), c(3));
        end

        function testBudgetScales(testCase)
            % Doubling the budget doubles the voxel count.
            small = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', 4 * 2^20);
            big = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [1200 2000 2000], 'zyx', [1 1 1], 'uint16', 8 * 2^20);
            testCase.verifyLessThan(abs(prod(big) / prod(small) - 2) / 2, 0.1);
        end

        function testRedistributionWhenOneAxisClamps(testCase)
            % Level whose Z is very short but XY is huge: Z clamps and
            % the budget should shift into XY rather than being wasted.
            budget = 8 * 2^20;
            c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                [8 4096 4096], 'zyx', [1 1 1], 'uint16', budget);
            testCase.verifyEqual(c(1), 8);  % Z clamped to shape
            bytes = prod(c) * 2;
            % After redistribution should be near budget rather than at
            % the naive isotropic-cube figure (which would leave a lot
            % on the table when Z is short).
            testCase.verifyGreaterThan(bytes, 0.7 * budget);
            testCase.verifyLessThan(bytes, 1.3 * budget);
        end

        function testTileCountMonotonicallyDecreasesAcrossLadder(testCase)
            % Across a dyadic ladder each level halves shape and
            % doubles voxel size, so chunk-in-voxels stays constant and
            % chunk_grid drops by 2 per axis -> 8x fewer tiles per
            % level for a 3D pyramid. Codified because a future
            % refactor that dropped voxel-size scaling would break it
            % silently.
            budget = 8 * 2^20;
            shape0 = [1200 2000 2000];
            vox0 = [1 1 1];
            tileCounts = zeros(1, 5);
            byteSizes = zeros(1, 5);
            for L = 0:4
                shp = max(1, floor(shape0 / 2^L));
                vs = vox0 * 2^L;
                c = ndi.fun.doc.lightsheet.chooseTileShape( ...
                    shp, 'zyx', vs, 'uint16', budget);
                tileCounts(L+1) = prod(ceil(shp ./ c));
                byteSizes(L+1) = prod(c) * 2;
            end
            % Strictly non-increasing.
            testCase.verifyEqual(tileCounts, sort(tileCounts, 'descend'));
            % Every level's per-tile bytes at or below the budget
            % (coarse levels may fall well below when clamped, but no
            % level oversizes).
            testCase.verifyLessThanOrEqual(byteSizes, 1.3 * budget);
            % Coarsest level should be one tile.
            testCase.verifyEqual(tileCounts(end), 1);
        end

        function testShapeAxesLengthMismatchErrors(testCase)
            testCase.verifyError( ...
                @() ndi.fun.doc.lightsheet.chooseTileShape( ...
                    [1200 2000 2000], 'yx', [1 1 1], 'uint16', 8 * 2^20), ...
                'NDI:lightsheet:chooseTileShape:axesShapeMismatch');
        end

    end
end
