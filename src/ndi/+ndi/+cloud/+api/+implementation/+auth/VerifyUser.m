classdef VerifyUser < ndi.cloud.api.call
%VERIFYUSER Implementation class for verifying a new user account.

    properties
        email
        confirmationCode
    end

    methods
        function this = VerifyUser(args)
            %VERIFYUSER Creates a new VerifyUser API call object.
            %
            %   Inputs:
            %       'email' - The user's email address.
            %       'confirmationCode' - The code sent to the user's email.
            %
            arguments
                args.email (1,1) string
                args.confirmationCode (1,1) string
            end
            
            this.email = args.email;
            this.confirmationCode = args.confirmationCode;
            this.endpointName = 'verify_user';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to verify the user.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('email', this.email, 'confirmationCode', this.confirmationCode);

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

