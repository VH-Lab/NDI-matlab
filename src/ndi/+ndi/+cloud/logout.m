function logout()
% LOGOUT - Log out from NDI Cloud by clearing the authentication token and organization list.
%
%   ndi.cloud.logout()
%
%   This function performs the following actions:
%   1. Calls the NDI Cloud API to invalidate the current session token on the server.
%   2. Clears the locally stored NDI Cloud authentication token (the
%      'NDI_CLOUD_TOKEN' environment variable) and the cached list of the
%      user's organizations (see ndi.cloud.internal.setOrganizations).
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
    ndi.cloud.internal.setOrganizations([]);
end
