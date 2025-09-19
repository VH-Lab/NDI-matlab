classdef GetDataset < ndi.cloud.api.call
%GETDATASET Implementation class for getting a dataset from NDI Cloud.

    methods
        function this = GetDataset(args)
            %GETDATASET Creates a new GetDataset API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.GetDataset('cloudDatasetID', ID)
            %
            %   Inputs:
            %       'cloudDatasetID' - The string ID of the dataset.
            %
            arguments
                args.cloudDatasetID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get the dataset.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The dataset struct on success, or error message on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %
            
            % Initialize outputs
            b = false;
            answer = [];
            
            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('get_dataset', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
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

