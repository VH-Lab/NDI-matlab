classdef WaitForBulkUpload < ndi.cloud.api.call
%WAITFORBULKUPLOAD Polls a bulk upload job until it finishes or times out.
%
%   Implementation class behind ndi.cloud.api.files.waitForBulkUpload.
%   Polls GET /bulk-uploads/{jobId} at exponentially growing intervals
%   (capped) until the job reaches a terminal state ('complete' or
%   'failed') or the overall timeout elapses.

    properties
        jobId (1,1) string
        timeout (1,1) double = 60
        initialInterval (1,1) double = 1
        maxInterval (1,1) double = 30
        backoffFactor (1,1) double = 2
    end

    methods
        function this = WaitForBulkUpload(args)
            %WAITFORBULKUPLOAD Creates a new WaitForBulkUpload call.
            arguments
                args.jobId (1,1) string
                args.timeout (1,1) double {mustBePositive} = 60
                args.initialInterval (1,1) double {mustBePositive} = 1
                args.maxInterval (1,1) double {mustBePositive} = 30
                args.backoffFactor (1,1) double {mustBePositive} = 2
            end
            this.jobId = args.jobId;
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.endpointName = 'get_bulk_upload_status';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll the bulk upload job until it completes or times out.
            %
            %   b           - true iff the job reached the 'complete' state before
            %                 the timeout. false on 'failed', timeout, or API error.
            %   answer      - The last status struct returned by the server on
            %                 success or a struct with fields 'state' = 'timeout'
            %                 or the server error payload on failure.
            %   apiResponse - The matlab.net.http.ResponseMessage from the last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            answer = [];
            apiResponse = [];
            apiURL = [];

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, status, apiResponse, apiURL] = ndi.cloud.api.files.getBulkUploadStatus(this.jobId);
                answer = status;

                if ok && isstruct(status) && isfield(status, 'state')
                    switch string(status.state)
                        case "complete"
                            b = true;
                            return;
                        case "failed"
                            b = false;
                            return;
                        % 'queued' and 'extracting' are non-terminal; keep polling.
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

                % Cap the next sleep so we never overshoot the deadline by more
                % than one interval.
                remaining = this.timeout - elapsed;
                sleepFor = min([interval, this.maxInterval, remaining]);
                pause(sleepFor);

                interval = min(interval * this.backoffFactor, this.maxInterval);
            end
        end
    end
end
