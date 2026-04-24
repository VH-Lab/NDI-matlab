classdef BulkFetch < ndi.cloud.api.call
%BULKFETCH Implementation class for synchronously fetching multiple documents by ID.

    properties (Access=protected)
        documentIDsToFetch
    end

    methods
        function this = BulkFetch(args)
            %BULKFETCH Creates a new BulkFetch API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.BulkFetch( ...
            %      'cloudDatasetID', ID, 'cloudDocumentIDs', DOC_IDS)
            %
            %   Inputs:
            %       'cloudDatasetID'   - The ID of the dataset containing the documents.
            %       'cloudDocumentIDs' - A string array of cloud API document IDs to fetch.
            %                            Must be non-empty, at most 500 entries,
            %                            and each entry must be a 24-character hex string.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentIDs (1,:) string
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.documentIDsToFetch = args.cloudDocumentIDs;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to bulk-fetch documents.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - On success, a struct array of documents from the
            %                      server's `documents` field (each with id, ndiId,
            %                      name, className, datasetId, data). On failure,
            %                      the error body returned by the server.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %

            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url('bulk_fetch_documents', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;

            % The server expects an array for documentIds. When MATLAB encodes a
            % scalar string to JSON it produces a bare string (not an array), so
            % duplicate the single entry as a workaround (matching the pattern
            % used by GetBulkDownloadURL).
            if isscalar(this.documentIDsToFetch)
                docIdRequest = [this.documentIDsToFetch this.documentIDsToFetch];
            else
                docIdRequest = this.documentIDsToFetch;
            end

            json = struct('documentIds', docIdRequest);
            body = matlab.net.http.MessageBody(json);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiResponse = send(request, apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                if ~isempty(apiResponse.Body.Data) && isfield(apiResponse.Body.Data, 'documents')
                    answer = apiResponse.Body.Data.documents;
                else
                    answer = [];
                end
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
