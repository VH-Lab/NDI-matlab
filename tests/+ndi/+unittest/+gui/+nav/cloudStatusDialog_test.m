classdef cloudStatusDialog_test < matlab.unittest.TestCase
    % CLOUDSTATUSDIALOG_TEST - Tests for ndi.gui.nav.cloudStatusDialog.
    %
    % The static helpers run headless; the window tests build it with
    % 'Visible','off'.

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigatorCloudStatus'));
        end
    end

    methods (Test)
        function testCopyEnableInCloud(testCase)
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudStatusDialog.copyEnable(true, 'abc123'), 'on');
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudStatusDialog.idText(true, 'abc123'), 'abc123');
        end

        function testCopyDisabledWhenNotInCloud(testCase)
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudStatusDialog.copyEnable(false, ''), 'off');
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudStatusDialog.idText(false, ''), 'not in NDI Cloud');
        end

        function testCopyDisabledWhenIdMissing(testCase)
            % A linked dataset with no id has nothing to copy.
            testCase.verifyEqual( ...
                ndi.gui.nav.cloudStatusDialog.copyEnable(true, ''), 'off');
        end

        function testStatusMessage(testCase)
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudStatusDialog.statusMessage(true), 'linked to NDI Cloud');
            testCase.verifySubstring( ...
                ndi.gui.nav.cloudStatusDialog.statusMessage(false), 'not in NDI Cloud');
        end

        function testWindowInCloud(testCase)
            d = ndi.gui.nav.cloudStatusDialog(true, 'abc123', 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifyEqual(d.IdField.Value, 'abc123');
            testCase.verifyEqual(char(d.CopyButton.Enable), 'on');
        end

        function testWindowNotInCloud(testCase)
            d = ndi.gui.nav.cloudStatusDialog(false, '', 'Visible', 'off');
            testCase.addTeardown(@() delete(d.Figure));
            testCase.verifyEqual(char(d.CopyButton.Enable), 'off');
        end
    end
end
