function [b, answer, apiResponse, apiURL] = setMatlabLicense(licenseFile, options)
%SETMATLABLICENSE Upload a MATLAB BYOL license file for the current user.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.setMatlabLicense(LICENSEFILE)
%   [...] = ndi.cloud.api.users.setMatlabLicense(LICENSEFILE, 'mode', "network")
%   [...] = ndi.cloud.api.users.setMatlabLicense(LICENSEFILE, 'mode', "dedicated", 'release', "R2024b")
%
%   Calls PUT /users/me/matlab-license. LICENSEFILE may be either the
%   contents of the .lic file as a string, OR a path to a .lic file on
%   disk (auto-detected: a single line that exists as a file is read in).
%
%   Modes:
%       "dedicated" (default) - per-MAC license. Requires a 'release' tag
%                               (e.g. "R2024b") and a prior call to
%                               ndi.cloud.api.users.allocateMatlabLicenseMac
%                               whose MAC the lic file's HOSTID matches.
%       "network"             - license-server file containing a SERVER
%                               line. Must NOT supply 'release'.
%
%   Outputs:
%       b            - True on HTTP 200, false otherwise.
%       answer       - Updated MatlabLicenseStatus on success, or error
%                      payload on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   See also: ndi.cloud.api.users.getMatlabLicense,
%             ndi.cloud.api.users.allocateMatlabLicenseMac,
%             ndi.cloud.api.users.clearMatlabLicense,
%             ndi.cloud.api.implementation.users.SetMatlabLicense

    arguments
        licenseFile (1,1) string
        options.mode (1,1) string {mustBeMember(options.mode, ["dedicated","network"])} = "dedicated"
        options.release (1,1) string = ""
    end

    % If licenseFile looks like a path that exists on disk, read it in.
    licenseText = licenseFile;
    if ~contains(licenseFile, newline) && exist(licenseFile, 'file') == 2
        licenseText = string(fileread(char(licenseFile)));
    end

    api_call = ndi.cloud.api.implementation.users.SetMatlabLicense(...
        'licenseFile', licenseText, 'mode', options.mode, 'release', options.release);

    [b, answer, apiResponse, apiURL] = api_call.execute();
end
