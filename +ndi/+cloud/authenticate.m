function [token, organizationID] = authenticate(options)
% authenticate - Authenticate using secret, environment variables or GUI Form
% 
% Syntax:
%   ndi.cloud.authenticate() will attempt authentication in the following
%       order:
%       1) If MATLAB Vault for storing secrets is available, will check if
%          credentials already exist. If credentials exist, they will be used for
%          logging in to NDI cloud. If they don't exist, used will be prompted
%          to add their credentials to the vault.
%       2) If the following variables are present in the environment
%          variables, they will be used for logging in:
%           - NDI_CLOUD_USERNAME
%           - NDI_CLOUD_PASSWORD
%       3) If none of the above results in successful authentication, user
%          will be prompted for username (email) and password in a login
%          dialog.
%
% Input Arguments:
%   options (optional name, value pairs)
%       - UserName (string) : Username to use for login. If a token already
%       exists and the provided username is different than the username the
%       token was issued for, this function will force a re-login.
%
% Output Arguments: (optional)
%   token - The authentication token retrieved after successful authentication.
%   organizationID - The organization ID fetched from the environment variable.

    arguments
        options.UserName (1,1) string = missing
    end

    if isAuthenticated(options.UserName)
        % pass
    elseif authenticatedWithSecret(options.UserName)
        % pass
    elseif authenticatedWithEnvironmentVariable(options.UserName)
        % pass
    else
        % Todo: need to relogin?
        ndi.cloud.uilogin('UserName', options.UserName);
    end

    if nargout >= 1
        token = ndi.cloud.internal.get_active_token();
    end
    if nargout >= 2
        organizationID = getenv("NDI_CLOUD_ORGANIZATION_ID");
    end
end


function result = isAuthenticated(username)
    token = ndi.cloud.internal.get_active_token();
    result = ~isempty(token);

    if ~ismissing(username)
        decodedToken = ndi.cloud.internal.decode_jwt(token);
        if ~strcmp(decodedToken.email, username)
            result = false;
        end
    end
end

function isSuccess = authenticatedWithSecret(userName)
    isSuccess = false;
    if exist("isSecret", "file") % Introduced in R2024a
        if isSecret("NDICloud:Email")
            secretUserName = getSecret("NDICloud:Email");
            secretPassword = getSecret("NDICloud:Password");
            if strcmp(secretUserName, userName)
                isSuccess = login(secretUserName, secretPassword);
            else
                isSuccess = false;
            end
        else
            if getpref('NDICloud', 'UseSecretVaultForCredentials', true)
                isSuccess = promptAddCredentialsToVault();
            end
        end
    end
end

function isSuccess = authenticatedWithEnvironmentVariable(requestedUsername)
    isSuccess = false;
    [userName, password] = deal('');

    if exist("isenv", "file") % Introduced in R2022b
        if isenv("NDI_CLOUD_USERNAME") && isenv("NDI_CLOUD_PASSWORD")
            userName = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
        end
    else
        userName = getenv("NDI_CLOUD_USERNAME");
        password = getenv("NDI_CLOUD_PASSWORD");
    end

    if ~isempty(userName) && ~isempty(password)
        if ismissing(requestedUsername) || strcmp(userName, requestedUsername)
            isSuccess = login(userName, password);
        end
    end
end

function isSuccess = promptAddCredentialsToVault()
    isSuccess = false;
    if exist("isSecret", "file") % Introduced in R2024a
        answer = questdlg( ...
            "Would you like to securely store your NDI Cloud username " + ...
            "(email) and password as secrets in the MATLAB vault for " + ...
            "future use?", "Store NDI Cloud Credentials?");
        if strcmp(answer, "Yes")
            setSecret("NDICloud:Email");
            setSecret("NDICloud:Password");
            isSuccess = authenticatedWithSecret();
        else
            answer = questdlg( ...
                "Do you want MATLAB to remember this choice for future sessions?", ...
                "Remember Choice", ...
                "Yes", "No", "No");
            if answer == "Yes"
                setpref('NDICloud', 'UseSecretVaultForCredentials', false)
            end
        end
    end
end

function isSuccess = login(userName, password)
    isSuccess = false;

    [token, organization_id] = ndi.cloud.api.auth.login(userName, password);
    if ~strcmp(token, 'Unable to Login')
        setenv('NDI_CLOUD_TOKEN', token)
        setenv('NDI_CLOUD_ORGANIZATION_ID', organization_id)
        isSuccess = true;
    end
end
