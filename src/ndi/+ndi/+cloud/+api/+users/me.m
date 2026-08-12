function [b, answer, apiResponse, apiURL] = me()
%ME Retrieves information for the current user.
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.users.me()
%
%   Retrieves the public profile information for the current user, including
%   the organizations that the user belongs to.
%
%   Outputs:
%       b            - True if the call succeeded, false otherwise.
%       answer       - A struct with user information on success, or an error
%                      struct on failure. On success it contains the fields
%                      returned by the NDI Cloud API for the current user:
%                        id                     - user ID (char)
%                        name                   - user's name
%                        email                  - user's email
%                        isValidated            - whether the account is validated
%                        isAdmin                - whether the user is an admin
%                        bookmarkedDatasetIds   - IDs of bookmarked datasets
%                        organizations          - array of the raw organization
%                                                 structs (each with fields
%                                                 'id', 'name' and
%                                                 'canUploadDataset')
%                      plus the following convenience fields derived from
%                      'organizations':
%                        organizationID              - cell array of organization
%                                                      IDs (char) the user belongs to
%                        organizationName            - cell array of organization
%                                                      names (char), parallel to
%                                                      organizationID
%                        organizationCanUploadDataset - cell array of logicals,
%                                                      parallel to organizationID,
%                                                      indicating upload permission
%       apiResponse  - The full matlab.net.http.ResponseMessage object.
%       apiURL       - The URL that was called.
%
%   Example:
%       [success, userInfo] = ndi.cloud.api.users.me();
%       if success
%           for i = 1:numel(userInfo.organizationID)
%               fprintf('%s (%s)\n', userInfo.organizationName{i}, ...
%                   userInfo.organizationID{i});
%           end
%       end
%
%   See also: ndi.cloud.api.implementation.users.Me

    % 1. Create an instance of the implementation class.
    api_call = ndi.cloud.api.implementation.users.Me();

    % 2. Call the execute method and return its outputs directly.
    [b, answer, apiResponse, apiURL] = api_call.execute();

end
