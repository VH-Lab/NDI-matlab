classdef Logout < ndi.cloud.api.call
%LOGOUT Implementation class for user logout.

    methods
        function this = Logout()
            %LOGOUT Creates a new Logout API call object.
            %
            % This call takes no inputs.
            %
            this.endpointName = 'logout';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to log out the user.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url(this.endpointName);
            
            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(''); % Empty body for logout

            h1 = matlab.net.http.HeaderField('accept','application/json');
            h2 = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [h1 h2];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            % Suppress MATLAB warning for POST with empty body
            originalWarnState = warning('off', 'MATLAB:http:BodyExpectedFor');
            warningResetObj = onCleanup(@() warning(originalWarnState));

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

