classdef TestGratingValue < matlab.unittest.TestCase
%TESTGRATINGVALUE Unit tests for ndi.migrate.internal.gratingValueFromParameters
%   (pure struct mapping; no database, schema, or toolbox needed).
%
%   Run with:  runtests('ndi.unittest.migrate.TestGratingValue')

    methods (Test)

        function testNdiNamesMapped(testCase)
            % NDI/vhlab names -> V_eta visual_grating value names
            params = struct('angle', 45, 'sFrequency', 0.5, 'tFrequency', 2, ...
                'contrast', 1, 'size', 30, 'isblank', 0);
            v = ndi.migrate.internal.gratingValueFromParameters(params);
            testCase.verifyEqual(v.angle, 45);
            testCase.verifyEqual(v.spatial_frequency, 0.5);
            testCase.verifyEqual(v.temporal_frequency, 2);
            testCase.verifyEqual(v.contrast, 1);
            testCase.verifyEqual(v.size, 30);
            testCase.verifyFalse(v.is_blank);
        end

        function testStaticGratingIsZeroTemporalFreq(testCase)
            % an orientation-tuning (static) grating: tFrequency = 0, still valid
            params = struct('angle', 90, 'sFrequency', 0.2, 'tFrequency', 0, 'contrast', 1);
            v = ndi.migrate.internal.gratingValueFromParameters(params);
            testCase.verifyEqual(v.temporal_frequency, 0);
            testCase.verifyEqual(v.angle, 90);
        end

        function testBlankStimulus(testCase)
            params = struct('isblank', 1);
            v = ndi.migrate.internal.gratingValueFromParameters(params);
            testCase.verifyTrue(v.is_blank);
            testCase.verifyEqual(v.contrast, 0);   % absent -> default 0
        end

        function testSnakeCaseFallback(testCase)
            params = struct('orientation', 135, 'spatial_frequency', 0.4, ...
                'temporal_frequency', 4);
            v = ndi.migrate.internal.gratingValueFromParameters(params);
            testCase.verifyEqual(v.angle, 135);
            testCase.verifyEqual(v.spatial_frequency, 0.4);
            testCase.verifyEqual(v.temporal_frequency, 4);
        end

        function testPositionVectorAndStruct(testCase)
            v1 = ndi.migrate.internal.gratingValueFromParameters(...
                struct('position', [3 -5]));
            testCase.verifyEqual(v1.position.x, 3);
            testCase.verifyEqual(v1.position.y, -5);
            v2 = ndi.migrate.internal.gratingValueFromParameters(...
                struct('position', struct('x', 7, 'y', 9)));
            testCase.verifyEqual(v2.position.x, 7);
            testCase.verifyEqual(v2.position.y, 9);
        end

        function testEmptyParametersAllDefault(testCase)
            v = ndi.migrate.internal.gratingValueFromParameters(struct());
            testCase.verifyEqual(v.angle, 0);
            testCase.verifyEqual(v.spatial_frequency, 0);
            testCase.verifyFalse(v.is_blank);
            testCase.verifyEqual(v.position.x, 0);
        end

    end
end
