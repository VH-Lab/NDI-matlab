classdef ClearMatlabLicense < ndi.cloud.api.call
%CLEARMATLABLICENSE Implementation class for removing a MATLAB BYOL
%license registration for the current user.
%
%   Calls DELETE /users/me/matlab-license[?release=Rxxxx]. Without
%   release, clears the entire registration (releasing the AWS ENI for
%   dedicated mode). With release, removes only that release entry from
%   a dedicated registration while keeping the MAC.
%
%   Server returns 204 on full clear, 200 with the remaining status when
%   a single release was removed.

    properties
        release (1,1) string = ""
    end

    methods
        function this = ClearMatlabLicense(args)
            arguments
                args.release (1,1) string = ""
            end
            this.release = args.release;
            this.endpointName = 'clear_matlab_license';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);
            if strlength(this.release) > 0
                apiURL.Query = matlab.net.QueryParameter('release', char(this.release));
            end

            method = matlab.net.http.RequestMethod.DELETE;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200 || apiResponse.StatusCode == 204
                b = true;
                if apiResponse.StatusCode == 200 && isprop(apiResponse.Body, 'Data')
                    answer = apiResponse.Body.Data;
                else
                    answer = struct();
                end
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
