classdef ProbeMapTest <  matlab.unittest.TestCase
    % ProbeMapTest - Unit test for testing the probe type map.

    properties
        ProbeMap = ndi.probe.fun.getProbeTypeMap()
    end

    properties (TestParameter)
        % pass?
    end

    methods (TestClassSetup)
        function setupClass(testCase) %#ok<*MANU>
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
        end
    end

    methods (TestClassTeardown)
        function tearDownClass(testCase)
            % Pass. No class teardown routines needed
        end
    end

    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Pass. No method setup routines needed
        end
    end

    methods (Test)
        function testInitProbeTypeMap(testCase)
            probeTypeMap = ndi.probe.fun.initProbeTypeMap();
            if isMATLABReleaseOlderThan('R2022b')
                testCase.verifyClass(probeTypeMap, 'containers.Map')
            else
                testCase.verifyClass(probeTypeMap, 'dictionary')
            end
        end

        function testInitProbeTypeMapLegacy(testCase)
            probeTypeMap = ndi.probe.fun.initProbeTypeMap(true);
            testCase.verifyClass(probeTypeMap, 'containers.Map')
        end
    end
end
