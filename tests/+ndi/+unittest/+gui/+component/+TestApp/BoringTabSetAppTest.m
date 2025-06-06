classdef BoringTabSetAppTest < matlab.unittest.TestCase
    % BoringTabSetAppTest - Unit tests for the BoringTabSetApp
    %
    % To run these tests, save this file as 'BoringTabSetAppTest.m'
    % on your MATLAB path and run the command:
    % >> runtests('BoringTabSetAppTest')
    %
    % Alternatively, open the "Tests" tab in the MATLAB toolstrip
    % and click the "Run Tests" button.

    properties
        % This property will hold a handle to the app instance
        % so all test methods can access it.
        AppHandle
    end

    methods (TestClassSetup)
        % The TestClassSetup method runs once before any of the tests in
        % this class. It's the ideal place to create the GUI.
        function setupApp(testCase)
            % Create an instance of the app and store its handle
            testCase.AppHandle = ndi.gui.component.TestApp.BoringTabSetApp();
            
            % Use 'drawnow' to ensure the app has fully rendered and is
            % ready for interaction before any tests begin.
            drawnow;
        end
    end

    methods (TestClassTeardown)
        % The TestClassTeardown method runs once after all tests have
        % finished. This is where we clean up by deleting the app figure.
        function teardownApp(testCase)
            delete(testCase.AppHandle);
        end
    end

    methods (Test)
        % Each method with the (Test) attribute is an individual test case.

        function testAppCreationAndInitialState(testCase)
            % This test verifies that the app was created correctly and
            % is in the expected initial state.
            
            % 1. Verify the app handle is a valid object of the correct class
            testCase.verifyClass(testCase.AppHandle, 'ndi.gui.component.TestApp.BoringTabSetApp', ...
                'The app handle should be of the correct class.');
            testCase.verifyTrue(isvalid(testCase.AppHandle), 'The app handle should be valid.');

            % 2. Verify the main figure was created
            testCase.verifyTrue(isvalid(testCase.AppHandle.TSCFigure), 'The main UI figure should be created and valid.');
            
            % 3. Verify the correct number of tabs were created
            testCase.verifyNumElements(testCase.AppHandle.TabGroup.Children, 3, ...
                'The app should start with 3 tabs.');
                
            % 4. Verify the initial button visibility
            testCase.verifyFalse(testCase.AppHandle.Footer.PreviousTabButton.Visible, ...
                'The "Previous" button should be invisible on the first tab.');
            testCase.verifyTrue(testCase.AppHandle.Footer.NextTabButton.Visible, ...
                'The "Next" button should be visible on the first tab.');
        end

        function testNextButtonFunctionality(testCase)
            % This test verifies that the "Next" button works as expected.
            
            % 1. Programmatically "press" the Next button.
            % We do this by getting a handle to the button and executing its callback function.
            nextButton = testCase.AppHandle.Footer.NextTabButton;
            nextButton.ButtonPushedFcn(testCase.AppHandle, []); % The second argument can be empty for this callback
            drawnow; % Allow UI to update
            
            % 2. Verify the state has changed correctly
            testCase.verifyEqual(testCase.AppHandle.TabGroup.SelectedTab.Title, 'Boring Tab 2', ...
                'The selected tab should now be the second one.');
            
            % 3. Verify button visibility has updated
            testCase.verifyTrue(testCase.AppHandle.Footer.PreviousTabButton.Visible, ...
                'The "Previous" button should now be visible.');
        end

        function testPreviousButtonAndTabLimits(testCase)
            % This test verifies the "Previous" button and the visibility logic at the ends.
            
            % 1. Get to the last tab
            nextButton = testCase.AppHandle.Footer.NextTabButton;
            nextButton.ButtonPushedFcn(testCase.AppHandle, []); % Go to Tab 2
            nextButton.ButtonPushedFcn(testCase.AppHandle, []); % Go to Tab 3
            drawnow;
            
            % 2. Verify state on the last tab
            testCase.verifyEqual(testCase.AppHandle.TabGroup.SelectedTab.Title, 'Boring Tab 3', ...
                'The selected tab should be the third one.');
            testCase.verifyFalse(testCase.AppHandle.Footer.NextTabButton.Visible, ...
                'The "Next" button should be invisible on the last tab.');

            % 3. Programmatically "press" the Previous button
            previousButton = testCase.AppHandle.Footer.PreviousTabButton;
            previousButton.ButtonPushedFcn(testCase.AppHandle, []);
            drawnow;

            % 4. Verify the state has changed correctly
            testCase.verifyEqual(testCase.AppHandle.TabGroup.SelectedTab.Title, 'Boring Tab 2', ...
                'The selected tab should now be the second one.');
            testCase.verifyTrue(testCase.AppHandle.Footer.NextTabButton.Visible, ...
                'The "Next" button should be visible again after moving back.');
        end
        
        function testRequiredFieldValidation(testCase)
            % This test verifies that the required field check prevents tab navigation.
            
            % 1. Ensure we are on the first tab by setting the public 'SelectedTab' property.
            % This replaces the call to the protected 'changeTab' method.
            testCase.AppHandle.TabGroup.SelectedTab = testCase.AppHandle.TabGroup.Children(1);
            drawnow;

            % 2. Get a handle to the controller for the first tab
            firstTabController = testCase.AppHandle.tabControllers(1);
            
            % 3. Intentionally blank out the required field
            firstTabController.NameEditField.Value = '   '; % Use spaces, not empty
            
            % 4. Programmatically "press" the Next button
            nextButton = testCase.AppHandle.Footer.NextTabButton;
            nextButton.ButtonPushedFcn(testCase.AppHandle, []);
            drawnow;
            
            % 5. Verify that the tab did NOT change
            testCase.verifyEqual(testCase.AppHandle.TabGroup.SelectedTab.Title, 'Boring Tab 1', ...
                'Navigation should be blocked when a required field is empty.');
        end

    end

end
