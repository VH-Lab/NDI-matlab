classdef WaitForFileUpload < ndi.cloud.api.call
%WAITFORFILEUPLOAD Wait until single-file uploads are recorded by the server.
%
%   Implementation class behind ndi.cloud.api.files.waitForFileUpload.
%   Polls lookupFiles(datasetId, uids) with exponential backoff until every
%   uid is marked uploaded or the overall timeout elapses.
%
%   A signed PUT returning 200 only means S3 has the object; the server
%   records the upload in an S3-triggered step afterwards. Use this between
%   a single-file putFiles and anything that reads the file's record
%   (listFiles, getFileDetails, a download URL).

    properties
        cloudFileUIDs (1,:) string
        timeout (1,1) double = 120
        initialInterval (1,1) double = 1
        maxInterval (1,1) double = 10
        backoffFactor (1,1) double = 2
    end

    methods
        function this = WaitForFileUpload(args)
            %WAITFORFILEUPLOAD Construct a new WaitForFileUpload call.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUIDs (1,:) string
                args.timeout (1,1) double {mustBePositive} = 120
                args.initialInterval (1,1) double {mustBePositive} = 1
                args.maxInterval (1,1) double {mustBePositive} = 10
                args.backoffFactor (1,1) double {mustBePositive} = 2
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUIDs = unique(args.cloudFileUIDs, 'stable');
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.endpointName = 'lookup_dataset_files';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll until every uid is uploaded or the timeout elapses.
            %
            %   b           - true iff every uid was marked uploaded before
            %                 the timeout. false on timeout; a failing
            %                 lookupFiles call is retried until then.
            %   answer      - struct with state ('complete' or 'timeout'),
            %                 files (the uploaded rows, plus on timeout the
            %                 last poll's rows for uids still pending),
            %                 pending (uids not yet uploaded) and elapsed.
            %   apiResponse - The ResponseMessage from the last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            apiResponse = [];
            apiURL = [];
            doneFiles = []; % lookupFiles rows already marked uploaded
            pendingFiles = []; % latest rows for uids not yet uploaded
            pending = this.cloudFileUIDs;

            deadline = tic;
            interval = this.initialInterval;

            while ~isempty(pending)
                [ok, result, apiResponse, apiURL] = this.pollStatus(pending);

                if ok && isstruct(result) && isfield(result, 'files')
                    pendingFiles = [];
                    if ~isempty(result.files)
                        result.files = result.files(:);
                        isUp = [result.files.uploaded];
                        doneFiles = [doneFiles; result.files(isUp)]; %#ok<AGROW>
                        pendingFiles = result.files(~isUp);
                        pending = setdiff(pending, string({result.files(isUp).uid}), 'stable');
                    end
                    if isempty(pending)
                        break;
                    end
                end

                elapsed = toc(deadline);
                if elapsed >= this.timeout
                    answer = struct('state', 'timeout', 'files', [doneFiles; pendingFiles], ...
                                    'pending', pending, 'elapsed', elapsed);
                    return;
                end

                remaining = this.timeout - elapsed;
                pause(min([interval, this.maxInterval, remaining]));
                interval = min(interval * this.backoffFactor, this.maxInterval);
            end

            b = true;
            answer = struct('state', 'complete', 'files', doneFiles, ...
                            'pending', strings(1, 0), 'elapsed', toc(deadline));
        end
    end

    methods (Access = protected)
        function [ok, result, apiResponse, apiURL] = pollStatus(this, uids)
            %POLLSTATUS Look up the given uids once. Seam: a test subclass
            %   overrides this to script a sequence of lookupFiles results,
            %   so the completion, timeout and retry logic can be exercised
            %   without a server.
            [ok, result, apiResponse, apiURL] = ...
                ndi.cloud.api.files.lookupFiles(this.cloudDatasetID, uids);
        end
    end
end
