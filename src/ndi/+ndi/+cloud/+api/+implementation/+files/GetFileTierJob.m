classdef GetFileTierJob < ndi.cloud.api.call
%GETFILETIERJOB Implementation for GET /file-tier-jobs/{jobId}.
%
%   Poll for the state of an async file-tier job created by SetFileTier.
%   Response body always carries { jobId, datasetId, state, targetTier,
%   fileCount, filesDone, filesFailed, perPhaseCounts, errors, createdAt,
%   updatedAt }. Terminal states: 'completed' | 'failed' | 'superseded'.

    properties
        jobID (1,1) string
    end

    methods
        function this = GetFileTierJob(args)
            arguments
                args.jobID (1,1) string
            end
            this.jobID = args.jobID;
            this.endpointName = 'get_file_tier_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            apiURL = ndi.cloud.api.url('get_file_tier_job', 'job_id', this.jobID);

            method = matlab.net.http.RequestMethod.GET;
            acceptField        = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end
