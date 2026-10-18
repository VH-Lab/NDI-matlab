classdef TestCompareVersions < matlab.unittest.TestCase
    % TestCompareVersions - ordering rules of ndi.update.compareVersions.

    methods (Test)
        function testEqual(testCase)
            testCase.verifyEqual(ndi.update.compareVersions("1.2.3", "1.2.3"), 0);
            testCase.verifyEqual(ndi.update.compareVersions("v1.2.3", "1.2.3"), 0);
            testCase.verifyEqual(ndi.update.compareVersions("1.2", "1.2.0"), 0);
        end

        function testOlderAndNewer(testCase)
            testCase.verifyEqual(ndi.update.compareVersions("1.1.2", "1.2.0"), -1);
            testCase.verifyEqual(ndi.update.compareVersions("1.10.0", "1.9.9"), 1);
            testCase.verifyEqual(ndi.update.compareVersions("2.0.0", "v1.99.99"), 1);
            testCase.verifyEqual(ndi.update.compareVersions("1.2.3", "1.2.4"), -1);
        end

        function testSuffixIgnored(testCase)
            testCase.verifyEqual(ndi.update.compareVersions("1.2.3-beta", "1.2.3"), 0);
            testCase.verifyEqual(ndi.update.compareVersions("1.2.3+abc", "1.2.3"), 0);
        end

        function testBadVersionErrors(testCase)
            testCase.verifyError(@() ndi.update.compareVersions("main", "1.2.3"), ...
                'ndi:update:compareVersions:badVersion');
        end
    end
end
