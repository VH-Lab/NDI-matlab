classdef TestCheckPython < matlab.unittest.TestCase
    % TestCheckPython - ndi.update.checkPython against a fake ~/.ndi folder
    % and a fake GitHub API (the GitHubApi option), so no network is used
    % and no real NDI-python is needed.

    properties
        Home    % fake NDI_HOME
    end

    properties (Constant)
        Installed = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        Latest    = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    end

    methods (TestMethodSetup)
        function makeHome(testCase)
            testCase.Home = string(tempname);
            mkdir(testCase.Home);
            testCase.addTeardown(@() rmdir(testCase.Home, 's'));
        end
    end

    methods (Test)
        function testNotInstalled(testCase)
            py = ndi.update.checkPython(NdiHome = testCase.Home, ...
                GitHubApi = @(~, ~) error('test:noNetwork', 'should not be called'));
            testCase.verifyFalse(py.Installed);
            testCase.verifyEqual(py.Status, "notInstalled");
            testCase.verifyFalse(py.UpdateAvailable);
        end

        function testReceiptBehindMain(testCase)
            testCase.makeCommand();
            testCase.writeFile(fullfile(testCase.Home, "install.json"), ...
                jsonencode(struct('commit', testCase.Installed)));
            api = @(p, ~) fakeApi(p, testCase.Installed, testCase.Latest, 3, 0);
            py = ndi.update.checkPython(NdiHome = testCase.Home, GitHubApi = api);
            testCase.verifyTrue(py.Installed);
            testCase.verifyEqual(py.Kind, "installer");
            testCase.verifyTrue(py.CanInstall);
            testCase.verifyEqual(py.Status, "updateAvailable");
            testCase.verifyTrue(py.UpdateAvailable);
            testCase.verifyEqual(py.CommitsBehind, 3);
            testCase.verifyEqual(py.CurrentVersion, "aaaaaaa");
            testCase.verifyEqual(py.LatestVersion, "bbbbbbb");
            testCase.verifySubstring(py.Message, "ndi.update.install()");
        end

        function testReceiptUpToDate(testCase)
            testCase.makeCommand();
            testCase.writeFile(fullfile(testCase.Home, "install.json"), ...
                jsonencode(struct('commit', testCase.Latest)));
            api = @(p, ~) fakeApi(p, testCase.Latest, testCase.Latest, 0, 0);
            py = ndi.update.checkPython(NdiHome = testCase.Home, GitHubApi = api);
            testCase.verifyEqual(py.Status, "upToDate");
            testCase.verifyFalse(py.UpdateAvailable);
        end

        function testInstallTimeCountsCommitsSince(testCase)
            % Without install.json, the uv receipt's time is used and the
            % commits made on main since then are counted.
            testCase.makeCommand();
            testCase.writeFile(fullfile(testCase.Home, "venvs", "ndi", "uv-receipt.toml"), "[tool]");
            api = @(p, ~) fakeApi(p, "", testCase.Latest, 0, 2);
            py = ndi.update.checkPython(NdiHome = testCase.Home, GitHubApi = api);
            testCase.verifyEqual(py.Status, "updateAvailable");
            testCase.verifyEqual(py.CommitsBehind, 2);
            testCase.verifySubstring(py.CurrentVersion, "installed ");
            testCase.verifyNotEmpty(regexp(py.InstalledAt, ...
                '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$', 'once'));
            testCase.verifySubstring(py.Message, "since it was installed on");
        end

        function testReceiptWithoutCommitUsesItsTime(testCase)
            % The installer could not reach GitHub's API: the receipt has a
            % null commit and the install time, which is used.
            testCase.makeCommand();
            testCase.writeFile(fullfile(testCase.Home, "install.json"), ...
                '{"commit": null, "installedAt": "2026-10-01T12:00:00Z"}');
            api = @(p, ~) fakeApi(p, "", testCase.Latest, 0, 4);
            py = ndi.update.checkPython(NdiHome = testCase.Home, GitHubApi = api);
            testCase.verifyEqual(py.CommitsBehind, 4);
            testCase.verifyEqual(py.InstalledAt, "2026-10-01T12:00:00Z");
            testCase.verifyEqual(py.CurrentVersion, "installed 2026-10-01");
        end

        function testGitHubFailureIsUnknown(testCase)
            testCase.makeCommand();
            testCase.writeFile(fullfile(testCase.Home, "install.json"), ...
                jsonencode(struct('commit', testCase.Installed)));
            py = ndi.update.checkPython(NdiHome = testCase.Home, ...
                GitHubApi = @(~, ~) error('test:offline', 'no network'));
            testCase.verifyEqual(py.Status, "unknown");
            testCase.verifyFalse(py.UpdateAvailable);
            testCase.verifySubstring(py.Message, "no network");
        end
    end

    methods (Access = private)
        function makeCommand(testCase)
            name = "ndi";
            if ispc
                name = name + ".exe";
            end
            testCase.writeFile(fullfile(testCase.Home, "bin", name), "");
        end

        function writeFile(~, f, text)
            folder = fileparts(f);
            if ~isfolder(folder)
                mkdir(folder);
            end
            fid = fopen(f, 'w');
            fwrite(fid, char(text));
            fclose(fid);
        end
    end
end

function data = fakeApi(apiPath, installed, latest, aheadBy, commitsSince)
% Stand-in for GitHub: answers the three requests checkPython makes.
    repo = "repos/Waltham-Data-Science/NDI-python";
    if apiPath == repo + "/commits/main"
        data = struct('sha', char(latest));
    elseif apiPath == repo + "/compare/" + installed + "...main"
        data = struct('ahead_by', aheadBy, 'behind_by', 0);
    elseif startsWith(apiPath, repo + "/commits?sha=main&per_page=100&since=")
        data = repmat(struct('sha', 'c'), commitsSince, 1);
    else
        error('test:unexpectedRequest', 'Unexpected GitHub request: %s', apiPath);
    end
end
