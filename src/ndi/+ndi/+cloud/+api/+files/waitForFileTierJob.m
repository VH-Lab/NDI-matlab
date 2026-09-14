function [b, answer, apiResponse, apiURL] = waitForFileTierJob(jobId, options)
%WAITFORFILETIERJOB Poll a file-tier job until it finishes or times out.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.files.waitForFileTierJob(JOBID)
%   [...] = ndi.cloud.api.files.waitForFileTierJob(JOBID, 'timeout', T, ...)
%
%   Repeatedly calls ndi.cloud.api.files.getFileTierJob(JOBID) at
%   exponentially growing intervals until the job reaches a terminal state
%   ('completed', 'failed', or 'superseded') or the overall timeout
%   elapses. See ndi-cloud-node/manuals/file-tier-design.md for state
%   semantics.
%
%   Inputs:
%       jobId  - The file-tier job identifier.
%
%   Name-value options:
%       'timeout'         - Overall deadline in seconds. Default 600
%                           (tier moves fan out to many CopyObject calls;
%                           give them room).
%       'initialInterval' - First sleep between polls (s). Default 3.
%       'maxInterval'     - Cap on the per-poll sleep (s). Default 30.
%       'backoffFactor'   - Multiplier applied after each poll. Default 2.
%
%   Outputs:
%       b            - True iff the job reached state 'completed'. False
%                      on 'failed'/'superseded', timeout, or API error.
%       answer       - The last status struct from the server. On timeout,
%                      `state` is set to 'timeout' and `elapsed` holds the
%                      wall time spent polling.
%       apiResponse  - The ResponseMessage from the last poll.
%       apiURL       - The URL of the last poll.

    arguments
        jobId (1,1) string
        options.timeout         (1,1) double {mustBePositive} = 600
        options.initialInterval (1,1) double {mustBePositive} = 3
        options.maxInterval     (1,1) double {mustBePositive} = 30
        options.backoffFactor   (1,1) double {mustBePositive} = 2
    end

    startTime  = tic;
    interval   = options.initialInterval;
    answer     = struct('state', 'unknown');
    apiResponse = [];
    apiURL      = [];

    while true
        [ok, answer, apiResponse, apiURL] = ndi.cloud.api.files.getFileTierJob(jobId);
        if ~ok
            b = false;
            return;
        end

        if isfield(answer, 'state')
            switch string(answer.state)
                case "completed"
                    b = true;
                    return;
                case {"failed", "superseded"}
                    b = false;
                    return;
            end
        end

        elapsed = toc(startTime);
        if elapsed >= options.timeout
            answer.state = 'timeout';
            answer.elapsed = elapsed;
            b = false;
            return;
        end

        pause(min(interval, options.timeout - elapsed));
        interval = min(interval * options.backoffFactor, options.maxInterval);
    end
end
