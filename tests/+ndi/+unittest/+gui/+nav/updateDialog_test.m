classdef updateDialog_test < matlab.unittest.TestCase
    % UPDATEDIALOG_TEST - Tests for ndi.gui.nav.updateDialog, built hidden
    % ('Visible','off') from a hand-made ndi.update.check result. The
    % static helpers are covered in ndi.unittest.update.TestPackageStatus.

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigatorUpdate'));
        end
    end

    methods (Test)
        function testCalculatorUpdate(testCase)
            r = ndi.unittest.gui.nav.updateDialog_test.result();
            r.Calculators(1).Status = "behind";
            r.Calculators(1).CommitsBehind = 2;
            r.CalculatorUpdateAvailable = true;
            d = ndi.gui.nav.updateDialog(r, 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifySize(d.Table.Data, [2 numel(ndi.gui.nav.updateDialog.Columns)]);
            testCase.verifyEqual(char(d.UpdateButton.Enable), 'on');
            testCase.verifyEqual(char(d.UpdateButton.Text), 'Update (1)');
            testCase.verifyEqual(char(d.CancelButton.Text), 'Cancel');
            testCase.verifyEqual(d.selectedPackages(), "NDIcalc-vis-matlab");
            % Unticking the only package leaves nothing to update.
            d.setSelected(2, false);
            testCase.verifyEqual(char(d.UpdateButton.Enable), 'off');
            testCase.verifyEmpty(d.selectedPackages());
        end

        function testNothingToUpdate(testCase)
            d = ndi.gui.nav.updateDialog(ndi.unittest.gui.nav.updateDialog_test.result(), 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifyEqual(char(d.UpdateButton.Enable), 'off');
            testCase.verifyEqual(char(d.CancelButton.Text), 'Close');
        end

        function testDetailsAndChoice(testCase)
            r = ndi.unittest.gui.nav.updateDialog_test.result();
            r.UpdateAvailable = true;
            r.CommitsBehind = 1;
            r.Modifications = struct('Name', "NDI-matlab", 'Path', r.RepoRoot, ...
                'ChangedFiles', {"README.md"}, 'BlockingFiles', {strings(0, 1)}, ...
                'CommitsAhead', 0);
            d = ndi.gui.nav.updateDialog(r, 'Visible', 'off');
            % NDI-matlab has your edits, so it starts unticked.
            testCase.verifyFalse(d.Table.Data{1, 1});
            testCase.verifyEqual(char(d.UpdateButton.Enable), 'off');
            d.setSelected(1, true);
            testCase.verifyTrue(d.Table.Data{1, 1});
            testCase.verifyEqual(char(d.UpdateButton.Text), 'Update anyway (1)');
            % An up-to-date package cannot be ticked.
            d.setSelected(2, true);
            testCase.verifyFalse(d.Table.Data{2, 1});
            testCase.verifyEqual(d.selectedPackages(), "NDI-matlab");
            % The row with notes is shown first.
            testCase.verifyTrue(any(contains(d.DetailsArea.Value, 'README.md')));
            d.showDetails(2);
            testCase.verifyTrue(any(contains(d.DetailsArea.Value, 'NDIcalc-vis-matlab')));
            d.choose("update");
            testCase.verifyEqual(d.Choice, "update");
            testCase.verifyFalse(isvalid(d.Figure));
        end
    end

    methods (Static, Access = private)
        function r = result()
            % An up-to-date git install with one calculator.
            noRepos = struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {}, ...
                'CurrentVersion', {}, 'LatestVersion', {});
            r = struct('InstallType', "git", 'Status', "upToDate", 'UpdateAvailable', false, ...
                'CurrentVersion', "1111111", 'LatestVersion', "1111111", 'Message', "", ...
                'Branch', "main", 'CommitsBehind', 0, 'CommitsAhead', 0, ...
                'HasModifications', false, ...
                'Modifications', struct('Name', {}, 'Path', {}, 'ChangedFiles', {}, ...
                    'BlockingFiles', {}, 'CommitsAhead', {}), ...
                'Dependencies', noRepos, 'Calculators', noRepos, ...
                'CalculatorUpdateAvailable', false, 'ReleaseUrl', "", 'MltbxUrl', "", ...
                'BothInstalled', false, 'RepoRoot', "/tools/NDI-matlab", ...
                'Python', struct('Installed', false, 'Kind', "none", 'Status', "notChecked", ...
                    'UpdateAvailable', false, 'CanInstall', false, 'Message', "", ...
                    'CurrentVersion', "", 'LatestVersion', "", 'CommitsBehind', NaN));
            r.Calculators = struct('Name', "NDIcalc-vis-matlab", ...
                'Path', "/tools/NDIcalc-vis-matlab", 'Status', "upToDate", ...
                'CommitsBehind', 0, 'CurrentVersion', "2222222", 'LatestVersion', "2222222");
        end
    end
end
