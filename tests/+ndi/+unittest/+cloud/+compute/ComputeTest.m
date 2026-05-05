classdef ComputeTest < matlab.unittest.TestCase
% ComputeTest - Test suite for the ndi.cloud.api.compute namespace
%
%   This test class verifies the functionality of the compute-related API
%   endpoints, including starting sessions, checking status, listing
%   sessions, and aborting a long-running session.
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
            % 4. Wait for pipeline to complete (helloWorld self-cascades)

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

            % --- 4. Wait for pipeline to complete ---
            % helloWorld auto-cascades initial-setup -> process -> cleanup with no
            % manual triggers; verify it actually reaches COMPLETED rather than
            % aborting it mid-flight.
            narrative(end+1) = "Polling getSessionStatus until terminal (max 60s)";
            deadline = tic;
            finalStatus = "";
            while toc(deadline) < 60
                [b_poll, answer_poll, ~, ~] = ndi.cloud.api.compute.getSessionStatus(sessionId);
                if b_poll && isstruct(answer_poll) && isfield(answer_poll, 'status')
                    if any(strcmp(answer_poll.status, {'COMPLETED', 'ABORTED'}))
                        finalStatus = string(answer_poll.status);
                        break;
                    end
                end
                pause(2);
            end
            narrative(end+1) = "Final session status: " + finalStatus;
            testCase.verifyEqual(finalStatus, "COMPLETED", ...
                "helloWorld pipeline did not reach COMPLETED within 60s");

            testCase.Narrative = narrative;
        end

        function testAbortZombieFlow(testCase)
            % zombie-test-v1's wait-and-die stage sleeps 10min; we abort it
            % almost immediately so the abort always finds a runner that is
            % actually running. This is the test we want for the abortSession
            % API surface, not a race against helloWorld's fast self-completion.
            pipelineId = "zombie-test-v1";
            [b_start, answer_start, ~, ~] = ndi.cloud.api.compute.startSession(pipelineId);
            testCase.verifyTrue(b_start, "startSession failed");
            sessionId = string(answer_start.sessionId);

            % Give the runner a couple seconds to land in RUNNING. Without
            % this we race the auto-cascade in the other direction (abort
            % arrives before initial-setup has even run).
            pause(5);

            [b_abort, ~, apiResponse_abort, ~] = ndi.cloud.api.compute.abortSession(sessionId);
            testCase.verifyTrue(b_abort, "abortSession failed for zombie pipeline");

            % Verify the session reached ABORTED.
            pause(2);
            [~, answer_status, ~, ~] = ndi.cloud.api.compute.getSessionStatus(sessionId);
            testCase.verifyEqual(string(answer_status.status), "ABORTED", ...
                "Session should be ABORTED after abortSession call");
        end
    end
end
