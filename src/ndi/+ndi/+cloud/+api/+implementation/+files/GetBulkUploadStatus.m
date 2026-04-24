classdef GetBulkUploadStatus < ndi.cloud.api.call
%GETBULKUPLOADSTATUS Implementation for the GET /bulk-uploads/{jobId} endpoint.
%
%   Returns the current state of a single bulk upload job so clients can
%   wait for server-side zip extraction to finish before downloading the
%   extracted files.

    properties
        jobId (1,1) string
    end

    methods
        function this = GetBulkUploadStatus(args)
            %GETBULKUPLOADSTATUS Creates a new GetBulkUploadStatus call.
            arguments
                args.jobId (1,1) string
            end
            this.jobId = args.jobId;
            this.endpointName = 'get_bulk_upload_status';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.

            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('get_bulk_upload_status', ...
                'job_id', this.jobId);

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
