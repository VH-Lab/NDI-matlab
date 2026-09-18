classdef TestNavigatorLauncher < matlab.unittest.TestCase
    % TestNavigatorLauncher Tests the 'ndi' launcher's single-window behavior.
    %
    %   The 'ndi' command opens the navigator, but if one is already open it
    %   must raise and reuse that window instead of creating a second one.
    %
    %   Windows are created with 'Visible','off' so the tests run headless
    %   (e.g. under Xvfb in CI).

    methods (TestClassSetup)
        function cleanUpBeforeAllTests(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (Test)
        function testReusesExistingNavigator(testCase)
            % With a navigator already open, the launcher must reuse it.
            first = ndi.gui.navigator('Visible', 'off');

            feval('ndi');   % call the 'ndi' launcher function

            open = ndi.gui.navigator.findOpen();
            testCase.verifyNumElements(open, 1, ...
                'The launcher should not open a second navigator window.');
            testCase.verifySameHandle(open(end), first, ...
                'The launcher should reuse the already-open navigator.');
        end

        function testIgnoresArgumentsWhenReusing(testCase)
            % Inputs are ignored when an existing window is reused; no new
            % window is created regardless of the arguments passed.
            first = ndi.gui.navigator('Visible', 'off'); %#ok<NASGU>

            feval('ndi', 'Position', [50 50 300 500]);

            open = ndi.gui.navigator.findOpen();
            testCase.verifyNumElements(open, 1, ...
                'Passing arguments must not open a second navigator window.');
        end

        function testCreatesNavigatorWhenNoneOpen(testCase)
            % With no navigator open, the launcher creates one, forwarding
            % its arguments (here 'Visible','off' to stay headless).
            testCase.verifyEmpty(ndi.gui.navigator.findOpen(), ...
                'Precondition: no navigator should be open.');

            feval('ndi', 'Visible', 'off');

            testCase.verifyNumElements(ndi.gui.navigator.findOpen(), 1, ...
                'The launcher should create a navigator when none is open.');
        end
    end
end
