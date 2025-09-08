classdef AuthTest < matlab.unittest.TestCase
% AuthTest - Test auth/ api endpoints 

    % Requirements for test:
    %   - The following environment variables must be set
    %       - NDI_CLOUD_USERNAME
    %       - NDI_CLOUD_PASSWORD
    
    methods (Test)
        function testLoginLogout(testCase)
            % Initialize a narrative to track test steps for clear reporting
            narrative = strings(0,1);
            narrative(end+1) = "Begin AuthTest: testLoginLogout";

            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:http:BodyExpectedFor'))
        
            % --- 1. Check for local configuration ---
            narrative(end+1) = "Checking for local credentials in environment variables.";
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            % Use a fatal assertion to stop the test immediately if credentials are not set.
            % The error message clearly indicates a local setup issue.
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set. This is not an API problem.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set. This is not an API problem.');
            
            narrative(end+1) = "Local credentials found.";

            % --- 2. Test Login ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.auth.login.";
            [b_login, answer_login, apiResponse_login, apiURL_login] = ndi.cloud.api.auth.login(username, password);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_login);
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";
            
            % Generate a detailed message for the verification step
            login_message = ndi.unittest.cloud.APIMessage(b_login, answer_login, apiResponse_login, apiURL_login, narrative);
            testCase.verifyTrue(b_login, login_message);
            
            narrative(end+1) = "Login successful. Token and Organization ID received.";

            % --- 3. Test Logout ---
            narrative(end+1) = "Preparing to call ndi.cloud.api.auth.logout.";
            [b_logout, answer_logout, apiResponse_logout, apiURL_logout] = ndi.cloud.api.auth.logout();
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_logout);
            narrative(end+1) = "Testing: Verifying the API call was successful (APICallSuccessFlag should be true).";

            % Generate a detailed message for the logout verification
            logout_message = ndi.unittest.cloud.APIMessage(b_logout, answer_logout, apiResponse_logout, apiURL_logout, narrative);
            testCase.verifyTrue(b_logout, logout_message);

            narrative(end+1) = "Logout successful.";
        end        
    end
end




