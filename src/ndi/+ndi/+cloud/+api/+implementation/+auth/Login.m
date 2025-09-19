classdef Login < ndi.cloud.api.call
%LOGIN Implementation class for user authentication.

    properties
        email
        password
    end

    methods
        function this = Login(args)
            %LOGIN Creates a new Login API call object.
            %
            %   Inputs:
            %       'email'    - The user's email address.
            %       'password' - The user's password.
            %
            arguments
                args.email (1,1) string
                args.password (1,1) string
            end
            
            this.email = args.email;
            this.password = args.password;
            this.endpointName = 'login';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to log in the user.
            
            % Initialize outputs
            b = false;
            answer = [];

            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('email', this.email, 'password', this.password);

            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(json);

            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
            headers = [acceptField contentTypeField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
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

