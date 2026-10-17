function [apiResponse, answer] = sendRequest(method, apiURL, body)
%SENDREQUEST Send an authenticated request to an NDI Cloud admin endpoint.
%
%   [APIRESPONSE, ANSWER] = ndi.cloud.api.implementation.admin.sendRequest(METHOD, APIURL)
%   [APIRESPONSE, ANSWER] = ndi.cloud.api.implementation.admin.sendRequest(METHOD, APIURL, BODY)
%
%   Shared by the ndi.cloud.api.implementation.admin classes. Adds the
%   bearer token of the logged-in user and, when BODY is given, sends it
%   as a JSON body.
%
%   Inputs:
%       method - A matlab.net.http.RequestMethod (GET, POST, PATCH, DELETE).
%       apiURL - The matlab.net.URI to call.
%       body   - (Optional) A scalar struct sent as the JSON body.
%
%   Outputs:
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       answer      - The decoded response body. On failure this is the
%                     server's error struct (for example, struct('error', ...)).

    arguments
        method (1,1) matlab.net.http.RequestMethod
        apiURL (1,1) matlab.net.URI
        body struct {mustBeScalarOrEmpty} = struct.empty
    end

    token = ndi.cloud.authenticate();
    acceptField = matlab.net.http.HeaderField('accept', 'application/json');
    authorizationField = matlab.net.http.HeaderField('Authorization', ['Bearer ' char(token)]);

    if isempty(body)
        headers = [acceptField authorizationField];
        request = matlab.net.http.RequestMessage(method, headers);
    else
        contentTypeField = matlab.net.http.field.ContentTypeField( ...
            matlab.net.http.MediaType('application/json'));
        headers = [acceptField contentTypeField authorizationField];
        request = matlab.net.http.RequestMessage(method, headers, ...
            matlab.net.http.MessageBody(body));
    end

    apiResponse = send(request, apiURL);

    if isprop(apiResponse.Body, 'Data') && ~isempty(apiResponse.Body.Data)
        answer = apiResponse.Body.Data;
    elseif isprop(apiResponse.Body, 'Payload')
        answer = apiResponse.Body.Payload;
    else
        answer = apiResponse.Body;
    end
end
