classdef AuthTest < matlab.unittest.TestCase
% AuthTest - Test auth/ api endpoints 

    % Requirements for test:
    %   - The following environment variables must be set
    %       - NDI_CLOUD_USERNAME
    %       - NDI_CLOUD_PASSWORD
    
    methods (Test)
        function testLoginLogout(testCase)

            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:http:BodyExpectedFor'))
        
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            [auth_token, organization_id] = ndi.cloud.api.auth.login(username, password);
            testCase.verifyClass(auth_token, 'char')
            testCase.verifyClass(organization_id, 'char')

            output = ndi.cloud.api.auth.logout();
            testCase.verifyEqual(output.StatusCode, matlab.net.http.StatusCode.OK)
        end        
    end
end
