classdef DeleteDataset < ndi.cloud.api.call
    %DELETEDATASET Implements the API call to delete a dataset.

    methods
        function this = DeleteDataset(args)
            % The arguments block for name-value pair validation
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.endpointName = "delete_dataset";
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            % EXECUTE - Performs the API call to delete a dataset.
            
            method = matlab.net.http.RequestMethod.DELETE;

            auth_token = ndi.cloud.authenticate();
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiURL = ndi.cloud.api.url(this.endpointName, 'dataset_id', this.cloudDatasetID);
            
            apiResponse = request.send(apiURL);
            
            % Special case: The delete endpoint can return a 504 timeout on
            % a successful deletion, so we treat it as a success. 204 is also success.
            if (apiResponse.StatusCode == 204 || apiResponse.StatusCode == 504)
                b = true;
                answer = 'Dataset deleted successfully.';
            else
                b = false;
                answer = [];
            end
        end
    end
end

