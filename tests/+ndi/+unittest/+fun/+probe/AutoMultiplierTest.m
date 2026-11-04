classdef AutoMultiplierTest < matlab.unittest.TestCase
    methods (Test)
        function testIntegerClassData(testCase)
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) int16(round(1000*sin(t*[1 2]))));
            testCase.verifyEqual(ndi.fun.probe.export.autoMultiplier(p), 1);
        end

        function testWholeNumberDoubleData(testCase)
            % raw ADC counts returned as double (e.g. SpikeGLX) must pass through
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) round(1000*sin(1000*t*[1 2]) + 600));
            testCase.verifyEqual(ndi.fun.probe.export.autoMultiplier(p), 1);
        end

        function testFloatingPointPhysicalData(testCase)
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) 0.195*round(1000*sin(1000*t*[1 2])) + 0.0975);
            testCase.verifyEqual(ndi.fun.probe.export.autoMultiplier(p), 1/0.195, 'AbsTol', 1e-12);
        end

        function testAllZeroDataIsInconclusive(testCase)
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) zeros(numel(t), 2));
            testCase.verifyEqual(ndi.fun.probe.export.autoMultiplier(p), 1/0.195, 'AbsTol', 1e-12);
        end

        function testReadErrorKeepsDefault(testCase)
            p = ndi.unittest.fun.probe.MockDataProbe(@(t) error('mock:fail', 'read failed'));
            testCase.verifyEqual(ndi.fun.probe.export.autoMultiplier(p), 1/0.195, 'AbsTol', 1e-12);
        end
    end
end
