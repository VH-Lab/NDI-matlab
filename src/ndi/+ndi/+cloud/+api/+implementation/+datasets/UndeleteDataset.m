classdef UndeleteDataset < ndi.cloud.api.call
    %UNDELETEDATASET Implements the API call to undelete a dataset.

    methods
        function this = UndeleteDataset(args)
            % The arguments block for name-value pair validation
            arguments
                args.cloudDatasetID (1,1) string
            end

            this.cloudDatasetID = args.cloudDatasetID;
            this.endpointName = "undelete_dataset";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to undelete a dataset.

            method = matlab.net.http.RequestMethod.POST;

            auth_token = ndi.cloud.authenticate();
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiURL = ndi.cloud.api.url(this.endpointName, 'dataset_id', this.cloudDatasetID);

            apiResponse = request.send(apiURL);

            if (apiResponse.StatusCode == 200)
                b = true;
                if ~isempty(apiResponse.Body.Data)
                     answer = apiResponse.Body.Data;
                else
                     answer = 'Dataset undelete process started.';
                end
            else
                b = false;
                answer = [];
            end
        end
    end
end
