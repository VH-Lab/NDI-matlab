function [token, organization_id] = getActiveToken()
% GETACTIVETOKEN - Retrieves the active NDI cloud token and organization ID.
%
% [TOKEN, ORGANIZATION_ID] = GETACTIVETOKEN()
%
% This function retrieves the NDI cloud authentication token and the
% organization ID from the environment variables 'NDI_CLOUD_TOKEN' and
% 'NDI_CLOUD_ORGANIZATION_ID', respectively.
%
% After retrieving the token, it checks if the token has expired using the
% ndi.cloud.internal.getTokenExpiration function. If the token is expired, an
% empty string is returned for the token.
%
% If the function is called with only one output argument, it will only return
% the token.
%
% Outputs:
%   token (string) - The active NDI cloud authentication token. Returns an
%     empty string if the token is not found or has expired.
%   organization_id (string) - The NDI cloud organization ID.
%
% Example:
%   [myToken, myOrg] = ndi.cloud.internal.getActiveToken();
%   if isempty(myToken)
%     error('No active token found.');
%   end
%
% See also: ndi.cloud.internal.getTokenExpiration, getenv

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
