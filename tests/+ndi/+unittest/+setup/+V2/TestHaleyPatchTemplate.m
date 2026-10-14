classdef TestHaleyPatchTemplate < matlab.unittest.TestCase
%TESTHALEYPATCHTEMPLATE Placing detected E. coli patches by the acetate template (decision #80).
%
%   The layout is the spec's `ecoli_patch_layout` (learned by patchLayout
%   from Jess's full images, 2026-10-14). Centroids are made from it with a
%   known template centre, angle and scale -- the inverse of the transform
%   matchTemplatePatches applies -- so the right answer is known.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Layout
    end

    methods (TestClassSetup)
        function readLayout(testCase)
            f = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), 'import_V2_spec.json');
            spec = jsondecode(fileread(f));
            testCase.Layout = spec.ecoli_patch_layout;
        end
    end

    methods (Test)
        function testElevenPatchesGetTheirNumbers(testCase)
            keep = setdiff(1:12, 4);                   % row 1, column 2 not detected
            c = testCase.centroids(keep, [1100 1400], 2, 30, 0.3);
            [slot, why] = ndi.setup.conv.haley.matchTemplatePatches(c, [1100 1400], 2, 30, testCase.Layout);
            testCase.verifyEmpty(why);
            testCase.verifyEqual(slot(:)', keep);
        end

        function testThreePatchesAreStillPlaced(testCase)
            % nothing depends on which rows or how many were detected
            keep = [3 9 12];
            c = testCase.centroids(keep, [1000 1300], -1.5, 28, 0.3);
            slot = ndi.setup.conv.haley.matchTemplatePatches(c, [1000 1300], -1.5, 28, testCase.Layout);
            testCase.verifyEqual(slot(:)', keep);
        end

        function testAPatchFarFromEveryPositionIsNotPlaced(testCase)
            c = testCase.centroids(1:11, [1100 1400], 0, 30, 0);
            c(5, :) = c(5, :) + [0 3 * 30];            % 3 mm off its position
            [slot, why] = ndi.setup.conv.haley.matchTemplatePatches(c, [1100 1400], 0, 30, testCase.Layout);
            testCase.verifyEmpty(slot);
            testCase.verifySubstring(why, 'from the nearest template position');
        end

        function testTwoPatchesOnOnePositionAreNotPlaced(testCase)
            c = testCase.centroids([1 1], [1100 1400], 0, 30, 0);
            c(2, :) = c(2, :) + [10 0];
            [slot, why] = ndi.setup.conv.haley.matchTemplatePatches(c, [1100 1400], 0, 30, testCase.Layout);
            testCase.verifyEmpty(slot);
            testCase.verifySubstring(why, 'same template position');
        end
    end

    methods
        function c = centroids(testCase, slots, centerYX, angleDeg, scale, jitterMm)
            % pixel centroids of the given patch numbers in an image whose
            % template has CENTERYX ([y x]), ANGLEDEG and SCALE (px/mm)
            pos = reshape(testCase.Layout.positions_mm, [], 2);
            th = testCase.Layout.angle_sign * angleDeg * pi / 180;
            rng(1);
            p = pos(slots, :) + jitterMm * (rand(numel(slots), 2) - 0.5);
            u = p(:, 1) * scale;
            v = p(:, 2) * scale;
            c = [centerYX(2) + cos(th) * u - sin(th) * v, centerYX(1) + sin(th) * u + cos(th) * v];
        end
    end
end
