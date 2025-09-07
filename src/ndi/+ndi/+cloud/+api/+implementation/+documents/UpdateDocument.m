classdef UpdateDocument < ndi.cloud.api.call
%UPDATEDOCUMENT Implementation class for updating a document.

    properties
        documentInfoStruct
    end

    methods
        function this = UpdateDocument(args)
            %UPDATEDOCUMENT Creates a new UpdateDocument API call object.
            %
            %   THIS = ndi.cloud.api.implementation.documents.UpdateDocument(...
            %       'cloudDatasetID', ID, 'cloudDocumentID', DOC_ID, 'documentInfoStruct', S)
            %
            %   Inputs:
            %       'cloudDatasetID'      - The ID of the dataset.
            %       'cloudDocumentID'     - The cloud API ID of the document to update.
            %       'documentInfoStruct'  - A struct with the updated document data.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudDocumentID (1,1) string
                args.documentInfoStruct (1,1) struct
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudDocumentID = args.cloudDocumentID;
            this.documentInfoStruct = args.documentInfoStruct;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to update the document.
            
            % Initialize outputs
            b = false;
            answer = [];
            
            % Create a temporary file to hold the document JSON
            tempFilePath = [tempname '.json'];
            cleanupObj = onCleanup(@() delete(tempFilePath));
            
            try
                jsonString = did.datastructures.jsonencodenan(this.documentInfoStruct);
                fid = fopen(tempFilePath, 'w');
                fprintf(fid, '%s', jsonString);
                fclose(fid);
            catch ME
                error('Failed to create temporary JSON file for document update: %s', ME.message);
            end

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('update_document', ...
                'dataset_id', this.cloudDatasetID, ...
                'document_id', this.cloudDocumentID);

            method = matlab.net.http.RequestMethod.POST;
            
            provider = matlab.net.http.io.FileProvider(tempFilePath);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, provider);
            
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

