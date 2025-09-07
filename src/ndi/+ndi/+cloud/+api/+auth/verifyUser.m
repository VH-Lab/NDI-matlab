function [b, answer, apiResponse, apiURL] = verifyUser(email, confirmationCode)
%VERIFYUSER Verifies a user account with a confirmation code.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.auth.verifyUser(EMAIL, CONFIRMATIONCODE)
%
%   Submits the confirmation code sent to a user's email to complete
%   the account registration process.
%
%   Inputs:
%       email            - The user's email address.
%       confirmationCode - The confirmation code from the email.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A success message or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success] = ndi.cloud.api.auth.verifyUser('newuser@example.com', '123456');
%
%   See also: ndi.cloud.api.implementation.auth.VerifyUser

    arguments
        email (1,1) string
        confirmationCode (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.auth.VerifyUser(...
        'email', email, 'confirmationCode', confirmationCode);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

