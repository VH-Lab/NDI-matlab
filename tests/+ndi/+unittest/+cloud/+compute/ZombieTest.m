classdef ZombieTest < matlab.unittest.TestCase
% ZOMBIETEST - Test the 'zombie-test-v1' compute pipeline flow
%
%   This test mimics the behavior of the 'test_zombie_flow.sh' script.
%   It starts a 'zombie-test-v1' pipeline, monitors its status, and waits for completion.

    properties
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            % Ensure credentials are present in the environment
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set.');
        end
    end

    methods (Test)
        function testZombieFlow(testCase)
            import ndi.cloud.api.compute.*

            testCase.Narrative = "Begin ZombieTest: testZombieFlow";
            narrative = testCase.Narrative;

            pipelineId = "zombie-test-v1";

            % 1. Start Pipeline
            narrative(end+1) = "Starting 'zombie-test-v1' pipeline...";

            % Handle optional Org ID from env (mimicking script logic)
            % The script: ORG_ID=$4. If -n "$ORG_ID", include it.
            % We don't have direct access to script args, but we can check if the user
            % typically has multiple orgs or if we want to rely on default.
            % For this test, we'll stick to the default unless we want to look up an org.
            % The user instruction said "You do not need to get the username and password...".
            % We'll assume default org behavior is sufficient or handled by authentication context.

            [b_start, answer_start, apiResponse_start, apiURL_start] = startSession(pipelineId);

            narrative(end+1) = "Attempted to start session. URL: " + string(apiURL_start);
            start_msg = ndi.unittest.cloud.APIMessage(narrative, b_start, answer_start, apiResponse_start, apiURL_start);
            testCase.verifyTrue(b_start, start_msg);

            sessionId = "";
            if isstruct(answer_start)
                if isfield(answer_start, 'sessionId')
                    sessionId = answer_start.sessionId;
                elseif isfield(answer_start, 'id')
                    sessionId = answer_start.id;
                end
            end

            testCase.fatalAssertTrue(strlength(sessionId) > 0, "Failed to obtain valid Session ID. " + start_msg);

            narrative(end+1) = "Pipeline started. Session ID: " + sessionId;
            narrative(end+1) = "Monitoring session status. Pipeline should timeout after 2 minutes.";

            % 2. Initial Wait
            pause(10);

            % 3. List Sessions (Verification)
            narrative(end+1) = "Verifying session appears in list...";
            [b_list, answer_list, ~, ~] = listSessions();

            found = false;
            if b_list
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

                for i = 1:numel(sessionsList)
                    if iscell(sessionsList)
                        s = sessionsList{i};
                    else
                        s = sessionsList(i);
                    end

                    % Check for sessionId or id
                    sid = "";
                    if isfield(s, 'sessionId'), sid = s.sessionId;
                    elseif isfield(s, 'id'), sid = s.id; end

                    if strcmp(sid, sessionId)
                        found = true;
                        break;
                    end
                end
            end

            if found
                narrative(end+1) = "Session found in list.";
            else
                narrative(end+1) = "Warning: Session " + sessionId + " not found in list.";
                % The script just echoes a warning, so we verify but maybe don't fail hard?
                % Actually, if it's not in the list, that's usually bad.
                % But complying with "mimic the script", it warns.
                % We will use verifyTrue to flag it but proceed.
                testCase.verifyTrue(found, "Session ID not found in listSessions response.");
            end

            % 4. Polling Loop
            narrative(end+1) = "Waiting for status change...";

            max_iterations = 30; % 30 * 10s = 300s = 5 mins max
            final_status_reached = false;

            for iter = 1:max_iterations
                [b_status, answer_status, ~, ~] = getSessionStatus(sessionId);

                if ~b_status
                    narrative(end+1) = "Warning: Failed to get status on iteration " + iter;
                    continue;
                end

                status = "UNKNOWN";
                currentStage = "UNKNOWN";

                if isfield(answer_status, 'status')
                    status = answer_status.status;
                end
                if isfield(answer_status, 'currentStageId')
                    currentStage = answer_status.currentStageId;
                end

                % Try to extract stage status (e.g. history['wait-and-die'].status)
                stageStatus = "N/A";
                if isfield(answer_status, 'history') && isstruct(answer_status.history)
                    if isfield(answer_status.history, 'wait_and_die') % Matlab struct field name might be sanitized
                        s = answer_status.history.wait_and_die;
                        if isfield(s, 'status'), stageStatus = s.status; end
                    elseif isfield(answer_status.history, 'wait-and-die') % If jsondecode keeps dashes (less likely in struct)
                         s = answer_status.history.('wait-and-die');
                         if isfield(s, 'status'), stageStatus = s.status; end
                    end
                end

                timestamp = char(datetime('now', 'Format', 'HH:mm:ss'));
                narrative(end+1) = timestamp + " - Status: " + status + " | Stage: " + currentStage + " | Stage Status: " + stageStatus;

                if strcmp(status, 'ABORTED') || strcmp(status, 'FAILED') || strcmp(status, 'COMPLETED')
                    narrative(end+1) = "Final Status Reached: " + status;
                    final_status_reached = true;
                    break;
                end

                pause(10);
            end

            testCase.Narrative = narrative;
            testCase.verifyTrue(final_status_reached, "Test timed out before reaching a final status (ABORTED/FAILED/COMPLETED).");

            % In the shell script, there isn't an explicit final success check other than breaking the loop.
            % However, for a unit test, we generally want to know it finished.
            % The "zombie" test usually implies it tests a timeout or specific failure mode,
            % so effectively finishing is the success criteria.
        end
    end
end
