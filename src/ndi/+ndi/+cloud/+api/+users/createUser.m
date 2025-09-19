function [b, answer, apiResponse, apiURL] = createUser(email, name, password)
%CREATEUSER Creates a new user on the NDI Cloud.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.createUser(EMAIL, NAME, PASSWORD)
%
%   Registers a new user account.
%
%   Inputs:
%       email    - The email address for the new account.
%       name     - The user's name.
%       password - The desired password for the new account.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with user information on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, userInfo] = ndi.cloud.api.users.createUser('newuser@example.com', 'New User', 'a_strong_password');
%
%   See also: ndi.cloud.api.implementation.users.CreateUser

    arguments
        email (1,1) string
        name (1,1) string
        password (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.users.CreateUser(...
        'email', email, ...
        'name', name, ...
        'password', password);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

