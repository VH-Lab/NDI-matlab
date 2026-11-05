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
%   Stale jobs: the server creates a BulkUploadJob in state 'queued' as
%   soon as a client asks for a bulk upload URL. If the zip PUT then
%   fails, is interrupted, or never happens, that job can stay 'queued'
%   (or, after a crashed extraction, 'extracting') indefinitely, and a
%   naive wait would spend the full timeout on every call for that
%   dataset. Jobs whose relevant timestamp (startedAt for 'extracting',
%   otherwise createdAt) is older than staleAfter seconds are treated as
%   abandoned: they are ignored when deciding whether the active set has
%   drained and are reported in answer.staleJobs. Jobs whose timestamps
%   cannot be parsed are never treated as stale.
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
        staleAfter (1,1) double = 3600
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
                args.staleAfter (1,1) double {mustBePositive} = 3600
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.requireAllComplete = args.requireAllComplete;
            this.staleAfter = args.staleAfter;
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
            %                 offending jobs and elapsed wall time. In all
            %                 cases, staleJobs lists active jobs that were
            %                 ignored as abandoned (see staleAfter).
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
                    [liveJobs, staleJobs] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.partitionStaleJobs(...
                        status.jobs, this.staleAfter, datetime('now', 'TimeZone', 'UTC'));
                    answer = status;
                    answer.jobs = liveJobs;
                    answer.staleJobs = staleJobs;
                    if isempty(liveJobs)
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
                                    answer.staleJobs = staleJobs;
                                    return;
                                end
                            end
                        end
                        b = true;
                        answer = struct('state', 'complete', ...
                                        'jobs', [], ...
                                        'elapsed', toc(deadline));
                        answer.staleJobs = staleJobs;
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
                        answer = struct('state', 'timeout', 'elapsed', elapsed, 'jobs', [], 'staleJobs', []);
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

    methods (Static)
        function [liveJobs, staleJobs] = partitionStaleJobs(jobs, staleAfter, nowUtc)
            %PARTITIONSTALEJOBS Split a jobs list into live and abandoned jobs.
            %
            %   [LIVEJOBS, STALEJOBS] = PARTITIONSTALEJOBS(JOBS, STALEAFTER, NOWUTC)
            %
            %   JOBS is the 'jobs' value decoded from the bulk-uploads
            %   listing (a struct array, a cell array of structs, or []).
            %   A job is stale when its reference time (startedAt for
            %   state 'extracting', otherwise createdAt) is more than
            %   STALEAFTER seconds before NOWUTC (a UTC datetime). Jobs
            %   with missing or unparseable timestamps are kept as live.
            %   Both outputs have the same container type as JOBS.
            arguments
                jobs
                staleAfter (1,1) double
                nowUtc (1,1) datetime
            end

            if isempty(jobs) || ~(isstruct(jobs) || iscell(jobs))
                liveJobs = jobs;
                staleJobs = [];
                return;
            end

            isStale = false(size(jobs));
            for k = 1:numel(jobs)
                if iscell(jobs)
                    job = jobs{k};
                else
                    job = jobs(k);
                end
                if ~isstruct(job) || ~isscalar(job)
                    continue;
                end
                refTime = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobReferenceTime(job);
                if ~isnat(refTime)
                    isStale(k) = seconds(nowUtc - refTime) > staleAfter;
                end
            end

            liveJobs = jobs(~isStale);
            staleJobs = jobs(isStale);
        end

        function refTime = jobReferenceTime(job)
            %JOBREFERENCETIME The timestamp used to judge whether a job is stale.
            %
            %   Returns startedAt for jobs in state 'extracting' (falling
            %   back to createdAt), otherwise createdAt. Returns NaT
            %   (UTC) if no usable timestamp is present.
            refTime = NaT('TimeZone', 'UTC');
            candidates = {'createdAt'};
            if isfield(job, 'state') && strcmpi(string(job.state), "extracting")
                candidates = {'startedAt', 'createdAt'};
            end
            for c = 1:numel(candidates)
                f = candidates{c};
                if isfield(job, f)
                    t = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.parseTimestamp(job.(f));
                    if ~isnat(t)
                        refTime = t;
                        return;
                    end
                end
            end
        end

        function t = parseTimestamp(value)
            %PARSETIMESTAMP Parse an ISO 8601 server timestamp as a UTC datetime.
            %
            %   Accepts strings such as '2026-11-05T12:34:56.789Z',
            %   '2026-11-05T12:34:56Z' or '2026-11-05T12:34:56+00:00'.
            %   Strings without an offset are taken to be UTC.
            %   Returns NaT (UTC) for empty or unparseable input.
            t = NaT('TimeZone', 'UTC');
            if isempty(value) || ~(ischar(value) || isstring(value))
                return;
            end
            str = strtrim(char(string(value)));
            if isempty(str)
                return;
            end
            % Drop fractional seconds (any precision); staleness is
            % judged on a scale of minutes, so they do not matter.
            str = regexprep(str, '(:\d{2})\.\d+', '$1');
            % Spell a trailing 'Z' (UTC) as an explicit offset.
            str = regexprep(str, '[zZ]$', '+00:00');
            formats = { ...
                'yyyy-MM-dd''T''HH:mm:ssXXX', ...
                'yyyy-MM-dd''T''HH:mm:ssXX', ...
                'yyyy-MM-dd''T''HH:mm:ss', ...
                'yyyy-MM-dd HH:mm:ss'};
            for k = 1:numel(formats)
                try
                    t = datetime(str, 'InputFormat', formats{k}, 'TimeZone', 'UTC');
                    return;
                catch
                    % try the next format
                end
            end
            t = NaT('TimeZone', 'UTC');
        end
    end
end
