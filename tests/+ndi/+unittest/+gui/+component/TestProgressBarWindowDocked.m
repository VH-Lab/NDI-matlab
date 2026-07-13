% TestProgressBarWindowDocked.m
classdef TestProgressBarWindowDocked < matlab.unittest.TestCase
    % TestProgressBarWindowDocked Tests for docking progress bars into the
    %   ndi.gui.navigator progress pane.
    %
    %   When a navigator is open, ndi.gui.component.ProgressBarWindow renders
    %   its bars inside the navigator's progress pane instead of a standalone
    %   window. These tests exercise that routing, the cascade of multiple
    %   bars, reuse across nested tasks, and the idle-reset behaviour when the
    %   last bar is removed (which must never delete the navigator).
    %
    %   The navigator is created with 'Visible','off' so the tests run
    %   headless (e.g. under Xvfb in CI), exactly like TestProgressBarWindow.

    properties
        Nav   % ndi.gui.navigator under test
        Pane  % its ndi.gui.nav.progressPane
    end

    methods (TestClassSetup)
        function cleanUpBeforeAllTests(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'));
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (TestMethodSetup)
        function openNavigator(testCase)
            % A fresh, hidden navigator for each test.
            testCase.Nav = ndi.gui.navigator('Visible', 'off');
            testCase.addTeardown(@() delete(testCase.Nav.Figure));
            testCase.Pane = testCase.Nav.progressPaneHandle();
            testCase.verifyNotEmpty(testCase.Pane, 'Navigator should have a progress pane.');
        end
    end

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'));
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (Test)
        function testDocksInsteadOfWindow(testCase)
            % With a navigator open, no standalone progressbar window is made.
            app = ndi.gui.component.ProgressBarWindow('Docked Test');
            app.addBar('Label', 'Task 1', 'Tag', 'T1');

            testCase.verifyTrue(app.IsDocked, 'App should be docked.');
            testCase.verifyEmpty(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'), ...
                'No standalone progressbar window should be created when docked.');
            testCase.verifySameHandle(app.ProgressGrid, testCase.Pane.BarGrid, ...
                'Bars should render into the pane bar grid.');
            testCase.verifySameHandle(testCase.Pane.ActiveApp, app, ...
                'Pane should record the docked app.');
        end

        function testDockedBarRenders(testCase)
            % The bar graphics are created inside the pane bar grid.
            app = ndi.gui.component.ProgressBarWindow('Render Test');
            app.addBar('Label', 'Task 1', 'Tag', 'T1');
            app.updateBar('T1', 0.5);

            testCase.verifyEqual(app.ProgressBars(1).Progress, 0.5);
            testCase.verifyEqual(app.ProgressBars(1).Percent.Text, '50%');
            testCase.verifySameHandle(app.ProgressBars(1).Axes.Parent, testCase.Pane.BarGrid, ...
                'Bar axes should be parented to the pane bar grid.');
        end

        function testCascadeMultipleBars(testCase)
            app = ndi.gui.component.ProgressBarWindow('Cascade Test');
            app.addBar('Label', 'Task A', 'Tag', 'TA');
            app.addBar('Label', 'Task B', 'Tag', 'TB');

            testCase.verifyNumElements(app.ProgressBars, 2, 'Should have two bars.');
            testCase.verifyNumElements(app.ProgressGrid.RowHeight, 4, ...
                'Pane grid should have 4 rows (2 per bar).');
        end

        function testReuseAcrossNestedTasks(testCase)
            % A second construction while a navigator is open returns the
            % pane's already-active docked app so tasks cascade together.
            app1 = ndi.gui.component.ProgressBarWindow('Outer');
            app1.addBar('Label', 'Outer', 'Tag', 'outer');

            app2 = ndi.gui.component.ProgressBarWindow('Inner');
            testCase.verifySameHandle(app2, app1, ...
                'Nested construction should reuse the docked app.');

            app2.addBar('Label', 'Inner', 'Tag', 'inner');
            testCase.verifyNumElements(app1.ProgressBars, 2, ...
                'Both tasks should share one docked app.');
        end

        function testRemovingLastBarResetsPaneKeepsNavigator(testCase)
            navFig = testCase.Nav.Figure;

            app = ndi.gui.component.ProgressBarWindow('Reset Test', 'AutoDelete', true);
            app.addBar('Label', 'Only', 'Tag', 'only');
            app.updateBar('only', 1);   % complete
            app.removeBar('only');      % remove the last bar
            drawnow;

            testCase.verifyTrue(ishandle(navFig), ...
                'Navigator figure must survive removal of the last docked bar.');
            testCase.verifyEmpty(testCase.Pane.ActiveApp, ...
                'Pane should have no active app after the last bar is removed.');
        end

        function testDockFalseForcesStandalone(testCase)
            % Dock=false opts out of docking even with a navigator open.
            app = ndi.gui.component.ProgressBarWindow('Forced Window', ...
                'Dock', false, 'Visible', 'off');
            testCase.addTeardown(@delete, app.ProgressFigure);

            testCase.verifyFalse(app.IsDocked, 'App should not dock when Dock=false.');
            testCase.verifyClass(app.ProgressFigure, 'matlab.ui.Figure', ...
                'A standalone figure should be created when Dock=false.');
        end
    end
end
