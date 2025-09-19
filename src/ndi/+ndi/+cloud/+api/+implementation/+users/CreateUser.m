classdef CreateUser < ndi.cloud.api.call
%CREATEUSER Implementation class for creating a new user.

    properties
        email
        userName
        password
    end

    methods
        function this = CreateUser(args)
            %CREATEUSER Creates a new CreateUser API call object.
            %
            %   Inputs:
            %       'email'    - The email address for the new user.
            %       'name'     - The name for the new user.
            %       'password' - The password for the new user.
            %
            arguments
                args.email (1,1) string
                args.name (1,1) string
                args.password (1,1) string
            end
            
            this.email = args.email;
            this.userName = args.name;
            this.password = args.password;
            this.endpointName = 'create_user';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to create a new user.
            
            % Initialize outputs
            b = false;
            answer = [];

            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('email', this.email, 'name', this.userName, 'password', this.password);

            method = matlab.net.http.RequestMethod.POST;
            body = matlab.net.http.MessageBody(json);

            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
            headers = [acceptField contentTypeField];

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

