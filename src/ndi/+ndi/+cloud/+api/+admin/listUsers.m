function [b, answer, apiResponse, apiURL] = listUsers(options)
%LISTUSERS List NDI Cloud users (admin only).
%
%   [B, ANSWER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.listUsers(...)
%
%   Lists one page of active (not disabled) users, sorted by email.
%   Requires an account with administrator rights; other accounts get
%   B = false and a 403 response.
%
%   Optional name-value inputs:
%       query    - Case-insensitive substring matched against the user's
%                  name or email. Default "" (all users). This is a
%                  substring match: to find one user by exact email, use
%                  ndi.cloud.api.admin.findUserByEmail.
%       page     - 1-based page number. Default 1.
%       pageSize - Users per page, 1-100. Default 25.
%
%   Outputs:
%       b           - True if the call succeeded, false otherwise.
%       answer      - On success, a struct with fields:
%                       users - the users on this page, each with 'id',
%                               'name', 'email', 'isAdmin', 'isValidated',
%                               and other account flags. A struct array, or
%                               a cell array of structs if their fields differ.
%                       page, limit, total, totalPages
%                     On failure, the server's error struct.
%       apiResponse - The full matlab.net.http.ResponseMessage object.
%       apiURL      - The URL that was called.
%
%   See also: ndi.cloud.api.admin.findUserByEmail, ndi.cloud.api.admin.getUser,
%             ndi.cloud.api.implementation.admin.ListUsers

    arguments
        options.query (1,1) string = ""
        options.page (1,1) double {mustBePositive, mustBeInteger} = 1
        options.pageSize (1,1) double {mustBeInteger, mustBeInRange(options.pageSize, 1, 100)} = 25
    end

    api_call = ndi.cloud.api.implementation.admin.ListUsers( ...
        'query', options.query, 'page', options.page, 'pageSize', options.pageSize);
    [b, answer, apiResponse, apiURL] = api_call.execute();
end
