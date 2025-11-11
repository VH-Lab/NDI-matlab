classdef FilesDifficult < matlab.unittest.TestCase
% FilesDifficult - Test suite for the ndi.cloud.api.files namespace
%
%   This test class verifies the functionality of the file-related API
%   endpoints. It follows a narrative-driven approach to provide clear,
%   actionable feedback for both MATLAB and API developers.
%
%   This is a difficult test because the binary file contains embedded
%   within it a zip file that can be difficult for the API to interpret
%   properly.
%
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_DIFFICULT_FILES_';
    end
    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
        Narrative (1,:) string % Stores the narrative for each test
        KeepDataset (1,1) logical = false % Flag to prevent teardown from deleting dataset
    end
    methods (TestClassSetup)
        function checkCredentials(testCase)
            % This fatal assertion runs once before any tests in this class.
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set. This is not an API problem.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set. This is not an API problem.');
        end
    end
    methods (TestMethodSetup)
        % This now runs BEFORE EACH test method, creating a fresh dataset.
        function setupNewDataset(testCase)
            testCase.KeepDataset = false; % Ensure flag is reset for each test
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);

            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);

            if ~b
                setup_narrative = "TestMethodSetup: Failed to create temporary dataset " + unique_name;
                msg = ndi.unittest.cloud.APIMessage(setup_narrative, b, cloudDatasetID, resp, url);
                testCase.fatalAssertTrue(b, "Failed to create dataset in TestMethodSetup. " + msg);
            end
            testCase.DatasetID = cloudDatasetID;
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
        end
    end
    methods (Access = private)
        % Private helper for teardown, called by addTeardown.
        function deleteDatasetAfterTest(testCase)
            if testCase.KeepDataset
                narrative = testCase.Narrative;
                narrative(end+1) = "TEARDOWN SKIPPED: Preserving dataset for inspection.";
                testCase.Narrative = narrative;
                return;
            end
            if ~ismissing(testCase.DatasetID)
                narrative = testCase.Narrative; % Make a local copy
                narrative(end+1) = "TEARDOWN: Deleting temporary dataset ID: " + testCase.DatasetID;
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID);
                if ~b
                    msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_del, resp_del, url_del);
                    testCase.assertTrue(b, "Failed to delete dataset in TestMethodTeardown. " + msg);
                end
            end
        end
    end
    methods (Test)
        function testBulkUploadAndDownloadDifficultFile(testCase)
            testCase.Narrative = "Begin testBulkUploadAndDownloadDifficultFile";
            narrative = testCase.Narrative;

            % Step 1: Locate the difficult file
            narrative(end+1) = "SETUP: Locating the difficult binary file for upload.";
            localFilePath = fullfile(ndi.toolboxdir,'ndi_common','example_binaries','4126945b0315ec90_c0d16626cae2dacf');
            fileUID = '4126945b0315ec90_c0d16626cae2dacf';

            try
                fid = fopen(localFilePath, 'r');
                originalContent = fread(fid, inf, '*uint8')'; % Read as uint8 and transpose
                fclose(fid);
            catch ME
                narrative(end+1) = "FAILURE: Could not read local difficult file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to read local test file. " + msg_fail);
                return;
            end

            narrative(end+1) = "Local difficult file located and read successfully.";

            % Step 2: Get bulk upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for bulk file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileCollectionUploadURL(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get bulk file upload URL. " + msg_url);
            if ~b_url, return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained bulk upload URL.";

            % Step 3: Zip and upload the file with the correct naming convention
            narrative(end+1) = "Preparing to zip and upload the files.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            uniqueString = string(did.ido.unique_id());
            zipFileName = testCase.DatasetID + "." + uniqueString + ".zip";
            zipFilePath = fullfile(tempFolder.Folder, zipFileName);
            try
                zip(zipFilePath, localFilePath);
            catch ME
                narrative(end+1) = "FAILURE: Could not create zip archive for bulk upload.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:zip');
                testCase.verifyFail("Failed to create zip archive. " + msg_fail);
                return;
            end

            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, zipFilePath);
            narrative(end+1) = "Attempted to upload zip file to " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "Bulk file upload (PUT request) failed. " + msg_put);
            if ~b_put, return; end
            narrative(end+1) = "Bulk upload successful.";

            pause(20); % Give server time to process the zip file

            % Step 3.5: Verify the file appears in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the file list is not empty and contains 1 file.";
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly 1 file. " + msg_list);
            if numel(file_list) ~= 1, return; end

            narrative(end+1) = "Testing: Verifying that UID " + fileUID + " is in the file list.";
            testCase.verifyEqual(file_list(1).uid, fileUID, "UID " + fileUID + " not found in the dataset's file list. " + msg_list);
            narrative(end+1) = "Testing: Verifying that file " + fileUID + " is marked as 'uploaded'.";
            testCase.verifyTrue(file_list(1).uploaded, "File " + fileUID + " is not marked as 'uploaded'. " + msg_list);

            narrative(end+1) = "All uploaded files appeared in the dataset's file list and are marked as uploaded.";

            % Step 4: Verify each file individually
            narrative(end+1) = "Preparing to verify the uploaded file.";

            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get details for file " + fileUID + ". " + msg_details);
            if ~b_details, return; end

            downloadURL = ans_details.downloadUrl;
            downloadedFilePath = fullfile(tempFolder.Folder, "downloaded_" + fileUID);

            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed for " + fileUID + ". " + msg_get);
            if ~b_get, return; end

            % Read file as binary and compare byte arrays to avoid encoding issues
            try
                fid = fopen(downloadedFilePath, 'r');
                retrievedContent = fread(fid, inf, '*uint8')'; % Read as uint8 and transpose
                fclose(fid);
            catch ME
                narrative(end+1) = "FAILURE: Could not read downloaded file " + fileUID + ".";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], downloadedFilePath);
                testCase.verifyFail("Failed to read downloaded file for verification. " + msg_fail);
                return;
            end

            % Use isequal for byte-to-byte comparison, which verifyEqual will do
            match = isequal(retrievedContent, originalContent);

            % For display in case of error, show truncated byte arrays
            expected_str = mat2str(originalContent, 30);
            retrieved_str = mat2str(retrievedContent, 30);

            msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                struct('FileUID', fileUID, 'Expected_bytes', expected_str, 'Retrieved_bytes', retrieved_str), ...
                resp_details, url_details);

            testCase.verifyEqual(retrievedContent, originalContent, ...
                "Binary content mismatch for file " + fileUID + ". " + msg_content);
            narrative(end+1) = "Difficult file has been verified.";

            testCase.Narrative = narrative;
        end
    end
end