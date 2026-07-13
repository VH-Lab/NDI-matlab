% TestNavigatorLayout.m
classdef TestNavigatorLayout < matlab.unittest.TestCase
    % TestNavigatorLayout Tests the navigator's content-driven layout model.
    %
    %   Verifies that the panes fill the window (no dead space), that the
    %   elastic Datasets pane absorbs a window resize, and that collapsing a
    %   pane shrinks the window while expanding grows it.
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
            testCase.Nav = ndi.gui.navigator('Position', [100 100 300 500], ...
                'Visible', 'off');
            testCase.addTeardown(@() delete(testCase.Nav.Figure));
        end
    end

    methods (TestMethodTeardown)
        function closeStrays(~)
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (Test)
        function testPanesFillWindow(testCase)
            % The pane rows should consume essentially the whole window
            % height (only padding/spacing left over), i.e. no dead space.
            rows = cell2mat(testCase.Nav.RootGrid.RowHeight);
            figH = testCase.Nav.Figure.Position(4);
            testCase.verifyGreaterThan(sum(rows), figH - 40, ...
                'Pane rows should fill the window (no large dead space).');
            testCase.verifyLessThanOrEqual(sum(rows), figH, ...
                'Pane rows should not exceed the window height.');
        end

        function testDatasetsAbsorbsWindowResize(testCase)
            ds = testCase.datasetsPane();
            h0 = ds.RenderedHeight;

            % Grow the window; the elastic Datasets pane should take the space.
            pos = testCase.Nav.Figure.Position;
            testCase.Nav.Figure.Position = [pos(1) pos(2) pos(3) pos(4)+120];
            drawnow;

            testCase.verifyGreaterThan(ds.RenderedHeight, h0 + 100, ...
                'Datasets should grow to absorb a larger window.');
        end

        function testCollapseProgressShrinksWindow(testCase)
            h0 = testCase.Nav.Figure.Position(4);
            testCase.progressPane().toggle();   % collapse
            drawnow;
            testCase.verifyLessThan(testCase.Nav.Figure.Position(4), h0, ...
                'Collapsing Progress should shrink the window.');

            testCase.progressPane().toggle();   % expand again
            drawnow;
            testCase.verifyEqual(testCase.Nav.Figure.Position(4), h0, ...
                'AbsTol', 2, 'Expanding Progress should restore the height.');
        end

        function testCollapseDatasetsShrinksWindow(testCase)
            h0 = testCase.Nav.Figure.Position(4);
            testCase.datasetsPane().toggle();   % collapse the elastic pane
            drawnow;
            testCase.verifyLessThan(testCase.Nav.Figure.Position(4), h0, ...
                'Collapsing Datasets should shrink the window.');
        end

        function testCollapseAllShrinksBelowFloor(testCase)
            % Collapsing every collapsible pane should shrink the window to
            % the collapsed pane stack, not stop at the initial 300px floor.
            testCase.datasetsPane().toggle();
            testCase.progressPane().toggle();
            drawnow;

            rows = cell2mat(testCase.Nav.RootGrid.RowHeight);
            figH = testCase.Nav.Figure.Position(4);
            testCase.verifyLessThan(figH, 300, ...
                'Fully collapsed window should shrink below the 300px floor.');
            testCase.verifyLessThanOrEqual(sum(rows), figH, ...
                'Pane rows should still fit within the window.');
        end
    end

    methods (Access = private)
        function p = progressPane(testCase)
            p = testCase.Nav.progressPaneHandle();
        end

        function p = datasetsPane(testCase)
            p = [];
            for i = 1:numel(testCase.Nav.Panes)
                if isa(testCase.Nav.Panes{i}, 'ndi.gui.nav.datasetsPane')
                    p = testCase.Nav.Panes{i};
                    return;
                end
            end
        end
    end
end
