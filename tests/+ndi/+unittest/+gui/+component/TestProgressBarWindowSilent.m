% TestProgressBarWindowSilent.m
classdef TestProgressBarWindowSilent < matlab.unittest.TestCase
    % TestProgressBarWindowSilent Tests for the silent (headless) mode of
    %   ndi.gui.component.ProgressBarWindow.
    %
    %   Creating a uifigure spawns a MATLABWindow (CEF) process, whose
    %   launch can fail in a headless context with a silent timeout rather
    %   than an error, stalling the calling job (VH-Lab/NDI-matlab#941). The
    %   class now detects headless contexts and, in that mode, creates no
    %   figure at all while keeping every piece of its bookkeeping.
    %
    %   The failure being fixed is a hang, not a red test, so a green CI run
    %   does not by itself demonstrate that the guard works - CI would be
    %   green whether the guard fired or the uifigure launch simply happened
    %   to succeed. These tests are the actual evidence. Two groups matter
    %   most:
    %
    %       * testNoFigureIsCreated* assert directly that NO figure comes
    %         into existence across a construct/addBar/updateBar cycle. That
    %         is what proves the GUI launch is not merely fast, but absent.
    %       * the bookkeeping tests assert that the no-op path still tracks
    %         bars, progress, completion and timeouts, so that "no window"
    %         does not quietly mean "does nothing useful".
    %
    %   Every test pins the rendering decision explicitly (via the 'Silent'
    %   argument or the silentModeDefault override) instead of relying on
    %   detection, so both modes are exercised whatever display the runner
    %   happens to have.
    %
    %   Run with: results = runtests('ndi.unittest.gui.component.TestProgressBarWindowSilent');
    %
    %   See also: ndi.gui.component.ProgressBarWindow,
    %       ndi.unittest.gui.component.TestProgressBarWindow

    methods (TestClassSetup)
        function cleanUpBeforeAllTests(testCase)
            % No stray windows from earlier suites, and no navigator (which
            % would otherwise offer to dock the bars).
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'));
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));

            % Leave the process-wide override exactly as it was found.
            previousSilentDefault = ndi.gui.component.ProgressBarWindow.silentModeDefault();
            testCase.addTeardown(@() ...
                ndi.gui.component.ProgressBarWindow.silentModeDefault(previousSilentDefault));
        end
    end

    methods (TestMethodSetup)
        function clearOverride(~)
            % Each test starts from "detection decides" and sets the
            % override itself if it needs one.
            ndi.gui.component.ProgressBarWindow.silentModeDefault([]);
        end
    end

    methods (TestMethodTeardown)
        function closeStrays(~)
            ndi.gui.component.ProgressBarWindow.silentModeDefault([]);
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'));
            delete(findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator'));
        end
    end

    methods (Test)

        % ---------------------------------------------------------------
        % The headless decision. These need no display in either
        % direction, because the decision is injected rather than detected.
        % ---------------------------------------------------------------

        function testIsHeadlessMatchesDocumentedSignals(testCase)
            % isHeadless is exactly "started with -batch, or an empty
            % DISPLAY on Linux". Asserting the rule rather than a fixed
            % answer keeps this meaningful on any runner.
            expected = batchStartupOptionUsed;
            if ~expected && isunix() && ~ismac()
                expected = isempty(getenv('DISPLAY'));
            end

            actual = ndi.gui.component.ProgressBarWindow.isHeadless();

            testCase.verifyClass(actual, 'logical');
            testCase.verifyTrue(isscalar(actual), 'isHeadless must return a scalar.');
            testCase.verifyEqual(actual, logical(expected));
        end

        function testOverrideWinsOverDetection(testCase)
            import ndi.gui.component.ProgressBarWindow

            ProgressBarWindow.silentModeDefault(true);
            testCase.verifyTrue(ProgressBarWindow.resolveSilentMode([]), ...
                'Override of true should force silent mode.');

            % The direction that matters for testing the windowed path: the
            % test process itself runs under -batch in CI, so without this
            % the graphics suites would have no figure to assert on.
            ProgressBarWindow.silentModeDefault(false);
            testCase.verifyFalse(ProgressBarWindow.resolveSilentMode([]), ...
                'Override of false should force windowed mode, even under -batch.');
        end

        function testExplicitArgumentWinsOverOverride(testCase)
            import ndi.gui.component.ProgressBarWindow

            ProgressBarWindow.silentModeDefault(false);
            testCase.verifyTrue(ProgressBarWindow.resolveSilentMode(true), ...
                'An explicit Silent=true should beat an override of false.');

            ProgressBarWindow.silentModeDefault(true);
            testCase.verifyFalse(ProgressBarWindow.resolveSilentMode(false), ...
                'An explicit Silent=false should beat an override of true.');
        end

        function testClearingOverrideRestoresDetection(testCase)
            import ndi.gui.component.ProgressBarWindow

            ProgressBarWindow.silentModeDefault(true);
            ProgressBarWindow.silentModeDefault([]);

            testCase.verifyEmpty(ProgressBarWindow.silentModeDefault(), ...
                'Passing [] should clear the override.');
            testCase.verifyEqual(ProgressBarWindow.resolveSilentMode([]), ...
                ProgressBarWindow.isHeadless(), ...
                'With no override, resolution should fall through to detection.');
        end

        % ---------------------------------------------------------------
        % The core evidence: no figure is created.
        % ---------------------------------------------------------------

        function testNoFigureIsCreatedInSilentMode(testCase)
            % The headline assertion for issue #941. A full
            % construct/addBar/updateBar cycle must not bring a single
            % figure into existence.
            figuresBefore = findall(groot, 'Type', 'figure');

            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 0.5);

            figuresAfter = findall(groot, 'Type', 'figure');

            testCase.verifyTrue(app.Silent, 'App should report silent mode.');
            testCase.verifyEmpty(app.ProgressFigure, ...
                'No uifigure should have been created in silent mode.');
            testCase.verifyEmpty(app.ProgressGrid, ...
                'No uigridlayout should have been created in silent mode.');
            testCase.verifyEqual(numel(figuresAfter), numel(figuresBefore), ...
                'Silent mode must not add any figure to the graphics root.');
            testCase.verifyEmpty(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'), ...
                'No figure tagged progressbar should exist.');
        end

        function testNoFigureIsCreatedWhenDetectionSaysHeadless(testCase)
            % The same proof through the path the 21 production call sites
            % actually take: a plain constructor call, with the headless
            % decision coming from detection (here forced, so that this
            % holds on a runner with a display too).
            ndi.gui.component.ProgressBarWindow.silentModeDefault(true);

            figuresBefore = findall(groot, 'Type', 'figure');

            app = ndi.gui.component.ProgressBarWindow('Import Dataset');
            testCase.addTeardown(@() delete(app));
            app.addBar('Label', 'Create Session(s)', 'Tag', 'session');
            app.updateBar('session', 0.25);

            testCase.verifyTrue(app.Silent, ...
                'Detection should have selected silent mode.');
            testCase.verifyEmpty(app.ProgressFigure, ...
                'A plain constructor call must not create a figure when headless.');
            testCase.verifyEqual(numel(findall(groot, 'Type', 'figure')), ...
                numel(figuresBefore), ...
                'No figure should be added to the graphics root.');
        end

        function testGraphicsFieldsStayEmptyInSilentMode(testCase)
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');

            bar = app.ProgressBars(1);
            testCase.verifyEmpty(bar.Axes,    'No axes should be created.');
            testCase.verifyEmpty(bar.Patch,   'No patch should be created.');
            testCase.verifyEmpty(bar.Percent, 'No percent label should be created.');
            testCase.verifyEmpty(bar.Button,  'No button should be created.');
            testCase.verifyEmpty(bar.Label,   'No label should be created.');
            testCase.verifyEmpty(bar.Timer,   'No timer label should be created.');
        end

        % ---------------------------------------------------------------
        % The bookkeeping must still work, or "no window" would just mean
        % "does nothing".
        % ---------------------------------------------------------------

        function testAddBarRecordsBookkeeping(testCase)
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');

            testCase.verifyNumElements(app.ProgressBars, 1);
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'task');
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0);
            testCase.verifyEqual(app.getState('task'), 'Open');
        end

        function testAddBarDefaultsTagToLabel(testCase)
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Just A Label');

            testCase.verifyEqual(app.ProgressBars(1).Tag, 'Just A Label');
            testCase.verifyEqual(app.getBarNum('Just A Label'), 1);
        end

        function testUpdateBarRecordsProgress(testCase)
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');

            app.updateBar('task', 0.4);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0.4);
            testCase.verifyEqual(app.getState('task'), 'Open');

            app.updateBar('task', 0.75);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0.75);
        end

        function testGetBarNumByTagAndIndex(testCase)
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'First',  'Tag', 'one');
            app.addBar('Label', 'Second', 'Tag', 'two');

            testCase.verifyEqual(app.getBarNum('one'), 1);
            testCase.verifyEqual(app.getBarNum('two'), 2);
            testCase.verifyEqual(app.getBarNum(2), 2);

            [barNum, status] = app.getBarNum('nope');
            testCase.verifyEmpty(barNum);
            testCase.verifyEqual(status.identifier, 'ProgressBarWindow:InvalidBarTag');
        end

        function testCheckCompleteInSilentMode(testCase)
            % Reaching 100% must flag the bar complete. This also runs the
            % success-icon path with no button behind it.
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');

            app.updateBar('task', 1);

            testCase.verifyEqual(app.getState('task'), 'Complete');
            testCase.verifyEqual(app.checkComplete(), 1);
        end

        function testCheckTimeoutInSilentMode(testCase)
            % Timeout tracking must survive, and the error-icon path must
            % tolerate the absent button.
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 0.5);
            testCase.verifyEqual(app.getState('task'), 'Open');

            app.setTimeout(seconds(0));
            timedOut = app.checkTimeout();

            testCase.verifyEqual(timedOut, 1, 'The stale bar should be reported.');
            testCase.verifyEqual(app.getState('task'), 'Timeout');
        end

        function testRemoveBarInSilentMode(testCase)
            app = testCase.makeSilentApp('Silent Window', 'AutoDelete', false);
            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 1);

            app.removeBar('task');

            testCase.verifyEqual(app.getState('task'), 'Closed');
            testCase.verifyTrue(isvalid(app), ...
                'With AutoDelete off, the app should outlive its last bar.');
        end

        function testAutoDeleteAfterLastBarInSilentMode(testCase)
            % Exercises the silent branch of deleteIfNoOpenBars: there is no
            % figure to close, so the app is simply dropped.
            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 1);

            app.removeBar('task');

            testCase.verifyFalse(isvalid(app), ...
                'AutoDelete should delete the app once no bars remain.');
        end

        function testAutoBarRemovesItselfOnCompletion(testCase)
            app = testCase.makeSilentApp('Silent Window', 'AutoDelete', false);
            app.addBar('Label', 'Task', 'Tag', 'task', 'Auto', true);

            app.updateBar('task', 1);

            testCase.verifyEqual(app.getState('task'), 'Closed', ...
                'An Auto bar should close itself when it completes.');
        end

        function testMultipleBarsTrackedIndependently(testCase)
            app = testCase.makeSilentApp('Silent Window', 'AutoDelete', false);
            app.addBar('Label', 'First',  'Tag', 'one');
            app.addBar('Label', 'Second', 'Tag', 'two');

            app.updateBar('one', 1);
            app.updateBar('two', 0.3);

            testCase.verifyNumElements(app.ProgressBars, 2);
            testCase.verifyEqual(app.getState('one'), 'Complete');
            testCase.verifyEqual(app.getState('two'), 'Open');
            testCase.verifyEqual(app.ProgressBars(2).Progress, 0.3);
        end

        function testDuplicateTagResetsBarInSilentMode(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('ProgressBarWindow:DuplicateTag'));

            app = testCase.makeSilentApp('Silent Window');
            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 0.6);

            app.addBar('Label', 'Task', 'Tag', 'task');

            testCase.verifyNumElements(app.ProgressBars, 1, ...
                'A duplicate tag should reset the existing bar, not add one.');
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0);
        end

        function testTitleIsRecordedWithoutAFigure(testCase)
            % setFigureTitle has no figure to write to; it must not error,
            % and the title stays available on the object.
            app = testCase.makeSilentApp('My Batch Job');

            testCase.verifyEqual(app.WindowTitle, 'My Batch Job');

            app.setFigureTitle('Renamed');
            testCase.verifyEqual(app.WindowTitle, 'Renamed');
            testCase.verifyEmpty(app.ProgressFigure);
        end

        function testUpdateUnknownBarWarnsInSilentMode(testCase)
            app = testCase.makeSilentApp('Silent Window');

            % No bars yet: this must warn and return, not error on missing
            % graphics.
            testCase.verifyWarning(@() app.updateBar('missing', 0.5), ...
                'ProgressBarWindow:NoBarsExist');
        end

        % ---------------------------------------------------------------
        % The other direction: forcing windowed mode still builds a figure,
        % so the guard is genuinely opt-out-able and the graphics path is
        % unchanged.
        % ---------------------------------------------------------------

        function testForcedWindowedModeStillCreatesFigure(testCase)
            app = ndi.gui.component.ProgressBarWindow('Windowed', ...
                'Silent', false, 'Visible', 'off', 'AutoDelete', false);
            testCase.addTeardown(@() delete(app.ProgressFigure));

            testCase.verifyFalse(app.Silent, 'Silent=false should be honoured.');
            testCase.verifyClass(app.ProgressFigure, 'matlab.ui.Figure');
            testCase.verifyTrue(isvalid(app.ProgressFigure), ...
                'A figure should exist when silent mode is refused.');

            app.addBar('Label', 'Task', 'Tag', 'task');
            app.updateBar('task', 0.5);
            testCase.verifyNotEmpty(app.ProgressBars(1).Patch, ...
                'The windowed path should still build bar graphics.');
        end

    end

    methods (Access = private)
        function app = makeSilentApp(testCase, title, varargin)
            %makeSilentApp Construct a silent window and clean it up after.
            app = ndi.gui.component.ProgressBarWindow(title, varargin{:}, ...
                'Silent', true);
            testCase.addTeardown(@() delete(app));
        end
    end
end
