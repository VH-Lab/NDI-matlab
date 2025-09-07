function [b, answer, apiResponse, apiURL] = login(email, password)
%LOGIN Authenticates a user and retrieves a token.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.auth.login(EMAIL, PASSWORD)
%
%   Authenticates a user with the NDI Cloud and returns an authentication
%   token and organization ID.
%
%   Inputs:
%       email    - The user's email address.
%       password - The user's password.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct containing the 'token' and 'user' info on success,
%                      or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, authInfo] = ndi.cloud.api.auth.login('user@example.com', 'mypassword');
%       if success
%           token = authInfo.token;
%           orgId = authInfo.user.organizations.id;
%       end
%
%   See also: ndi.cloud.api.implementation.auth.Login

    arguments
        email (1,1) string
        password (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.auth.Login(...
        'email', email, ...
        'password', password);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

