classdef TestCloudPane < matlab.unittest.TestCase
    % TestCloudPane Verifies the NDI Cloud pane's header controls.
    %
    %   Checks that the "NDI Cloud" pane exposes a reload button (hover text
    %   "Refresh NDI Cloud login") alongside the existing "Profile" button.
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
            testCase.addTeardown(@() delete(testCase.Nav.Figure));
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
                'Tooltip', 'Refresh NDI Cloud login');
            testCase.verifyNumElements(btn, 1, ...
                ['The NDI Cloud pane should have exactly one ' ...
                 '"Refresh NDI Cloud login" button.']);
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
    end
end
