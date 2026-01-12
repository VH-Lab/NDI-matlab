function [token, organization_id] = uilogin(force_relogin, options)
    % uilogin - Retrieves the token from a ui dialog
    %
    %   [TOKEN, ORGANIZATION_ID] = UILOGIN([FORCE_RELOGIN])
    %
    %   Note: When the token is retrieved for the first time, it is stored in
    %   an environment variable. This function will try to first retrieve the
    %   token from the environment variable, and if the variable does not
    %   exist, the ui dialog is opened for user to enter username and password.
    %
    %   Also, if the token exists, but has expired, the dialog will open for
    %   user to re-enter username and password.
    %
    %   If FORCE_RELOGIN is 1 or true, then the user is prompted to log in
    %   again.
    %
    
    arguments
        force_relogin (1,1) logical = false
        options.UserName (1,1) string = missing
    end

    [token, organization_id] = ndi.cloud.internal.getActiveToken();
    
    if ~isempty(token) && ~ismissing(options.UserName)
        decodedToken = ndi.cloud.internal.decodeJwt(token);
        force_relogin = ~strcmp(decodedToken.email, options.UserName);
    end

    if isempty(token) || isempty(organization_id) || force_relogin==true
        hApp = ndi.cloud.ui.dialog.LoginDialog(options.UserName);
        hApp.waitfor()
        token = getenv('NDI_CLOUD_TOKEN');
        organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');
    end

    if nargout == 1
        clear organization_id
    end
end
