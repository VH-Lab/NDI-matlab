classdef GetDocument < ndi.cloud.api.call
%GETDOCUMENT Implementation class for getting a single document.

    methods
        function this = GetDocument(args)
            %GETDOCUMENT Creates a new GetDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.GetDocument('cloudDatasetID', ID, 'cloudDocumentID', DOC_ID)
            %
            %   Inputs:
            %       'cloudDatasetID'  - The ID of the dataset.
            %       'cloudDocumentID' - The cloud API ID of the document.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the document.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('get_document', ...
                'dataset_id', this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

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

