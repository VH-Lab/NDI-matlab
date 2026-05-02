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
%   Order of operations:
%       1. Probe the currently active token. If it is valid and the
%          server accepts it, return true.
%       2. Otherwise log out (clearing any stale token) and check for
%          silent credentials in the environment (NDI_CLOUD_USERNAME and
%          NDI_CLOUD_PASSWORD; CLOUD_API_ENVIRONMENT is honored
%          automatically by the underlying API URL machinery).
%       3. If those env credentials are set, attempt a non-interactive
%          re-login via ndi.cloud.authenticate('InteractionEnabled','off')
%          (which also tries the MATLAB Vault silently). Probe again.
%          The UI login dialog is NOT shown in this case, even if the
%          silent re-login does not succeed: when env credentials are
%          present we trust them and report success/failure accordingly.
%       4. Only if the env credentials are empty, AND UseUILogin is true,
%          launch ndi.cloud.uilogin and probe a final time.
%
%   Optional Inputs (Name-Value Pairs):
%       UseUILogin - If true (default), prompt the user to log in via the
%           UI dialog when there are no silent credentials available. If
%           false, never prompt. Note: when NDI_CLOUD_USERNAME and
%           NDI_CLOUD_PASSWORD are set, the UI login is never shown
%           regardless of this flag.
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
%   See also: ndi.cloud.logout, ndi.cloud.uilogin, ndi.cloud.authenticate

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
        reportApiEnvironment(verbose);
        reportTokenState(verbose, 'initial');
    end

    % Attempt 1: probe the currently active token.
    if verbose
        fprintf('[testLogin] Attempt 1: probing the currently active token.\n');
    end
    isGood = probe(options.UserName, verbose);
    if isGood
        if verbose
            fprintf('[testLogin] Attempt 1 succeeded. Returning isGood = true.\n');
            reportTokenState(verbose, 'final');
        end
        return;
    end

    % No good current token; clear stale state.
    if verbose
        fprintf('[testLogin] Attempt 1 failed. Logging out to clear stale state.\n');
    end
    ndi.cloud.logout();
    if verbose
        reportTokenState(verbose, 'after logout');
    end

    % Attempt 2: silent re-auth via NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD
    % (and the MATLAB Vault, if available). When env credentials are set,
    % we never fall through to the UI login: success or failure here is
    % the final answer.
    envUser = getenv('NDI_CLOUD_USERNAME');
    envPass = getenv('NDI_CLOUD_PASSWORD');
    haveEnvCreds = ~isempty(envUser) && ~isempty(envPass);

    if haveEnvCreds
        if verbose
            fprintf('[testLogin] Attempt 2: NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD are set; attempting silent re-auth (no UI).\n');
            fprintf('[testLogin]   NDI_CLOUD_USERNAME = %s.\n', envUser);
        end
        if ~ismissing(options.UserName) && ~strcmp(envUser, options.UserName)
            if verbose
                fprintf('[testLogin]   NDI_CLOUD_USERNAME (%s) does not match requested UserName (%s); skipping silent login.\n', ...
                    envUser, options.UserName);
            end
        else
            try
                if ismissing(options.UserName)
                    ndi.cloud.authenticate('InteractionEnabled', 'off');
                else
                    ndi.cloud.authenticate('UserName', options.UserName, ...
                        'InteractionEnabled', 'off');
                end
                if verbose
                    fprintf('[testLogin]   silent ndi.cloud.authenticate completed.\n');
                end
            catch ME
                if verbose
                    fprintf('[testLogin]   silent ndi.cloud.authenticate threw: %s\n', ME.message);
                    fprintf('[testLogin]   identifier = %s\n', ME.identifier);
                end
            end
        end
        if verbose
            reportTokenState(verbose, 'after silent re-auth');
            fprintf('[testLogin] Probing after silent re-auth.\n');
        end
        isGood = probe(options.UserName, verbose);
        if verbose
            if isGood
                fprintf('[testLogin] Attempt 2 succeeded. Returning isGood = true.\n');
            else
                fprintf('[testLogin] Attempt 2 failed. Env credentials are set; per policy, NOT falling through to UI login. Returning isGood = false.\n');
            end
            reportTokenState(verbose, 'final');
        end
        return;
    end

    % Attempt 3: env credentials are empty; only now consider the UI
    % login, and only if UseUILogin is true.
    if ~options.UseUILogin
        if verbose
            fprintf('[testLogin] No env credentials and UseUILogin is false. Returning isGood = false.\n');
            reportTokenState(verbose, 'final');
        end
        isGood = false;
        return;
    end

    if verbose
        fprintf('[testLogin] Attempt 3: no env credentials; launching ndi.cloud.uilogin.\n');
    end
    if ismissing(options.UserName)
        ndi.cloud.uilogin(true);
    else
        ndi.cloud.uilogin(true, 'UserName', options.UserName);
    end
    if verbose
        reportTokenState(verbose, 'after UI login');
        fprintf('[testLogin] Probing after UI login.\n');
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
end

function ok = probe(userName, verbose)
    % A login is "good" only if we currently hold a valid token from
    % which a username (email) can be extracted, AND the server accepts
    % that token.
    %
    % We deliberately check the local token first (and bail out if it
    % is missing or malformed) BEFORE calling listDatasets(). That call
    % goes through ndi.cloud.authenticate(), which by default has
    % InteractionEnabled='on' and would pop the UI login dialog if no
    % silent credentials are available. probe() must never trigger the
    % UI login on its own; the caller decides if/when to do that.
    ok = false;

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
            fprintf('[testLogin]   probe: no active token (missing or expired). probe = false.\n');
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

    if ~ismissing(userName) && ~strcmp(decoded.email, userName)
        if verbose
            fprintf('[testLogin]   probe: token email does NOT match UserName (%s). probe = false.\n', userName);
        end
        return;
    end

    % Token looks locally valid; confirm the server accepts it.
    if verbose
        fprintf('[testLogin]   probe: calling ndi.cloud.api.datasets.listDatasets() to verify the server accepts the token.\n');
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
    ok = logical(b);
    if verbose
        if ok
            fprintf('[testLogin]   probe: server accepted token. probe = true.\n');
        else
            fprintf('[testLogin]   probe: server did NOT accept token. probe = false.\n');
        end
    end
end

function reportApiEnvironment(verbose)
    if ~verbose
        return;
    end
    apiEnv = getenv('CLOUD_API_ENVIRONMENT');
    if isempty(apiEnv)
        fprintf('[testLogin] CLOUD_API_ENVIRONMENT is empty (defaulting to ''prod'').\n');
    else
        fprintf('[testLogin] CLOUD_API_ENVIRONMENT = %s.\n', apiEnv);
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
