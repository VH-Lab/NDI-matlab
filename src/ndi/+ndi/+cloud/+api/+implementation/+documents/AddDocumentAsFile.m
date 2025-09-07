classdef AddDocumentAsFile < ndi.cloud.api.call
%ADDDOCUMENTASFILE Implementation class for adding a large document from a file.

    properties (Access=protected)
        filePath
    end

    methods
        function this = AddDocumentAsFile(args)
            %ADDDOCUMENTASFILE Creates a new AddDocumentAsFile API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.AddDocumentAsFile( ...
            %      'cloudDatasetID', ID, 'filePath', PATH)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to add the document to.
            %       'filePath'       - The full path to a file containing the 
            %                          JSON-encoded document.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.filePath (1,1) string {mustBeFile}
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.filePath = args.filePath;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to add the document from a file.
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
            
            provider = matlab.net.http.io.FileProvider(this.filePath);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, provider);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
                b = true;
                answer = apiResponse.Body.Data;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

