classdef GetUser < ndi.cloud.api.call
%GETUSER Implementation class for retrieving user information.

    methods
        function this = GetUser(args)
            %GETUSER Creates a new GetUser API call object.
            %
            %   Inputs:
            %       'cloudUserID' - The ID of the user to retrieve.
            %
            arguments
                args.cloudUserID (1,1) string
            end
            
            this.cloudUserID = args.cloudUserID;
            this.endpointName = 'get_user';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to retrieve user information.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url(this.endpointName, 'user_id', this.cloudUserID);

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

