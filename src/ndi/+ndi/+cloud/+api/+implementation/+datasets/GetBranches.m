classdef GetBranches < ndi.cloud.api.call
%GETBRANCHES Implementation class for getting dataset branches from NDI Cloud.

    methods
        function this = GetBranches(args)
            %GETBRANCHES Creates a new GetBranches API call object.
            %
            %   THIS = ndi.cloud.api.implementation.datasets.GetBranches('cloudDatasetID', ID)
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
            %EXECUTE Performs the API call to get the dataset branches.
            %
            %   [B, ANSWER, APIRESPONSE, APIURL] = EXECUTE(THIS)
            %
            %   Outputs:
            %       b            - True if the call succeeded, false otherwise.
            %       answer       - The branches data on success, or error message on failure.
            %       apiResponse  - The full matlab.net.http.ResponseMessage object.
            %       apiURL       - The URL that was called.
            %
            
            % Initialize outputs
            b = false;
            answer = [];
            
            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('get_branches', 'dataset_id', this.cloudDatasetID);

            method = matlab.net.http.RequestMethod.GET;
            
            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200)
                b = true;
                answer = apiResponse.Body.Data.branches;
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

