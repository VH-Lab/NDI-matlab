function [auth_token, organization_id] = login(email, password)
    % LOGIN - logs in a user
    %
    % [AUTH_TOKEN,ORGANIZATION_ID] = ndi.cloud.api.auth.LOGIN(EMAIL, PASSWORD)
    %
    % Inputs:
    %   EMAIL - a string representing the user's e-mail
    %   PASSWORD - a string representing the user's password
    %
    % Outputs:
    %   AUTH_TOKEN - bearer token
    %   ORGANIZATION_ID - the organization id that the user belongs to
    %

    json = struct('email', email, 'password', password);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    header = [acceptField contentTypeField];

    req = matlab.net.http.RequestMessage(method, header, body);

    url = ndi.cloud.api.url('login');

    response = req.send(url);
    
    if (response.StatusCode == 200)
        % Request succeeded
        auth_token = response.Body.Data.token;
        organization_id = response.Body.Data.user.organizations.id;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
