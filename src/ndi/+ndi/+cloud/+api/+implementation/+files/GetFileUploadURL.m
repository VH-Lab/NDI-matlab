classdef GetFileUploadURL < ndi.cloud.api.call
%GETFILEUPLOADURL Implementation for getting a single file upload URL.

    properties
        cloudFileUID
    end

    methods
        function this = GetFileUploadURL(args)
            %GETFILEUPLOADURL Creates a new GetFileUploadURL call.
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'cloudFileUID'   - The unique identifier for the file.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUID = args.cloudFileUID;
            this.endpointName = 'get_file_upload_url';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            % This endpoint requires organizationId, which we get from the dataset info
            [get_b, dsetinfo, ~, ~] = ndi.cloud.api.datasets.getDataset(this.cloudDatasetID);
            if ~get_b
                apiResponse = [];
                apiURL = [];
                answer = 'Failed to retrieve dataset info to determine organization ID.';
                return;
            end
            
            apiURL = ndi.cloud.api.url('get_file_upload_url', ...
                'dataset_id', this.cloudDatasetID, ...
                'organization_id', dsetinfo.organizationId, ...
                'file_uid', this.cloudFileUID);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data.url;
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

