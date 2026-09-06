classdef GetSignedURLSetJob < ndi.cloud.api.call
%GETSIGNEDURLSETJOB Implementation for GET /signed-url-set-jobs/{jobId}.
%
%   Poll for the state of an async signed-URL-set job created by
%   CreateSignedURLSetJob. The response body always carries
%   { jobId, datasetId, documentId, state, ... }. When state is 'ready'
%   the body also carries `resultUrl` (a 24 h presigned GET for the
%   gzipped JSON blob), `resultByteSize`, and `filesExpireAt`. When state
%   is 'failed' it carries `error`.

    properties
        jobId (1,1) string
    end

    methods
        function this = GetSignedURLSetJob(args)
            arguments
                args.jobId (1,1) string
            end
            this.jobId = args.jobId;
            this.endpointName = 'get_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_signed_url_set_job', ...
                'job_id', this.jobId);

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
