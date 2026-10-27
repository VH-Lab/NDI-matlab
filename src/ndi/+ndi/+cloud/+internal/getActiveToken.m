function token = getActiveToken()
% GETACTIVETOKEN - Retrieves the active NDI cloud token.
%
% TOKEN = GETACTIVETOKEN()
%
% This function retrieves the NDI cloud authentication token from the
% environment variable 'NDI_CLOUD_TOKEN'.
%
% After retrieving the token, it checks if the token has expired using the
% ndi.cloud.internal.getTokenExpiration function. If the token is expired, an
% empty string is returned for the token.
%
% The organizations the user belongs to are not part of the token; see
% ndi.cloud.internal.getOrganizations.
%
% Outputs:
%   token (string) - The active NDI cloud authentication token. Returns an
%     empty string if the token is not found or has expired.
%
% Example:
%   myToken = ndi.cloud.internal.getActiveToken();
%   if isempty(myToken)
%     error('No active token found.');
%   end
%
% See also: ndi.cloud.internal.getTokenExpiration,
%           ndi.cloud.internal.getOrganizations, getenv

    token = getenv('NDI_CLOUD_TOKEN');

    if ~isempty(token)
        expiration_time = ndi.cloud.internal.getTokenExpiration(token);
        if datetime("now", "TimeZone", "local") > expiration_time
            token = '';
        end
    end
end
