function [status, response] = logout()
    % LOGOUT - logs a user out and invalidates their token
    %
    % [STATUS,RESPONSE] = ndi.cloud.api.auth.LOGOUT()
    %
    % Inputs:
    %
    % Outputs:
    %   STATUS - did user log out? 1 for no, 0 for yes
    %   RESPONSE - the response summary
    %

    [auth_token, ~] = ndi.cloud.uilogin();

    method = matlab.net.http.RequestMethod.POST;

    json = '';
    body = matlab.net.http.MessageBody(json);

    h1 = matlab.net.http.HeaderField('accept','application/json');
    h2 = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [h1 h2];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = matlab.net.URI(ndi.cloud.api.url('logout'));

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
