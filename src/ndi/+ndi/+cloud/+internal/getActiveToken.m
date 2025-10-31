function [token, organization_id] = getActiveToken()

    token = getenv('NDI_CLOUD_TOKEN');
    organization_id = getenv('NDI_CLOUD_ORGANIZATION_ID');

    if ~isempty(token)
        expiration_time = ndi.cloud.internal.getTokenExpiration(token);
        if datetime("now", "TimeZone", "local") > expiration_time
            token = '';
        end
    end

    if nargout == 1
        clear organization_id
    end
end
