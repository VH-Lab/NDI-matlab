classdef UnpublishDataset < ndi.cloud.api.call
%UNPUBLISHDATASET Implementation class for unpublishing a dataset.

    methods
        function this = UnpublishDataset(args)
            %UNPUBLISHDATASET Creates a new UnpublishDataset API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.UnpublishDataset( ...
            %      'cloudDatasetID', ID)
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset to unpublish.
            %
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to unpublish the dataset.
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
            
            apiURL = ndi.cloud.api.url('unpublish_dataset', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.POST;
            
            body = matlab.net.http.MessageBody('');

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
end

