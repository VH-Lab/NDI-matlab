function [b, answer, apiResponse, apiURL] = getUser(cloudUserID)
%GETUSER Retrieves information for a specific user.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.getUser(CLOUDUSERID)
%
%   Retrieves the public profile information for a given user.
%
%   Inputs:
%       cloudUserID  - The unique identifier of the user to retrieve.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with user information on success, or an error struct on failure.
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, userInfo] = ndi.cloud.api.users.getUser('u-abcdef12345');
%
%   See also: ndi.cloud.api.implementation.users.GetUser

    arguments
        cloudUserID (1,1) string
    end

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.users.GetUser('cloudUserID', cloudUserID);
    
    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();
    
end

