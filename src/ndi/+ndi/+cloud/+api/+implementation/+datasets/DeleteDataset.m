classdef DeleteDataset < ndi.cloud.api.call
    %DELETEDATASET Implements the API call to delete a dataset.

    properties (Access = protected)
        when
    end

    methods
        function this = DeleteDataset(args)
            % The arguments block for name-value pair validation
            arguments
                args.cloudDatasetID (1,1) string
                args.when (1,1) string = "7d"
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.when = args.when;
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

            % Add query parameter 'when'
            q = matlab.net.QueryParameter('when', this.when);
            if isempty(apiURL.Query)
                apiURL.Query = q;
            else
                apiURL.Query = [apiURL.Query q];
            end
            
            apiResponse = request.send(apiURL);
            
            % Special case: The delete endpoint can return a 504 timeout on
            % a successful deletion, so we treat it as a success. 204 is also success.
            % New behavior: 200 OK with JSON body.
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 204 || apiResponse.StatusCode == 504)
                b = true;
                if apiResponse.StatusCode == 200 && ~isempty(apiResponse.Body.Data)
                     answer = apiResponse.Body.Data;
                else
                     answer = 'Dataset deleted successfully.';
                end
            else
                b = false;
                answer = [];
            end
        end
    end
end
