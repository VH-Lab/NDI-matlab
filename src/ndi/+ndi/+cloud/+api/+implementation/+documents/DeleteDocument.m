classdef DeleteDocument < ndi.cloud.api.call
%DELETEDOCUMENT Implementation class for deleting a single document.

    properties (Access = protected)
        when
    end

    methods
        function this = DeleteDocument(args)
            %DELETEDOCUMENT Creates a new DeleteDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.DeleteDocument('cloudDatasetID', ID, 'cloudDocumentID', DOC_ID, 'when', '7d')
            %
            %   Inputs:
            %       'cloudDatasetID'  - The ID of the dataset containing the document.
            %       'cloudDocumentID' - The cloud API ID of the document to delete.
            %       'when'            - (Optional) Duration string. Default: '7d'.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.when (1,1) string = "7d"
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.when = args.when;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to delete the document.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The API response body on success, or an error struct on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('delete_document', ...
                'dataset_id', this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            % Add query parameter 'when'
            q = matlab.net.QueryParameter('when', this.when);
            if isempty(apiURL.Query)
                apiURL.Query = q;
            else
                apiURL.Query = [apiURL.Query q];
            end

            method = matlab.net.http.RequestMethod.DELETE;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 204 || apiResponse.StatusCode == 504)
                b = true;
                if ~isempty(apiResponse.Body.Data)
                    answer = apiResponse.Body.Data;
                else
                    answer = "Document deleted.";
                end
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end
