% TestProgressBarWindow.m
classdef TestProgressBarWindow < matlab.unittest.TestCase
    % TestProgressBarWindow Unittests for ProgressBarWindow class.
    %
    %   Run with: results = runtests('TestProgressBarWindow');
    %
    %   Ensure ProgressBarWindow.m (and its package +ndi) is on the path.

    methods (TestClassSetup)
        % Add the path to the component under test
        function addComponentPath(testCase)
            % Assuming ProgressBarWindow.m is in a folder like:
            % .../YourProject/+ndi/+gui/+component/ProgressBarWindow.m
            % And this test file is e.g. .../YourProject/tests/TestProgressBarWindow.m
            % Adjust as necessary for your project structure.
            [testPath, ~] = fileparts(mfilename('fullpath'));
            [projectRoot, ~] = fileparts(testPath); % Assumes test is in a 'tests' subfolder
            addpath(fullfile(projectRoot)); % Add project root to access +ndi
            % If your +ndi package is structured differently, adjust path logic
            % For example, if +ndi is directly in projectRoot:
            % addpath(projectRoot);
            testCase.log(1, ['Test path: ', testPath]);
            testCase.log(1, ['Added to path: ', projectRoot]);
        end
    end

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

        function testConstructorOverwriteFalse(testCase)
            title = 'Overwrite Test';
            app1 = ndi.gui.component.ProgressBarWindow(title);
            testCase.addTeardown(@delete, app1.ProgressFigure); % Ensure app1 is deleted
            
            % Ensure app1's figure is drawn and guidata is set
            drawnow; 
            guidata(app1.ProgressFigure, app1);

            app2 = ndi.gui.component.ProgressBarWindow(title, 'Overwrite', false);
            % If it returned app1, app2.ProgressFigure should be app1.ProgressFigure
            testCase.verifySameHandle(app2.ProgressFigure, app1.ProgressFigure, ...
                'Should return handle to existing figure if Overwrite is false.');
        end

        function testConstructorOverwriteTrue(testCase)
            title = 'Overwrite Test';
            app1 = ndi.gui.component.ProgressBarWindow(title);
            fig1Handle = app1.ProgressFigure;
            testCase.addTeardown(@delete, fig1Handle); % Teardown for the first figure
            
            drawnow; % Ensure figure1 is registered

            app2 = ndi.gui.component.ProgressBarWindow(title, 'Overwrite', true);
            testCase.addTeardown(@delete, app2.ProgressFigure); % Teardown for the second figure

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
            testCase.verifyEqual(app.ProgressBars(1).Status, 'Open');
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
        end

        function testAddBarDuplicateTag(testCase)
            app = ndi.gui.component.ProgressBarWindow('Duplicate Tag Test');
            testCase.addTeardown(@delete, app.ProgressFigure);

            app.addBar('Tag', 'DupTag');
            initialNumBars = numel(app.ProgressBars);
            
            % Adding with duplicate tag should reset the existing bar, not add a new one
            testCase.verifyWarning(@() app.addBar('Tag', 'DupTag'), 'ProgressBarWindow:DuplicateTag');
            testCase.verifyNumElements(app.ProgressBars, initialNumBars, ...
                'Number of bars should not change when duplicate tag is added.');
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0, 'Progress should reset on duplicate tag.');
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

        % UpdateBar Tests
        function testUpdateBarProgress(testCase)
            app = ndi.gui.component.ProgressBarWindow('Update Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TUpdate');
            
            app.updateBar('TUpdate', 0.5);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 0.5, 'Progress not updated.');
            testCase.verifyEqual(app.ProgressBars(1).Percent.Text, '50%', 'Percent text not updated.');
            % Verify patch XData (assuming YData is [0 1 1 0])
            % Corrected XData: [0 progress progress 0]
            testCase.verifyEqual(app.ProgressBars(1).Patch.XData, [0 0.5 0.5 0], 'Patch XData not updated correctly.');
        end

        function testUpdateBarToComplete(testCase)
            app = ndi.gui.component.ProgressBarWindow('Complete Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TComplete');

            app.updateBar('TComplete', 1);
            testCase.verifyEqual(app.ProgressBars(1).Progress, 1);
            testCase.verifyEqual(app.ProgressBars(1).Percent.Text, '100%');
            testCase.verifyEqual(app.ProgressBars(1).Status, 'Complete', 'Status should be Complete.');
            testCase.verifyEqual(app.ProgressBars(1).Timer.Text, 'Complete', 'Timer text should be Complete.');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'success', 'Button icon should be success.');
        end

        function testUpdateBarNonExistent(testCase)
            app = ndi.gui.component.ProgressBarWindow('NonExistent Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            % Should warn but not error, and not add a bar
            testCase.verifyWarning(@() app.updateBar('TNonExistent', 0.5), 'ProgressBarWindow:InvalidBarID');
            testCase.verifyEmpty(app.ProgressBars, 'No bar should be created on update of non-existent.');
        end
        
        function testUpdateBarAfterManualClose(testCase)
            app = ndi.gui.component.ProgressBarWindow('Update Closed Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TClosed');
            
            % Manually close
            app.removeBar('TClosed', 'AutoClose', true); % Use AutoClose to suppress error
            
            % Attempting to update a closed bar should not error and ideally not warn
            % (getBarNum handles the warning if it's not found or is 'Closed')
            % The current getBarNum returns empty if closed (and not allowClosed)
            % which means updateBar will try to use an empty barNum, leading to index error.
            % The getBarNum in the provided code returns a status struct.
            app.updateBar('TClosed', 0.5); % This should be handled gracefully
            % No specific verification here other than it doesn't error hard.
            % The 'ProgressBarWindow:BarClosed' warning is expected from getBarNum.
            testCase.verifyWarning(@() app.updateBar('TClosed', 0.5), 'ProgressBarWindow:BarClosed');
        end

        % RemoveBar Tests
        function testRemoveBar(testCase)
            app = ndi.gui.component.ProgressBarWindow('Remove Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TRemove', 'Label', 'Item to Remove');
            app.addBar('Tag', 'TStay', 'Label', 'Item to Stay');
            
            initialRowCount = numel(app.ProgressGrid.RowHeight);

            % Simulate task completion before removal
            app.updateBar('TRemove', 1);
            app.removeBar('TRemove');
            
            testCase.verifyEqual(app.ProgressBars(1).Tag, 'TStay', 'Remaining bar is incorrect.');
            testCase.verifyEqual(app.ProgressBars(1).Status, 'Open', 'Remaining bar status incorrect.');
            testCase.verifyNumElements(app.ProgressGrid.RowHeight, initialRowCount - 2, 'Grid rows not removed.');
        end

        function testRemoveBarIncompleteError(testCase)
            app = ndi.gui.component.ProgressBarWindow('Remove Incomplete Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TIncomplete');
            
            testCase.verifyError(@() app.removeBar('TIncomplete'), 'ProgressBarWindow:UserTermination');
        end
        
        function testRemoveBarAutoClose(testCase)
            app = ndi.gui.component.ProgressBarWindow('AutoClose Remove Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TAutoRemove');
            
            % No error should be thrown if AutoClose is true (internal call)
            app.removeBar('TAutoRemove', 'AutoClose', true);
            testCase.verifyEmpty(app.ProgressGrid.RowHeight, 'Grid rows should be empty after removing only bar.');
        end


        % Button Press Test
        function testHandleButtonPressRemovesBar(testCase)
            app = ndi.gui.component.ProgressBarWindow('Button Press Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TButton');
            
            % Simulate task completion before allowing button removal without error
            app.updateBar('TButton', 1); 
            
            buttonHandle = app.ProgressBars(1).Button;
            
            % Programmatically press the button
            buttonHandle.ButtonPushedFcn(buttonHandle, []); % Pass empty event data
            
            drawnow; % Allow callbacks and deletions to process
            
            % Check if the bar was removed (ProgressGrid.RowHeight should be empty)
            testCase.verifyEmpty(app.ProgressGrid.RowHeight, ...
                'Bar should be removed after button press.');
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
            app = ndi.gui.component.ProgressBarWindow('Check Complete');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TCompleteCheck');
            
            app.updateBar('TCompleteCheck', 1); % This calls checkComplete internally
            
            testCase.verifyEqual(app.ProgressBars(1).Status, 'Complete');
            testCase.verifyEqual(app.ProgressBars(1).Timer.Text, 'Complete');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'success');
        end

        function testCheckTimeout(testCase)
            app = ndi.gui.component.ProgressBarWindow('Check Timeout');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            % Temporarily reduce timeout for testing
            originalTimeout = app.Timeout;
            app.Timeout = duration(0,0,0.1); % 0.1 seconds
            testCase.addTeardown(@() app.set('Timeout',originalTimeout)); % Restore original timeout
            
            app.addBar('Tag', 'TTimeoutCheck');
            app.updateBar('TTimeoutCheck', 0.1); % Initial update
            
            pause(0.2); % Wait longer than the timeout
            
            app.updateBar('TTimeoutCheck', 0.2); % Another update triggers checkTimeout
            
            testCase.verifyEqual(app.ProgressBars(1).Status, 'Timeout');
            testCase.verifyEqual(app.ProgressBars(1).Button.Icon, 'error');
        end
        
        function testGetStatus(testCase)
            app = ndi.gui.component.ProgressBarWindow('Get Status Test');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TStatus');
            
            status = app.getStatus('TStatus');
            testCase.verifyEqual(status, 'Open');
            
            app.updateBar('TStatus', 1);
            status = app.getStatus('TStatus');
            testCase.verifyEqual(status, 'Complete');
            
            statusNonExistent = app.getStatus('TNonExistent');
            testCase.verifyEmpty(statusNonExistent, "Status of non-existent bar should be empty.");
        end

        function testAutoCloseOnComplete(testCase)
            app = ndi.gui.component.ProgressBarWindow('Auto Close Complete');
            testCase.addTeardown(@delete, app.ProgressFigure);
            app.addBar('Tag', 'TAutoClose', 'Auto', true); % Auto is true

            app.updateBar('TAutoClose', 1); % Complete the bar
            drawnow; % Allow updates and auto-removal

            testCase.verifyEmpty(app.ProgressGrid.RowHeight, ...
                'Bar should be auto-closed on completion.');
        end
        
        function testAutoCloseOnTimeout(testCase)
            app = ndi.gui.component.ProgressBarWindow('Auto Close Timeout');
            testCase.addTeardown(@delete, app.ProgressFigure);
            
            originalTimeout = app.Timeout;
            app.Timeout = duration(0,0,0.1);
            testCase.addTeardown(@() app.set('Timeout',originalTimeout));
            
            app.addBar('Tag', 'TAutoTimeout', 'Auto', true);
            app.updateBar('TAutoTimeout', 0.1);
            
            pause(0.2); % Wait for timeout
            app.updateBar('TAutoTimeout', 0.2); % Trigger checks
            drawnow;

            testCase.verifyEmpty(app.ProgressGrid.RowHeight, ...
                'Bar should be auto-closed on timeout.');
        end

    end
end