function isGood = testLogin(options)
% TESTLOGIN - Test whether the user has a good NDI Cloud login.
%
%   ISGOOD = ndi.cloud.testLogin()
%
%   Returns true if and only if there is currently a valid login token in
%   this process from which a username (the JWT 'email' claim) can be
%   extracted, AND that token works against the server. If the user has
%   not logged in, or the active token is missing/expired, or the token
%   has no extractable username, the result is false.
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
%       Verbose - If true, print a step-by-step description of what the
%           function is doing, including details about the active token,
%           API call results, and any errors encountered. Useful for
%           debugging cases where testLogin reports success but
%           subsequent uses of the token fail. Default is false.
%
%   Outputs:
%       isGood - True if the user has a valid login (and, when UserName is
%           provided, the token belongs to that user), false otherwise.
%
%   Example:
%       isGood = ndi.cloud.testLogin();
%       isGood = ndi.cloud.testLogin('UseUILogin', false);
%       isGood = ndi.cloud.testLogin('UserName', "alice@example.com");
%       isGood = ndi.cloud.testLogin('Verbose', true);
%
%   See also: ndi.cloud.logout, ndi.cloud.uilogin, ndi.cloud.api.datasets.listDatasets

    arguments
        options.UseUILogin (1,1) logical = true
        options.UserName (1,1) string = missing
        options.Verbose (1,1) logical = false
    end

    verbose = options.Verbose;

    if verbose
        fprintf('[testLogin] Starting NDI Cloud login test.\n');
        if ismissing(options.UserName)
            fprintf('[testLogin] No UserName specified; token-user check will be skipped.\n');
        else
            fprintf('[testLogin] UserName specified: %s (token must match).\n', options.UserName);
        end
        fprintf('[testLogin] UseUILogin = %d.\n', options.UseUILogin);
        reportTokenState(verbose, 'initial');
    end

    if verbose
        fprintf('[testLogin] Attempt 1: probing current credentials.\n');
    end
    isGood = probe(options.UserName, verbose);
    if isGood
        if verbose
            fprintf('[testLogin] Attempt 1 succeeded. Returning isGood = true.\n');
            reportTokenState(verbose, 'final');
        end
        return;
    end

    % First attempt failed; logout and retry. The retry may silently
    % re-authenticate from vault/env credentials inside listDatasets ->
    % authenticate(); that path can throw on bad credentials, so probe()
    % swallows errors and reports false.
    if verbose
        fprintf('[testLogin] Attempt 1 failed. Logging out and retrying.\n');
        fprintf('[testLogin] (Logout clears NDI_CLOUD_TOKEN; the next probe may re-authenticate from vault/env.)\n');
    end
    ndi.cloud.logout();
    if verbose
        reportTokenState(verbose, 'after logout');
        fprintf('[testLogin] Attempt 2: probing after logout (allows silent re-auth).\n');
    end
    isGood = probe(options.UserName, verbose);
    if isGood
        if verbose
            fprintf('[testLogin] Attempt 2 succeeded. Returning isGood = true.\n');
            reportTokenState(verbose, 'final');
        end
        return;
    end

    % Second attempt failed; force a fresh interactive login if allowed.
    if options.UseUILogin
        if verbose
            fprintf('[testLogin] Attempt 2 failed. Forcing UI login.\n');
        end
        ndi.cloud.logout();
        if verbose
            reportTokenState(verbose, 'after second logout');
            fprintf('[testLogin] Launching ndi.cloud.uilogin(true).\n');
        end
        if ismissing(options.UserName)
            ndi.cloud.uilogin(true);
        else
            ndi.cloud.uilogin(true, 'UserName', options.UserName);
        end
        if verbose
            reportTokenState(verbose, 'after UI login');
            fprintf('[testLogin] Attempt 3: probing after UI login.\n');
        end
        isGood = probe(options.UserName, verbose);
        if verbose
            if isGood
                fprintf('[testLogin] Attempt 3 succeeded. Returning isGood = true.\n');
            else
                fprintf('[testLogin] Attempt 3 failed. Returning isGood = false.\n');
            end
            reportTokenState(verbose, 'final');
        end
    else
        if verbose
            fprintf('[testLogin] UseUILogin is false; not attempting interactive login. Returning isGood = false.\n');
            reportTokenState(verbose, 'final');
        end
    end
end

function ok = probe(userName, verbose)
    % A login is "good" only if we currently hold a valid token from
    % which a username (email) can be extracted, AND the token works
    % against the server. Successfully calling listDatasets() is not
    % sufficient on its own: silent re-authentication paths can make the
    % API call succeed without leaving a usable token in this process.
    ok = false;

    if verbose
        fprintf('[testLogin]   probe: calling ndi.cloud.api.datasets.listDatasets().\n');
    end
    try
        [b, ~] = ndi.cloud.api.datasets.listDatasets();
    catch ME
        if verbose
            fprintf('[testLogin]   probe: listDatasets() threw an error: %s\n', ME.message);
            fprintf('[testLogin]   probe: identifier = %s\n', ME.identifier);
        end
        return;
    end
    if verbose
        fprintf('[testLogin]   probe: listDatasets() returned status = %d.\n', b);
    end
    if ~b
        if verbose
            fprintf('[testLogin]   probe: listDatasets() reported failure (status false). probe = false.\n');
        end
        return;
    end

    % listDatasets() succeeded; now require a currently valid local token
    % with an extractable username.
    if verbose
        fprintf('[testLogin]   probe: verifying that a currently valid token with an extractable username exists.\n');
    end
    try
        token = ndi.cloud.internal.getActiveToken();
    catch ME
        if verbose
            fprintf('[testLogin]   probe: getActiveToken() threw: %s. probe = false.\n', ME.message);
        end
        return;
    end
    if isempty(token)
        if verbose
            fprintf('[testLogin]   probe: getActiveToken() returned empty (token missing or expired). probe = false.\n');
        end
        return;
    end

    try
        decoded = ndi.cloud.internal.decodeJwt(token);
    catch ME
        if verbose
            fprintf('[testLogin]   probe: decodeJwt() threw: %s. probe = false.\n', ME.message);
        end
        return;
    end

    if ~isfield(decoded, 'email') || isempty(decoded.email)
        if verbose
            fprintf('[testLogin]   probe: token has no extractable username (no ''email'' claim). probe = false.\n');
        end
        return;
    end

    if verbose
        fprintf('[testLogin]   probe: token email = %s.\n', decoded.email);
    end

    if ismissing(userName)
        if verbose
            fprintf('[testLogin]   probe: token is valid and username is extractable; no UserName check requested. probe = true.\n');
        end
        ok = true;
        return;
    end

    if strcmp(decoded.email, userName)
        if verbose
            fprintf('[testLogin]   probe: token email matches UserName. probe = true.\n');
        end
        ok = true;
    else
        if verbose
            fprintf('[testLogin]   probe: token email does NOT match UserName. probe = false.\n');
        end
    end
end

function reportTokenState(verbose, label)
    if ~verbose
        return;
    end
    rawToken = getenv('NDI_CLOUD_TOKEN');
    rawOrg = getenv('NDI_CLOUD_ORGANIZATION_ID');
    if isempty(rawToken)
        fprintf('[testLogin] [token state - %s] NDI_CLOUD_TOKEN is empty.\n', label);
    else
        fprintf('[testLogin] [token state - %s] NDI_CLOUD_TOKEN is set (length=%d, prefix=%s...).\n', ...
            label, length(rawToken), rawToken(1:min(8,length(rawToken))));
        try
            decoded = ndi.cloud.internal.decodeJwt(rawToken);
            if isfield(decoded, 'email')
                fprintf('[testLogin] [token state - %s] token email = %s.\n', label, decoded.email);
            end
            if isfield(decoded, 'sub')
                fprintf('[testLogin] [token state - %s] token sub   = %s.\n', label, decoded.sub);
            end
            if isfield(decoded, 'exp')
                expTime = datetime(decoded.exp, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
                now_local = datetime('now', 'TimeZone', 'local');
                fprintf('[testLogin] [token state - %s] token exp   = %s (local).\n', label, char(expTime));
                if now_local > expTime
                    fprintf('[testLogin] [token state - %s] token is EXPIRED (now=%s).\n', label, char(now_local));
                else
                    fprintf('[testLogin] [token state - %s] token valid for %s.\n', label, char(expTime - now_local));
                end
            end
            if isfield(decoded, 'iat')
                iatTime = datetime(decoded.iat, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
                fprintf('[testLogin] [token state - %s] token iat   = %s (local).\n', label, char(iatTime));
            end
        catch ME
            fprintf('[testLogin] [token state - %s] could not decode JWT: %s\n', label, ME.message);
        end
    end
    if isempty(rawOrg)
        fprintf('[testLogin] [token state - %s] NDI_CLOUD_ORGANIZATION_ID is empty.\n', label);
    else
        fprintf('[testLogin] [token state - %s] NDI_CLOUD_ORGANIZATION_ID = %s.\n', label, rawOrg);
    end
end
