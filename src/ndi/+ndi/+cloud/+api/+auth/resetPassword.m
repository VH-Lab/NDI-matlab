function [b, answer, apiResponse, apiURL] = resetPassword(email)
%RESETPASSWORD Sends a password reset email to the specified address.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.auth.resetPassword(EMAIL)
%
%   Requests that a password reset email be sent to the user's address.
%
%   Inputs:
%       email - The email address of the user requesting the reset.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A success message or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success] = ndi.cloud.api.auth.resetPassword('user@example.com');
%
%   See also: ndi.cloud.api.implementation.auth.ResetPassword

    arguments
        email (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.auth.ResetPassword('email', email);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

