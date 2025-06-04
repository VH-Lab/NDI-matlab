% TestProgressBarWindow.m
classdef TestProgressBarWindow < matlab.unittest.TestCase
    % TestProgressBarWindow Unittests for ProgressBarWindow class.
    %
    %   Run with: results = runtests('TestProgressBarWindow');
    %
    %   Ensure ProgressBarWindow.m (and its package +ndi) is on the path.

    methods (TestMethodTeardown)
        function closeAllProgressBars(testCase)
            % Close any progress bar figures created during tests
            figs = findall(groot, 'Type', 'figure', 'Tag', 'progressbar');
            delete(figs);
        end
    end

    methods (Test)
        % Constructor Tests
        function testConstructorDefault(testCase)
            app = ndi.gui.component.ProgressBarWindow();
            testCase.addTeardown(@delete, app.ProgressFigure);
            testCase.verifyClass(app.ProgressFigure, 'matlab.ui.Figure');
            testCase.verifyEmpty(app.ProgressFigure.Name, 'Default title should be empty.');
            testCase.verifyEmpty(app.ProgressBars, 'ProgressBars should be initialized empty.');
        end

        function testConstructorWithTitle(testCase)
            title = 'My Test Progress';
            app = ndi.gui.component.ProgressBarWindow(title);
            testCase.addTeardown(@delete, app.ProgressFigure);
            testCase.verifyEqual(app.ProgressFigure.Name, title, 'Title not set correctly.');
        end

        function testConstructorOverwriteFalseReturnsExisting(testCase)
            title = 'Overwrite Test False';
            app1 = ndi.gui.component.ProgressBarWindow(title);
            testCase.addTeardown(@delete, app1.ProgressFigure);
            guidata(app1.ProgressFigure, app1); % Save app instance
            drawnow;

            app2 = ndi.gui.component.ProgressBarWindow(title, 'Overwrite', false);
            testCase.verifySameHandle(app2.ProgressFigure, app1.ProgressFigure, ...
                'Should return handle to existing figure if Overwrite is false.');
            testCase.verifySameHandle(app2, app1, 'Should return the same app object.');
        end

        function testConstructorOverwriteFalseCreatesNewIfDifferentApp(testCase)
            title = 'Overwrite Test False Different App';
            fig = uifigure('Name',title,'Tag','progressbar'); % A plain figure, not our app
            testCase.addTeardown(@delete, fig);
            guidata(fig, struct('dummy',true)); % Put some other guidata
            drawnow;

            app = ndi.gui.component.ProgressBarWindow(title, 'Overwrite', false);
            testCase.addTeardown(@delete, app.ProgressFigure);

            testCase.verifyNotSameHandle(app.ProgressFigure, fig, ...
                'Should create a new figure if existing is not a ProgressBarWindow.');
            testCase.verifyFalse(ishandle(fig), 'Non-app figure should have been deleted.');
        end

        function testConstructorOverwriteTrue(testCase)
            title = 'Overwrite Test True';
            app1 = ndi.gui.component.ProgressBarWindow(title);
            fig1Handle = app1.ProgressFigure;
            guidata(app1.ProgressFigure, app1); % Save app instance
            testCase.addTeardown(@delete, fig1Handle); % Will be deleted by app2 creation
            drawnow;

            app2 = ndi.gui.component.ProgressBarWindow(title, 'Overwrite', true);
            testCase.addTeardown(@delete, app2.ProgressFigure);

            testCase.verifyNotSameHandle(app2.ProgressFigure, fig1Handle, ...
                'Should create a new figure if Overwrite is true.');
            testCase.verifyFalse(ishandle(fig1Handle), 'Old figure should be deleted.');
        end

        % AddBar Tests
        function testAddOneBar(testCase)
            app = ndi.gui.component.ProgressBarWindow('Add Bar Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            app.addBar('Label', 'Task 1', 'Tag', 'T1');
            testCase.verifyNumElements(app.ProgressBars, 1, 'Should have one progress bar.');
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'T1');
            testCase.verifyEqual(app.ProgressBars(1).Label.Text, 'Task 1');
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0);
            testCase.verifyEqual(app.ProgressBars(1).State, 'Open');
            testCase.verifyNotEmpty(app.ProgressBars(1).Axes, 'Axes handle should not be empty.');
            testCase.verifyNotEmpty(app.ProgressBars(1).Patch, 'Patch handle should not be empty.');
        end

        function testAddMultipleBars(testCase)
            app = ndi.gui.component.ProgressBarWindow('Multi Bar Test');
            testCase.addTeardown(@delete, app.ProgressFigure);

            app.addBar('Label', 'Task A', 'Tag', 'TA');
            app.addBar('Label', 'Task B', 'Tag', 'TB');
            testCase.verifyNumElements(app.ProgressBars, 2, 'Should have two progress bars.');
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'TA');
            testCase.verifyEqual(app.ProgressBars(2).Tag, 'TB');
            testCase.verifyNumElements(app.ProgressGrid.RowHeight, 4, 'Grid should have 4 rows.');
        end

        function testAddBarDuplicateTagResets(testCase)
            app = ndi.gui.component.ProgressBarWindow('Duplicate Tag Test');
            testCase.addTeardown(@delete, app.ProgressFigure);

            app.addBar('Tag', 'DupTag');
            app.updateBar('DupTag', 0.5); % Set some progress
            
            testCase.verifyWarning(@() app.addBar('Tag', 'DupTag'), 'ProgressBarWindow:DuplicateTag');
            testCase.verifyNumElements(app.ProgressBars, 1, ...
                'Number of bars should not change when duplicate tag is added.');
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0, 'Progress should reset on duplicate tag.');
        end

        function testAddBarDuplicateTagWhenClosed(testCase)
            app = ndi.gui.component.ProgressBarWindow('Duplicate Closed Tag Test');
            testCase.addTeardown(@delete, app.ProgressFigure);

            app.addBar('Tag', 'DupTagClosed');
            app.ProgressBars(1).State = 'Closed'; % Manually mark as closed
            
            app.addBar('Tag', 'DupTagClosed', 'Label', 'New Bar Same Tag'); % Should add a new bar
            
            testCase.verifyNumElements(app.ProgressBars, 1, ... % Assuming the closed one is removed from active list internally
                'Should have 1 bar if old one was closed and removed from struct.');
            % If the old one is simply overwritten by the new one due to removal then re-add:
            activeBars = app.ProgressBars(~strcmpi({app.ProgressBars.State}, 'Closed'));
            testCase.verifyNumElements(activeBars, 1);
            testCase.verifyEqual(activeBars(1).Label.Text, 'New Bar Same Tag');
        end
        
        function testAddBarDefaultColor(testCase)
            app = ndi.gui.component.ProgressBarWindow('Default Color Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            app.addBar('Tag', 'ColorTest');
            patchColor = app.ProgressBars(1).Patch.FaceColor;
            testCase.verifyFalse(all(patchColor == [1 1 1]), 'Default color should not be white.');
            testCase.verifyTrue(sum(patchColor) >= 1.5 && sum(patchColor) <= 2.8, ...
                'Random color sum is out of expected bounds.');
        end

        function testAddBarProvidedColor(testCase)
            app = ndi.gui.component.ProgressBarWindow('Provided Color Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            testColor = [0.1 0.2 0.3];
            app.addBar('Tag', 'ColorTestProvided', 'Color', testColor);
            patchColor = app.ProgressBars(1).Patch.FaceColor;
            testCase.verifyEqual(patchColor, testColor, 'Provided color not used.');
        end

        % UpdateBar Tests
        function testUpdateBarProgress(testCase)
            app = ndi.gui.component.ProgressBarWindow('Update Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TUpdate');
            
            app.updateBar('TUpdate', 0.5);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0.5, 'Progress not updated.');
            testCase.verifyEqual(app.ProgressBars(1).Percent.Text, '50%', 'Percent text not updated.');
            testCase.verifyEqual(app.ProgressBars(1).Patch.XData, [0; 0.5; 0.5; 0], 'Patch XData not updated correctly.');
            testCase.verifyEqual(app.ProgressBars(1).Patch.YData, [0; 0; 1; 1], 'Patch YData should be for full height.');
        end

        function testUpdateBarToComplete(testCase)
            app = ndi.gui.component.ProgressBarWindow('Complete Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TComplete');

            app.updateBar('TComplete', 1);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 1);
            testCase.verifyEqual(app.ProgressBars(1).Percent.Text, '100%');
            testCase.verifyEqual(app.ProgressBars(1).State, 'Complete', 'Status should be Complete.');
            testCase.verifyEqual(app.ProgressBars(1).Timer.Text, 'Complete', 'Timer text should be Complete.');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'success', 'Button icon should be success.');
        end

        function testUpdateBarNonExistent(testCase)
            app = ndi.gui.component.ProgressBarWindow('NonExistent Test');
            testCase.addTeardown(@delete, app.ProgressFigure);

            testCase.verifyWarning(@() app.updateBar('TNonExistent', 0.5), 'ProgressBarWindow:NoBarsExist');
            testCase.verifyEmpty(app.ProgressBars, 'No bar should be created on update of non-existent.');
        end

        function testUpdateBarAutoCloseMultipleCorrectly(testCase)
            app = ndi.gui.component.ProgressBarWindow('Auto Close Multi');
            testCase.addTeardown(@delete, app.ProgressFigure);

            app.addBar('Tag', 'AC1', 'Auto', true);
            app.addBar('Tag', 'AC2', 'Auto', true);
            app.addBar('Tag', 'NoAC', 'Auto', false);
            app.addBar('Tag', 'AC3', 'Auto', true);

            % Mark AC1 and AC3 as complete by updating them
            app.updateBar('AC1', 1); % This update should also trigger their auto-removal
            app.updateBar('AC3', 1); % This update should also trigger their auto-removal

            % Update a non-auto-close bar to ensure the auto-close for others has processed
            app.updateBar('NoAC', 0.5);
            drawnow;

            testCase.verifyEqual(app.getState('AC1'), 'Closed');
            testCase.verifyEqual(app.getState('AC3'), 'Closed');
            testCase.verifyEqual(app.getState('AC2'), 'Open');
            testCase.verifyEqual(app.getState('NoAC'), 'Open');

            % Count bars that are NOT closed
            openOrActiveCount = sum(~strcmpi({app.ProgressBars.State}, 'Closed'));
            testCase.verifyEqual(openOrActiveCount, 2, 'Only AC2 and NoAC should remain effectively open/active in the struct logic.');
            testCase.verifyNumElements(app.ProgressGrid.RowHeight, 2 * 2, 'Grid should have rows for 2 bars.');
        end

        % RemoveBar Tests
        function testRemoveBar(testCase)
           app = ndi.gui.component.ProgressBarWindow('Remove Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TRemove', 'Label', 'Item to Remove');
            app.addBar('Tag', 'TStay', 'Label', 'Item to Stay');
            
            initialRowCount = numel(app.ProgressGrid.RowHeight); % Should be 4

            app.updateBar('TRemove', 1); % Mark as complete to avoid error on removal
            app.removeBar('TRemove');
            
            testCase.verifyNumElements(app.ProgressBars, 2, 'The deleted bar should still remain in progress bars.');
            
            % Verify properties of remaining bar
            testCase.verifyEqual(app.ProgressBars(2).Tag, 'TStay', 'Remaining bar is incorrect.');
            testCase.verifyEqual(app.ProgressBars(2).State, 'Open', 'Remaining bar state incorrect.');
            testCase.verifyNumElements(app.ProgressGrid.RowHeight, initialRowCount - 2, 'Grid rows not removed correctly.');
            testCase.verifyEqual(app.ProgressBars(2).Label.Layout.Row, 1);
            testCase.verifyEqual(app.ProgressBars(2).Axes.Layout.Row, 2);

            % Verify properties of removed bar
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'TRemove', 'Removed bar is incorrect.');
            testCase.verifyEqual(app.ProgressBars(1).State, 'Closed', 'Removed bar state incorrect.');
            testCase.verifyFalse(isvalid(app.ProgressBars(1).Patch),'Removed bar patch was not deleted.')
        end

        function testRemoveBarIncompleteWarning(testCase)
            app = ndi.gui.component.ProgressBarWindow('Remove Incomplete Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TIncomplete');
            
            testCase.verifyWarning(@() app.removeBar('TIncomplete'), 'ProgressBarWindow:BarRemoved');
        end

        function testRemoveBarIncompleteDifferentStates(testCase)
            % Test 'Button' state leading to UserTermination error
            app = ndi.gui.component.ProgressBarWindow();
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TButtonTerm');
            app.ProgressBars(1).State = 'Button'; % Simulate state set by handleButtonPress
            testCase.verifyError(@() app.removeBar('TButtonTerm'), 'ProgressBarWindow:UserTermination');
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar')); % Cleanup

            % Test 'Timeout' state leading to AutoCloseOnTimeout error
            app = ndi.gui.component.ProgressBarWindow();
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TTimeoutTerm');
            app.ProgressBars(1).State = 'Timeout';
            testCase.verifyError(@() app.removeBar('TTimeoutTerm'), 'ProgressBarWindow:AutoCloseOnTimeout');
            delete(findall(groot, 'Type', 'figure', 'Tag', 'progressbar'));

            % Test 'Open' state leading to BarRemoved warning
            app = ndi.gui.component.ProgressBarWindow();
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TOpenTerm');
            app.ProgressBars(1).State = 'Open'; % Default state if not completed
            testCase.verifyWarning(@() app.removeBar('TOpenTerm'), 'ProgressBarWindow:BarRemoved');
        end

        % Button Press Test
        function testHandleButtonPressRemovesBar(testCase)
            app = ndi.gui.component.ProgressBarWindow('Button Press Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TButton');
            
            app.updateBar('TButton', 1); % Complete it so removeBar doesn't error
            
            buttonHandle = app.ProgressBars(1).Button;
            
            buttonHandle.ButtonPushedFcn(buttonHandle, []); % Programmatic press
            drawnow; 
            
            testCase.verifyNumElements(app.ProgressBars,1, 'Bar metadata should remain after button press.');
            testCase.verifyEmpty(app.ProgressGrid.RowHeight, 'Grid rows should be empty.');
            testCase.verifyFalse(isvalid(app.ProgressBars(1).Patch),'Bar patch should be deleted after button press.')
        end

        % SetFigureTitle Test
        function testSetFigureTitle(testCase)
            app = ndi.gui.component.ProgressBarWindow();
            testCase.addTeardown(@delete, app.ProgressFigure);
            newTitle = 'New Progress Title';
            app.setFigureTitle(newTitle);
            testCase.verifyEqual(app.ProgressFigure.Name, newTitle);
        end

        % Status Checks
        function testCheckComplete(testCase)
            app = ndi.gui.component.ProgressBarWindow('Check Complete Method');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TCheckComplete');
            app.ProgressBars(1).Progress = 1; % Manually set progress

            app.checkComplete(); % Call the method directly

            testCase.verifyEqual(app.ProgressBars(1).State, 'Complete');
            testCase.verifyEqual(app.ProgressBars(1).Timer.Text, 'Complete');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'success');
        end

        function testCheckTimeout(testCase)
            app = ndi.gui.component.ProgressBarWindow('Check Timeout Method');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            originalTimeout = app.Timeout;
            app.setTimeout(duration(0,0,0.1)); % 0.1 seconds
            testCase.addTeardown(@() setfield(app,'Timeout',originalTimeout));
            
            app.addBar('Tag', 'TCheckTimeout');
            app.ProgressBars(1).Clock{2} = datetime('now') - duration(0,0,0.2); % Simulate last update was 0.2s ago
            app.ProgressBars(1).Progress = 0.5; % Not complete
            
            app.checkTimeout();
            
            testCase.verifyEqual(app.ProgressBars(1).State, 'Timeout');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'error');
        end
        
        function testGetState(testCase)
            app = ndi.gui.component.ProgressBarWindow('Get State Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TGetState');
            
            state = app.getState('TGetState');
            testCase.verifyEqual(state, 'Open');
            
            app.ProgressBars(1).State = 'Complete'; % Manually change
            state = app.getState('TGetState');
            testCase.verifyEqual(state, 'Complete');
            
            % Test non-existent
            testCase.verifyWarning(@() app.getState('TNonExistent'), 'ProgressBarWindow:InvalidBarTag');
            stateNonExistent = app.getState('TNonExistent');
            testCase.verifyEmpty(stateNonExistent);
        end

        function testAutoCloseOnComplete(testCase)
            app = ndi.gui.component.ProgressBarWindow('Auto Close Complete');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TAutoClose', 'Auto', true);

            app.updateBar('TAutoClose', 1); % This will trigger checkComplete and auto-close
            drawnow;
            
            testCase.verifyNumElements(app.ProgressBars, 1, 'The auto-closed bar should still remain in progress bars.');
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'TAutoClose', 'Auto-closed bar tag is incorrect.');
            testCase.verifyEqual(app.ProgressBars(1).State, 'Closed', 'Auto-closed bar state incorrect.');
            testCase.verifyFalse(isvalid(app.ProgressBars(1).Patch),'Auto-closed bar patch was not deleted.')
        end
        
        function testAutoCloseOnTimeout(testCase)
            app = ndi.gui.component.ProgressBarWindow('Auto Close Timeout');
            testCase.addTeardown(@delete, app.ProgressFigure);

            originalTimeout = app.Timeout;
            app.setTimeout(duration(0,0,0.1)); % 0.1 seconds
            testCase.addTeardown(@() setfield(app,'Timeout',originalTimeout));

            app.addBar('Tag', 'TAutoTimeout', 'Auto', true);
            app.addBar('Tag', 'TUpdated', 'Auto', true);
            
            pause(0.2); % Wait for timeout
            testCase.verifyError(@() app.updateBar('TUpdated', 0.2), 'ProgressBarWindow:AutoCloseOnTimeout');
        end

    end
end