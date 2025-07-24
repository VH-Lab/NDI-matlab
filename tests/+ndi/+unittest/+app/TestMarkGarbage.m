classdef TestMarkGarbage < matlab.unittest.TestCase
    % TestMarkGarbage - Unittest for the ndi.app.markgarbage class
    %
    % Description:
    %   This test class verifies the functionality of the ndi.app.markgarbage
    %   application. It sets up a test session with sample data, marks specific
    %   time intervals as valid ("good"), and then asserts that the application
    %   correctly identifies these intervals. It also tests the clearing
    %   functionality.
    %

    properties
        testSession % The NDI session object for the test
        testApp     % The ndi.app.markgarbage instance
        testProbe   % The probe object used for testing
        timeref     % The time reference for the probe
    end

    methods (TestClassSetup)
        % This method runs once before any tests are executed.
        function setupOnce(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            
            % Define the test directory and create it if it doesn't exist.
            temp_session_path = fullfile(fixture.Folder, 'example_app_sessions', 'markgarbage_ex');
            if ~isfolder(temp_session_path)
                mkdir(temp_session_path)
            end

            % Set up the session, device, app, and probe for all tests.
            
            % 1. Copy example files to the test directory
            example_path = [ndi.common.PathConstants.CommonFolder filesep 'example_app_sessions' filesep 'markgarbage_ex'];
            copyfile(example_path, temp_session_path)
            
            % 2. Create the session object
            testCase.testSession = ndi.session.dir('exp1_markgarbage_eg', temp_session_path);

            % 3. Remove any old devices to ensure a clean start
            devs = testCase.testSession.daqsystem_load('name','(.*)');
            for i = 1:numel(devs)
                testCase.testSession.daqsystem_rm(vlt.data.celloritem(devs,i));
            end

            % 4. Add the acquisition device (Intan) to the session
            file_nav = ndi.file.navigator(testCase.testSession, {'.*\.rhd\>','.*\.epochmetadata\>'}, ...
                'ndi.epoch.epochprobemap_daqsystem','.*\.epochmetadata\>');
            dev1 = ndi.daq.system.mfdaq('intan1', file_nav, ndi.daq.reader.mfdaq.intan());
            testCase.testSession.daqsystem_add(dev1);

            % 5. Create an instance of the markgarbage app
            testCase.testApp = ndi.app.markgarbage(testCase.testSession);

            % 6. Get a probe and its time reference to use in the tests
            testCase.testProbe = getprobes(testCase.testSession, 'name', 'cortex', 'reference', 1);
            [~, ~, testCase.timeref] = testCase.testProbe{1}.readtimeseriesepoch(1, 0, 1); % Read 1s to get timeref
        end
    end

    methods (TestClassTeardown)
        % This method runs once after all tests have been executed.
        function teardownOnce(testCase)
            % Clean up the session by removing the device to allow the test to be re-run.
            devs = testCase.testSession.daqsystem_load('name', 'intan1');
            
            % Loop through the found devices. This pattern works whether 'devs' is a
            % single object or a cell array of objects.
            if ~isempty(devs)
                for i = 1:numel(devs)
                    device_to_remove = vlt.data.celloritem(devs, i);
                    testCase.testSession.daqsystem_rm(device_to_remove);
                end
            end
        end
    end

    methods (TestMethodSetup)
        % This method runs before each individual test method.
        function setupTest(testCase)
            % Ensure a clean slate for each test by clearing any previously marked intervals.
            testCase.testApp.clearvalidinterval(testCase.testProbe{1});
        end
    end

    methods (Test)
        % --- Test Methods --- %

        function testMarkAndIdentifyValidInterval(testCase)
            % Test the core functionality: marking an interval and then identifying it.
            
            % 1. Define the interval to mark as "valid"
            valid_start_time = 1.0;
            valid_end_time = 3.0;

            % 2. Mark the interval using the app
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, ...
                valid_start_time, testCase.timeref, ...
                valid_end_time, testCase.timeref);

            % 3. Ask the app to identify valid intervals over a broad time range
            search_range_start = 0;
            search_range_end = Inf;
            identified_intervals = testCase.testApp.identifyvalidintervals(...
                testCase.testProbe{1}, testCase.timeref, ...
                search_range_start, search_range_end);

            % 4. Verify the results with assertions
            expected_interval = [valid_start_time, valid_end_time];

            % Verify that exactly one interval was returned
            testCase.verifySize(identified_intervals, [1, 2], ...
                'Error: Expected to find exactly one valid interval.');

            % Verify that the identified interval matches the one we marked
            testCase.verifyEqual(identified_intervals, expected_interval, 'AbsTol', 1e-6, ...
                'Error: The identified interval does not match the marked interval.');
        end

        function testClearValidInterval(testCase)
            % Test that marked intervals can be successfully cleared.
            
            % 1. Mark an interval
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, ...
                1.0, testCase.timeref, 3.0, testCase.timeref);

            % 2. Clear all valid intervals for the probe
            testCase.testApp.clearvalidinterval(testCase.testProbe{1});

            % 3. Attempt to load any valid interval documents from the database
            [vi, ~] = testCase.testApp.loadvalidinterval(testCase.testProbe{1});

            % 4. Verify that the result is empty, confirming the clear operation worked
            testCase.verifyEmpty(vi, ...
                'Error: Expected no valid intervals after clearing.');
        end

        function testIdentifyWithNoMarkings(testCase)
            % Test the behavior when no intervals have been marked. The entire
            % requested range should be returned.
            
            % 1. Define a search range
            search_start = 0;
            search_end = 15.0;
            
            % 2. Identify intervals (setupTest ensures none are marked)
            identified_intervals = testCase.testApp.identifyvalidintervals(...
                testCase.testProbe{1}, testCase.timeref, ...
                search_start, search_end);
            
            % 3. Verify that the entire search range is returned as valid
            expected_interval = [search_start, search_end];
            testCase.verifyEqual(identified_intervals, expected_interval, 'AbsTol', 1e-6, ...
                'Error: When no intervals are marked, the entire search range should be valid.');
        end

        function testMultipleDisjointIntervals(testCase)
            % Test marking two separate intervals and identifying them both.

            % 1. Mark two disjoint intervals
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, 2, testCase.timeref, 4, testCase.timeref);
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, 8, testCase.timeref, 10, testCase.timeref);

            % 2. Identify over a range that contains both
            intervals = testCase.testApp.identifyvalidintervals(testCase.testProbe{1}, testCase.timeref, 0, 20);

            % 3. Verify the result
            expected_intervals = [2, 4; 8, 10];

            % Use sortrows to ensure order doesn't affect the test
            testCase.verifyEqual(sortrows(intervals), expected_intervals, 'AbsTol', 1e-6, ...
                'Error: Did not correctly identify multiple disjoint intervals.');
        end

        function testOverlappingIntervalsAreMerged(testCase)
            % Test that two overlapping valid intervals are correctly merged.

            % 1. Mark two overlapping intervals
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, 5, testCase.timeref, 10, testCase.timeref);
            testCase.testApp.markvalidinterval(testCase.testProbe{1}, 8, testCase.timeref, 15, testCase.timeref);

            % 2. Identify over a range containing the merged interval
            intervals = testCase.testApp.identifyvalidintervals(testCase.testProbe{1}, testCase.timeref, 0, 20);

            % 3. Verify that they were merged into a single interval
            expected_merged_interval = [5, 15];
            testCase.verifyEqual(intervals, expected_merged_interval, 'AbsTol', 1e-6, ...
                'Error: Overlapping intervals were not merged correctly.');
        end
    end
end