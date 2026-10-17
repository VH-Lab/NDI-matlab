function [b, answer, apiResponse, apiURL] = getUserOrganizations(user)
%GETUSERORGANIZATIONS List the organizations a user belongs to.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.getUserOrganizations()
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.getUserOrganizations(USER)
%
%   With no input, lists the organizations of the logged-in user, using
%   ndi.cloud.api.users.me. This form needs no administrator rights.
%
%   With USER, lists the organizations of that user, using
%   ndi.cloud.api.admin.getUser. This form requires an account with
%   administrator rights. USER is either a user id or an email address
%   (anything containing "@" is treated as an email address and looked up
%   with ndi.cloud.api.admin.findUserByEmail).
%
%   Inputs:
%       user - (Optional) The user's id or email address.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, a struct with fields:
%                       userID           - the user's id (char)
%                       email            - the user's email (char)
%                       organizationID   - cell array of organization ids (char)
%                       organizationName - cell array of organization names
%                                          (char), parallel to organizationID
%                     On failure, the error from whichever step failed.
%       apiResponse - The ResponseMessage of the last call made.
%       apiURL      - The URL of the last call made.
%
%   Example:
%       [ok, r] = ndi.cloud.api.admin.getUserOrganizations("person@example.com");
%       if ok, disp(r.organizationName'); end
%
%   See also: ndi.cloud.api.users.me, ndi.cloud.api.admin.getUser,
%             ndi.cloud.api.admin.findUserByEmail

    arguments
        user (1,1) string = missing
    end

    if ismissing(user)
        [b, info, apiResponse, apiURL] = ndi.cloud.api.users.me();
    else
        user = strtrim(user);
        userID = user;
        if contains(user, "@")
            [b, found, apiResponse, apiURL] = ndi.cloud.api.admin.findUserByEmail(user);
            if ~b
                answer = found;
                return
            end
            userID = found.id;
        end
        [b, info, apiResponse, apiURL] = ndi.cloud.api.admin.getUser(userID);
    end

    if ~b
        answer = info;
        return
    end

    answer = struct( ...
        'userID', char(string(info.id)), ...
        'email', char(string(info.email)), ...
        'organizationID', {info.organizationID}, ...
        'organizationName', {info.organizationName});
end
