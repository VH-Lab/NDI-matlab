function isGood = testLogin(options)
% TESTLOGIN - Test whether the user has a good NDI Cloud login.
%
%   ISGOOD = ndi.cloud.testLogin()
%
%   Returns true if and only if there is currently a valid login token in
%   this process from which a username (the JWT 'email' claim) can be
%   extracted, AND that exact token is accepted by the server (via a
%   direct GET /users/me with the token as the Bearer credential). If
%   the user has not logged in, or the active token is missing /
%   expired / malformed, or the token has no extractable username, or
%   the server returns 401 for the token, the result is false.
%
%   The /users/me probe is deliberately issued as a raw HTTP request
%   rather than via ndi.cloud.api.users.me or ndi.cloud.api.datasets.
%   listDatasets, both of which would route through ndi.cloud.
%   authenticate() and could silently re-authenticate as a different
%   user mid-call -- which would defeat the purpose of probing the
%   currently held token.
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
%   See also: ndi.cloud.logout, ndi.cloud.uilogin, ndi.cloud.authenticate,
%   ndi.cloud.api.users.me

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
    % A login is "good" only if the token currently in NDI_CLOUD_TOKEN
    % is non-expired, decodable, has an extractable username, AND is
    % accepted by the server right now.
    %
    % We deliberately do NOT go through any wrapper that calls
    % ndi.cloud.authenticate() (e.g. ndi.cloud.api.datasets.listDatasets,
    % ndi.cloud.api.users.me): authenticate() can silently re-auth via
    % vault/env credentials and replace NDI_CLOUD_TOKEN with a token
    % for a *different* user. If that happens, the API call would
    % succeed and probe would falsely report the original login as
    % good. Instead, we read the raw token from the environment, do
    % local JWT validity checks, and then send a GET /users/me
    % directly with that exact token as the Bearer credential.
    % /users/me requires authentication, so a missing or stale token
    % yields a 401 and probe correctly returns false.
    ok = false;

    rawToken = getenv('NDI_CLOUD_TOKEN');
    if isempty(rawToken)
        if verbose
            fprintf('[testLogin]   probe: NDI_CLOUD_TOKEN is empty (no token in env). probe = false.\n');
        end
        return;
    end

    try
        decoded = ndi.cloud.internal.decodeJwt(rawToken);
    catch ME
        if verbose
            fprintf('[testLogin]   probe: decodeJwt() threw: %s. probe = false.\n', ME.message);
        end
        return;
    end

    % Local expiration check.
    if isfield(decoded, 'exp')
        try
            expTime = datetime(decoded.exp, 'ConvertFrom', 'posixtime', 'TimeZone', 'local');
            if datetime('now', 'TimeZone', 'local') > expTime
                if verbose
                    fprintf('[testLogin]   probe: token expired at %s (local). probe = false.\n', char(expTime));
                end
                return;
            end
        catch ME
            if verbose
                fprintf('[testLogin]   probe: could not parse token exp claim: %s. probe = false.\n', ME.message);
            end
            return;
        end
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

    % Local checks pass; verify the server accepts this exact token.
    % We send the request directly so no wrapper can silently re-auth
    % as a different user mid-call.
    if verbose
        fprintf('[testLogin]   probe: sending GET /users/me with the current token to verify the server accepts it.\n');
    end
    try
        url = ndi.cloud.api.url('get_current_user');
        accept = matlab.net.http.HeaderField('accept', 'application/json');
        authHeader = matlab.net.http.HeaderField('Authorization', ['Bearer ' rawToken]);
        request = matlab.net.http.RequestMessage( ...
            matlab.net.http.RequestMethod.GET, [accept authHeader]);
        response = send(request, url);
    catch ME
        if verbose
            fprintf('[testLogin]   probe: GET /users/me threw an error: %s\n', ME.message);
            fprintf('[testLogin]   probe: identifier = %s\n', ME.identifier);
        end
        return;
    end

    if response.StatusCode ~= matlab.net.http.StatusCode.OK
        if verbose
            fprintf('[testLogin]   probe: GET /users/me returned status %d (%s). probe = false.\n', ...
                double(response.StatusCode), char(response.StatusCode));
        end
        return;
    end

    if verbose
        fprintf('[testLogin]   probe: GET /users/me returned 200 OK.\n');
    end

    % Defense in depth: cross-check the server's reported email
    % against the JWT's email. If they disagree, something has swapped
    % the token underneath us; report false.
    body = response.Body.Data;
    if isstruct(body) && isfield(body, 'email') && ~isempty(body.email)
        serverEmail = string(body.email);
        if ~strcmpi(serverEmail, string(decoded.email))
            if verbose
                fprintf('[testLogin]   probe: server email (%s) does NOT match JWT email (%s). probe = false.\n', ...
                    serverEmail, decoded.email);
            end
            return;
        end
        if verbose
            fprintf('[testLogin]   probe: server email matches JWT email. probe = true.\n');
        end
    else
        if verbose
            fprintf('[testLogin]   probe: server response had no email field; trusting 200 status. probe = true.\n');
        end
    end

    ok = true;
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
