classdef UpdateDocument < ndi.cloud.api.call
%UPDATEDOCUMENT Implementation class for updating an existing document.

    properties
        jsonDocument    % The new document data as a JSON string
    end

    methods
        function this = UpdateDocument(args)
            %UPDATEDOCUMENT Creates a new UpdateDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.UpdateDocument('cloudDatasetID', ID, 'cloudDocumentID', DOC_ID, 'jsonDocument', JSON)
            %
            %   Inputs:
            %       'cloudDatasetID'  - The ID of the dataset.
            %       'cloudDocumentID' - The cloud API ID of the document to update.
            %       'jsonDocument'    - A string containing the full JSON data for the updated document.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.jsonDocument (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.jsonDocument = args.jsonDocument;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to update the document.
            
            % Initialize outputs
            b = false;
            answer = [];
            apiResponse = [];

            try
                token = ndi.cloud.authenticate();
                apiURL = ndi.cloud.api.url('update_document', ...
                    'dataset_id', this.cloudDatasetID, ...
                    'document_id', this.cloudDocumentID);

                % Save JSON to a temporary file to ensure correct transmission
                [tempFilePath, cleanupObj] = saveDocumentToTemporaryFile(this.jsonDocument);
                
                method = matlab.net.http.RequestMethod.POST;
                body = matlab.net.http.io.FileProvider(tempFilePath);

                headers = [
                    matlab.net.http.HeaderField('accept','application/json'), ...
                    matlab.net.http.field.ContentTypeField('application/json'), ...
                    matlab.net.http.HeaderField('Authorization', ['Bearer ' token])
                ];

                request = matlab.net.http.RequestMessage(method, headers, body);
                apiResponse = request.send(apiURL);

                answer = apiResponse.Body.Data;

                if apiResponse.StatusCode == matlab.net.http.StatusCode.OK
                    b = true;
                    % Robustness check: if response is a char, decode it
                    if ischar(answer)
                        answer = jsondecode(answer);
                    end
                else
                    b = false;
                end

            catch ME
                b = false;
                answer = ME.message;
                apiResponse = ME;
            end
        end
    end
end

function [file_path, file_cleanup_obj] = saveDocumentToTemporaryFile(document)
    % Helper function to save a string to a temporary file and ensure cleanup.
    file_path = [tempname, '.json'];
    fid = fopen(file_path, 'w');
    fprintf(fid, '%s', document);
    fclose(fid);
    file_cleanup_obj = onCleanup(@() delete(file_path));
end


