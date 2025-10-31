function expiration_time = getTokenExpiration(token)
    % GETTOKENEXPIRATION - Return token expiration time in local time zone

    decoded_token = ndi.cloud.internal.decodeJwt(token);
    expiration_time = datetime(decoded_token.exp, ...
        'ConvertFrom', 'posixtime', 'TimeZone', 'local');
end
