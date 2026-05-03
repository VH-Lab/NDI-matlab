classdef SetMatlabLicense < ndi.cloud.api.call
%SETMATLABLICENSE Implementation class for uploading a MATLAB BYOL license
%file (network or dedicated) for the current user.
%
%   Calls PUT /users/me/matlab-license with a JSON body containing exactly
%   one of:
%       networkLicenseFile  - full text of a network/server lic file
%       dedicatedLicenseFile + release - full text of a dedicated lic file
%                             plus the MATLAB release tag (e.g. "R2024b")
%
%   Dedicated uploads require a prior allocation call to obtain the MAC
%   address that the lic file's HOSTID must match.

    properties
        licenseFile     (1,1) string = ""
        mode            (1,1) string = "dedicated"   % "dedicated" | "network"
        release         (1,1) string = ""
    end

    methods
        function this = SetMatlabLicense(args)
            arguments
                args.licenseFile (1,1) string
                args.mode (1,1) string {mustBeMember(args.mode, ["dedicated","network"])} = "dedicated"
                args.release (1,1) string = ""
            end
            this.licenseFile = args.licenseFile;
            this.mode = args.mode;
            this.release = args.release;
            this.endpointName = 'set_matlab_license';

            if strcmp(this.mode, "dedicated") && strlength(this.release) == 0
                error('NDICloud:SetMatlabLicense:MissingRelease', ...
                    'A "release" tag (e.g. "R2024b") is required for dedicated licenses.');
            end
            if strcmp(this.mode, "network") && strlength(this.release) > 0
                error('NDICloud:SetMatlabLicense:UnexpectedRelease', ...
                    '"release" must not be supplied for network licenses.');
            end
        end

        function [b, answer, apiResponse, apiURL] = execute(this)
            b = false;
            answer = [];

            token = ndi.cloud.authenticate();

            apiURL = ndi.cloud.api.url(this.endpointName);

            method = matlab.net.http.RequestMethod.PUT;

            requestBodyStruct = struct();
            switch this.mode
                case "network"
                    requestBodyStruct.networkLicenseFile = char(this.licenseFile);
                case "dedicated"
                    requestBodyStruct.dedicatedLicenseFile = char(this.licenseFile);
                    requestBodyStruct.release = char(this.release);
            end

            body = matlab.net.http.MessageBody(requestBodyStruct);

            acceptField = matlab.net.http.HeaderField('accept','application/json');
            contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
            authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' token]);
            headers = [acceptField contentTypeField authorizationField];

            request = matlab.net.http.RequestMessage(method, headers, body);

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
