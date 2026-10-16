function [b, user, apiResponse, apiURL] = findUserByEmail(email)
%FINDUSERBYEMAIL Find an NDI Cloud user by exact email address (admin only).
%
%   [B, USER, APIRESPONSE, APIURL] = ndi.cloud.api.admin.findUserByEmail(EMAIL)
%
%   The API has no lookup by email, so this searches with
%   ndi.cloud.api.admin.listUsers and keeps only the user whose email
%   equals EMAIL, ignoring case. (The search itself is a substring match:
%   "bob@lab.edu" also matches "jimbob@lab.edu".) Disabled users are not
%   found. Requires an account with administrator rights.
%
%   Inputs:
%       email - The user's email address.
%
%   Outputs:
%       b           - True if exactly one user has this email, false otherwise.
%       user        - On success, the user struct from listUsers (with 'id',
%                     'name', 'email', ...), with 'id' as char. If no user
%                     matches, a struct with an 'error' field. If the
%                     search itself failed, the server's error struct.
%       apiResponse - The ResponseMessage of the last listUsers call.
%       apiURL      - The URL of the last listUsers call.
%
%   Example:
%       [ok, u] = ndi.cloud.api.admin.findUserByEmail("person@example.com");
%       if ok, disp(u.id); end
%
%   See also: ndi.cloud.api.admin.listUsers,
%             ndi.cloud.api.admin.addOrganizationMemberByEmail

    arguments
        email (1,1) string {mustBeNonzeroLengthText}
    end

    email = strtrim(email);
    matches = {};
    page = 1;
    while true
        [b, answer, apiResponse, apiURL] = ndi.cloud.api.admin.listUsers( ...
            'query', email, 'page', page, 'pageSize', 100);
        if ~b
            user = answer;
            return
        end
        users = ndi.cloud.api.implementation.admin.asStructCell(answer.users);
        for i = 1:numel(users)
            if isfield(users{i}, 'email') && strcmpi(string(users{i}.email), email)
                matches{end+1} = users{i}; %#ok<AGROW>
            end
        end
        if page >= answer.totalPages
            break
        end
        page = page + 1;
    end

    if isscalar(matches)
        b = true;
        user = matches{1};
        user.id = char(string(user.id));
    elseif isempty(matches)
        b = false;
        user = struct('error', sprintf('No active NDI Cloud user has the email address %s.', email));
    else
        b = false;
        user = struct('error', sprintf('%d NDI Cloud users have the email address %s.', ...
            numel(matches), email));
    end
end
