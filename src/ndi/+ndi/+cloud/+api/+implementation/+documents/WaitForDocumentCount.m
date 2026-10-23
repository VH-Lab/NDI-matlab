classdef WaitForDocumentCount < ndi.cloud.api.call
%WAITFORDOCUMENTCOUNT Poll a dataset's document count until it reaches a target.
%
%   Implementation behind ndi.cloud.api.documents.waitForDocumentCount.
%   Polls GET /datasets/{id}/documents/count at exponentially growing
%   intervals (capped) until the count is at least expectedCount or the
%   overall timeout elapses.
%
%   A bulk document upload (ndi.cloud.api.documents.getBulkUploadURL plus
%   a PUT of the zip) returns before the server has ingested the
%   documents, and unlike a bulk file upload it gives no job id to wait
%   on. The document count is the only signal that ingestion has caught
%   up, so this is the document-side counterpart to
%   ndi.cloud.api.files.waitForAllBulkUploads.

    properties
        expectedCount   (1,1) double = 0
        timeout         (1,1) double = 300
        initialInterval (1,1) double = 1
        maxInterval     (1,1) double = 10
        backoffFactor   (1,1) double = 2
    end

    methods
        function this = WaitForDocumentCount(args)
            arguments
                args.cloudDatasetID  (1,1) string
                args.expectedCount   (1,1) double {mustBeNonnegative, mustBeInteger}
                args.timeout         (1,1) double {mustBePositive} = 300
                args.initialInterval (1,1) double {mustBePositive} = 1
                args.maxInterval     (1,1) double {mustBePositive} = 10
                args.backoffFactor   (1,1) double {mustBePositive} = 2
            end
            this.cloudDatasetID  = args.cloudDatasetID;
            this.expectedCount   = args.expectedCount;
            this.timeout         = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval     = args.maxInterval;
            this.backoffFactor   = args.backoffFactor;
            this.endpointName = 'document_count';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll until the document count reaches expectedCount.
            %
            %   b           - true iff a poll reported a count of at least
            %                 expectedCount before the timeout.
            %   answer      - struct with fields state ('complete' or
            %                 'timeout'), count (the last count read, or
            %                 NaN if no poll succeeded), expectedCount and
            %                 elapsed (seconds).
            %   apiResponse - The ResponseMessage from the last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            answer = struct('state', 'unknown', 'count', NaN, ...
                'expectedCount', this.expectedCount, 'elapsed', 0);

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, count, apiResponse, apiURL] = this.pollCount();
                % A failing poll is transient: keep the last good count
                % and try again rather than giving up on a gateway blip.
                if ok && isnumeric(count) && isscalar(count)
                    answer.count = double(count);
                    if answer.count >= this.expectedCount
                        b = true;
                        answer.state = 'complete';
                        answer.elapsed = toc(deadline);
                        return;
                    end
                end

                elapsed = toc(deadline);
                if elapsed >= this.timeout
                    answer.state = 'timeout';
                    answer.elapsed = elapsed;
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
        function [ok, count, apiResponse, apiURL] = pollCount(this)
            %POLLCOUNT Read the dataset's document count once. Seam: a test
            %   subclass overrides this to script a sequence of counts, so
            %   the target, timeout and retry logic can be exercised
            %   without a server.
            [ok, count, apiResponse, apiURL] = ...
                ndi.cloud.api.documents.documentCount(this.cloudDatasetID);
        end
    end
end
