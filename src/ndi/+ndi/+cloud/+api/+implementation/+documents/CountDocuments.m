classdef CountDocuments < ndi.cloud.api.call
%COUNTDOCUMENTS Implementation class for counting documents in a dataset.

    methods
        function this = CountDocuments(args)
            %COUNTDOCUMENTS Creates a new CountDocuments API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.CountDocuments('cloudDatasetID', ID)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to query.
            %
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to count documents.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The document count on success, or an error struct on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('document_count', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data.count;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

