function [b, answer, apiResponse, apiURL] = getMatlabLicense()
%GETMATLABLICENSE Retrieve the current user's MATLAB BYOL registration.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.getMatlabLicense()
%
%   Calls GET /users/me/matlab-license and returns the MatlabLicenseStatus
%   document (mode, eniId, macAddress, subnetId, registeredAt, files,
%   instructions). When no license is registered the server still returns
%   200 with mode == "" / null and an empty files array.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - The MatlabLicenseStatus struct on success.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.users.setMatlabLicense,
%             ndi.cloud.api.users.allocateMatlabLicenseMac,
%             ndi.cloud.api.users.clearMatlabLicense,
%             ndi.cloud.api.implementation.users.GetMatlabLicense

    api_call = ndi.cloud.api.implementation.users.GetMatlabLicense();
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
