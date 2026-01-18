classdef ComputeTest < matlab.unittest.TestCase
% ComputeTest - Test suite for the ndi.cloud.api.compute namespace
%
%   This test class verifies the functionality of the compute-related API
%   endpoints, including starting sessions, checking status, and listing sessions.
%
    properties
        Narrative (1,:) string % Stores the narrative for each test
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            % This fatal assertion runs once before any tests in this class.
            % It ensures that the necessary credentials are set as environment variables.
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set.');
        end
    end

    methods (Test)
        function testHelloWorldFlow(testCase)
            % This test verifies the "Hello World" compute pipeline workflow.
            % 1. Start session
            % 2. Check status
            % 3. List sessions
            % 4. Abort session (cleanup)

            testCase.Narrative = "Begin ComputeTest: testHelloWorldFlow";
            narrative = testCase.Narrative;

            pipelineId = "hello-world-v1";

            % --- 1. Start Session ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.compute.startSession with pipelineId: " + pipelineId;
            [b_start, answer_start, apiResponse_start, apiURL_start] = ndi.cloud.api.compute.startSession(pipelineId);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_start);

            narrative(end+1) = "Testing: Verifying the startSession API call was successful.";
            start_message = ndi.unittest.cloud.APIMessage(narrative, b_start, answer_start, apiResponse_start, apiURL_start);
            testCase.verifyTrue(b_start, start_message);

            % Verify we got a session ID
            sessionId = "";
            if isstruct(answer_start) && isfield(answer_start, 'sessionId')
                sessionId = answer_start.sessionId;
                narrative(end+1) = "Session started successfully. Session ID: " + sessionId;
            elseif isstruct(answer_start) && isfield(answer_start, 'id')
                 % Fallback in case ID is returned as 'id'
                sessionId = answer_start.id;
                narrative(end+1) = "Session started successfully. Session ID: " + sessionId;
            else
                testCase.verifyTrue(false, "Response is missing 'sessionId' or 'id' field. " + start_message);
            end

            testCase.verifyTrue(strlength(sessionId) > 0, "Session ID should not be empty.");

            % --- 2. Get Session Status ---
            if strlength(sessionId) > 0
                narrative(end+1) = "Preparing to call ndi.cloud.api.compute.getSessionStatus for session: " + sessionId;
                [b_status, answer_status, apiResponse_status, apiURL_status] = ndi.cloud.api.compute.getSessionStatus(sessionId);
                narrative(end+1) = "Attempted to call API with URL " + string(apiURL_status);

                narrative(end+1) = "Testing: Verifying the getSessionStatus API call was successful.";
                status_message = ndi.unittest.cloud.APIMessage(narrative, b_status, answer_status, apiResponse_status, apiURL_status);
                testCase.verifyTrue(b_status, status_message);

                if isstruct(answer_status) && isfield(answer_status, 'status')
                    narrative(end+1) = "Current session status: " + string(answer_status.status);
                end
            end

            % --- 3. List Sessions ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.compute.listSessions.";
            [b_list, answer_list, apiResponse_list, apiURL_list] = ndi.cloud.api.compute.listSessions();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_list);

            narrative(end+1) = "Testing: Verifying the listSessions API call was successful.";
            list_message = ndi.unittest.cloud.APIMessage(narrative, b_list, answer_list, apiResponse_list, apiURL_list);
            testCase.verifyTrue(b_list, list_message);

            % Verify our session is in the list
            if strlength(sessionId) > 0
                % Handle different possible return types (Struct Array, Cell Array, or Envelope)
                sessionsList = [];
                if isstruct(answer_list)
                    if isfield(answer_list, 'sessions')
                        sessionsList = answer_list.sessions;
                    else
                        sessionsList = answer_list; % Struct array
                    end
                elseif iscell(answer_list)
                    sessionsList = answer_list;
                end

                 found = false;
                 for i = 1:numel(sessionsList)
                     if iscell(sessionsList)
                         s = sessionsList{i};
                     else
                         s = sessionsList(i);
                     end

                     if isstruct(s) && ( (isfield(s, 'id') && strcmp(s.id, sessionId)) || (isfield(s, 'sessionId') && strcmp(s.sessionId, sessionId)) )
                         found = true;
                         break;
                     end
                 end
                 narrative(end+1) = "Testing: Verifying the new session is present in the list.";
                 testCase.verifyTrue(found, "Newly created session ID " + sessionId + " was not found in the session list.");
            end

            % --- 4. Abort Session ---
            if strlength(sessionId) > 0
                narrative(end+1) = "Preparing to call ndi.cloud.api.compute.abortSession for session: " + sessionId;
                [b_abort, answer_abort, apiResponse_abort, apiURL_abort] = ndi.cloud.api.compute.abortSession(sessionId);
                narrative(end+1) = "Attempted to call API with URL " + string(apiURL_abort);

                narrative(end+1) = "Testing: Verifying the abortSession API call was successful.";
                abort_message = ndi.unittest.cloud.APIMessage(narrative, b_abort, answer_abort, apiResponse_abort, apiURL_abort);
                % Note: If session already finished (hello world is fast), abort might fail or be no-op.
                % We accept failure if status code implies it's already done/gone, but usually abort returns success or 4xx.
                % For this test we expect success or specific error codes.
                if ~b_abort && apiResponse_abort.StatusCode == 404
                     narrative(end+1) = "Abort returned 404, likely session already finished/cleaned up.";
                else
                     testCase.verifyTrue(b_abort, abort_message);
                end
            end

            % --- 5. Test Trigger Stage (dummy call just to verify mechanics) ---
            % Hello World might not have stages we can trigger, but we test the API invocation.
            % We expect this to likely fail (400/404) if the session is gone or stage invalid,
            % but we want to ensure the MATLAB code doesn't crash.
            if strlength(sessionId) > 0
                 narrative(end+1) = "Testing triggerStage (expecting potential API error, verifying function stability).";
                 [b_trig, ~, ~, ~] = ndi.cloud.api.compute.triggerStage(sessionId, 'dummy-stage');
                 % We don't verifyTrue(b_trig) because we don't know a valid stage.
                 % We just want to ensure it runs without throwing MATLAB error.
                 narrative(end+1) = "triggerStage call completed (Result: " + string(b_trig) + ")";
            end

             % --- 6. Test Finalize Session (dummy call) ---
            if strlength(sessionId) > 0
                 narrative(end+1) = "Testing finalizeSession (expecting potential API error, verifying function stability).";
                 [b_fin, ~, ~, ~] = ndi.cloud.api.compute.finalizeSession(sessionId);
                 narrative(end+1) = "finalizeSession call completed (Result: " + string(b_fin) + ")";
            end

            testCase.Narrative = narrative;
        end
    end
end
