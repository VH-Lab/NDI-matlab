function [response] = resend_confirmation(email)
    % RESEND_CONFIRMATION - Resends the verification code via email
    %
    % [RESPONSE] = ndi.cloud.api.auth.resend_confirmation(EMAIL)
    %
    % Inputs:
    %   EMAIL - a string representing the email address used to send the
    %   verification
    %
    % Outputs:
    %   RESPONSE - the response summary
    %

    % Prepare the JSON data to be sent in the POST request
    json = struct('email', email);

    method = matlab.net.http.RequestMethod.POST;

    body = matlab.net.http.MessageBody(json);

    contentTypeField = matlab.net.http.field.ContentTypeField(matlab.net.http.MediaType('application/json'));
    acceptField = matlab.net.http.field.AcceptField(matlab.net.http.MediaType('application/json'));
    header = [acceptField contentTypeField];

    req = matlab.net.http.RequestMessage(method, header, body);

    url = ndi.cloud.api.url('resend_confirmation');

    response = req.send(url);
    if (response.StatusCode == 200 || response.StatusCode == 201)
        
    else
        error('Failed to run command. StatusCode: %d. StatusLine: %s ', response.StatusCode, response.StatusLine.ReasonPhrase);
    end
end
