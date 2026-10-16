function [b, answer, apiResponse, apiURL] = getUser(cloudUserID)
%GETUSER Retrieve an NDI Cloud user, including their organizations (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.getUser(CLOUDUSERID)
%
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response. To look up your own account, use
%   ndi.cloud.api.users.me, which needs no administrator rights.
%
%   Inputs:
%       cloudUserID - The user's id.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, the user struct with fields such as 'id',
%                     'name', 'email', 'isAdmin', 'isValidated',
%                     'isDisabled' and 'organizations' (each with 'id' and
%                     'name'), plus parallel cell arrays of char:
%                       organizationID, organizationName
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.findUserByEmail,
%             ndi.cloud.api.admin.getUserOrganizations,
%             ndi.cloud.api.implementation.admin.GetUser

    arguments
        cloudUserID (1,1) string
    end

    api_call = ndi.cloud.api.implementation.admin.GetUser('cloudUserID', cloudUserID);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
