classdef ChangePassword < ndi.cloud.api.call
%CHANGEPASSWORD Implementation class for changing a user's password.

    properties
        oldPassword
        newPassword
    end

    methods
        function this = ChangePassword(args)
            %CHANGEPASSWORD Creates a new ChangePassword API call object.
            %
            %   Inputs:
            %       'oldPassword' - The user's current password.
            %       'newPassword' - The user's desired new password.
            %
            arguments
                args.oldPassword (1,1) string
                args.newPassword (1,1) string
            end
            
            this.oldPassword = args.oldPassword;
            this.newPassword = args.newPassword;
            this.endpointName = 'change_password';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to change the password.
            
            % Initialize outputs
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();
            
            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('oldPassword', this.oldPassword, 'newPassword', this.newPassword);

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

