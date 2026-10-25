classdef TestPackageStatus < matlab.unittest.TestCase
    % TestPackageStatus - ndi.update.packageStatus on hand-made results of
    % ndi.update.check. No git, no network.

    methods (Test)
        function testGitUpToDate(testCase)
            [rows, summary] = ndi.update.packageStatus(ndi.unittest.update.TestPackageStatus.gitResult());
            testCase.verifyEqual([rows.Name], ["NDI-matlab", "depA", "NDIcalc-vis-matlab"]);
            testCase.verifyEqual([rows.Kind], ["ndi", "dependency", "calculator"]);
            testCase.verifyEqual([rows.Status], repmat("Up to date", 1, 3));
            testCase.verifyFalse(any([rows.WillUpdate]));
            testCase.verifyFalse(summary.CanUpdate);
            testCase.verifyEqual(summary.Message, "Everything is up to date.");
        end

        function testBehindDependencyWithEditsIsStashed(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.UpdateAvailable = true;
            r.Status = "updateAvailable";
            r.Dependencies(1).Status = "behind";
            r.Dependencies(1).CommitsBehind = 3;
            r.Modifications = ndi.unittest.update.TestPackageStatus.mods("depA", ["a.m"; "b.m"], strings(0, 1), 0);
            [rows, summary] = ndi.update.packageStatus(r);
            dep = rows(2);
            testCase.verifyEqual(dep.Status, "3 new commits");
            testCase.verifyTrue(dep.WillUpdate);
            testCase.verifyEqual(dep.NoteLevel, "warning");
            testCase.verifySubstring(dep.Notes(1), "2 changed file(s) will be stashed");
            testCase.verifySubstring(dep.Details, "changed:    a.m");
            testCase.verifyTrue(dep.TouchesChanges);
            testCase.verifyTrue(summary.CanUpdate);
            testCase.verifyTrue(summary.HasUserChanges);
            % NDI-matlab itself is not pulled when it is not behind.
            testCase.verifyFalse(rows(1).WillUpdate);
        end

        function testUntrackedFileInTheWayBlocks(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.UpdateAvailable = true;
            r.CommitsBehind = 1;
            r.Modifications = ndi.unittest.update.TestPackageStatus.mods("NDI-matlab", strings(0, 1), "new.m", 0);
            [rows, summary] = ndi.update.packageStatus(r);
            testCase.verifyTrue(rows(1).Blocked);
            testCase.verifyEqual(rows(1).NoteLevel, "error");
            testCase.verifySubstring(rows(1).Details, "in the way: new.m");
            testCase.verifyFalse(summary.CanUpdate);
            testCase.verifyTrue(summary.Blocked);
        end

        function testOtherBranchBlocks(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.UpdateAvailable = true;
            r.CommitsBehind = 2;
            r.Branch = "myFeature";
            rows = ndi.update.packageStatus(r);
            testCase.verifyTrue(rows(1).Blocked);
            testCase.verifySubstring(rows(1).Notes(1), "myFeature");
        end

        function testEditsInPackageNotUpdatedAreLeftAlone(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.Modifications = ndi.unittest.update.TestPackageStatus.mods("NDIcalc-vis-matlab", "x.m", strings(0, 1), 0);
            [rows, summary] = ndi.update.packageStatus(r);
            testCase.verifyEqual(rows(3).NoteLevel, "info");
            testCase.verifySubstring(rows(3).Notes(1), "not touched");
            testCase.verifyFalse(summary.HasUserChanges);
        end

        function testCalculatorBehind(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.Calculators(1).Status = "behind";
            r.Calculators(1).CommitsBehind = 1;
            r.CalculatorUpdateAvailable = true;
            [rows, summary] = ndi.update.packageStatus(r);
            testCase.verifyTrue(rows(3).WillUpdate);
            testCase.verifyEqual(rows(3).Status, "1 new commit");
            testCase.verifyTrue(summary.CanUpdate);
            testCase.verifyEqual(summary.Message, "1 package(s) will be updated.");
        end

        function testMissingDependencyIsInstalled(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.UpdateAvailable = true;
            r.Dependencies(1).Status = "missing";
            rows = ndi.update.packageStatus(r);
            testCase.verifyTrue(rows(2).WillUpdate);
            testCase.verifyEqual(ndi.gui.nav.updateDialog.actionText(rows(2)), 'Install');
        end

        function testToolboxUpdate(testCase)
            r = ndi.unittest.update.TestPackageStatus.toolboxResult();
            [rows, summary] = ndi.update.packageStatus(r);
            testCase.verifyEqual(rows(1).Name, "NDI-matlab toolbox");
            testCase.verifyEqual(rows(1).Installed, "1.2.0");
            testCase.verifyEqual(rows(1).Latest, "1.3.0");
            testCase.verifyTrue(rows(1).WillUpdate);
            testCase.verifyEqual(rows(1).NoteLevel, "warning");
            testCase.verifyTrue(any(contains(rows(1).Notes, "will be lost")));
            testCase.verifyTrue(any(contains(rows(1).Notes, "Restart MATLAB")));
            testCase.verifyTrue(summary.CanUpdate);
        end

        function testToolboxWithoutMltbxBlocks(testCase)
            r = ndi.unittest.update.TestPackageStatus.toolboxResult();
            r.MltbxUrl = "";
            [rows, summary] = ndi.update.packageStatus(r);
            testCase.verifyTrue(rows(1).Blocked);
            testCase.verifyFalse(summary.CanUpdate);
        end

        function testPythonNotInstalledByNdiIsNotUpdated(testCase)
            r = ndi.unittest.update.TestPackageStatus.toolboxResult();
            r.UpdateAvailable = false;
            r.Status = "upToDate";
            r.Python = struct('Installed', true, 'Kind', "other", 'Status', "updateAvailable", ...
                'UpdateAvailable', true, 'CanInstall', false, 'Message', "", ...
                'CurrentVersion', "abc1234", 'LatestVersion', "def5678", 'CommitsBehind', 4);
            [rows, summary] = ndi.update.packageStatus(r);
            py = rows(end);
            testCase.verifyEqual(py.Name, "NDI-python");
            testCase.verifyEqual(py.Status, "4 new commits");
            testCase.verifyFalse(py.WillUpdate);
            testCase.verifyEqual(py.NoteLevel, "info");
            testCase.verifyFalse(summary.AnyUpdate);
        end

        function testDialogTable(testCase)
            r = ndi.unittest.update.TestPackageStatus.gitResult();
            r.Calculators(1).Status = "behind";
            r.Calculators(1).CommitsBehind = 2;
            r.CalculatorUpdateAvailable = true;
            r.Modifications = ndi.unittest.update.TestPackageStatus.mods("NDIcalc-vis-matlab", "x.m", strings(0, 1), 0);
            rows = ndi.update.packageStatus(r);
            data = ndi.gui.nav.updateDialog.tableData(rows);
            testCase.verifySize(data, [3 numel(ndi.gui.nav.updateDialog.Columns)]);
            testCase.verifyEqual(data{3, 1}, 'NDIcalc-vis-matlab');
            testCase.verifyEqual(data{3, 5}, 'Update');
            testCase.verifySubstring(data{3, 6}, 'stashed');
            testCase.verifyEqual(data{1, 6}, '');
        end

        function testNoteTextShowsMostSeriousNote(testCase)
            r = ndi.unittest.update.TestPackageStatus.toolboxResult();
            r.MltbxUrl = "";
            rows = ndi.update.packageStatus(r);
            txt = ndi.gui.nav.updateDialog.noteText(rows(1));
            testCase.verifySubstring(txt, 'no toolbox file');
            testCase.verifySubstring(txt, 'more)');
        end

        function testUpdateButtonState(testCase)
            s = struct('CanUpdate', true, 'HasUserChanges', true);
            [text, enable] = ndi.gui.nav.updateDialog.updateButtonState(s);
            testCase.verifyEqual(text, 'Update anyway');
            testCase.verifyEqual(enable, 'on');
            s = struct('CanUpdate', false, 'HasUserChanges', false);
            [text, enable] = ndi.gui.nav.updateDialog.updateButtonState(s);
            testCase.verifyEqual(text, 'Update');
            testCase.verifyEqual(enable, 'off');
        end
    end

    methods (Static, Access = private)
        function r = gitResult()
            % An up-to-date git install with one dependency and one calculator.
            r = ndi.unittest.update.TestPackageStatus.baseResult("git");
            r.RepoRoot = "/tools/NDI-matlab";
            r.Branch = "main";
            r.CurrentVersion = "1111111";
            r.LatestVersion = "1111111";
            r.CommitsBehind = 0;
            r.CommitsAhead = 0;
            r.Status = "upToDate";
            r.Dependencies = ndi.unittest.update.TestPackageStatus.repo("depA", "/tools/depA");
            r.Calculators = ndi.unittest.update.TestPackageStatus.repo("NDIcalc-vis-matlab", "/tools/NDIcalc-vis-matlab");
        end

        function r = toolboxResult()
            % A toolbox install with a newer release.
            r = ndi.unittest.update.TestPackageStatus.baseResult("toolbox");
            r.Status = "updateAvailable";
            r.UpdateAvailable = true;
            r.CurrentVersion = "1.2.0";
            r.LatestVersion = "1.3.0";
            r.ReleaseUrl = "https://example.com/release";
            r.MltbxUrl = "https://example.com/NDI.mltbx";
        end

        function r = baseResult(type)
            noRepos = struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {}, ...
                'CurrentVersion', {}, 'LatestVersion', {});
            r = struct('InstallType', type, 'Status', "unknown", 'UpdateAvailable', false, ...
                'CurrentVersion', "", 'LatestVersion', "", 'Message', "", 'Branch', "", ...
                'CommitsBehind', NaN, 'CommitsAhead', NaN, 'HasModifications', false, ...
                'Modifications', ndi.unittest.update.TestPackageStatus.mods(strings(1, 0), {}, {}, {}), ...
                'Dependencies', noRepos, 'Calculators', noRepos, ...
                'CalculatorUpdateAvailable', false, 'ReleaseUrl', "", 'MltbxUrl', "", ...
                'BothInstalled', false, 'RepoRoot', "", ...
                'Python', struct('Installed', false, 'Kind', "none", 'Status', "notChecked", ...
                    'UpdateAvailable', false, 'CanInstall', false, 'Message', "", ...
                    'CurrentVersion', "", 'LatestVersion', "", 'CommitsBehind', NaN));
        end

        function d = repo(name, folder)
            d = struct('Name', string(name), 'Path', string(folder), 'Status', "upToDate", ...
                'CommitsBehind', 0, 'CurrentVersion', "2222222", 'LatestVersion', "2222222");
        end

        function m = mods(name, changed, blocking, ahead)
            % One Modifications entry, or (with an empty NAME) none.
            if isempty(name)
                m = struct('Name', {}, 'Path', {}, 'ChangedFiles', {}, ...
                    'BlockingFiles', {}, 'CommitsAhead', {});
                return
            end
            m = struct('Name', string(name), 'Path', "/tools/" + name, ...
                'ChangedFiles', {string(changed)}, 'BlockingFiles', {string(blocking)}, ...
                'CommitsAhead', ahead);
        end
    end
end
