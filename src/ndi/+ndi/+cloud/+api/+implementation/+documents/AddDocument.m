classdef AddDocument < ndi.cloud.api.call
%ADDDOCUMENT Implementation class for adding a new document.

    properties
        jsonDocument % The document data as a JSON string
    end

    methods
        function this = AddDocument(args)
            %ADDDOCUMENT Creates a new AddDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.AddDocument('cloudDatasetID', ID, 'jsonDocument', JSON)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'jsonDocument'   - The document data as a JSON string.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.jsonDocument (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.jsonDocument = args.jsonDocument;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to add the document using webwrite for robustness.
            
            % Initialize outputs
            b = false;
            answer = [];
            apiResponse = [];

            token = ndi.cloud.authenticate();
            apiURL = ndi.cloud.api.url('add_document', 'dataset_id', this.cloudDatasetID);

            try
                opts = weboptions(...
                    'HeaderFields', ["Authorization", sprintf("Bearer %s", token)] ...
                    );
                
                % webwrite automatically handles JSON encoding and decoding
                answer = webwrite(apiURL.EncodedURI, this.jsonDocument, opts);
                
                b = true;
                apiResponse = answer; % Set apiResponse to be the same as the answer

            catch ME
                b = false;
                answer = ME.message;
                apiResponse = ME.message;
            end
        end
    end
end

