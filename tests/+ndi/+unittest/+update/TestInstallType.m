classdef TestInstallType < matlab.unittest.TestCase
    % TestInstallType - ndi.update.installType reports a consistent answer
    % for the copy of NDI-matlab running the tests. Offline.

    methods (Test)
        function testFields(testCase)
            [type, info] = ndi.update.installType();
            testCase.verifyTrue(ismember(type, ["git", "toolbox", "unknown"]));
            testCase.verifyTrue(all(isfield(info, ...
                {'SourceDir', 'RepoRoot', 'ToolboxVersion', 'BothInstalled'})));
            testCase.verifyEqual(info.SourceDir, string(ndi.toolboxdir()));
        end

        function testGitRepoRoot(testCase)
            [type, info] = ndi.update.installType();
            if type == "git"
                testCase.verifyTrue(isfile(fullfile(info.RepoRoot, 'ndi_install.m')));
            else
                testCase.verifyEqual(info.RepoRoot, "");
            end
        end

        function testCheckOnStartupNeverErrors(testCase)
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            % With CI set, the startup check returns without touching the network.
            testCase.applyFixture(EnvironmentVariableFixture('CI', 'true'));
            testCase.verifyWarningFree(@() ndi.update.checkOnStartup());
        end
    end
end
