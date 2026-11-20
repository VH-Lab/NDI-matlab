classdef TestCloudPane < matlab.unittest.TestCase
    % TestCloudPane Verifies the NDI Cloud pane's header controls.
    %
    %   Checks that the "NDI Cloud" pane exposes a reload button (hover text
    %   "Refresh NDI Cloud login (logout)") alongside the existing "Profile"
    %   button, and the login indicator (green/yellow/red) whose decision
    %   ndi.gui.nav.cloudPane.describeLogin is tested without a display.
    %   Building the navigator also exercises the reload button's SVG icon
    %   path: a bad Icon path would error at construction.
    %
    %   The navigator is created with 'Visible','off' so the tests run
    %   headless (e.g. under Xvfb in CI).

    properties
        Nav
    end

    methods (TestClassSetup)
        function cleanUpBeforeAllTests(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (TestMethodSetup)
        function openNavigator(testCase)
            testCase.Nav = ndi.gui.navigator('Visible', 'off');
            testCase.addTeardown(@() delete(findall(groot, 'Type', 'figure', ...
                'Tag', 'ndiNavigator')));
        end
    end

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (Test)
        function testReloadButtonPresent(testCase)
            btn = findall(testCase.Nav.Figure, 'Type', 'uibutton', ...
                'Tooltip', 'Refresh NDI Cloud login (logout)');
            testCase.verifyNumElements(btn, 1, ...
                ['The NDI Cloud pane should have exactly one ' ...
                 '"Refresh NDI Cloud login (logout)" button.']);
            testCase.verifyNotEmpty(btn.ButtonPushedFcn, ...
                'The reload button should have a callback.');
            testCase.verifyNotEmpty(btn.Icon, ...
                'The reload button should have an icon.');
        end

        function testProfileButtonStillPresent(testCase)
            btn = findall(testCase.Nav.Figure, 'Type', 'uibutton', ...
                'Text', 'Profile');
            testCase.verifyNumElements(btn, 1, ...
                'The NDI Cloud pane should still have a Profile button.');
        end

        function testLoginIndicatorPresentAndColoured(testCase)
            btn = findall(testCase.Nav.Figure, 'Type', 'uibutton', ...
                'Tag', 'ndiNavigatorCloudLoginIndicator');
            testCase.verifyNumElements(btn, 1, ...
                'The NDI Cloud pane should have one login indicator.');
            expected = ndi.gui.nav.cloudPane.loginStatus();
            testCase.verifyEqual(btn.BackgroundColor, expected.color, 'AbsTol', 1e-6);
            testCase.verifyEqual(char(btn.Tooltip), expected.tooltip);
            testCase.verifyNotEmpty(btn.ButtonPushedFcn, ...
                'Clicking the indicator should open the profile editor.');
        end

        function testLoginTimerStopsWhenNavigatorCloses(testCase)
            pane = testCase.cloudPane();
            t = pane.LoginTimer;
            testCase.verifyTrue(isvalid(t));
            testCase.verifyEqual(t.Running, 'on');
            delete(testCase.Nav.Figure);
            testCase.verifyFalse(isvalid(t), ...
                'Closing the navigator should delete the login timer.');
        end

        function testDescribeLoginGreenWhenTokenValid(testCase)
            s = ndi.gui.nav.cloudPane.describeLogin(3*3600, 'me@lab.org', [], false, false);
            c = ndi.gui.cloudColors();
            testCase.verifyEqual(s.state, 'loggedin');
            testCase.verifyEqual(s.color, c.okGreen);
            testCase.verifySubstring(s.tooltip, 'Logged in to NDI Cloud as me@lab.org');
            testCase.verifySubstring(s.tooltip, 'about 3 hours');
        end

        function testDescribeLoginYellowWithReadyProfile(testCase)
            p = struct('UID', 'u1', 'Nickname', 'Lab', 'Email', 'me@lab.org');
            c = ndi.gui.cloudColors();
            s = ndi.gui.nav.cloudPane.describeLogin(NaN, '', p, true, false);
            testCase.verifyEqual(s.state, 'ready');
            testCase.verifyEqual(s.color, c.warnAmber);
            testCase.verifySubstring(s.tooltip, 'me@lab.org (profile "Lab")');
            % An expired token falls back to the profile, and says so.
            s = ndi.gui.nav.cloudPane.describeLogin(-600, '', p, true, false);
            testCase.verifyEqual(s.state, 'ready');
            testCase.verifySubstring(s.tooltip, 'expired 10 minutes ago');
            % Environment credentials also make a login ready.
            s = ndi.gui.nav.cloudPane.describeLogin(NaN, 'env@lab.org', [], false, true);
            testCase.verifyEqual(s.state, 'ready');
            testCase.verifySubstring(s.tooltip, 'env@lab.org');
        end

        function testDescribeLoginRedWhenNotConfigured(testCase)
            c = ndi.gui.cloudColors();
            s = ndi.gui.nav.cloudPane.describeLogin(NaN, '', [], false, false);
            testCase.verifyEqual(s.state, 'notconfigured');
            testCase.verifyEqual(s.color, c.alertRed);
            testCase.verifySubstring(s.tooltip, 'there is no NDI Cloud profile');
            % A profile without a stored password cannot log in.
            p = struct('UID', 'u1', 'Nickname', 'Lab', 'Email', 'me@lab.org');
            s = ndi.gui.nav.cloudPane.describeLogin(NaN, '', p, false, false);
            testCase.verifyEqual(s.state, 'notconfigured');
            testCase.verifySubstring(s.tooltip, 'profile "Lab"');
            % The three states never share a glyph.
            g = {ndi.gui.nav.cloudPane.describeLogin(60, '', [], false, false).glyph, ...
                ndi.gui.nav.cloudPane.describeLogin(NaN, '', p, true, false).glyph, s.glyph};
            testCase.verifyNumElements(unique(g), 3);
        end

        function testDurationText(testCase)
            f = @ndi.gui.nav.cloudPane.durationText;
            testCase.verifyEqual(f(30), 'less than 2 minutes');
            testCase.verifyEqual(f(600), '10 minutes');
            testCase.verifyEqual(f(-600), '10 minutes');
            testCase.verifyEqual(f(5*3600), 'about 5 hours');
            testCase.verifyEqual(f(3*86400), 'about 3 days');
        end
    end

    methods (Access = private)
        function pane = cloudPane(testCase)
            panes = testCase.Nav.Panes;
            k = find(cellfun(@(p) isa(p, 'ndi.gui.nav.cloudPane'), panes), 1);
            pane = panes{k};
        end
    end
end
