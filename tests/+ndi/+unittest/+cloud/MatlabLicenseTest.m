classdef MatlabLicenseTest < matlab.unittest.TestCase
% MatlabLicenseTest - Test MATLAB BYOL license endpoints.
%
%   Requires the following environment variables:
%       - NDI_CLOUD_USERNAME, NDI_CLOUD_PASSWORD
%       - NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE - Must be explicitly set to
%         "true" or "false" (case insensitive; "1"/"0" also accepted).
%         Leaving this variable unset (empty) is a fatal configuration error
%         so that an accidental omission can never silently destroy an
%         existing license.
%
%   NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE values:
%       "true"  / "1" - The test user already has a registered MATLAB
%                       license that must be preserved. Destructive tests
%                       (allocate-then-clear lifecycle, invalid-file PUT)
%                       are skipped via assumeFail; only the read-only
%                       getMatlabLicense check runs.
%       "false" / "0" - The test user is assumed to start with no
%                       registration. The lifecycle test allocates a
%                       dedicated MAC, exercises GET/PUT/DELETE against it,
%                       and tears down by calling clearMatlabLicense so a
%                       mid-test failure does not strand an AWS ENI.

    properties (Access = private)
        UserHasExistingLicense (1,1) logical = false
        ClearOnTeardown (1,1) logical = false
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: NDI_CLOUD_USERNAME is not set.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: NDI_CLOUD_PASSWORD is not set.');

            flag = string(getenv("NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE"));
            testCase.fatalAssertNotEmpty(char(flag), ...
                "LOCAL CONFIGURATION ERROR: NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE is not set. " + ...
                "Set it to ""true"" if the test account already has a MATLAB license " + ...
                "(destructive tests will be skipped), or ""false"" if it does not " + ...
                "(destructive tests will run).");
            testCase.UserHasExistingLicense = strcmpi(flag, "true") || flag == "1";
        end
    end

    methods (TestMethodTeardown)
        function maybeClear(testCase)
            % Only clean up when WE allocated the registration during the
            % test. Never touch a registration the user brought in.
            if testCase.ClearOnTeardown
                try
                    ndi.cloud.api.users.clearMatlabLicense();
                catch
                    % Best-effort; the test itself will report failure.
                end
                testCase.ClearOnTeardown = false;
            end
        end
    end

    methods (Test)
        function testGetMatlabLicense(testCase)
            % Read-only check that runs in both modes.
            narrative = "Begin MatlabLicenseTest: testGetMatlabLicense";

            narrative(end+1) = "Calling ndi.cloud.api.users.getMatlabLicense.";
            [b, answer, apiResponse, apiURL] = ndi.cloud.api.users.getMatlabLicense();
            msg = ndi.unittest.cloud.APIMessage(narrative, b, answer, apiResponse, apiURL);
            testCase.verifyTrue(b, msg);

            if testCase.UserHasExistingLicense
                % NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE=true asserts a
                % registration exists; reflect that in the assertion.
                testCase.verifyTrue(isstruct(answer) && isfield(answer, 'files') ...
                    && ~isempty(answer.files), ...
                    "NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE=true but the user has no " + ...
                    "registered files. " + msg);
            else
                % No registration expected: server returns 200 with mode
                % null/missing and an empty files array.
                hasFiles = isstruct(answer) && isfield(answer, 'files') ...
                    && ~isempty(answer.files);
                testCase.verifyFalse(hasFiles, ...
                    "Expected an empty registration but the test user already has " + ...
                    "MATLAB license files registered. Set NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE=true " + ...
                    "to preserve them. " + msg);
            end
        end

        function testAllocateAndClearLifecycle(testCase)
            % POST -> GET -> DELETE -> GET. Skipped when the user already
            % has a license (DELETE would destroy it; allocate is itself
            % idempotent but verifying the post-state would be ambiguous).
            if testCase.UserHasExistingLicense
                testCase.assumeFail(...
                    "Skipped: NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE=true. " + ...
                    "The allocate/clear lifecycle would mutate an existing " + ...
                    "registration we are required to preserve.");
            end

            narrative = "Begin MatlabLicenseTest: testAllocateAndClearLifecycle";

            % --- allocate
            narrative(end+1) = "Calling ndi.cloud.api.users.allocateMatlabLicenseMac.";
            [b_alloc, answer_alloc, apiResponse_alloc, apiURL_alloc] = ...
                ndi.cloud.api.users.allocateMatlabLicenseMac();
            alloc_msg = ndi.unittest.cloud.APIMessage(narrative, b_alloc, answer_alloc, apiResponse_alloc, apiURL_alloc);
            testCase.verifyTrue(b_alloc, alloc_msg);

            % From here on a failure must trigger teardown so we don't
            % strand an ENI.
            testCase.ClearOnTeardown = true;

            testCase.verifyTrue(isstruct(answer_alloc) && isfield(answer_alloc, 'macAddress') ...
                && ~isempty(answer_alloc.macAddress), ...
                "Allocate response did not include a macAddress. " + alloc_msg);

            % --- get reflects allocation
            narrative(end+1) = "Calling ndi.cloud.api.users.getMatlabLicense to confirm allocation.";
            [b_get1, answer_get1, apiResponse_get1, apiURL_get1] = ndi.cloud.api.users.getMatlabLicense();
            get1_msg = ndi.unittest.cloud.APIMessage(narrative, b_get1, answer_get1, apiResponse_get1, apiURL_get1);
            testCase.verifyTrue(b_get1, get1_msg);
            if b_get1 && isstruct(answer_get1)
                if isfield(answer_get1, 'mode')
                    testCase.verifyEqual(string(answer_get1.mode), "dedicated", get1_msg);
                end
                if isfield(answer_get1, 'macAddress') && isfield(answer_alloc, 'macAddress')
                    testCase.verifyEqual(string(answer_get1.macAddress), ...
                        string(answer_alloc.macAddress), get1_msg);
                end
            end

            % --- clear (full removal; releases the ENI)
            narrative(end+1) = "Calling ndi.cloud.api.users.clearMatlabLicense.";
            [b_clear, answer_clear, apiResponse_clear, apiURL_clear] = ndi.cloud.api.users.clearMatlabLicense();
            clear_msg = ndi.unittest.cloud.APIMessage(narrative, b_clear, answer_clear, apiResponse_clear, apiURL_clear);
            testCase.verifyTrue(b_clear, clear_msg);

            % We just succeeded at clearing; the teardown clear is now redundant.
            testCase.ClearOnTeardown = false;

            % --- get reflects empty
            narrative(end+1) = "Calling ndi.cloud.api.users.getMatlabLicense to confirm empty.";
            [b_get2, answer_get2, apiResponse_get2, apiURL_get2] = ndi.cloud.api.users.getMatlabLicense();
            get2_msg = ndi.unittest.cloud.APIMessage(narrative, b_get2, answer_get2, apiResponse_get2, apiURL_get2);
            testCase.verifyTrue(b_get2, get2_msg);
            if b_get2 && isstruct(answer_get2)
                hasFiles = isfield(answer_get2, 'files') && ~isempty(answer_get2.files);
                testCase.verifyFalse(hasFiles, ...
                    "Files array should be empty after clearMatlabLicense. " + get2_msg);
            end
        end

        function testSetMatlabLicenseRejectsInvalidFile(testCase)
            % Negative test: PUT with a clearly-invalid lic body should
            % return 400. Exercises the setMatlabLicense wrapper end-to-end
            % without needing a real license, and never lands a valid
            % file on the server. Skipped when the user has a real
            % registration we must not disturb.
            if testCase.UserHasExistingLicense
                testCase.assumeFail(...
                    "Skipped: NDI_CLOUD_TEST_USER_HAS_MATLAB_LICENSE=true. " + ...
                    "Even a 400-rejected PUT could disturb the existing " + ...
                    "registration if the server changes its semantics.");
            end

            narrative = "Begin MatlabLicenseTest: testSetMatlabLicenseRejectsInvalidFile";

            % We need an allocated MAC for dedicated PUT to be evaluated
            % at all (the API rejects dedicated PUTs that arrive without
            % prior allocation, which would also pass this test, but we
            % want to verify the *file* is what gets rejected, not the
            % missing allocation).
            narrative(end+1) = "Allocating a MAC so the PUT exercises file validation.";
            [b_alloc, answer_alloc, apiResponse_alloc, apiURL_alloc] = ...
                ndi.cloud.api.users.allocateMatlabLicenseMac();
            alloc_msg = ndi.unittest.cloud.APIMessage(narrative, b_alloc, answer_alloc, apiResponse_alloc, apiURL_alloc);
            testCase.fatalAssertTrue(b_alloc, alloc_msg);
            testCase.ClearOnTeardown = true;

            narrative(end+1) = "Calling ndi.cloud.api.users.setMatlabLicense with a bogus dedicated file.";
            bogusFile = "this is not a real MATLAB license file";
            [b_set, answer_set, apiResponse_set, apiURL_set] = ndi.cloud.api.users.setMatlabLicense(...
                bogusFile, 'mode', "dedicated", 'release', "R2024b");
            set_msg = ndi.unittest.cloud.APIMessage(narrative, b_set, answer_set, apiResponse_set, apiURL_set);

            testCase.verifyFalse(b_set, ...
                "setMatlabLicense should fail for an invalid lic file. " + set_msg);
            if isa(apiResponse_set, 'matlab.net.http.ResponseMessage') && ~isempty(apiResponse_set)
                testCase.verifyEqual(double(apiResponse_set.StatusCode), 400, ...
                    "Expected HTTP 400 (invalid file); got " + ...
                    string(apiResponse_set.StatusCode) + ". " + set_msg);
            end
        end
    end
end
