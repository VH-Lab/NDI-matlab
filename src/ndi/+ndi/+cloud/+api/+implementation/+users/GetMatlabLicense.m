classdef GetMatlabLicense < ndi.cloud.api.call
%GETMATLABLICENSE Implementation class for retrieving the current user's
%MATLAB BYOL registration status.
%
%   Calls GET /users/me/matlab-license. Returns the MatlabLicenseStatus
%   document: mode (dedicated|network|null), eniId, macAddress, subnetId,
%   registeredAt, files (per-release entries), and an instructions hint.

    methods
        function this = GetMatlabLicense()
            this.endpointName = 'get_matlab_license';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);

            method = matlab.net.http.RequestMethod.GET;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200
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
