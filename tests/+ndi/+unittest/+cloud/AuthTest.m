classdef AuthTest < matlab.unittest.TestCase
% AuthTest - Test auth/ api endpoints 

    % Requirements for test:
    %   - The following environment variables must be set
    %       - NDI_CLOUD_USERNAME
    %       - NDI_CLOUD_PASSWORD
    
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
            % currently valid login token in this process. This exercises
            % the contract that the function reports "do we currently
            % have a valid login token?" rather than "if we have a token,
            % is it valid?".

            cleanup = saveAndClearCloudEnv(); %#ok<NASGU>
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError'));

            isGood = ndi.cloud.testLogin('UseUILogin', false);

            testCase.verifyFalse(isGood, ...
                'testLogin should return false when no token is present and UseUILogin is false.');
        end

        function testTestLoginWithFakeTokenReturnsFalse(testCase)
            % A non-empty but invalid token must not be accepted: the
            % server-side listDatasets() probe will fail, and probe()
            % must return false. Even if that path falls through to the
            % silent-reauth retry, the absence of NDI_CLOUD_USERNAME /
            % NDI_CLOUD_PASSWORD here keeps testLogin from succeeding.

            cleanup = saveAndClearCloudEnv(); %#ok<NASGU>
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError'));

            setenv('NDI_CLOUD_TOKEN', 'not.a.real.jwt');
            setenv('NDI_CLOUD_ORGANIZATION_ID', 'fake_org_id');

            isGood = ndi.cloud.testLogin('UseUILogin', false);

            testCase.verifyFalse(isGood, ...
                'testLogin should return false when the token is invalid and UseUILogin is false.');
        end

        function testTestLoginVerboseProducesOutput(testCase)
            % The Verbose option must produce step-by-step output and
            % must default to false (no output) when not requested.

            cleanup = saveAndClearCloudEnv(); %#ok<NASGU>
            warning('off', 'NDI:Cloud:LogoutAPIError');
            warningCleanup = onCleanup(@() warning('on', 'NDI:Cloud:LogoutAPIError'));

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
            % even though the token itself is valid.
            isGoodMismatch = ndi.cloud.testLogin('UseUILogin', false, ...
                'UserName', "definitely-not-this-user@example.invalid");
            testCase.verifyFalse(isGoodMismatch, ...
                'testLogin should return false when UserName does not match the token email.');
        end
    end
end

function cleanup = saveAndClearCloudEnv()
% Save and clear all NDI cloud env vars that affect login state, then
% restore them on cleanup. Used to put testLogin into a known
% "no-credentials" state for tests that exercise the failure paths.
    names = {'NDI_CLOUD_TOKEN', 'NDI_CLOUD_ORGANIZATION_ID', ...
             'NDI_CLOUD_USERNAME', 'NDI_CLOUD_PASSWORD'};
    saved = cell(1, numel(names));
    for k = 1:numel(names)
        saved{k} = getenv(names{k});
        setenv(names{k}, '');
    end
    cleanup = onCleanup(@() restoreEnv(names, saved));
end

function restoreEnv(names, saved)
    for k = 1:numel(names)
        setenv(names{k}, saved{k});
    end
end
