classdef FilesUSFTest < matlab.unittest.TestCase
% FilesUSFTest - Test suite for the ndi.cloud.uploadSingleFile function
%
%   This test class verifies the functionality of ndi.cloud.uploadSingleFile,
%   which provides a simplified interface for uploading single files to the
%   NDI cloud service. It follows a narrative-driven approach to provide clear,
%   actionable feedback.
%
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_FILESUSF_';
        TestFileContent = 'This is a test file for NDI Cloud API testing using uploadSingleFile.';
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
        function testUploadSingleFileDefault(testCase)
            testCase.Narrative = "Begin testUploadSingleFileDefault";
            narrative = testCase.Narrative;

            % Step 1: Create a local test file
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID);
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return; % Stop the test
            end

            % Step 2: Upload the file using ndi.cloud.uploadSingleFile
            narrative(end+1) = "ACTION: Calling ndi.cloud.uploadSingleFile with default options.";
            [b_upload, errormsg] = ndi.cloud.uploadSingleFile(testCase.DatasetID, fileUID, localFilePath);
            msg_upload = ndi.unittest.cloud.APIMessage(narrative, b_upload, errormsg, [], 'ndi.cloud.uploadSingleFile');
            testCase.verifyTrue(b_upload, "ndi.cloud.uploadSingleFile failed. " + msg_upload);
            if ~b_upload, return; end
            narrative(end+1) = "File uploaded successfully via wrapper function.";

            pause(10); % Give server time to process the file

            % Step 3: Verify the file appears in the dataset's file list
            narrative(end+1) = "VERIFICATION: Checking dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            testCase.verifyTrue(b_list, "Failed to list files. " + msg_list);
            if ~b_list, return; end
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the file list does not match. " + msg_list);
            testCase.verifyTrue(file_list(1).uploaded, "The file is not marked as 'uploaded'. " + msg_list);
            narrative(end+1) = "File correctly appeared in the dataset's file list.";

            % Step 4: Download and verify content
            narrative(end+1) = "VERIFICATION: Downloading file to verify its content.";
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, fileUID);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details, return; end
            downloadURL = ans_details.downloadUrl;

            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end

            retrievedContent = fileread(downloadedFilePath);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content.");
            narrative(end+1) = "File content verified successfully.";

            testCase.Narrative = narrative;
        end

        function testUploadSingleFileAsBulk(testCase)
            testCase.Narrative = "Begin testUploadSingleFileAsBulk";
            narrative = testCase.Narrative;

            % Step 1: Create a local test file
            narrative(end+1) = "SETUP: Creating a local temporary file for upload.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUID = string(did.ido.unique_id());
            localFilePath = fullfile(tempFolder.Folder, fileUID);
            try
                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', testCase.TestFileContent);
                fclose(fid);
                narrative(end+1) = "Local file created successfully with name (UID): " + fileUID;
            catch ME
                narrative(end+1) = "FAILURE: Could not create local test file during test setup.";
                msg_fail = ndi.unittest.cloud.APIMessage(narrative, false, ME.message, [], 'local_operation:fopen');
                testCase.verifyFail("Failed to create local test file. " + msg_fail);
                return;
            end

            % Step 2: Upload the file using ndi.cloud.uploadSingleFile with useBulkUpload
            narrative(end+1) = "ACTION: Calling ndi.cloud.uploadSingleFile with 'useBulkUpload', true.";
            [b_upload, errormsg] = ndi.cloud.uploadSingleFile(testCase.DatasetID, fileUID, localFilePath, 'useBulkUpload', true);
            msg_upload = ndi.unittest.cloud.APIMessage(narrative, b_upload, errormsg, [], 'ndi.cloud.uploadSingleFile');
            testCase.verifyTrue(b_upload, "ndi.cloud.uploadSingleFile with bulk option failed. " + msg_upload);
            if ~b_upload, return; end
            narrative(end+1) = "File uploaded successfully via wrapper function (bulk mode).";

            pause(10); % Give server time to process the file

            % Step 3: Verify the file appears in the dataset's file list
            narrative(end+1) = "VERIFICATION: Checking dataset file list for the newly uploaded file.";
            [b_list, file_list, resp_list, url_list] = ndi.cloud.api.files.listFiles(testCase.DatasetID, 'checkForUpdates', true);
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, file_list, resp_list, url_list);
            testCase.verifyTrue(b_list, "Failed to list files. " + msg_list);
            if ~b_list, return; end

            % Note: Bulk upload may not use the provided fileUID, the server assigns it from the filename.
            % We need to check for a file with the correct name. The UID will be the filename.
            testCase.verifyNumElements(file_list, 1, "Dataset file list does not contain exactly one file. " + msg_list);
            if numel(file_list) ~= 1, return; end

            % The UID in the remote file list will be the name of the file inside the zip, which is `fileUID`
            testCase.verifyEqual(file_list(1).uid, char(fileUID), "The UID in the file list does not match the filename. " + msg_list);
            testCase.verifyTrue(file_list(1).uploaded, "The file is not marked as 'uploaded'. " + msg_list);
            narrative(end+1) = "File correctly appeared in the dataset's file list.";

            % Step 4: Download and verify content
            narrative(end+1) = "VERIFICATION: Downloading file to verify its content.";
            % Use the UID from the file list to get details
            remoteFileUID = file_list(1).uid;
            [b_details, ans_details, resp_details, url_details] = ndi.cloud.api.files.getFileDetails(testCase.DatasetID, remoteFileUID);
            msg_details = ndi.unittest.cloud.APIMessage(narrative, b_details, ans_details, resp_details, url_details);
            testCase.verifyTrue(b_details, "Failed to get file details. " + msg_details);
            if ~b_details, return; end
            downloadURL = ans_details.downloadUrl;

            downloadedFilePath = fullfile(tempFolder.Folder, 'downloaded_file.txt');
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.files.getFile(downloadURL, downloadedFilePath, "useCurl", true);
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, "File download failed. " + msg_get);
            if ~b_get, return; end

            retrievedContent = fileread(downloadedFilePath);
            testCase.verifyEqual(retrievedContent, testCase.TestFileContent, ...
                "Content of downloaded file does not match original content.");
            narrative(end+1) = "File content verified successfully.";

            testCase.Narrative = narrative;
        end
    end
end
