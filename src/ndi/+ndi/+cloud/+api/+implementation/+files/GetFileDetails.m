classdef GetFileDetails < ndi.cloud.api.call
%GETFILEDETAILS Implementation class for retrieving file details.

    properties
        cloudFileUID
    end

    methods
        function this = GetFileDetails(args)
            %GETFILEDETAILS Creates a new GetFileDetails API call object.
            %
            %   Inputs:
            %       'cloudDatasetID' - The ID of the dataset.
            %       'cloudFileUID'   - The unique identifier (UID) of the file.
            %
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUID (1,1) string
            end
            
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUID = args.cloudFileUID;
            this.endpointName = 'get_file_details';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to get file details.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url('get_file_details', ...
                'dataset_id', this.cloudDatasetID, ...
                'file_uid', this.cloudFileUID);

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
                if isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = apiResponse.Body;
                end
            end
        end
    end
end

