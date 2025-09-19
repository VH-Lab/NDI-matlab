classdef GetFileDetails < ndi.cloud.api.call
%GETFILEDETAILS Implementation class for retrieving file details.

    properties
        cloudFileUID
    end

    methods
        function this = GetFileDetails(args)
            %GETFILEDETAILS Creates a new GetFileDetails API call object.
            arguments
                args.cloudDatasetID (1,1) string
                args.cloudFileUID (1,1) string
            end
            this.cloudDatasetID = args.cloudDatasetID;
            this.cloudFileUID = args.cloudFileUID;
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call.
            
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
                answer = apiResponse.Body.Data;
                
                % --- NEW VALIDATION STEP ---
                % A successful call must return a downloadUrl. If it doesn't,
                % it's a functional failure from the client's perspective.
                if isfield(answer, 'downloadUrl') && ~isempty(answer.downloadUrl)
                    b = true; % This is a true success.
                else
                    b = false; % Mark as failure.
                    
                    % Create a descriptive error message for the test logs.
                    error_message = 'API call succeeded (200 OK) but the response was missing the ''downloadUrl'' field.';
                    pretty_response = jsonencode(answer, "PrettyPrint", true);
                    answer = struct('error', error_message, 'details', pretty_response);
                end
            else
                answer = apiResponse.Body.Data;
            end
        end
    end
end

