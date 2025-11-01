function expiration_time = getTokenExpiration(token)
% GETTOKENEXPIRATION - Return the expiration time of a JWT.
%
% EXPIRATION_TIME = GETTOKENEXPIRATION(TOKEN)
%
% This function decodes a JSON Web Token (JWT) to extract its expiration
% time. The expiration time, which is typically provided in POSIX/Unix time
% (seconds since 1970-01-01 UTC), is converted to a MATLAB datetime object
% in the local time zone.
%
% Inputs:
%   token (string) - The JSON Web Token from which to extract the
%     expiration time.
%
% Outputs:
%   expiration_time (datetime) - A datetime object representing the token's
%     expiration time, adjusted to the local time zone.
%
% Example:
%   % Assume jwt is a valid JWT string
%   exp_time = ndi.cloud.internal.getTokenExpiration(jwt);
%   if datetime('now', 'TimeZone', 'local') > exp_time
%     disp('Token has expired.');
%   end
%
% See also: ndi.cloud.internal.decodeJwt, datetime

    arguments
        token (1,:) char
    end

    decoded_token = ndi.cloud.internal.decodeJwt(token);
    expiration_time = datetime(decoded_token.exp, ...
        'ConvertFrom', 'posixtime', 'TimeZone', 'local');
end
