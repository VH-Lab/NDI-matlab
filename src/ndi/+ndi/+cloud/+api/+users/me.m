function [b, answer, apiResponse, apiURL] = me()
%ME Retrieves information for the current user.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.me()
%
%   Retrieves the public profile information for the current user.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with user information on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, userInfo] = ndi.cloud.api.users.me();
%
%   See also: ndi.cloud.api.implementation.users.Me

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.users.Me();

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
