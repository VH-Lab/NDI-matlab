classdef AddDocument < ndi.cloud.api.call
%ADDDOCUMENT Implementation class for adding a document to a dataset.

    properties (Access=protected)
        jsonDocument
    end

    methods
        function this = AddDocument(args)
            %ADDDOCUMENT Creates a new AddDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.AddDocument( ...
            %      'cloudDatasetID', ID, 'jsonDocument', JSON)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to add the document to.
            %       'jsonDocument'   - A JSON-encoded string representing the new document.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.jsonDocument (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.jsonDocument = args.jsonDocument;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to add the document.
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
            
            apiURL = ndi.cloud.api.url('add_document', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;
            
            body = matlab.net.http.MessageBody(this.jsonDocument);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiResponse = send(request, apiURL);
            
            % A successful document creation can return 200 (OK) or 201 (Created)
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

