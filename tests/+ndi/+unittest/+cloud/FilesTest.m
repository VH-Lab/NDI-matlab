classdef FilesTest < matlab.unittest.TestCase
% FilesTest - Test suite for ndi.cloud.api.files namespace
%
% This test suite tests the functionality of the ndi.cloud.api.files namespace,
% which includes functions for uploading and retrieving files from NDI Cloud.
%
% If running this on cloud, need to set password and username for
% testing as environment variables.

    properties (Constant)
        DatasetName = 'NDI_TEMPORARY_FILES_TEST';
        TestFileName = 'test_file.txt';
        TestFileContent = 'This is a test file for NDI Cloud API testing.';
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
        TestFilePath % Path to a temporary test file
    end

    methods (TestClassSetup)
        function createTestDataset(testCase)
            % Create a dataset for testing
            datasetInfo = struct("name", testCase.DatasetName);
            [status, ~, testCase.DatasetID] = ...
                ndi.cloud.api.datasets.create_dataset(datasetInfo); 
            assert(status == 0, 'Failed to create test dataset')
            testCase.addTeardown(@() deleteDataset(testCase.DatasetID));
        end

        function createTestFile(testCase)
            % Create a temporary test file
            testCase.TestFilePath = fullfile(tempdir, testCase.TestFileName);
            fid = fopen(testCase.TestFilePath, 'w');
            fprintf(fid, '%s', testCase.TestFileContent);
            fclose(fid);
            
            % Add teardown to clean up
            testCase.addTeardown(@() deleteFile(testCase.TestFilePath));
        end

        function useTemporaryWorkingFolder(testCase)
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture)
        end
    end

    methods (Test)
        function testGetFileUploadUrl(testCase)
            % Test getting an upload URL for a file
            fileUID = testCase.generateFileUID();
            
            [status, response, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            testCase.verifyEqual(status, 0, 'Expected API call to succeed');
            testCase.verifyNotEmpty(upload_url, 'Expected non-empty upload URL');
            testCase.verifyTrue(ischar(upload_url) || isstring(upload_url), ...
                'Expected upload URL to be a string');
        end

        function testGetRawFileUploadUrl(testCase)
            % Test getting an upload URL for a raw file
            fileUID = testCase.generateFileUID();
            
            [status, ~, upload_url] = ndi.cloud.api.files.get_raw_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            testCase.verifyEqual(status, 0, 'Expected API call to succeed');
            testCase.verifyNotEmpty(upload_url, 'Expected non-empty upload URL');
            testCase.verifyTrue(ischar(upload_url) || isstring(upload_url), ...
                'Expected upload URL to be a string');
        end

        function testPutFiles(testCase)
            % Test uploading a file using a presigned URL
            fileUID = testCase.generateFileUID();
            
            % Get upload URL
            [status, ~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            testCase.verifyEqual(status, 0, 'Failed to get upload URL');
            
            % Upload file
            [status, response] = ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            
            testCase.verifyEqual(status, 0, 'Expected file upload to succeed');
        end

        function testGetFileDetails(testCase)
            % Test getting file details after upload
            fileUID = testCase.generateFileUID();
            
            % Upload a file first
            [~, ~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            [status, ~] = ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            testCase.verifyEqual(status, 0, 'Failed to upload test file');
            
            pause(2)

            % Get file details
            [status, file_detail, downloadUrl, response] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            
            testCase.verifyEqual(status, 0, 'Expected API call to succeed');
            testCase.verifyNotEmpty(file_detail, 'Expected non-empty file details');
            testCase.verifyNotEmpty(downloadUrl, 'Expected non-empty download URL');
            testCase.verifyClass(file_detail, 'struct', 'Expected file details to be a struct');
            testCase.verifyTrue(ischar(downloadUrl) || isstring(downloadUrl), ...
                'Expected download URL to be a string');
        end

        function testEndToEndFileUpload(testCase)
            % Test the complete file upload workflow
            fileUID = testCase.generateFileUID();
            
            % Step 1: Get upload URL
            [status1, ~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            testCase.verifyEqual(status1, 0, 'Failed to get upload URL');
            
            % Step 2: Upload file
            [status2, ~] = ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            testCase.verifyEqual(status2, 0, 'Failed to upload file');
            
            pause(2)
            
            % Step 3: Get file details
            [status3, file_detail, downloadUrl, ~] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            testCase.verifyEqual(status3, 0, 'Failed to get file details');
            
            % Verify file details
            testCase.verifyNotEmpty(file_detail, 'Expected non-empty file details');
            testCase.verifyNotEmpty(downloadUrl, 'Expected non-empty download URL');
            
            % Download the file and verify its contents
            websave('temp_test.txt', downloadUrl);
            testCase.addTeardown(@() delete('temp_test.txt'))
            str = fileread('temp_test.txt');
            testCase.verifyEqual(str, testCase.TestFileContent)
        end
        
        function testRawFileEndToEnd(testCase)
            % Test the complete raw file upload workflow
            fileUID = testCase.generateFileUID();
            
            % Step 1: Get raw file upload URL
            [status1, ~, upload_url] = ndi.cloud.api.files.get_raw_file_upload_url(...
                testCase.DatasetID, fileUID);
            testCase.verifyEqual(status1, 0, 'Failed to get raw file upload URL');
            
            % Step 2: Upload file
            [status2, ~] = ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            testCase.verifyEqual(status2, 0, 'Failed to upload raw file');
            
            pause(5) % Todo: Use retry loop for getting download url

            % Step 3: Get file details
            [status3, file_detail, downloadUrl, ~] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            testCase.verifyEqual(status3, 0, 'Failed to get raw file details');
            
            % Verify file details
            testCase.verifyNotEmpty(file_detail, 'Expected non-empty file details');
            testCase.verifyNotEmpty(downloadUrl, 'Expected non-empty download URL');

            % Download the file and verify its contents
            websave('temp_test.txt', downloadUrl)
            testCase.addTeardown(@() delete('temp_test.txt'))
            str = fileread('temp_test.txt');
            testCase.verifyEqual(str, testCase.TestFileContent)
        end
    end

    methods % Helper methods
        function fileUID = generateFileUID(testCase)
            % Generate a unique ID for a file
            randomChars = char(randi([65 90], 1, 8)); % Random 8 uppercase letters
            timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
            fileUID = sprintf('test_file_%s_%s', timestamp, randomChars);
        end
    end
end

function deleteDataset(datasetId)
    try
        [status, ~] = ndi.cloud.api.datasets.delete_dataset(datasetId);
    catch
        % Expecting fail - dataset might be in a state that prevents deletion
        for i = 1:5
            try % This should fail if dataset is deleted
                [~, ~, ~] = ndi.cloud.api.datasets.get_dataset(datasetId);                    
            catch
                return % We want previous command to fail
            end
            pause(1); % Wait a bit before trying again
        end
    end
    % If we get here, dataset might not have been deleted
    warning('Dataset with id "%s" might not have been deleted', datasetId)
end

function deleteFile(filePath)
    if exist(filePath, 'file')
        delete(filePath);
    end
end
