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
                testCase.verifyFail("Failed to create local test file: " + ME.message);
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
            [b_get_dset, ans_get_dset, resp_get_dset, url_get_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get_dset);
            msg_get_dset = ndi.unittest.cloud.APIMessage(narrative, b_get_dset, ans_get_dset, resp_get_dset, url_get_dset);
            narrative(end+1) = "Testing: Verifying that getDataset call was successful.";
            testCase.verifyTrue(b_get_dset, "Failed to get dataset info to check file list. " + msg_get_dset);
            if ~b_get_dset, return; end
            cloudDatasetInfo = ans_get_dset;
            narrative(end+1) = "Testing: Verifying that the dataset's file list is not empty and contains 1 file.";
            testCase.verifyTrue(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files), "Dataset info does not contain a 'files' field or it is empty. " + msg_get_dset);
            if ~(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files)), return; end
            testCase.verifyNumElements(cloudDatasetInfo.files, 1, "Dataset file list does not contain exactly one file. " + msg_get_dset);
            if numel(cloudDatasetInfo.files) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(cloudDatasetInfo.files(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_get_dset);
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
            narrative(end+1) = "Preparing to download the file to verify its content.";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            try
                websave(downloadedFilePath, downloadURL);
                narrative(end+1) = "File downloaded successfully.";
            catch ME
                testCase.verifyFail("Failed to download file using websave: " + ME.message);
                return;
            end
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, "Content of downloaded file does not match original content.");
            narrative(end+1) = "File content verified successfully.";
            testCase.Narrative = narrative;
        end

        function testSingleFileUploadAndDownloadUseMatlabNotCurl(testCase)
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
                testCase.verifyFail("Failed to create local test file: " + ME.message);
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
            [b_get_dset, ans_get_dset, resp_get_dset, url_get_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get_dset);
            msg_get_dset = ndi.unittest.cloud.APIMessage(narrative, b_get_dset, ans_get_dset, resp_get_dset, url_get_dset);
            narrative(end+1) = "Testing: Verifying that getDataset call was successful.";
            testCase.verifyTrue(b_get_dset, "Failed to get dataset info to check file list. " + msg_get_dset);
            if ~b_get_dset, return; end
            cloudDatasetInfo = ans_get_dset;
            narrative(end+1) = "Testing: Verifying that the dataset's file list is not empty and contains 1 file.";
            testCase.verifyTrue(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files), "Dataset info does not contain a 'files' field or it is empty. " + msg_get_dset);
            if ~(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files)), return; end
            testCase.verifyNumElements(cloudDatasetInfo.files, 1, "Dataset file list does not contain exactly one file. " + msg_get_dset);
            if numel(cloudDatasetInfo.files) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(cloudDatasetInfo.files(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_get_dset);
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
            narrative(end+1) = "Preparing to download the file to verify its content.";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            try
                websave(downloadedFilePath, downloadURL);
                narrative(end+1) = "File downloaded successfully.";
            catch ME
                testCase.verifyFail("Failed to download file using websave: " + ME.message);
                return;
            end
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, "Content of downloaded file does not match original content.");
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
                testCase.verifyFail("Failed to create local test file: " + ME.message);
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
            [b_get_dset, ans_get_dset, resp_get_dset, url_get_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get_dset);
            msg_get_dset = ndi.unittest.cloud.APIMessage(narrative, b_get_dset, ans_get_dset, resp_get_dset, url_get_dset);
            narrative(end+1) = "Testing: Verifying that getDataset call was successful.";
            testCase.verifyTrue(b_get_dset, "Failed to get dataset info to check file list. " + msg_get_dset);
            if ~b_get_dset, return; end
            cloudDatasetInfo = ans_get_dset;
            narrative(end+1) = "Testing: Verifying that the dataset's file list is not empty and contains 1 file.";
            testCase.verifyTrue(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files), "Dataset info does not contain a 'files' field or it is empty. " + msg_get_dset);
            if ~(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files)), return; end
            testCase.verifyNumElements(cloudDatasetInfo.files, 1, "Dataset file list does not contain exactly one file. " + msg_get_dset);
            if numel(cloudDatasetInfo.files) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(cloudDatasetInfo.files(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_get_dset);
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
            narrative(end+1) = "Preparing to download the file to verify its content.";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            try
                websave(downloadedFilePath, downloadURL);
                narrative(end+1) = "File downloaded successfully.";
            catch ME
                testCase.verifyFail("Failed to download file using websave: " + ME.message);
                return;
            end
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, "Content of downloaded file does not match original content.");
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
                testCase.verifyFail("Failed to create local test file: " + ME.message);
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
            [b_get_dset, ans_get_dset, resp_get_dset, url_get_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get_dset);
            msg_get_dset = ndi.unittest.cloud.APIMessage(narrative, b_get_dset, ans_get_dset, resp_get_dset, url_get_dset);
            narrative(end+1) = "Testing: Verifying that getDataset call was successful.";
            testCase.verifyTrue(b_get_dset, "Failed to get dataset info to check file list. " + msg_get_dset);
            if ~b_get_dset, return; end
            cloudDatasetInfo = ans_get_dset;
            narrative(end+1) = "Testing: Verifying that the dataset's file list is empty.";
            testCase.verifyTrue(isfield(cloudDatasetInfo, 'files') && isempty(cloudDatasetInfo.files), "Dataset info should have an empty 'files' field before upload. " + msg_get_dset);
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
            [b_get_dset, ans_get_dset, resp_get_dset, url_get_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get_dset);
            msg_get_dset = ndi.unittest.cloud.APIMessage(narrative, b_get_dset, ans_get_dset, resp_get_dset, url_get_dset);
            narrative(end+1) = "Testing: Verifying that getDataset call was successful.";
            testCase.verifyTrue(b_get_dset, "Failed to get dataset info to check file list. " + msg_get_dset);
            if ~b_get_dset, return; end
            cloudDatasetInfo = ans_get_dset;
            narrative(end+1) = "Testing: Verifying that the dataset's file list is not empty and contains 1 file.";
            testCase.verifyTrue(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files), "Dataset info does not contain a 'files' field or it is empty. " + msg_get_dset);
            if ~(isfield(cloudDatasetInfo, 'files') && ~isempty(cloudDatasetInfo.files)), return; end
            testCase.verifyNumElements(cloudDatasetInfo.files, 1, "Dataset file list does not contain exactly one file. " + msg_get_dset);
            if numel(cloudDatasetInfo.files) ~= 1, return; end
            narrative(end+1) = "Testing: Verifying that the UID in the file list matches the uploaded file's UID.";
            testCase.verifyEqual(cloudDatasetInfo.files(1).uid, char(fileUID), "The UID in the dataset's file list does not match the uploaded UID. " + msg_get_dset);
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
            narrative(end+1) = "Preparing to download the file to verify its content.";
            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            try
                websave(downloadedFilePath, downloadURL);
                narrative(end+1) = "File downloaded successfully.";
            catch ME
                testCase.verifyFail("Failed to download file using websave: " + ME.message);
                return;
            end
            retrievedContent = fileread(downloadedFilePath);
            narrative(end+1) = "Testing: Verifying content of downloaded file matches original.";
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, "Content of downloaded file does not match original content.");
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
                    testCase.verifyFail("Failed to create local test file #" + i + ": " + ME.message);
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
                testCase.verifyFail("Failed to create zip archive for bulk upload: " + ME.message);
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
                try
                    websave(downloadedFilePath, downloadURL);
                catch ME
                    testCase.verifyFail("Failed to download file " + fileUID + ": " + ME.message);
                    continue; % Continue to next file
                end
                
                retrievedContent = fileread(downloadedFilePath);
                % NOTE: fileread returns char, so we cast original bytes to char for comparison
                testCase.verifyEqual(retrievedContent, char(fileContents{i}), "Content mismatch for file " + fileUID);
            end
            narrative(end+1) = "All bulk-uploaded files have been individually verified.";
            
            testCase.Narrative = narrative;
        end
    end
end
