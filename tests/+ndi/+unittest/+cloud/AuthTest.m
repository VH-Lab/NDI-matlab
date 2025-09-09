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
    end
end


