classdef UserTest < matlab.unittest.TestCase
% UserTest - Test users/ api endpoints

    % Requirements for test:
    %   - The following environment variables must be set
    %       - NDI_CLOUD_USERNAME
    %       - NDI_CLOUD_PASSWORD

    methods (Test)
        function testMe(testCase)
            narrative = "Begin UserTest: testMe";

            % Step 1: Check local configuration
            narrative(end+1) = "Checking for local NDI credentials in environment variables.";
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            local_config_message = "Local NDI configuration error: NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment variables must be set.";
            testCase.verifyTrue(~(isempty(username) || isempty(password)), local_config_message);

            narrative(end+1) = "Local credentials found.";

            % Step 2: Ensure we are logged in (or log in)
            narrative(end+1) = "Preparing to call ndi.cloud.api.auth.login.";
            [b_login, answer_login, apiResponse_login, apiURL_login] = ndi.cloud.api.auth.login(username, password);
            login_message = ndi.unittest.cloud.APIMessage(narrative, b_login, answer_login, apiResponse_login, apiURL_login);
            testCase.verifyTrue(b_login, login_message);
            narrative(end+1) = "Login successful (or already logged in).";

            % Step 3: Test me endpoint
            narrative(end+1) = "Preparing to call ndi.cloud.api.users.me.";
            [b_me, answer_me, apiResponse_me, apiURL_me] = ndi.cloud.api.users.me();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_me);

            narrative(end+1) = "Testing: Verifying the me API call was successful (APICallSuccessFlag should be true).";
            me_message = ndi.unittest.cloud.APIMessage(narrative, b_me, answer_me, apiResponse_me, apiURL_me);
            testCase.verifyTrue(b_me, me_message);

            if b_me
                narrative(end+1) = "Me call successful. Verifying response fields.";

                % Verify id is char
                testCase.verifyTrue(isfield(answer_me, 'id'), me_message);
                if isfield(answer_me, 'id')
                    testCase.verifyClass(answer_me.id, 'char', me_message);
                end

                % Verify organizationID is cell array of chars
                testCase.verifyTrue(isfield(answer_me, 'organizationID'), me_message);
                if isfield(answer_me, 'organizationID')
                    testCase.verifyClass(answer_me.organizationID, 'cell', me_message);
                    if ~isempty(answer_me.organizationID)
                        for i = 1:numel(answer_me.organizationID)
                             testCase.verifyClass(answer_me.organizationID{i}, 'char', me_message);
                        end
                    end
                end

                % Verify other fields exist as per new spec
                 testCase.verifyTrue(isfield(answer_me, 'email'), me_message);
                 testCase.verifyTrue(isfield(answer_me, 'name'), me_message);
                 testCase.verifyTrue(isfield(answer_me, 'organizations'), me_message);
            end

            narrative(end+1) = "UserTest: testMe complete.";
        end
    end
end
