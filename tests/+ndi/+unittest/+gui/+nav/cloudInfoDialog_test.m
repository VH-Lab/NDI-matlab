classdef cloudInfoDialog_test < matlab.unittest.TestCase
    % CLOUDINFODIALOG_TEST - Tests for ndi.gui.nav.cloudInfoDialog.
    %
    % The static helpers run headless; the window tests build it with
    % 'Visible','off'.

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigatorCloudInfo'));
        end
    end

    methods (Test)
        function testCopyEnableInCloud(testCase)
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudInfoDialog.copyEnable(true, 'abc123'), 'on');
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudInfoDialog.idText(true, 'abc123'), 'abc123');
        end

        function testCopyDisabledWhenNotInCloud(testCase)
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudInfoDialog.copyEnable(false, ''), 'off');
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudInfoDialog.idText(false, ''), 'not in NDI Cloud');
        end

        function testCopyDisabledWhenIdMissing(testCase)
            % A linked dataset with no id has nothing to copy.
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudInfoDialog.copyEnable(true, ''), 'off');
        end

        function testStatusMessage(testCase)
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudInfoDialog.statusMessage(true), 'linked to NDI Cloud');
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudInfoDialog.statusMessage(false), 'not in NDI Cloud');
        end

        function testValueText(testCase)
            testCase.verifyEqual(ndi.gui.nav.cloudInfoDialog.valueText('/a/b'), '/a/b');
            testCase.verifyEqual(ndi.gui.nav.cloudInfoDialog.valueText(''), '(unknown)');
        end

        function testWindowInCloud(testCase)
            d = ndi.gui.nav.cloudInfoDialog(true, 'abc123', ...
                'DatasetName', 'myds', 'LocalPath', '/data/myds', 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifyEqual(d.IdField.Value, 'abc123');
            testCase.verifyEqual(char(d.CopyButton.Enable), 'on');
            testCase.verifyEqual(d.NameField.Value, 'myds');
            testCase.verifyEqual(char(d.NameCopyButton.Enable), 'on');
            testCase.verifyEqual(d.PathField.Value, '/data/myds');
            testCase.verifyEqual(char(d.PathCopyButton.Enable), 'on');
        end

        function testWindowNotInCloud(testCase)
            d = ndi.gui.nav.cloudInfoDialog(false, '', 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifyEqual(char(d.CopyButton.Enable), 'off');
            testCase.verifyEqual(char(d.NameCopyButton.Enable), 'off');
            testCase.verifyEqual(char(d.PathCopyButton.Enable), 'off');
        end
    end
end
