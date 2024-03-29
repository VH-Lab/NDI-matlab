function decodedPayload = decode_jwt(jwtToken)
    
    % Split the JWT token into its components
    tokenParts = strsplit(jwtToken, '.');

    % Extract and decode the payload
    payloadBase64 = tokenParts{2};
    payloadBase64 = strrep(payloadBase64, '-', '+');
    payloadBase64 = strrep(payloadBase64, '_', '/');
    padding = mod(length(payloadBase64), 4);
    if padding > 0
        payloadBase64 = [payloadBase64, repmat('=', 1, 4 - padding)];
    end
    payloadBytes = javax.xml.bind.DatatypeConverter.parseBase64Binary(payloadBase64);
    payloadJSON = native2unicode(payloadBytes, 'UTF-8');
    
    % Ensure json payload is a row vector
    payloadJSON = reshape(payloadJSON, 1, []);

    % Parse the JSON payload
    decodedPayload = jsondecode(payloadJSON);
end
