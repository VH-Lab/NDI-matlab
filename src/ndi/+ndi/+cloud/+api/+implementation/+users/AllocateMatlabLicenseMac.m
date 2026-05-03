classdef AllocateMatlabLicenseMac < ndi.cloud.api.call
%ALLOCATEMATLABLICENSEMAC Implementation class for allocating an AWS ENI
%(and its MAC address) for a dedicated MATLAB BYOL license.
%
%   Calls POST /users/me/matlab-license. Idempotent: 200 if a dedicated
%   registration already exists, 201 if a new ENI was allocated.
%
%   Returns a MatlabLicenseStatus document with eniId, macAddress, and
%   subnetId populated. The user then registers that MAC with MathWorks
%   and uploads the resulting lic file via SetMatlabLicense.

    methods
        function this = AllocateMatlabLicenseMac()
            this.endpointName = 'allocate_matlab_license_mac';
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);

            method = matlab.net.http.RequestMethod.POST;

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField authorizationField];

            % POST has no body for this endpoint; sending an empty body
            % is conventional and avoids server-side content-length quirks.
            body = matlab.net.http.MessageBody('');

            request = matlab.net.http.RequestMessage(method, headers, body);

            apiResponse = send(request, apiURL);

            if apiResponse.StatusCode == 200 || apiResponse.StatusCode == 201
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
