function response = logout()
    % LOGOUT - logs a user out and invalidates their token
    %
    % RESPONSE = ndi.cloud.api.auth.LOGOUT()
    %
    % Inputs:
    %
    % Outputs:
    %   RESPONSE - the response summary
    %

    auth_token = ndi.cloud.authenticate();

    method = matlab.net.http.RequestMethod.POST;

    json = '';
    body = matlab.net.http.MessageBody(json);

    h1 = matlab.net.http.HeaderField('accept','application/json');
    h2 = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [h1 h2];

    req = matlab.net.http.RequestMessage(method, headers, body);
    
    originalWarnState = warning('off', 'MATLAB:http:BodyExpectedFor');
    warningResetObj = onCleanup(@() warning(originalWarnState));

    url = ndi.cloud.api.url('logout');

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end

    if ~nargout
        clear response
    end
end
