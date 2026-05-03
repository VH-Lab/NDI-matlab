function [success, sessionId, statusMessage, sessionDoc] = helloMatlab(options)
%HELLOMATLAB End-to-end check that the current user has a working MATLAB
%BYOL registration on NDI Cloud, by running the `hello-matlab-v1` pipeline
%and waiting for the verify stage to terminate.
%
%   This is the MATLAB equivalent of the e2eScripts/compute/Matlab/
%   test_helloMatlab.sh script in ndi-cloud-node: log in, start the
%   pipeline, poll GET /compute/{sessionId} until the verify stage hits
%   COMPLETED or FAILED, and surface the message MATLAB wrote back from
%   the EC2 instance.
%
%   [SUCCESS, SESSIONID, STATUSMESSAGE, SESSIONDOC] = ndi.cloud.helloMatlab()
%   [...] = ndi.cloud.helloMatlab('TimeoutSeconds', 1200, 'PollIntervalSeconds', 10)
%
%   Optional Inputs (Name-Value):
%       TimeoutSeconds      - Hard cap on polling, default 1200 (20 min).
%                             The stage's own watchdog is 15 min.
%       PollIntervalSeconds - Seconds between status polls, default 10.
%       Verbose             - Print one line per status change, default true.
%
%   Outputs:
%       success       - True if the verify stage reached COMPLETED.
%       sessionId     - The compute session ID, or "" if start failed.
%       statusMessage - The verify stage's statusMessage (the License
%                       Manager string from MATLAB on success or failure,
%                       or the proximate error text if the API rejected
%                       the start call before any session existed).
%       sessionDoc    - The final session struct (or the start-call error
%                       payload if start failed).
%
%   Prereq: the caller must have a registered BYOL license matching the
%   pipeline's `requiresMatlabRelease`. Use
%   ndi.cloud.api.users.allocateMatlabLicenseMac and
%   ndi.cloud.api.users.setMatlabLicense to register one. If no license
%   matches, the API refuses to start the session with HTTP 400 and a
%   `MATLAB_LICENSE_REQUIRED` payload, which this function reports
%   directly via STATUSMESSAGE.
%
%   See also: ndi.cloud.api.compute.startSession,
%             ndi.cloud.api.compute.getSessionStatus,
%             ndi.cloud.api.users.getMatlabLicense

    arguments
        options.TimeoutSeconds (1,1) double = 1200
        options.PollIntervalSeconds (1,1) double = 10
        options.Verbose (1,1) logical = true
    end

    success = false;
    sessionId = "";
    statusMessage = "";
    sessionDoc = struct();

    pipelineId = "hello-matlab-v1";

    % 1. Authenticate. ndi.cloud.authenticate() consults the active token,
    %    the MATLAB Vault, and NDI_CLOUD_USERNAME/PASSWORD env vars.
    ndi.cloud.authenticate();

    % 2. Start the pipeline.
    if options.Verbose
        fprintf('helloMatlab: starting pipeline %s ...\n', pipelineId);
    end
    [b_start, answer_start, apiResponse_start, ~] = ndi.cloud.api.compute.startSession(pipelineId);
    if ~b_start
        % Surface MATLAB_LICENSE_REQUIRED / MATLAB_LICENSE_DECRYPT_FAILED
        % directly, so the caller doesn't have to inspect the raw payload.
        statusMessage = extractStartFailureMessage(answer_start, apiResponse_start);
        sessionDoc = answer_start;
        if options.Verbose
            fprintf('helloMatlab: start failed -- %s\n', statusMessage);
        end
        return;
    end

    if isstruct(answer_start) && isfield(answer_start, 'sessionId')
        sessionId = string(answer_start.sessionId);
    elseif isstruct(answer_start) && isfield(answer_start, 'id')
        sessionId = string(answer_start.id);
    end
    if strlength(sessionId) == 0
        statusMessage = "start response had no sessionId";
        sessionDoc = answer_start;
        return;
    end
    if options.Verbose
        fprintf('helloMatlab: session %s started; polling verify stage...\n', sessionId);
    end

    % 3. Poll until the verify stage reaches a terminal state, or the
    %    deadline passes. The runner writes COMPLETED on rc=0 from
    %    `matlab -batch "ver"` and FAILED with the trimmed License
    %    Manager Error otherwise; the status handler propagates that
    %    into history.verify.statusMessage on the session document.
    deadline = posixtime(datetime('now')) + options.TimeoutSeconds;
    lastLine = "";
    while true
        now = posixtime(datetime('now'));
        if now > deadline
            statusMessage = sprintf("polling timed out after %d seconds", options.TimeoutSeconds);
            return;
        end

        [b_status, sessionDoc, ~, ~] = ndi.cloud.api.compute.getSessionStatus(sessionId);
        if ~b_status
            % Transient API hiccup; keep polling rather than aborting.
            pause(options.PollIntervalSeconds);
            continue;
        end

        sessionStatus = readField(sessionDoc, 'status', "");
        verify = readNested(sessionDoc, {'history','verify'}, struct());
        stageStatus = readField(verify, 'status', "");
        stageMsg = readField(verify, 'statusMessage', "");
        instanceId = readField(verify, 'awsResourceId', "");

        if options.Verbose
            line = sprintf("session=%s stage=%s instance=%s :: %s", ...
                sessionStatus, stageStatus, instanceId, stageMsg);
            if line ~= lastLine
                fprintf('  %s\n', line);
                lastLine = line;
            end
        end

        if stageStatus == "COMPLETED" || sessionStatus == "COMPLETED"
            success = true;
            statusMessage = stageMsg;
            return;
        end
        if stageStatus == "FAILED" || sessionStatus == "ABORTED" || sessionStatus == "FAILED"
            statusMessage = stageMsg;
            return;
        end

        pause(options.PollIntervalSeconds);
    end
end

function msg = extractStartFailureMessage(answer, apiResponse)
    msg = "start failed";
    if isstruct(answer)
        code = readField(answer, 'code', "");
        if strlength(code) > 0
            required = readField(answer, 'requiredRelease', "");
            err = readField(answer, 'error', "");
            switch code
                case "MATLAB_LICENSE_REQUIRED"
                    msg = sprintf("MATLAB_LICENSE_REQUIRED (need release %s); register one via " + ...
                        "ndi.cloud.api.users.allocateMatlabLicenseMac + setMatlabLicense", required);
                case "MATLAB_LICENSE_DECRYPT_FAILED"
                    msg = sprintf("MATLAB_LICENSE_DECRYPT_FAILED for %s: %s", required, err);
                otherwise
                    msg = sprintf("%s: %s", code, readField(answer, 'message', ""));
            end
            return;
        end
        if isfield(answer, 'message')
            msg = string(answer.message);
            return;
        end
    end
    if ~isempty(apiResponse) && isa(apiResponse, 'matlab.net.http.ResponseMessage')
        msg = sprintf("HTTP %s", string(apiResponse.StatusCode));
    end
end

function val = readField(s, name, defaultVal)
    val = defaultVal;
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        val = string(s.(name));
    end
end

function val = readNested(s, path, defaultVal)
    val = defaultVal;
    cur = s;
    for i = 1:numel(path)
        if isstruct(cur) && isfield(cur, path{i})
            cur = cur.(path{i});
        else
            return;
        end
    end
    val = cur;
end
