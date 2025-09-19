classdef UpdateDataset < ndi.cloud.api.call
%UPDATEDATASET Implementation class for updating a dataset's metadata.

    methods
        function this = UpdateDataset(args)
            %UPDATEDATASET Creates a new UpdateDataset API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.UpdateDataset( ...
            %      'cloudDatasetID', ID, 'datasetInfoStruct', STRUCT)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to update.
            %       'datasetInfoStruct' - A struct with the metadata to update.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.datasetInfoStruct (1,1) struct
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.datasetInfoStruct = args.datasetInfoStruct;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to update the dataset.
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
            
            apiURL = ndi.cloud.api.url('update_dataset', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;
            
            body = matlab.net.http.MessageBody(this.datasetInfoStruct);

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

    properties (Access=protected)
        datasetInfoStruct
    end
end

