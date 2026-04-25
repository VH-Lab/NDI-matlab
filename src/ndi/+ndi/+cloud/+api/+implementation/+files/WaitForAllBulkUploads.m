classdef WaitForAllBulkUploads < ndi.cloud.api.call
%WAITFORALLBULKUPLOADS Wait for every bulk-upload job on a dataset to finish.
%
%   Implementation class behind ndi.cloud.api.files.waitForAllBulkUploads.
%   Polls listActiveBulkUploads(datasetId, 'state', 'active') with
%   exponential backoff until no active (queued + extracting) jobs remain
%   or the overall timeout elapses. When requireAllComplete is true, also
%   re-queries with state='failed' once the active set drains and reports
%   b=false if any jobs ended in failure.
%
%   This is the dataset-level counterpart to WaitForBulkUpload. Use it at
%   sync-pipeline boundaries (before inventorying remote state) so the
%   list of files on the server is stable before being read.

    properties
        timeout (1,1) double = 300
        initialInterval (1,1) double = 1
        maxInterval (1,1) double = 30
        backoffFactor (1,1) double = 2
        requireAllComplete (1,1) logical = true
    end

    methods
        function this = WaitForAllBulkUploads(args)
            %WAITFORALLBULKUPLOADS Construct a new WaitForAllBulkUploads call.
            arguments
                args.cloudDatasetID (1,1) string
                args.timeout (1,1) double {mustBePositive} = 300
                args.initialInterval (1,1) double {mustBePositive} = 1
                args.maxInterval (1,1) double {mustBePositive} = 30
                args.backoffFactor (1,1) double {mustBePositive} = 2
                args.requireAllComplete (1,1) logical = true
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.requireAllComplete = args.requireAllComplete;
            this.endpointName = 'list_dataset_bulk_uploads';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll until no active bulk-upload jobs remain or timeout.
            %
            %   b           - true iff the active set drained before the
            %                 timeout AND (when requireAllComplete=true)
            %                 no jobs ended in state='failed'. false on
            %                 timeout, on any failed job, or on API error.
            %   answer      - On success, struct with state='complete' and
            %                 (empty) jobs array. On failure, struct with
            %                 state='timeout' or state='failed' plus the
            %                 offending jobs and elapsed wall time.
            %   apiResponse - The ResponseMessage from the last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            answer = struct('state', 'unknown', 'jobs', []);
            apiResponse = [];
            apiURL = [];

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, status, apiResponse, apiURL] = ndi.cloud.api.files.listActiveBulkUploads(...
                    this.cloudDatasetID, 'state', 'active');

                if ok && isstruct(status) && isfield(status, 'jobs')
                    answer = status;
                    if isempty(status.jobs)
                        % Active set drained. Decide success based on
                        % whether any jobs ended in 'failed'.
                        if this.requireAllComplete
                            [okF, failedList, respF, urlF] = ndi.cloud.api.files.listActiveBulkUploads(...
                                this.cloudDatasetID, 'state', 'failed');
                            if okF
                                apiResponse = respF;
                                apiURL = urlF;
                                if isstruct(failedList) && isfield(failedList, 'jobs') && ~isempty(failedList.jobs)
                                    b = false;
                                    answer = struct('state', 'failed', ...
                                                    'jobs', failedList.jobs, ...
                                                    'elapsed', toc(deadline));
                                    return;
                                end
                            end
                        end
                        b = true;
                        answer = struct('state', 'complete', ...
                                        'jobs', [], ...
                                        'elapsed', toc(deadline));
                        return;
                    end
                end

                elapsed = toc(deadline);
                if elapsed >= this.timeout
                    b = false;
                    if isstruct(answer)
                        answer.state = 'timeout';
                        answer.elapsed = elapsed;
                    else
                        answer = struct('state', 'timeout', 'elapsed', elapsed, 'jobs', []);
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
