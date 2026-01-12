classdef GetBulkDownloadURL < ndi.cloud.api.call
%GETBULKDOWNLOADURL Implementation class for getting a bulk download URL.

    methods
        function this = GetBulkDownloadURL(args)
            %GETBULKDOWNLOADURL Creates a new GetBulkDownloadURL API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.GetBulkDownloadURL('cloudDatasetID', ID, 'cloudDocumentIDs', DOC_IDS)
            %
            %   Inputs:
            %       'cloudDatasetID'   - The ID of the dataset.
            %       'cloudDocumentIDs' - (Optional) A string array of cloud API document IDs.
            %                          If not provided, a URL for ALL documents is returned.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentIDs (1,:) string = ""
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            % Note: Storing the array of document IDs in the singular base class property
            this.cloudDocumentID = args.cloudDocumentIDs; 
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the bulk download URL.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('bulk_download_documents', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;
            
            % The body of the request specifies which document IDs to include
            if isscalar(this.cloudDocumentID)
                docIdRequest = [this.cloudDocumentID this.cloudDocumentID]; % work around to make an array in JSON
            else
                docIdRequest = this.cloudDocumentID;
            end

            data = struct('documentIds', docIdRequest);
            body = matlab.net.http.MessageBody(data);
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField('application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data.url;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

