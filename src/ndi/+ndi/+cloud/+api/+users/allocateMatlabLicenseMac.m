function [b, answer, apiResponse, apiURL] = allocateMatlabLicenseMac()
%ALLOCATEMATLABLICENSEMAC Allocate an AWS ENI/MAC for a dedicated MATLAB
%license registration.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.allocateMatlabLicenseMac()
%
%   Calls POST /users/me/matlab-license. Idempotent: returns the existing
%   MAC if a dedicated registration already exists, otherwise allocates a
%   new ENI in the configured subnet and returns its MAC address.
%
%   The caller registers the returned MAC with MathWorks to obtain a
%   .lic file, then uploads it via ndi.cloud.api.users.setMatlabLicense
%   with the matching 'release' tag.
%
%   Conflicts: the call returns HTTP 409 if a network license is currently
%   registered; clear it first via ndi.cloud.api.users.clearMatlabLicense.
%
%   Outputs:
%       b            - True on HTTP 200/201, false otherwise.
%       answer       - MatlabLicenseStatus struct (eniId, macAddress, ...)
%                      on success, error payload on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.users.getMatlabLicense,
%             ndi.cloud.api.users.setMatlabLicense,
%             ndi.cloud.api.users.clearMatlabLicense,
%             ndi.cloud.api.implementation.users.AllocateMatlabLicenseMac

    api_call = ndi.cloud.api.implementation.users.AllocateMatlabLicenseMac();
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
