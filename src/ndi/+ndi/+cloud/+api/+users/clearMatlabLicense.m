function [b, answer, apiResponse, apiURL] = clearMatlabLicense(options)
%CLEARMATLABLICENSE Remove a MATLAB BYOL license registration.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.clearMatlabLicense()
%   [...] = ndi.cloud.api.users.clearMatlabLicense('release', "R2024b")
%
%   Calls DELETE /users/me/matlab-license. Without options, fully clears
%   the user's registration (releasing the AWS ENI for dedicated mode).
%   With 'release' set, only that release entry is removed from a
%   dedicated registration; the MAC and remaining releases stay intact.
%
%   Server returns 204 on full clear or empty registration, 200 with
%   the remaining MatlabLicenseStatus when only one release was removed.
%
%   Outputs:
%       b            - True on HTTP 200/204, false otherwise.
%       answer       - Remaining MatlabLicenseStatus struct (200) or an
%                      empty struct (204).
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.users.getMatlabLicense,
%             ndi.cloud.api.users.setMatlabLicense,
%             ndi.cloud.api.users.allocateMatlabLicenseMac,
%             ndi.cloud.api.implementation.users.ClearMatlabLicense

    arguments
        options.release (1,1) string = ""
    end

    api_call = ndi.cloud.api.implementation.users.ClearMatlabLicense(...
        'release', options.release);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
