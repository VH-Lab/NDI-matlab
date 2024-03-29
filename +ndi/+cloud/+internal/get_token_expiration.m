function expiration_time = get_token_expiration(token)
    decoded_token = ndi.cloud.internal.decode_jwt(token);
    expiration_time = datetime(decoded_token.exp, 'ConvertFrom', 'posixtime');
end