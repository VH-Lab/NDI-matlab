classdef GetBulkUploadURL < ndi.cloud.api.call
%GETBULKUPLOADURL Implementation class for getting a bulk upload URL.

    methods
        function this = GetBulkUploadURL(args)
            %GETBULKUPLOADURL Creates a new GetBulkUploadURL API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.GetBulkUploadURL('cloudDatasetID', ID)
            %
            %   Inputs:
            %       'cloudDatasetID'   - The ID of the dataset.
            %
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the bulk upload URL.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('bulk_upload_documents', 'dataset_id', this.cloudDatasetID);

            % Per the original implementation, this is a POST with an empty body
            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody('');
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
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

