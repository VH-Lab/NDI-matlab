classdef AuthTest < matlab.unittest.TestCase
% AuthTest - Test auth/ api endpoints

    % Requirements for test:
    %   - The following environment variables must be set
    %       - NDI_CLOUD_USERNAME
    %       - NDI_CLOUD_PASSWORD

    properties (Access = private)
        % Snapshot of NDI cloud env vars at the start of each test, so
        % tests can freely modify them without leaking state.
        SavedEnv struct = struct()
    end

    methods (TestMethodSetup)
        function snapshotCloudEnv(testCase)
            names = {'NDI_CLOUD_TOKEN', 'NDI_CLOUD_ORGANIZATION_ID', ...
                     'NDI_CLOUD_USERNAME', 'NDI_CLOUD_PASSWORD', ...
                     'CLOUD_API_ENVIRONMENT'};
            saved = struct();
            for k = 1:numel(names)
                saved.(names{k}) = getenv(names{k});
            end
            testCase.SavedEnv = saved;
        end
    end

    methods (TestMethodTeardown)
        function restoreCloudEnv(testCase)
            names = fieldnames(testCase.SavedEnv);
            for k = 1:numel(names)
                setenv(names{k}, testCase.SavedEnv.(names{k}));
            end
        end
    end

    methods (Test)
        function testLoginLogout(testCase)
            narrative = "Begin AuthTest: testLoginLogout";

            % Step 1: Check local configuration
            narrative(end+1) = "Checking for local NDI credentials in environment variables.";
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            local_config_message = "Local NDI configuration error: NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables must be set.";
            testCase.verifyTrue(~(isempty(username) || isempty(password)), local_config_message);

            narrative(end+1) = "Local credentials found.";

            % Step 2: Test Login
            narrative(end+1) = "Preparing to call ndi.cloud.api.auth.login.";
            [b_login, answer_login, apiResponse_login, apiURL_login] = ndi.cloud.api.auth.login(username, password);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_login);

            narrative(end+1) = "Testing: Verifying the login API call was successful (APICallSuccessFlag should be true).";
            login_message = ndi.unittest.cloud.APIMessage(narrative, b_login, answer_login, apiResponse_login, apiURL_login);
            testCase.verifyTrue(b_login, login_message);

            narrative(end+1) = "Login call successful. Verifying token and organization ID.";
            testCase.verifyClass(answer_login.token, 'char', login_message);
            testCase.verifyClass(answer_login.user.organizations.id, 'char', login_message);
            narrative(end+1) = "Token and organization ID are of the correct class.";

            % Step 3: Test Logout
            narrative(end+1) = "Preparing to call ndi.cloud.api.auth.logout.";
            [b_logout, answer_logout, apiResponse_logout, apiURL_logout] = ndi.cloud.api.auth.logout();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_logout);

            narrative(end+1) = "Testing: Verifying the logout API call was successful (APICallSuccessFlag should be true).";
            logout_message = ndi.unittest.cloud.APIMessage(narrative, b_logout, answer_logout, apiResponse_logout, apiURL_logout);
            testCase.verifyTrue(b_logout, logout_message);
            narrative(end+1) = "Logout call successful.";
        end

        function testHighLevelLogout(testCase)
            % This test verifies the behavior of ndi.cloud.logout

            % Setup: Set environment variables to simulate a logged-in state
            setenv('NDI_CLOUD_TOKEN', 'fake_token');
            setenv('NDI_CLOUD_ORGANIZATION_ID', 'fake_org_id');

            % Action: Call logout
            % We expect a warning because the token is fake and API call will likely fail,
            % but the function should still clear the environment variables.
            warning('off', 'NDI:Cloud:LogoutAPIError');
            cleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError'));

            ndi.cloud.logout();

            % Verify: Environment variables should be empty
            token = getenv('NDI_CLOUD_TOKEN');
            org_id = getenv('NDI_CLOUD_ORGANIZATION_ID');

            testCase.verifyEmpty(token, 'NDI_CLOUD_TOKEN should be empty after logout');
            testCase.verifyEmpty(org_id, 'NDI_CLOUD_ORGANIZATION_ID should be empty after logout');
        end

        function testTestLoginWithNoCredentialsReturnsFalse(testCase)
            % ndi.cloud.testLogin must return false when there is no
            % currently valid login token in this process and no silent
            % credentials are available. probe() must not trigger the UI
            % login dialog when called with no token; it must simply
            % report false.

            clearAllCloudEnv();
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError')); %#ok<NASGU>

            isGood = ndi.cloud.testLogin('UseUILogin', false);

            testCase.verifyFalse(isGood, ...
                'testLogin should return false when no token is present, no env credentials, and UseUILogin is false.');
        end

        function testTestLoginWithFakeTokenReturnsFalse(testCase)
            % A non-empty but malformed token must be rejected without
            % triggering the UI login dialog.

            clearAllCloudEnv();
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError')); %#ok<NASGU>

            setenv('NDI_CLOUD_TOKEN', 'not.a.real.jwt');
            setenv('NDI_CLOUD_ORGANIZATION_ID', 'fake_org_id');

            isGood = ndi.cloud.testLogin('UseUILogin', false);

            testCase.verifyFalse(isGood, ...
                'testLogin should return false when the token is invalid and UseUILogin is false.');
        end

        function testTestLoginVerboseProducesOutput(testCase)
            % The Verbose option must produce step-by-step output and
            % must default to false (no output) when not requested.

            clearAllCloudEnv();
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError')); %#ok<NASGU>

            % Default (Verbose not requested) should produce no output.
            quietOutput = evalc("ndi.cloud.testLogin('UseUILogin', false);");
            testCase.verifyEmpty(strtrim(quietOutput), ...
                'testLogin should produce no output when Verbose is not specified.');

            % Verbose explicitly false should produce no output.
            quietOutput2 = evalc("ndi.cloud.testLogin('UseUILogin', false, 'Verbose', false);");
            testCase.verifyEmpty(strtrim(quietOutput2), ...
                'testLogin should produce no output when Verbose is false.');

            % Verbose true should produce step-by-step output.
            verboseOutput = evalc("ndi.cloud.testLogin('UseUILogin', false, 'Verbose', true);");
            testCase.verifyNotEmpty(strtrim(verboseOutput), ...
                'testLogin should produce output when Verbose is true.');
            testCase.verifyTrue(contains(verboseOutput, '[testLogin]'), ...
                'Verbose output should be tagged with [testLogin].');
            testCase.verifyTrue(contains(verboseOutput, 'Attempt 1'), ...
                'Verbose output should describe the first attempt.');
        end

        function testTestLoginAfterLoginReturnsTrue(testCase)
            % After a real successful login, testLogin must return true.
            % We clear NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD before
            % calling testLogin so that the silent re-auth path is not
            % exercised here; we only want to verify that the existing
            % token (just obtained) is accepted by Attempt 1.

            narrative = "Begin AuthTest: testTestLoginAfterLoginReturnsTrue";
            narrative(end+1) = "Checking for local NDI credentials in environment variables.";
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            local_config_message = "Local NDI configuration error: NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables must be set.";
            testCase.verifyTrue(~(isempty(username) || isempty(password)), local_config_message);

            narrative(end+1) = "Logging in via ndi.cloud.api.auth.login.";
            [b_login, answer_login, apiResponse_login, apiURL_login] = ...
                ndi.cloud.api.auth.login(username, password);
            login_message = ndi.unittest.cloud.APIMessage(narrative, ...
                b_login, answer_login, apiResponse_login, apiURL_login);
            testCase.verifyTrue(b_login, login_message);

            % Populate token / org so that ndi.cloud functions see the
            % login. (auth.login only returns the token; the higher-level
            % authenticate() is what normally exports it.)
            setenv('NDI_CLOUD_TOKEN', answer_login.token);
            setenv('NDI_CLOUD_ORGANIZATION_ID', answer_login.user.organizations(1).id);

            % Clear silent re-auth credentials so we are exercising the
            % "Attempt 1 succeeds" path purely on the strength of the
            % token we just installed. (The TestMethodTeardown restores
            % USERNAME / PASSWORD afterwards.)
            setenv('NDI_CLOUD_USERNAME', '');
            setenv('NDI_CLOUD_PASSWORD', '');

            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError')); %#ok<NASGU>

            isGood = ndi.cloud.testLogin('UseUILogin', false);
            testCase.verifyTrue(isGood, ...
                'testLogin should return true after a successful login.');

            % UserName matching the token email should also succeed.
            isGoodMatch = ndi.cloud.testLogin('UseUILogin', false, 'UserName', string(username));
            testCase.verifyTrue(isGoodMatch, ...
                'testLogin should return true when UserName matches the token email.');

            % UserName not matching the token email must return false,
            % even though the token itself is valid. With env credentials
            % cleared, testLogin will not pop the UI login.
            isGoodMismatch = ndi.cloud.testLogin('UseUILogin', false, ...
                'UserName', "definitely-not-this-user@example.invalid");
            testCase.verifyFalse(isGoodMismatch, ...
                'testLogin should return false when UserName does not match the token email.');
        end

        function testTestLoginEnvCredsNeverPopUILogin(testCase)
            % When NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD are set,
            % testLogin must never fall through to the UI login --
            % even when UseUILogin is true. Here we set BOGUS env
            % credentials so the silent re-auth fails, then verify
            % that testLogin returns false without popping uilogin.
            %
            % We also pass UserName='bogus-user@example.invalid' so
            % that, on machines where the MATLAB Vault happens to hold
            % real credentials, the silent re-auth path inside
            % ndi.cloud.authenticate() will reject the vault entry on
            % the username-mismatch check and proceed to try the bogus
            % env credentials (which fail).

            bogusUser = 'bogus-user@example.invalid';

            clearAllCloudEnv();
            setenv('NDI_CLOUD_USERNAME', bogusUser);
            setenv('NDI_CLOUD_PASSWORD', 'not-a-real-password');

            % Suppress the warnings/errors that the silent login path
            % may emit when the bogus credentials are rejected.
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warning('off', 'NDI:Cloud:AuthenticationFailed');
            warningCleanup = onCleanup(@() restoreWarnings()); %#ok<NASGU>

            isGood = ndi.cloud.testLogin('UseUILogin', true, ...
                'UserName', string(bogusUser));

            testCase.verifyFalse(isGood, ...
                ['testLogin should return false when env credentials are set ', ...
                 'but invalid; it must not pop the UI login dialog.']);
        end
    end
end

function clearAllCloudEnv()
% Wipe the NDI cloud env vars so testLogin sees a known clean state.
% TestMethodTeardown restores them after the test.
    setenv('NDI_CLOUD_TOKEN', '');
    setenv('NDI_CLOUD_ORGANIZATION_ID', '');
    setenv('NDI_CLOUD_USERNAME', '');
    setenv('NDI_CLOUD_PASSWORD', '');
    setenv('CLOUD_API_ENVIRONMENT', '');
end

function restoreWarnings()
    warning('on', 'NDI:Cloud:LogoutAPIError');
    warning('on', 'NDI:Cloud:AuthenticationFailed');
end
