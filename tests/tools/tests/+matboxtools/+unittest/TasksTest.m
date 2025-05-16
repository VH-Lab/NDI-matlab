classdef TasksTest <  matlab.unittest.TestCase
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
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
        end
    end
    
    methods (Test)
        function testCodecheckToolbox(testCase)
            pathStr = matboxtools.projectdir();

            copyfile(pathStr, pwd);
            
            matbox.tasks.codecheckToolbox(pwd, ...
                "CreateBadge", false, "SaveReport", false);

            % Todo: Add test for saving badge and report

            testCase.verifyTrue(isfolder(fullfile(pwd, "docs", "reports")))
        end

        function testPackageToolbox(testCase)
            pathStr = matboxtools.projectdir();
            copyfile(pathStr, pwd);
            if isfolder(fullfile(pwd, 'releases'))
                rmdir(fullfile(pwd, 'releases'), 's')
            end
            matbox.tasks.packageToolbox(pwd, "build", "")
            testCase.verifyTrue(isfolder(fullfile(pwd, "releases")))
        end
    end
end
