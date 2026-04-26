classdef WaitForUnpublished < ndi.cloud.api.call
%WAITFORUNPUBLISHED Polls a dataset until its 'isPublished' flag becomes false.
%
%   Implementation class behind ndi.cloud.api.datasets.waitForUnpublished.
%   Polls GET /datasets/{cloudDatasetID} at exponentially growing intervals
%   (capped) until answer.isPublished is false (or absent) or the overall
%   timeout elapses.

    properties
        timeout (1,1) double = 180
        initialInterval (1,1) double = 2
        maxInterval (1,1) double = 30
        backoffFactor (1,1) double = 2
    end

    methods
        function this = WaitForUnpublished(args)
            %WAITFORUNPUBLISHED Creates a new WaitForUnpublished call.
            arguments
                args.cloudDatasetID (1,1) string
                args.timeout (1,1) double {mustBePositive} = 180
                args.initialInterval (1,1) double {mustBePositive} = 2
                args.maxInterval (1,1) double {mustBePositive} = 30
                args.backoffFactor (1,1) double {mustBePositive} = 2
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.timeout = args.timeout;
            this.initialInterval = args.initialInterval;
            this.maxInterval = args.maxInterval;
            this.backoffFactor = args.backoffFactor;
            this.endpointName = 'get_dataset';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Poll getDataset until isPublished is false or timeout.
            %
            %   b           - true iff the dataset reached
            %                 isPublished=false before the timeout. false
            %                 on API error or timeout.
            %   answer      - The last dataset struct returned by the
            %                 server. On timeout, fields 'state' = 'timeout'
            %                 and 'elapsed' are added.
            %   apiResponse - The matlab.net.http.ResponseMessage from the
            %                 last poll.
            %   apiURL      - The URL of the last poll.

            b = false;
            answer = [];
            apiResponse = [];
            apiURL = [];

            deadline = tic;
            interval = this.initialInterval;

            while true
                [ok, ds, apiResponse, apiURL] = ndi.cloud.api.datasets.getDataset(this.cloudDatasetID);
                answer = ds;

                if ok && isstruct(ds)
                    isPub = isfield(ds, 'isPublished') && ~isempty(ds.isPublished) ...
                        && logical(ds.isPublished);
                    if ~isPub
                        b = true;
                        return;
                    end
                end

                elapsed = toc(deadline);
                if elapsed >= this.timeout
                    b = false;
                    if ~isstruct(answer)
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
