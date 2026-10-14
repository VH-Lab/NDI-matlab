classdef TestHaleyPatchGrid < matlab.unittest.TestCase
%TESTHALEYPATCHGRID Placing detected E. coli patches on the 12-patch grid (decision #80).
%
%   The centres are image 3626's (plate 124, 11 patches detected, measured
%   by Jess 2026-10-14): three rows, rows 1 and 3 aligned, row 2 half a step
%   right, and row 1 column 2 not detected.
%
%   UNVERIFIED: written without MATLAB (the algorithm was checked in a
%   Python port on the same centres); test-import-v2.yml is the first run.

    properties (Constant)
        C11 = [407 1634; 394 631; 678 1133; 972 1635; 1260 1131; 1551 1630; ...
               1565 622; 1829 1118; 2120 1641; 2120 628; 2414 1131]
    end

    methods (Test)
        function testElevenPatchesPlaceWithRowOneColumnTwoMissing(testCase)
            [slot, why] = ndi.setup.conv.haley.matchGridPatches(testCase.C11, 12);
            testCase.verifyEmpty(why);
            testCase.verifyEqual(slot(:)', [2 1 3 5 6 8 7 9 11 10 12]);
            testCase.verifyEqual(setdiff(1:12, slot), 4, 'row 1, column 2');
        end

        function testTwelvePatchesNumberAsAFullImage(testCase)
            % the numbering of decision #62: left to right, then top to bottom
            c = [testCase.C11; 980 630];
            slot = ndi.setup.conv.haley.matchGridPatches(c, 12);
            testCase.verifyEqual(slot(:)', [2 1 3 5 6 8 7 9 11 10 12 4]);
        end

        function testTooFewPatchesAreNotGuessed(testCase)
            % 4 patches fit the grid four ways: reported, not placed
            [slot, why] = ndi.setup.conv.haley.matchGridPatches(testCase.C11([2 3 4 6], :), 12);
            testCase.verifyEmpty(slot);
            testCase.verifySubstring(why, 'ways to lay the grid');
        end

        function testAPatchBetweenColumnsIsNotPlaced(testCase)
            c = testCase.C11;
            c(5, 1) = c(5, 1) + 140;   % half a half-step off its column
            [slot, why] = ndi.setup.conv.haley.matchGridPatches(c, 12);
            testCase.verifyEmpty(slot);
            testCase.verifyNotEmpty(why);
        end
    end
end
