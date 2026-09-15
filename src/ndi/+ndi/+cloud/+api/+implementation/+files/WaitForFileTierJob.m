classdef WaitForFileTierJob < ndi.cloud.api.call
%WAITFORFILETIERJOB Poll a file-tier job until it finishes or times out.
%
%   Implementation behind ndi.cloud.api.files.waitForFileTierJob.
%   Polls GET /file-tier-jobs/{jobId} at exponentially growing
%   intervals (capped) until the job reaches a terminal state
%   ('completed', 'failed' or 'superseded') or the overall timeout
%   elapses. Mirrors the shape of WaitForSignedURLSetJob so callers
%   see a consistent poll pattern.

    properties
        jobId           (1,1) string
        timeout         (1,1) double = 600
        initialInterval (1,1) double = 3
        maxInterval     (1,1) double = 30
        backoffFactor   (1,1) double = 2
    end

    methods
        function this = WaitForFileTierJob(args)
            arguments
                args.jobId           (1,1) string
                args.timeout         (1,1) double {mustBePositive} = 600
                args.initialInterval (1,1) double {mustBePositive} = 3
                args.maxInterval     (1,1) double {mustBePositive} = 30
                args.backoffFactor   (1,1) double {mustBePositive} = 2
            end
            this.jobId = args.jobId;
            this.timeout         = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval     = args.maxInterval;
            this.backoffFactor   = args.backoffFactor;
            this.endpointName = 'get_file_tier_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];
            apiResponse = [];
            apiURL = [];

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, status, apiResponse, apiURL] = this.pollStatus();
                answer = status;

                if ok && isstruct(status) && isfield(status, 'state')
                    switch string(status.state)
                        case "completed"
                            b = true;
                            return;
                        case {"failed", "superseded"}
                            b = false;
                            return;
                        % 'queued' and 'running' are non-terminal; keep polling.
                        % A failing poll (ok == false) is transient too --
                        % don't mistake a gateway blip for a dead job.
                    end
                end

                elapsed = toc(deadline);
                if elapsed >= this.timeout
                    b = false;
                    if ~isstruct(answer) || ~isfield(answer, 'state')
                        answer = struct('state', 'timeout', 'elapsed', elapsed);
                    else
                        answer.state = 'timeout';
                        answer.elapsed = elapsed;
                    end
                    return;
                end

                remaining = this.timeout - elapsed;
                sleepFor = min([interval, this.maxInterval, remaining]);
                pause(sleepFor);

                interval = min(interval * this.backoffFactor, this.maxInterval);
            end
        end
    end

    methods (Access = protected)
        function [ok, status, apiResponse, apiURL] = pollStatus(this)
            %POLLSTATUS Read the job's state once. Seam: a test subclass
            %   overrides this to script a sequence of states, so the
            %   terminal-state, timeout and backoff logic can be exercised
            %   without a server.
            [ok, status, apiResponse, apiURL] = ...
                ndi.cloud.api.files.getFileTierJob(this.jobId);
        end
    end
end
