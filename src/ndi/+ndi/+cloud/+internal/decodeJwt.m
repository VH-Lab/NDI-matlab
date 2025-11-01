function decodedPayload = decodeJwt(jwtToken)
% DECODEJWT - Decode a JSON Web Token (JWT) and return its payload.
%
% DECODEDPAYLOAD = DECODEJWT(JWTTOKEN)
%
% This function takes a standard JSON Web Token (JWT) as input and extracts
% the payload section. The payload is Base64Url-decoded and then parsed as a
% JSON string to produce a MATLAB struct.
%
% This function handles the character replacements ('-' to '+', '_' to '/')
% and padding required to convert from Base64Url encoding to standard Base64
% encoding before decoding.
%
% Inputs:
%   jwtToken (string) - The JSON Web Token to be decoded.
%
% Outputs:
%   decodedPayload (struct) - A MATLAB struct representing the JSON payload
%     of the token.
%
% Example:
%   % Assume jwt is a valid JWT string
%   payload = ndi.cloud.internal.decodeJwt(jwt);
%   disp(payload);
%
% See also: ndi.cloud.internal.getTokenExpiration

    arguments
        jwtToken (1,:) char
    end

    % Split the token into its components
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
