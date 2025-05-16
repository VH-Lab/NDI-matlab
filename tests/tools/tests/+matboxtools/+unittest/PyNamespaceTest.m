classdef PyNamespaceTest < matlab.unittest.TestCase
% BasicTest - Unit test for testing the openMINDS tutorials.

    methods (TestClassSetup) % Shared setup for the entire test class
        function setupClass(testCase) %#ok<*MANU>
            try
                matbox.py.pipUninstall('pybadges')
            catch ME
                disp('Pybadges was not installed')
            end
        end
    end

    methods (TestMethodSetup)  % Setup for each test
        function setupMethod(testCase)
        end
    end
    
    methods (Test)

        function testPipUninstall(testCase)
            try
                matbox.py.pipUninstall('pybadges')
            catch
                disp('Pybadges was not installed')
            end
        end

        function testPipInstall(testCase)
            matbox.py.pipInstall('pybadges')
        end

        function testPipInstallUnknownPackage(testCase)
            testCase.assertError(@(name) matbox.py.pipInstall('pybaldges'), ...
                'MatBox:UnableToInstallPythonPackage')
        end

        function testGetPythonPackageInfo(testCase)
            info = matbox.py.getPackageInfo('pybadges');
            testCase.verifyClass(info, 'struct')

            location = matbox.py.getPackageInfo('pybadges', "Field", "Location");
            testCase.verifyClass(location, 'string')
        end
    end
end
