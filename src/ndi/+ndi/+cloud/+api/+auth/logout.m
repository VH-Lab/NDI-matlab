function [b, answer, apiResponse, apiURL] = logout()
%LOGOUT Logs out the current user and invalidates their token.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.auth.logout()
%
%   Invalidates the authentication token for the currently logged-in user.
%
%   Inputs:
%       None.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A success message or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success] = ndi.cloud.api.auth.logout();
%
%   See also: ndi.cloud.api.implementation.auth.Logout

    arguments
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.auth.Logout();
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

