classdef BulkDeleteDocuments < ndi.cloud.api.call
%BULKDELETEDOCUMENTS Implementation class for deleting multiple documents.

    properties (Access=protected)
        documentIDsToDelete
        when
    end

    methods
        function this = BulkDeleteDocuments(args)
            %BULKDELETEDOCUMENTS Creates a new BulkDeleteDocuments API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.BulkDeleteDocuments( ...
            %      'cloudDatasetID', ID, 'cloudDocumentIDs', DOC_IDS, 'when', '7d')
            %
            %   Inputs:
            %       'cloudDatasetID'   - The ID of the dataset from which to delete documents.
            %       'cloudDocumentIDs' - A string array of cloud API document IDs to delete.
            %       'when'             - (Optional) Duration string. Default: '7d'.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentIDs (1,:) string
                args.when (1,1) string = "7d"
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.documentIDsToDelete = args.cloudDocumentIDs;
            this.when = args.when;
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

            if isscalar(this.documentIDsToDelete)
                % just delete it singly to avoid JSON conversion that API
                % does not expect (it expects an array, Matlab produces a
                % single object)
                [b, answer, apiResponse, apiURL] = ndi.cloud.api.documents.deleteDocument(...
                    this.cloudDatasetID, this.documentIDsToDelete, 'when', this.when);
                return
            end

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('bulk_delete_documents', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;

            json = struct('documentIds', this.documentIDsToDelete, 'when', this.when);
            body = matlab.net.http.MessageBody(json);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 204 || apiResponse.StatusCode == 504)
                b = true;
                if ~isempty(apiResponse.Body.Data)
                    answer = apiResponse.Body.Data;
                else
                    answer = "Documents deleted.";
                end
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end
