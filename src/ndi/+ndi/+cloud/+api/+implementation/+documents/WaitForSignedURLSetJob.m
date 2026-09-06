classdef WaitForSignedURLSetJob < ndi.cloud.api.call
%WAITFORSIGNEDURLSETJOB Polls a signed-url-set job until it finishes or times out.
%
%   Mirrors ndi.cloud.api.implementation.files.WaitForBulkUpload: polls
%   GET /signed-url-set-jobs/{jobId} at exponentially growing intervals until
%   the job reaches a terminal state ('ready' or 'failed') or the overall
%   timeout elapses.

    properties
        jobId (1,1) string
        timeout (1,1) double = 300
        initialInterval (1,1) double = 1
        maxInterval (1,1) double = 30
        backoffFactor (1,1) double = 2
    end

    methods
        function this = WaitForSignedURLSetJob(args)
            %WAITFORSIGNEDURLSETJOB Creates a new WaitForSignedURLSetJob call.
            arguments
                args.jobId (1,1) string
                args.timeout (1,1) double {mustBePositive} = 300
                args.initialInterval (1,1) double {mustBePositive} = 1
                args.maxInterval (1,1) double {mustBePositive} = 30
                args.backoffFactor (1,1) double {mustBePositive} = 2
            end
            this.jobId = args.jobId;
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.endpointName = 'get_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll the job until it is ready, fails, or times out.
            %
            %   b      - true iff the job reached the 'ready' state before the
            %            timeout. false on 'failed', timeout, or API error.
            %   answer - The last status struct from the server. On timeout, its
            %            'state' is set to 'timeout' and 'elapsed' holds the wall
            %            time spent polling.

            % Every output is assigned by the first poll below -- the loop
            % has no exit that skips it -- so none are pre-initialized.

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, status, apiResponse, apiURL] = ...
                    ndi.cloud.api.documents.getSignedURLSetJobStatus(this.jobId);
                answer = status;

                if ok && isstruct(status) && isfield(status, 'state')
                    switch string(status.state)
                        case "ready"
                            b = true;
                            return;
                        case "failed"
                            b = false;
                            return;
                        % 'queued' and 'running' are non-terminal; keep polling.
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
end
