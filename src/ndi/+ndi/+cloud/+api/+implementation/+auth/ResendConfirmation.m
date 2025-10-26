classdef ResendConfirmation < ndi.cloud.api.call
%RESENDCONFIRMATION Implementation class for resending a user confirmation email.

    properties
        email
    end

    methods
        function this = ResendConfirmation(args)
            %RESENDCONFIRMATION Creates a new ResendConfirmation API call object.
            %
            %   Inputs:
            %       'email' - The email address to which the confirmation
            %                 should be sent.
            %
            arguments
                args.email (1,1) string
            end
            
            this.email = args.email;
            this.endpointName = 'resend_confirmation';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            %EXECUTE Performs the API call to resend the confirmation email.
            
            % Initialize outputs
            b = false;
            answer = [];

            apiURL = ndi.cloud.api.url(this.endpointName);

            json = struct('email', this.email);

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

