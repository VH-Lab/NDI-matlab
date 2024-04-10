function [token, organization_id] = uilogin()
% uilogin - Retrieves the token from a ui dialog
%
%   Note: When the token is retrieved for the first time, it is stored in
%   an environment variable. This function will try to first retrieve the
%   token from the environment variable, and if the variable does not
%   exist, the ui dialog is opened for user to enter username and password.
%
%   Also, if the token exists, but has expired, the dialog will open for
%   user to re-enter username and password.

    token = getenv('NDI_CLOUD_TOKEN');
    organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    
    if ~isempty(token),
        expiration_time = ndi.cloud.internal.get_token_expiration(token);
        if datetime("now") > expiration_time
            token = '';
        end
    end
    
    if isempty(token) || isempty(organization_id)
        hApp = ndi.cloud.ui.dialog.LoginDialog();
        hApp.waitfor()
        token = getenv('NDI_CLOUD_TOKEN');
        organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    end

    if nargout == 1
        clear organization_id
    end
end
