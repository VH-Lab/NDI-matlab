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

            verbose = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.debugEnabled();
            if verbose
                fprintf(['[waitForAllBulkUploads] START datasetID=%s timeout=%.1fs ', ...
                    'initialInterval=%.2fs maxInterval=%.2fs backoffFactor=%.2f ', ...
                    'requireAllComplete=%d\n'], ...
                    this.cloudDatasetID, this.timeout, this.initialInterval, ...
                    this.maxInterval, this.backoffFactor, this.requireAllComplete);
            end

            deadline = tic;
            interval = this.initialInterval;
            pollCount = 0;

            while true
                pollCount = pollCount + 1;
                pollT0 = tic;
                [ok, status, apiResponse, apiURL] = ndi.cloud.api.files.listActiveBulkUploads(...
                    this.cloudDatasetID, 'state', 'active');
                pollDur = toc(pollT0);

                if verbose
                    nJobs = NaN;
                    if isstruct(status) && isfield(status, 'jobs')
                        nJobs = numel(status.jobs);
                    end
                    fprintf(['[waitForAllBulkUploads] poll #%d ok=%d nActiveJobs=%g ', ...
                        'apiCallTime=%.3fs elapsed=%.2fs url=%s\n'], ...
                        pollCount, ok, nJobs, pollDur, toc(deadline), string(apiURL));
                    if isstruct(status) && isfield(status, 'jobs') && ~isempty(status.jobs)
                        ndi.cloud.api.implementation.files.WaitForAllBulkUploads.printJobs(status.jobs);
                    end
                end

                if ok && isstruct(status) && isfield(status, 'jobs')
                    answer = status;
                    if isempty(status.jobs)
                        % Active set drained. Decide success based on
                        % whether any jobs ended in 'failed'.
                        if verbose
                            fprintf(['[waitForAllBulkUploads] active set drained after ', ...
                                '%.2fs (poll #%d)\n'], toc(deadline), pollCount);
                        end
                        if this.requireAllComplete
                            if verbose
                                fprintf('[waitForAllBulkUploads] checking failed-job list...\n');
                            end
                            failedT0 = tic;
                            [okF, failedList, respF, urlF] = ndi.cloud.api.files.listActiveBulkUploads(...
                                this.cloudDatasetID, 'state', 'failed');
                            if verbose
                                nF = NaN;
                                if isstruct(failedList) && isfield(failedList, 'jobs')
                                    nF = numel(failedList.jobs);
                                end
                                fprintf(['[waitForAllBulkUploads] failed-list ok=%d nFailed=%g ', ...
                                    'apiCallTime=%.3fs\n'], okF, nF, toc(failedT0));
                            end
                            if okF
                                apiResponse = respF;
                                apiURL = urlF;
                                if isstruct(failedList) && isfield(failedList, 'jobs') && ~isempty(failedList.jobs)
                                    b = false;
                                    answer = struct('state', 'failed', ...
                                                    'jobs', failedList.jobs, ...
                                                    'elapsed', toc(deadline));
                                    if verbose
                                        fprintf(['[waitForAllBulkUploads] RETURN state=failed ', ...
                                            'elapsed=%.2fs nFailed=%d\n'], ...
                                            answer.elapsed, numel(failedList.jobs));
                                    end
                                    return;
                                end
                            end
                        end
                        b = true;
                        answer = struct('state', 'complete', ...
                                        'jobs', [], ...
                                        'elapsed', toc(deadline));
                        if verbose
                            fprintf(['[waitForAllBulkUploads] RETURN state=complete ', ...
                                'elapsed=%.2fs polls=%d\n'], answer.elapsed, pollCount);
                        end
                        return;
                    end
                elseif verbose
                    fprintf(['[waitForAllBulkUploads] poll #%d returned non-OK or ', ...
                        'malformed status; will retry\n'], pollCount);
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
                    if verbose
                        nJobs = 0;
                        if isstruct(answer) && isfield(answer, 'jobs') && ~isempty(answer.jobs)
                            nJobs = numel(answer.jobs);
                        end
                        fprintf(['[waitForAllBulkUploads] RETURN state=timeout ', ...
                            'elapsed=%.2fs polls=%d remainingActiveJobs=%d\n'], ...
                            elapsed, pollCount, nJobs);
                    end
                    return;
                end

                remaining = this.timeout - elapsed;
                sleepFor = min([interval, this.maxInterval, remaining]);
                if verbose
                    fprintf(['[waitForAllBulkUploads] sleeping %.2fs (interval=%.2fs ', ...
                        'maxInterval=%.2fs remaining=%.2fs)\n'], ...
                        sleepFor, interval, this.maxInterval, remaining);
                end
                pause(sleepFor);

                interval = min(interval * this.backoffFactor, this.maxInterval);
            end
        end
    end

    methods (Static, Access = private)
        function tf = debugEnabled()
            %DEBUGENABLED Toggle verbose logging via env var or global.
            %
            %   Set NDI_DEBUG_WAITBULK=1 in the environment, or set the
            %   global variable NDI_DEBUG_WAITBULK to true, to enable
            %   per-poll verbose output. Defaults to true while we are
            %   actively diagnosing slow sync tests.
            tf = true;
            envVal = getenv('NDI_DEBUG_WAITBULK');
            if ~isempty(envVal)
                tf = ~ismember(lower(string(envVal)), ["0","false","off","no",""]);
                return;
            end
            try
                global NDI_DEBUG_WAITBULK %#ok<GVMIS,TLEV>
                if ~isempty(NDI_DEBUG_WAITBULK)
                    tf = logical(NDI_DEBUG_WAITBULK);
                end
            catch
            end
        end

        function printJobs(jobs)
            %PRINTJOBS Best-effort one-line-per-job summary.
            try
                if iscell(jobs)
                    for i = 1:numel(jobs)
                        ndi.cloud.api.implementation.files.WaitForAllBulkUploads.printOneJob(i, jobs{i});
                    end
                elseif isstruct(jobs)
                    for i = 1:numel(jobs)
                        ndi.cloud.api.implementation.files.WaitForAllBulkUploads.printOneJob(i, jobs(i));
                    end
                else
                    fprintf('[waitForAllBulkUploads]   <unrecognized jobs container: %s>\n', class(jobs));
                end
            catch ME
                fprintf('[waitForAllBulkUploads]   <printJobs failed: %s>\n', ME.message);
            end
        end

        function printOneJob(idx, job)
            jobId = '?';
            jobState = '?';
            jobProgress = '';
            if isstruct(job) || isobject(job)
                fns = {};
                try
                    fns = fieldnames(job);
                catch
                end
                if any(strcmp(fns, 'id')); jobId = string(job.id); end
                if any(strcmp(fns, '_id')); jobId = string(job.('_id')); end
                if any(strcmp(fns, 'jobId')); jobId = string(job.jobId); end
                if any(strcmp(fns, 'state')); jobState = string(job.state); end
                if any(strcmp(fns, 'status')); jobState = string(job.status); end
                if any(strcmp(fns, 'progress'))
                    try
                        jobProgress = sprintf(' progress=%s', jsonencode(job.progress));
                    catch
                    end
                end
            end
            fprintf('[waitForAllBulkUploads]   job[%d] id=%s state=%s%s\n', ...
                idx, jobId, jobState, jobProgress);
        end
    end
end
