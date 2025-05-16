classdef SetupTest <  matlab.unittest.TestCase
% BasicTest - Unit test for testing the openMINDS tutorials.

    methods (TestClassSetup)
        function setupClass(testCase) %#ok<*MANU>
            % pass
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
        function testInstallRequirements(testCase)
            pathStr = matboxtools.projectdir();
            requirementsPath = fullfile(pathStr, "tools", "tests", "test_resources");
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);

            try
                matbox.installRequirements(requirementsPath, "InstallationLocation", pwd)
            catch ME
                testCase.verifyFail(ME.message)
            end
        end
    end
end
