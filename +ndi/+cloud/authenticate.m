function [token, organizationID] = authenticate()
% authenticate - Authenticate using secret, environment or GUI Form
    
    if isAuthenticated()
        % pass
    elseif authenticatedWithSecret()
        % pass
    elseif authenticatedWithEnvironmentVariable()
        % pass
    else
        ndi.cloud.uilogin();
    end

    if nargout >= 1
        token = ndi.cloud.internal.get_active_token();
    end
    if nargout >= 2
        organizationID = getenv("NDI_CLOUD_ORGANIZATION_ID");
    end
end

function result = isAuthenticated()
    token = ndi.cloud.internal.get_active_token();
    result = ~isempty(token);
end

function isSuccess = authenticatedWithSecret()
    isSuccess = false;
    if exist("isSecret", "file") % Introduced in R2024a
        try
            if isSecret("NDI_CLOUD_USERNAME")
                userName = getSecret("NDI_CLOUD_USERNAME");
                password = getSecret("NDI_CLOUD_PASSWORD");
                isSuccess = login(userName, password);
            end
        catch
            % Abort. The MATLAB Vault might be unavailable.
        end
    end
end

function isSuccess = authenticatedWithEnvironmentVariable()
    isSuccess = false;
    if exist("isenv", "file") % Introduced in R2022b
        if isenv("NDI_CLOUD_USERNAME") && isenv("NDI_CLOUD_PASSWORD")
            userName = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            isSuccess = login(userName, password);
        end
    else
        userName = getenv("NDI_CLOUD_USERNAME");
        password = getenv("NDI_CLOUD_PASSWORD");
        if ~isempty(userName) && ~isempty(password)
            isSuccess = login(userName, password);
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
