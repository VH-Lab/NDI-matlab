function [b, answer, apiResponse, apiURL] = changePassword(oldPassword, newPassword)
%CHANGEPASSWORD Changes the current user's password.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.auth.changePassword(OLDPASSWORD, NEWPASSWORD)
%
%   Updates the password for the currently authenticated user.
%
%   Inputs:
%       oldPassword - The user's current password.
%       newPassword - The user's desired new password.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A success message or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success] = ndi.cloud.api.auth.changePassword('oldPass123', 'newPass456');
%
%   See also: ndi.cloud.api.implementation.auth.ChangePassword

    arguments
        oldPassword (1,1) string
        newPassword (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.auth.ChangePassword(...
        'oldPassword', oldPassword, ...
        'newPassword', newPassword);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

