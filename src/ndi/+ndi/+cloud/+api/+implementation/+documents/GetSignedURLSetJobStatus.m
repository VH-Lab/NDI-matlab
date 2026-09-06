classdef GetSignedURLSetJobStatus < ndi.cloud.api.call
%GETSIGNEDURLSETJOBSTATUS Implementation for GET /signed-url-set-jobs/{jobId}.
%
%   Reports the state of an asynchronous signed-url-set job: queued, running,
%   ready or failed. When ready, the answer carries resultUrl -- a presigned GET
%   for the gzipped JSON map -- and filesExpireAt, when the URLs inside that map
%   stop working.

    properties
        jobId (1,1) string
    end

    methods
        function this = GetSignedURLSetJobStatus(args)
            %GETSIGNEDURLSETJOBSTATUS Creates a new GetSignedURLSetJobStatus call.
            arguments
                args.jobId (1,1) string
            end
            this.jobId = args.jobId;
            this.endpointName = 'get_signed_url_set_job';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_signed_url_set_job', 'job_id', this.jobId);

            method = matlab.net.http.RequestMethod.GET;
            acceptField = matlab.net.http.HeaderField('accept','application/json');
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
