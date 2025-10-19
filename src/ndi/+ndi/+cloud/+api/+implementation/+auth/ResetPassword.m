classdef ResetPassword < ndi.cloud.api.call
%RESETPASSWORD Implementation class for requesting a password reset email.

    properties
        email
    end

    methods
        function this = ResetPassword(args)
            %RESETPASSWORD Creates a new ResetPassword API call object.
            %
            %   Inputs:
            %       'email' - The email address for the password reset request.
            %
            arguments
                args.email (1,1) string
            end
            
            this.email = args.email;
            this.endpointName = 'reset_password';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to request a password reset email.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('email', this.email);

            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(json);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);
            
            apiResponse = send(request, apiURL);
            
            if (apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201)
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

