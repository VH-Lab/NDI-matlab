classdef WaitForAllBulkUploads < ndi.cloud.api.call
%WAITFORALLBULKUPLOADS Wait for every bulk-upload job on a dataset to finish.
%
%   Implementation class behind ndi.cloud.api.files.waitForAllBulkUploads.
%   Polls listActiveBulkUploads(datasetId, 'state', 'active') with
%   exponential backoff until no active (queued + extracting) jobs remain
%   or the overall timeout elapses. When requireAllComplete is true, also
%   queries state='failed' once the active set drains and reports b=false
%   if any job failed recently (see below).
%
%   Abandoned uploads: the server creates a BulkUploadJob in state
%   'queued' as soon as a client asks for a bulk upload URL, and the job
%   only leaves that state when the zip arrives. If the PUT fails, is
%   interrupted, or never happens, the job stays 'queued', and a naive
%   wait would spend the full timeout on every call for that dataset.
%   'queued' jobs created more than staleAfter seconds ago are treated as
%   abandoned: they are ignored when deciding whether the active set has
%   drained and are reported in answer.staleJobs. A healthy upload leaves
%   'queued' within minutes of getting its URL.
%
%   'extracting' jobs are never ignored here: a large zip is extracted in
%   many batches and can legitimately take hours, and only the server can
%   tell a slow extraction from a dead one. The server marks extractions
%   with no progress for several hours as failed (and expires 'queued'
%   jobs whose upload URL has expired), so dead jobs eventually leave the
%   active set on their own.
%
%   Recent failures: only jobs whose completedAt is no more than
%   staleAfter seconds before this wait began (or later) count. Older
%   failures are history from earlier uploads, and counting them would
%   make b=false permanent for any dataset that ever had a failure. The
%   cutoff is sent to the server as the 'since' filter and also applied
%   here, for servers that predate that filter.
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
            %                 no job failed recently. false on timeout, on
            %                 a recent failed job, or on API error.
            %   answer      - On success, struct with state='complete' and
            %                 (empty) jobs array. On failure, struct with
            %                 state='timeout' or state='failed' plus the
            %                 offending jobs and elapsed wall time. Once a
            %                 poll has succeeded, staleJobs lists the
            %                 'queued' jobs that were ignored as abandoned.
            %   apiResponse - The ResponseMessage from the last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            answer = struct('state', 'unknown', 'jobs', []);
            apiResponse = [];
            apiURL = [];

            deadline = tic;
            interval = this.initialInterval;
            failedSince = datetime('now', 'TimeZone', 'UTC') - seconds(this.staleAfter);

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
                        % whether any job failed recently.
                        if this.requireAllComplete
                            [okF, failedList, respF, urlF] = ndi.cloud.api.files.listActiveBulkUploads(...
                                this.cloudDatasetID, 'state', 'failed', 'since', failedSince);
                            if okF
                                apiResponse = respF;
                                apiURL = urlF;
                                if isstruct(failedList) && isfield(failedList, 'jobs')
                                    recentFailures = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobsCompletedSince(...
                                        failedList.jobs, failedSince);
                                    if ~isempty(recentFailures)
                                        b = false;
                                        answer = struct('state', 'failed', ...
                                                        'jobs', recentFailures, ...
                                                        'elapsed', toc(deadline));
                                        answer.staleJobs = staleJobs;
                                        return;
                                    end
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
            %PARTITIONSTALEJOBS Split active jobs into live and abandoned ones.
            %
            %   [LIVEJOBS, STALEJOBS] = PARTITIONSTALEJOBS(JOBS, STALEAFTER, NOWUTC)
            %
            %   JOBS is the 'jobs' value decoded from the bulk-uploads
            %   listing (a struct array, a cell array of structs, or []).
            %   A job is stale when its state is 'queued' and its
            %   createdAt is more than STALEAFTER seconds before NOWUTC (a
            %   UTC datetime). Jobs in any other state, and jobs with a
            %   missing or unparseable createdAt, are kept as live. Both
            %   outputs have the same container type as JOBS.
            arguments
                jobs
                staleAfter (1,1) double
                nowUtc (1,1) datetime
            end
            cutoff = nowUtc - seconds(staleAfter);
            isStale = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobMask(jobs, ...
                @(job) isfield(job, 'state') && strcmpi(string(job.state), "queued") && ...
                    ndi.cloud.api.implementation.files.WaitForAllBulkUploads.isBefore(job, 'createdAt', cutoff));
            [staleJobs, liveJobs] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.splitJobs(jobs, isStale);
        end

        function recent = jobsCompletedSince(jobs, sinceUtc)
            %JOBSCOMPLETEDSINCE Keep jobs that finished at or after a time.
            %
            %   RECENT = JOBSCOMPLETEDSINCE(JOBS, SINCEUTC)
            %
            %   Drops jobs whose completedAt (or, if absent, createdAt) is
            %   before SINCEUTC (a UTC datetime). Jobs with neither
            %   timestamp parseable are kept, so an unexpected server
            %   response errs toward reporting a failure. RECENT has the
            %   same container type as JOBS.
            arguments
                jobs
                sinceUtc (1,1) datetime
            end
            isOld = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.jobMask(jobs, ...
                @(job) ndi.cloud.api.implementation.files.WaitForAllBulkUploads.isBefore(job, {'completedAt', 'createdAt'}, sinceUtc));
            [~, recent] = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.splitJobs(jobs, isOld);
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
            % Drop fractional seconds (any precision); these timestamps are
            % compared on a scale of minutes, so they do not matter.
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

    % Helpers. Hidden rather than private because they are called from
    % anonymous functions.
    methods (Static, Hidden)
        function mask = jobMask(jobs, predicate)
            % Logical mask over JOBS (struct array or cell array) where
            % PREDICATE(job) is true. Non-struct entries are false.
            if isempty(jobs) || ~(isstruct(jobs) || iscell(jobs))
                mask = false(size(jobs));
                return;
            end
            mask = false(size(jobs));
            for k = 1:numel(jobs)
                if iscell(jobs)
                    job = jobs{k};
                else
                    job = jobs(k);
                end
                if isstruct(job) && isscalar(job)
                    mask(k) = predicate(job);
                end
            end
        end

        function [selected, rest] = splitJobs(jobs, mask)
            % Split JOBS by MASK, preserving the container type. Inputs
            % that are empty or not job containers are returned whole as
            % REST, with an empty SELECTED.
            if isempty(jobs) || ~(isstruct(jobs) || iscell(jobs))
                selected = [];
                rest = jobs;
                return;
            end
            selected = jobs(mask);
            rest = jobs(~mask);
        end

        function tf = isBefore(job, fields, cutoff)
            % True if the first parseable timestamp among FIELDS (a char
            % field name or a cell array of them, in priority order) is
            % before CUTOFF. False if none is present or parseable.
            if ischar(fields)
                fields = {fields};
            end
            tf = false;
            for k = 1:numel(fields)
                f = fields{k};
                if isfield(job, f)
                    t = ndi.cloud.api.implementation.files.WaitForAllBulkUploads.parseTimestamp(job.(f));
                    if ~isnat(t)
                        tf = t < cutoff;
                        return;
                    end
                end
            end
        end
    end
end
