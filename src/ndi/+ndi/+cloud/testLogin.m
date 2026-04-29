function isGood = testLogin(options)
% TESTLOGIN - Test whether the user has a good NDI Cloud login.
%
%   ISGOOD = ndi.cloud.testLogin()
%
%   Tests the current login by attempting to list datasets. If the first
%   attempt fails, logs out and retries (which gives cached credentials in
%   the MATLAB Vault or NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD environment
%   variables a chance to silently re-authenticate). If the second attempt
%   also fails and UseUILogin is true, logs out and forces the UI login
%   dialog before a final check.
%
%   Optional Inputs (Name-Value Pairs):
%       UseUILogin - If true (default), prompt the user to log in via the
%           UI dialog when the initial attempts fail. If false, skip the
%           UI login step.
%       UserName - If provided, the JWT in the active token must have been
%           issued for this email; otherwise the login is considered not
%           good even if the API call succeeds. This guards against the
%           case where a stale token (or vault/env credentials) would
%           silently authenticate as a different user than intended.
%
%   Outputs:
%       isGood - True if the user has a valid login (and, when UserName is
%           provided, the token belongs to that user), false otherwise.
%
%   Example:
%       isGood = ndi.cloud.testLogin();
%       isGood = ndi.cloud.testLogin('UseUILogin', false);
%       isGood = ndi.cloud.testLogin('UserName', "alice@example.com");
%
%   See also: ndi.cloud.logout, ndi.cloud.uilogin, ndi.cloud.api.datasets.listDatasets

    arguments
        options.UseUILogin (1,1) logical = true
        options.UserName (1,1) string = missing
    end

    isGood = probe(options.UserName);
    if isGood
        return;
    end

    % First attempt failed; logout and retry. The retry may silently
    % re-authenticate from vault/env credentials inside listDatasets ->
    % authenticate(); that path can throw on bad credentials, so probe()
    % swallows errors and reports false.
    ndi.cloud.logout();
    isGood = probe(options.UserName);
    if isGood
        return;
    end

    % Second attempt failed; force a fresh interactive login if allowed.
    if options.UseUILogin
        ndi.cloud.logout();
        if ismissing(options.UserName)
            ndi.cloud.uilogin(true);
        else
            ndi.cloud.uilogin(true, 'UserName', options.UserName);
        end
        isGood = probe(options.UserName);
    end
end

function ok = probe(userName)
    ok = false;
    try
        [b, ~] = ndi.cloud.api.datasets.listDatasets();
    catch
        return;
    end
    if ~b
        return;
    end
    if ismissing(userName)
        ok = true;
        return;
    end
    % Verify the active token was issued to the requested user.
    try
        token = ndi.cloud.internal.getActiveToken();
        if isempty(token)
            return;
        end
        decoded = ndi.cloud.internal.decodeJwt(token);
        if isfield(decoded, 'email') && strcmp(decoded.email, userName)
            ok = true;
        end
    catch
        ok = false;
    end
end
