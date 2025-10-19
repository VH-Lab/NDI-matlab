classdef BulkDeleteDocuments < ndi.cloud.api.call
%BULKDELETEDOCUMENTS Implementation class for deleting multiple documents.

    properties (Access=protected)
        documentIDsToDelete
    end

    methods
        function this = BulkDeleteDocuments(args)
            %BULKDELETEDOCUMENTS Creates a new BulkDeleteDocuments API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.BulkDeleteDocuments( ...
            %      'cloudDatasetID', ID, 'cloudDocumentIDs', DOC_IDS)
            %
            %   Inputs:
            %       'cloudDatasetID'   - The ID of the dataset from which to delete documents.
            %       'cloudDocumentIDs' - A string array of cloud API document IDs to delete.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentIDs (1,:) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.documentIDsToDelete = args.cloudDocumentIDs;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to bulk delete documents.
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
            
            apiURL = ndi.cloud.api.url('bulk_delete_documents', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;

            json = struct('documentIds', this.documentIDsToDelete);
            body = matlab.net.http.MessageBody(json);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

