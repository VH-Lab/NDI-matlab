classdef FilesTest < matlab.unittest.TestCase
% FilesTest - Test suite for the ndi.cloud.api.files namespace
%
%   This test class verifies the functionality of the file-related API
%   endpoints. It follows a narrative-driven approach to provide clear,
%   actionable feedback for both MATLAB and API developers.
%
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_FILES_';
        TestFileContent = 'This is a test file for NDI Cloud API testing.';
        runFileFieldTest = false;
    end
    properties
        RunTestSingleFileUploadAndDownloadUseMatlabNotCurl (1,1) logical = false
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
        function testSingleFileUploadAndDownloadUseCurl(testCase)
            testCase.Narrative = "Begin testSingleFileUploadAndDownloadUseCurl";
            narrative = testCase.Narrative;
            % Step 1: Create a local test file with a UID as its name
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID); % Filename is the UID
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return; % Stop the test if file creation fails
            end
            % Step 2: Get a pre-signed upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for single file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get file upload URL. " + msg_url);
            if ~b_url, return; end
            testCase.verifyNotEmpty(ans_url, "Upload URL was empty. " + msg_url);
            if isempty(ans_url), return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained upload URL.";
            % Step 3: Upload the file using the URL
            narrative(end+1) = "Preparing to upload the file using the pre-signed URL (useCurl is true).";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, localFilePath, "useCurl",true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "File upload (PUT request) failed. " + msg_put);
            if ~b_put, return; end
            narrative(end+1) = "File uploaded successfully.";
            pause(10); % Give server time to process the file
            % Step 3.5: Verify the file appears in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the file list is not empty and contains 1 file.";
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_list);
            narrative(end+1) = "File successfully appeared in the dataset's file list.";
            % Step 4: Get file details to verify upload and get download URL
            narrative(end+1) = "Preparing to get file details to verify upload.";
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_details);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details, return; end
            testCase.verifyEqual(ans_details.uid, char(fileUID), "Returned file details have incorrect UID. " + msg_details);
            downloadURL = ans_details.downloadUrl;
            narrative(end+1) = "Successfully retrieved file details. Download URL obtained.";
            % Step 5: Download the file and verify its content
            narrative(end+1) = "Preparing to download the file to verify its content (useCurl is true).";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            narrative(end+1) = "Attempted to download file from URL " + string(url_get);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end
            narrative(end+1) = "File downloaded successfully.";
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            match = strcmp(retrievedContent, testCase.TestFileContent);
            msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                struct('Expected', testCase.TestFileContent, 'Retrieved', retrievedContent), ...
                resp_details, url_details);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content. " + msg_content);
            narrative(end+1) = "File content verified successfully.";
            testCase.Narrative = narrative;
        end
        function testSingleFileUploadAndDownloadUseMatlabNotCurl(testCase)
            if ~testCase.RunTestSingleFileUploadAndDownloadUseMatlabNotCurl
                return;
            end
            testCase.Narrative = "Begin testSingleFileUploadAndDownloadUseMatlabNotCurl";
            narrative = testCase.Narrative;
            % Step 1: Create a local test file with a UID as its name
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID); % Filename is the UID
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return; % Stop the test if file creation fails
            end
            % Step 2: Get a pre-signed upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for single file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get file upload URL. " + msg_url);
            if ~b_url, return; end
            testCase.verifyNotEmpty(ans_url, "Upload URL was empty. " + msg_url);
            if isempty(ans_url), return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained upload URL.";
            % Step 3: Upload the file using the URL
            narrative(end+1) = "Preparing to upload the file using the pre-signed URL (useCurl is false).";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, localFilePath);
            narrative(end+1) = "Attempted to call API with URL " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "File upload (PUT request) failed. " + msg_put);
            if ~b_put, return; end
            narrative(end+1) = "File uploaded successfully.";
            pause(10); % Give server time to process the file
            % Step 3.5: Verify the file appears in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the file list is not empty and contains 1 file.";
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_list);
            narrative(end+1) = "File successfully appeared in the dataset's file list.";
            % Step 4: Get file details to verify upload and get download URL
            narrative(end+1) = "Preparing to get file details to verify upload.";
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_details);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details, return; end
            testCase.verifyEqual(ans_details.uid, char(fileUID), "Returned file details have incorrect UID. " + msg_details);
            downloadURL = ans_details.downloadUrl;
            narrative(end+1) = "Successfully retrieved file details. Download URL obtained.";
            % Step 5: Download the file and verify its content
            narrative(end+1) = "Preparing to download the file to verify its content (useCurl is false).";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath);
            narrative(end+1) = "Attempted to download file from URL " + string(url_get);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end
            narrative(end+1) = "File downloaded successfully.";
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            match = strcmp(retrievedContent, testCase.TestFileContent);
            msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                struct('Expected', testCase.TestFileContent, 'Retrieved', retrievedContent), ...
                resp_details, url_details);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content. " + msg_content);
            narrative(end+1) = "File content verified successfully.";
            testCase.Narrative = narrative;
        end
        function testSingleFileUploadAndDownloadUseCurlStop(testCase)
            testCase.Narrative = "Begin testSingleFileUploadAndDownloadUseCurlStop";
            narrative = testCase.Narrative;
            % Step 1: Create a local test file with a UID as its name
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID); % Filename is the UID
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return; % Stop the test if file creation fails
            end
            % Step 2: Get a pre-signed upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for single file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get file upload URL. " + msg_url);
            if ~b_url, return; end
            testCase.verifyNotEmpty(ans_url, "Upload URL was empty. " + msg_url);
            if isempty(ans_url), return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained upload URL.";
            % Step 3: Upload the file using the URL
            narrative(end+1) = "Preparing to upload the file using the pre-signed URL (useCurl is true).";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, localFilePath, "useCurl",true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "File upload (PUT request) failed. " + msg_put);
            if ~b_put, return; end
            narrative(end+1) = "File uploaded successfully.";
            pause(10); % Give server time to process the file
            % Step 3.5: Verify the file appears in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the file list is not empty and contains 1 file.";
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_list);
            narrative(end+1) = "File successfully appeared in the dataset's file list.";
            % Step 4: Get file details to verify upload and get download URL
            narrative(end+1) = "Preparing to get file details to verify upload.";
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_details);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details
                narrative(end+1) = "FAILURE: Stopping test to preserve dataset for inspection.";
                testCase.Narrative = narrative;
                testCase.KeepDataset = true;
                testCase.assertFail('Stopping test to inspect dataset state after file detail failure.');
                return;
            end
            testCase.verifyEqual(ans_details.uid, char(fileUID), "Returned file details have incorrect UID. " + msg_details);
            downloadURL = ans_details.downloadUrl;
            narrative(end+1) = "Successfully retrieved file details. Download URL obtained.";
            % Step 5: Download the file and verify its content
            narrative(end+1) = "Preparing to download the file to verify its content (useCurl is true).";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            narrative(end+1) = "Attempted to download file from URL " + string(url_get);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end
            narrative(end+1) = "File downloaded successfully.";
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            match = strcmp(retrievedContent, testCase.TestFileContent);
            msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                struct('Expected', testCase.TestFileContent, 'Retrieved', retrievedContent), ...
                resp_details, url_details);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content. " + msg_content);
            narrative(end+1) = "File content verified successfully.";
            testCase.Narrative = narrative;
        end
        function testSingleFileUploadAndDownloadUseCurlFileFieldTest(testCase)
            if ~testCase.runFileFieldTest
                return;
            end
            testCase.Narrative = "Begin testSingleFileUploadAndDownloadUseCurlFileFieldTest";
            narrative = testCase.Narrative;
            % Step 1: Create a local test file with a UID as its name
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID); % Filename is the UID
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return; % Stop the test if file creation fails
            end
            % Step 2: Get a pre-signed upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for single file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get file upload URL. " + msg_url);
            if ~b_url, return; end
            testCase.verifyNotEmpty(ans_url, "Upload URL was empty. " + msg_url);
            if isempty(ans_url), return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained upload URL.";
            % Step 2.5: Verify the file does not yet appear in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list to ensure it is empty.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the dataset's file list is empty.";
            testCase.verifyEmpty(file_list, "Dataset file list should be empty before upload. " + msg_list);
            narrative(end+1) = "File list is correctly empty before upload.";
            % Step 3: Upload the file using the URL
            narrative(end+1) = "Preparing to upload the file using the pre-signed URL (useCurl is true).";
            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, localFilePath, "useCurl",true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_put);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.verifyTrue(b_put, "File upload (PUT request) failed. " + msg_put);
            if ~b_put, return; end
            narrative(end+1) = "File uploaded successfully.";
            pause(10); % Give server time to process the file
            % Step 3.5: Verify the file appears in the dataset's file list
            narrative(end+1) = "Preparing to check dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            narrative(end+1) = "Testing: Verifying that listFiles call was successful.";
            testCase.verifyTrue(b_list, "Failed to list files to check file list. " + msg_list);
            if ~b_list, return; end
            narrative(end+1) = "Testing: Verifying that the file list is not empty and contains 1 file.";
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_list);
            narrative(end+1) = "File successfully appeared in the dataset's file list.";
            % Step 4: Get file details to verify upload and get download URL
            narrative(end+1) = "Preparing to get file details to verify upload.";
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_details);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details, return; end
            testCase.verifyEqual(ans_details.uid, char(fileUID), "Returned file details have incorrect UID. " + msg_details);
            downloadURL = ans_details.downloadUrl;
            narrative(end+1) = "Successfully retrieved file details. Download URL obtained.";
            % Step 5: Download the file and verify its content
            narrative(end+1) = "Preparing to download the file to verify its content (useCurl is true).";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            narrative(end+1) = "Attempted to download file from URL " + string(url_get);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end
            narrative(end+1) = "File downloaded successfully.";
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            match = strcmp(retrievedContent, testCase.TestFileContent);
            msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                struct('Expected', testCase.TestFileContent, 'Retrieved', retrievedContent), ...
                resp_details, url_details);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content. " + msg_content);
            narrative(end+1) = "File content verified successfully.";
            testCase.Narrative = narrative;
        end
        function testBulkFileUploadAndDownload(testCase)
            testCase.Narrative = "Begin testBulkFileUploadAndDownload";
            narrative = testCase.Narrative;
            
            numFiles = 5;
            
            % Step 1: Create local files for upload
            narrative(end+1) = "SETUP: Creating " + numFiles + " local temporary files for bulk upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            localFilePaths = strings(1, numFiles);
            fileUIDs = strings(1, numFiles);
            fileContents = cell(1, numFiles);
            
            for i = 1:numFiles
                fileUIDs(i) = string(did.ido.unique_id());
                localFilePaths(i) = fullfile(tempFolder.Folder, fileUIDs(i));
                fileContents{i} = uint8(randi([0 255], 1, 100)); % Random byte content
                try
                    fid = fopen(localFilePaths(i), 'w');
                    fwrite(fid, fileContents{i}, 'uint8');
                    fclose(fid);
                catch ME
                    narrative(end+1) = "FAILURE: Could not create local test file #" + i + " during test setup.";
                    msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                    testCase.verifyFail("Failed to create local test file. " + msg_fail);
                    return;
                end
            end
            narrative(end+1) = "Local files created successfully.";
            
            % Step 2: Get bulk upload URL
            narrative(end+1) = "Preparing to get a pre-signed URL for bulk file upload.";
            [b_url, ans_url, resp_url, url_url] = ndi.cloud.api.files.getFileCollectionUploadURL(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_url);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, ans_url, resp_url, url_url);
            testCase.verifyTrue(b_url, "Failed to get bulk file upload URL. " + msg_url);
            if ~b_url, return; end
            uploadURL = ans_url;
            narrative(end+1) = "Successfully obtained bulk upload URL.";
            
            % Step 3: Zip and upload the files with the correct naming convention
            narrative(end+1) = "Preparing to zip and upload the files.";
            uniqueString = string(did.ido.unique_id());
            zipFileName = testCase.DatasetID + "." + uniqueString + ".zip";
            zipFilePath = fullfile(tempFolder.Folder, zipFileName);
            try
                zip(zipFilePath, localFilePaths);
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
            
            pause(10); % Give server time to process the zip file
            
            % Step 4: Verify each file individually
            narrative(end+1) = "Preparing to verify each uploaded file individually.";
            for i=1:numFiles
                fileUID = fileUIDs(i);
                narrative(end+1) = "  Verifying file with UID: " + fileUID;
                
                [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
                msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
                testCase.verifyTrue(b_details, "Failed to get details for file " + fileUID + ". " + msg_details);
                if ~b_details, continue; end % Continue to next file if this one failed
                
                downloadURL = ans_details.downloadUrl;
                downloadedFilePath = fullfile(tempFolder.Folder, "downloaded_" + fileUID);

                [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
                msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
                testCase.verifyTrue(b_get, "File download failed for " + fileUID + ". " + msg_get);
                if ~b_get, continue; end

                % Read file as binary and compare byte arrays to avoid encoding issues
                try
                    fid = fopen(downloadedFilePath, 'r');
                    retrievedContent = fread(fid, inf, '*uint8')'; % Read as uint8 and transpose
                    fclose(fid);
                catch ME
                    narrative(end+1) = "FAILURE: Could not read downloaded file " + fileUID + ".";
                    msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], downloadedFilePath);
                    testCase.verifyFail("Failed to read downloaded file for verification. " + msg_fail);
                    continue;
                end

                expectedContent = fileContents{i};
                
                % Use isequal for byte-to-byte comparison, which verifyEqual will do
                match = isequal(retrievedContent, expectedContent);

                % For display in case of error, show truncated byte arrays
                expected_str = mat2str(expectedContent, 30);
                retrieved_str = mat2str(retrievedContent, 30);

                msg_content = ndi.unittest.cloud.APIMessage(narrative, match, ...
                    struct('FileUID', fileUID, 'Expected_bytes', expected_str, 'Retrieved_bytes', retrieved_str), ...
                    resp_details, url_details);

                testCase.verifyEqual(retrievedContent, expectedContent, ...
                    "Binary content mismatch for file " + fileUID + ". " + msg_content);
            end
            narrative(end+1) = "All bulk-uploaded files have been individually verified.";
            
            testCase.Narrative = narrative;
        end

        function testListFilesWithOptions(testCase)
            testCase.Narrative = "Begin testListFilesWithOptions";
            narrative = testCase.Narrative;

            % Step 1: Create and upload a file
            narrative(end+1) = "SETUP: Creating and uploading a file.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID);
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
            catch ME
                testCase.verifyFail("Failed to create local test file. " + ME.message);
                return;
            end

            [b_url, ans_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUID);
            testCase.verifyTrue(b_url, "Failed to get upload URL.");
            if ~b_url, return; end

            [b_put] = ndi.cloud.api.files.putFiles(ans_url, localFilePath, "useCurl", true);
            testCase.verifyTrue(b_put, "Failed to upload file.");
            if ~b_put, return; end

            narrative(end+1) = "File uploaded successfully.";

            pause(10); % Give server time to process

            % Step 2: Call listFiles with checkForUpdates enabled
            narrative(end+1) = "Calling listFiles with checkForUpdates=true.";
            [b_list_true, file_list_true, resp_list_true, url_list_true] = ndi.cloud.api.files.listFiles(testCase.DatasetID, ...
                'checkForUpdates', true, 'waitForUpdates', 1, 'maximumNumberUpdateReads', 2);

            msg_list_true = ndi.unittest.cloud.APIMessage(narrative, b_list_true, file_list_true, resp_list_true, url_list_true);
            testCase.verifyTrue(b_list_true, "listFiles with updates enabled failed. " + msg_list_true);
            testCase.verifyNumElements(file_list_true, 1, "Expected to find 1 file with update check enabled. " + msg_list_true);
            testCase.verifyEqual(file_list_true(1).uid, char(fileUID), "Incorrect UID with update check enabled. " + msg_list_true);
            narrative(end+1) = "Successfully listed 1 file with update check enabled.";

            % Step 3: Call listFiles with checkForUpdates disabled
            narrative(end+1) = "Calling listFiles with checkForUpdates=false.";
            [b_list_false, file_list_false, resp_list_false, url_list_false] = ndi.cloud.api.files.listFiles(testCase.DatasetID, ...
                'checkForUpdates', false);

            msg_list_false = ndi.unittest.cloud.APIMessage(narrative, b_list_false, file_list_false, resp_list_false, url_list_false);
            testCase.verifyTrue(b_list_false, "listFiles with updates disabled failed. " + msg_list_false);
            testCase.verifyNumElements(file_list_false, 1, "Expected to find 1 file with update check disabled. " + msg_list_false);
            testCase.verifyEqual(file_list_false(1).uid, char(fileUID), "Incorrect UID with update check disabled. " + msg_list_false);
            narrative(end+1) = "Successfully listed 1 file with update check disabled.";

            testCase.Narrative = narrative;
        end
    end
end