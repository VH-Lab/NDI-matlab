classdef TestReduceBlocks < matlab.unittest.TestCase
    % TestReduceBlocks - vectorized block reduction for building pyramid levels.
    %
    % Must agree with ndr.format.omezarr.reduce (the per-voxel reference):
    % output i covers inputs (i-1)*f+1 .. i*f, trailing partial block
    % reduced over what it has.

    methods (Test)

        function testMeanMatchesNdrReduce(testCase)
            rng(1);
            a = uint16(randi(65535, [5 7 9]));
            got = ndi.fun.doc.lightsheet.reduceBlocks(a, [2 2 2], 'mean', 'double');
            ref = ndr.format.omezarr.reduce(a, [2 2 2], 'mean');
            testCase.verifyEqual(got, ref, 'AbsTol', 1e-2);
        end

        function testMaxMatchesNdrReduce(testCase)
            rng(2);
            a = uint16(randi(65535, [6 5 3]));
            got = ndi.fun.doc.lightsheet.reduceBlocks(a, [2 2 2], 'max');
            ref = ndr.format.omezarr.reduce(a, [2 2 2], 'max');
            testCase.verifyEqual(got, ref);
            testCase.verifyClass(got, 'uint16');
        end

        function testPartialTrailingBlock(testCase)
            % Length 5, factor 2: blocks of 2, 2 and 1.
            a = uint16([1 3 5 7 9]);
            got = ndi.fun.doc.lightsheet.reduceBlocks(a, [1 2], 'mean', 'double');
            testCase.verifyEqual(got, [2 6 9]);
        end

        function testMeanIntoIntegerRounds(testCase)
            a = uint16([1 2]);
            got = ndi.fun.doc.lightsheet.reduceBlocks(a, [1 2], 'mean');
            testCase.verifyEqual(got, uint16(2));   % 1.5 rounds to 2
        end

        function testTrailingSingletonAxesInFiveD(testCase)
            % t, c, z, y, x with a singleton x: factor entries for every axis.
            a = reshape(uint16(1:16), [1 2 4 2 1]);
            got = ndi.fun.doc.lightsheet.reduceBlocks(a, [1 1 2 2 2], 'max');
            testCase.verifyEqual(size(got, 1:5), [1 2 2 1 1]);
            ref = ndr.format.omezarr.reduce(a, [1 1 2 2], 'max');
            testCase.verifyEqual(got(:), ref(:));
        end

        function testFactorOneIsIdentity(testCase)
            a = uint16(magic(4));
            testCase.verifyEqual(ndi.fun.doc.lightsheet.reduceBlocks(a, [1 1], 'mean'), a);
        end
    end
end
