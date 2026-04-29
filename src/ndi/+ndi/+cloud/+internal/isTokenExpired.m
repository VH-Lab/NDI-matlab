function expired = isTokenExpired(token, options)
% ISTOKENEXPIRED - Return true if a JWT is expired or close to expiring.
%
% EXPIRED = ISTOKENEXPIRED(TOKEN)
% EXPIRED = ISTOKENEXPIRED(TOKEN, 'SkewSeconds', SKEW)
%
% Decodes the JWT's `exp` claim and compares it to the current local
% time. Tokens within SkewSeconds of expiry (default 60) are reported as
% expired so callers can refresh before the server sees a stale token
% mid-request.
%
% Returns FALSE when the token cannot be decoded (e.g. it is opaque or
% malformed) or has no `exp` claim, so the server remains the source of
% truth in those cases.
%
% Inputs:
%   token (char) - The JSON Web Token to inspect.
%   options.SkewSeconds (double) - Seconds of slack before the actual
%       expiry at which to start reporting the token as expired.
%
% Outputs:
%   expired (logical) - True if the token is expired or expiring within
%       SkewSeconds of now.
%
% See also: ndi.cloud.internal.decodeJwt, ndi.cloud.internal.getTokenExpiration

    arguments
        token (1,:) char
        options.SkewSeconds (1,1) double = 60
    end

    expired = false;
    try
        expirationTime = ndi.cloud.internal.getTokenExpiration(token);
    catch
        return;
    end
    if isempty(expirationTime) || ~isa(expirationTime, 'datetime')
        return;
    end
    nowLocal = datetime('now', 'TimeZone', 'local');
    expired = nowLocal >= (expirationTime - seconds(options.SkewSeconds));
end
