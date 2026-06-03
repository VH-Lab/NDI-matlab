classdef HelloMatlabTest < matlab.unittest.TestCase
% HelloMatlabTest - MATLAB end-to-end equivalent of
% ndi-cloud-node/api/e2eScripts/compute/Matlab/test_helloMatlab.sh.
%
%   Runs the `hello-matlab-v1` pipeline via ndi.cloud.helloMatlab and
%   verifies that the verify stage reaches COMPLETED. Requires:
%       - NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD env vars
%       - The user has a registered MATLAB BYOL license matching the
%         pipeline's requiresMatlabRelease (use
%         ndi.cloud.api.users.getMatlabLicense to check, and the
%         allocateMatlabLicenseMac + setMatlabLicense pair to register).
%
%   The test is opt-in via the NDI_CLOUD_RUN_HELLO_MATLAB env var because
%   it spins up a real EC2 instance (~2-4 min, billable) and depends on
%   the BYOL setup above. It only runs when NDI_CLOUD_RUN_HELLO_MATLAB is
%   set to a truthy value ("1" or "true", case insensitive); any other
%   value (including "0", "false", or unset) is treated as opt-out and the
%   test is skipped via assumeFail with a message explaining how to enable
%   it. This way the suite does not silently drop license-verification
%   coverage but also does not break the default cloud-api run.

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: NDI_CLOUD_USERNAME is not set.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: NDI_CLOUD_PASSWORD is not set.');
        end
    end

    methods (Test)
        function testHelloMatlabFlow(testCase)
            narrative = "Begin HelloMatlabTest: testHelloMatlabFlow";

            runFlag = string(getenv("NDI_CLOUD_RUN_HELLO_MATLAB"));
            shouldRun = strcmpi(runFlag, "true") || runFlag == "1";
            if ~shouldRun
                testCase.assumeFail(...
                    "Set NDI_CLOUD_RUN_HELLO_MATLAB=1 to run the hello-matlab-v1 " + ...
                    "end-to-end test (it launches a real EC2 instance and requires " + ...
                    "a registered MATLAB BYOL license). Current value: """ + runFlag + """.");
            end

            % --- 1. Sanity-check that a license is registered before we
            %        spin up the pipeline. The server will reject the
            %        start call with MATLAB_LICENSE_REQUIRED otherwise,
            %        but failing here gives a clearer diagnostic.
            narrative(end+1) = "Calling ndi.cloud.api.users.getMatlabLicense to verify a registration exists.";
            [b_lic, answer_lic, apiResponse_lic, apiURL_lic] = ndi.cloud.api.users.getMatlabLicense();
            lic_message = ndi.unittest.cloud.APIMessage(narrative, b_lic, answer_lic, apiResponse_lic, apiURL_lic);
            testCase.verifyTrue(b_lic, lic_message);
            if b_lic
                hasFiles = isstruct(answer_lic) && isfield(answer_lic, 'files') && ~isempty(answer_lic.files);
                testCase.verifyTrue(hasFiles, ...
                    "No MATLAB license is registered for this user. Register one with " + ...
                    "ndi.cloud.api.users.allocateMatlabLicenseMac + setMatlabLicense " + ...
                    "before running this test. " + lic_message);
            end

            % --- 2. Run the hello-matlab-v1 pipeline end-to-end.
            narrative(end+1) = "Calling ndi.cloud.helloMatlab to start hello-matlab-v1 and poll until terminal.";
            [success, sessionId, statusMessage, sessionDoc] = ndi.cloud.helloMatlab(...
                'TimeoutSeconds', 1200, 'PollIntervalSeconds', 15, 'Verbose', true);

            narrative(end+1) = "helloMatlab completed. session=" + sessionId + ...
                " success=" + string(success) + " message=" + statusMessage;

            flow_message = jsonencode(struct(...
                'TestNarrative', narrative, ...
                'sessionId', sessionId, ...
                'success', success, ...
                'statusMessage', statusMessage, ...
                'sessionDoc', sessionDoc), "PrettyPrint", true);

            testCase.verifyTrue(success, flow_message);
        end
    end
end
