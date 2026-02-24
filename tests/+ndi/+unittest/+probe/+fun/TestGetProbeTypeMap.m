classdef TestGetProbeTypeMap < matlab.unittest.TestCase
    methods (Test)
        function testGetProbeTypeMap(testCase)
            % Test that getProbeTypeMap returns a valid map
            probeTypeMap = ndi.probe.fun.getProbeTypeMap();

            if isMATLABReleaseOlderThan('R2022b')
                testCase.verifyClass(probeTypeMap, 'containers.Map');
                testCase.verifyTrue(isKey(probeTypeMap, 'n-trode'));
            else
                testCase.verifyClass(probeTypeMap, 'dictionary');
                testCase.verifyTrue(isKey(probeTypeMap, 'n-trode'));
            end

            % Verify 'event' mapping
            if isMATLABReleaseOlderThan('R2022b')
                testCase.verifyEqual(probeTypeMap('event'), 'ndi.probe.timeseries.stimulator');
            else
                testCase.verifyEqual(probeTypeMap('event'), "ndi.probe.timeseries.stimulator");
            end
        end

        function testClearCache(testCase)
            % Test that ClearCache option works without error
            ndi.probe.fun.getProbeTypeMap('ClearCache', true);

            % Verify it still returns a valid map
            probeTypeMap = ndi.probe.fun.getProbeTypeMap();
            if isMATLABReleaseOlderThan('R2022b')
                testCase.verifyClass(probeTypeMap, 'containers.Map');
            else
                testCase.verifyClass(probeTypeMap, 'dictionary');
            end
        end
    end
end
