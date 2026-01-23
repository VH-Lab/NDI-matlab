function logout()
% LOGOUT - Log out from NDI Cloud by clearing the authentication token and organization ID.
%
%   ndi.cloud.logout()
%
%   This function performs the following actions:
%   1. Calls the NDI Cloud API to invalidate the current session token on the server.
%   2. Clears the environment variables 'NDI_CLOUD_TOKEN' and
%      'NDI_CLOUD_ORGANIZATION_ID', which are used to store the NDI Cloud
%      authentication token and organization ID locally.
%
%   After calling this function, any subsequent calls to NDI Cloud functions
%   that require authentication will prompt for a login or fail until authentication
%   is performed again.
%
%   Example:
%       ndi.cloud.logout();
%
%   See also: ndi.cloud.uilogin, ndi.cloud.internal.getActiveToken, ndi.cloud.authenticate

    try
        ndi.cloud.api.auth.logout();
    catch ME
        warning('NDI:Cloud:LogoutAPIError', 'Failed to call logout API: %s', ME.message);
    end

    setenv('NDI_CLOUD_TOKEN', '');
    setenv('NDI_CLOUD_ORGANIZATION_ID', '');
end
