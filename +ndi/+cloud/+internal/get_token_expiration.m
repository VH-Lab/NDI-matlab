function expiration_time = get_token_expiration(token)
    % Return token expiration time in local time zone
    decoded_token = ndi.cloud.internal.decode_jwt(token);
    expiration_time = datetime(decoded_token.exp, ...
        'ConvertFrom', 'posixtime', 'TimeZone', 'local');
end
