function [status, response] = verify_user(email, confirmation_code)
    % VERIFY_USER - verifies a user via the confirmation code sent in e-mail
    % [STATUS, RESPONSE] = ndi.cloud.api.auth.verify_user(EMAIL, CONFIRMATION_CODE)
    %
    % Inputs:
    %   EMAIL - a string representing the email address used to verify
    %   CONFIRMATION_CODE - the code send to the email
    %
    % Outputs:
    %   STATUS - is the confirmation code correct? 1 for no, 0 for yes
    %   RESPONSE - the response summary
    %

    auth_token = ndi.cloud.authenticate();
    json = struct('email', email, 'confirmationCode', confirmation_code);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    acceptField = matlab.net.http.HeaderField('accept','application/json');
    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' auth_token]);
    headers = [acceptField contentTypeField authorizationField];

    req = matlab.net.http.RequestMessage(method, headers, body);

    url = ndi.cloud.api.url('verify_user');

    response = req.send(url);
    status = 1;
    if (response.StatusCode == 200 || response.StatusCode == 201)
        status = 0;
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
