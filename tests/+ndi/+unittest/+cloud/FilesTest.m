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
            [~, testCase.DatasetID] = ...
                ndi.cloud.api.datasets.create_dataset(datasetInfo); 
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
            
            [response, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            testCase.verifyNotEmpty(upload_url, 'Expected non-empty upload URL');
            testCase.verifyTrue(ischar(upload_url) || isstring(upload_url), ...
                'Expected upload URL to be a string');
        end

        function testGetRawFileUploadUrl(testCase)
            % Test getting an upload URL for a raw file
            fileUID = testCase.generateFileUID();
            
            [~, upload_url] = ndi.cloud.api.files.get_raw_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            testCase.verifyNotEmpty(upload_url, 'Expected non-empty upload URL');
            testCase.verifyTrue(ischar(upload_url) || isstring(upload_url), ...
                'Expected upload URL to be a string');
        end

        function testPutFiles(testCase)
            % Test uploading a file using a presigned URL
            fileUID = testCase.generateFileUID();
            
            % Get upload URL
            [~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            % Upload file
            response = ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
        end

        function testGetFileDetails(testCase)
            % Test getting file details after upload
            fileUID = testCase.generateFileUID();
            
            % Upload a file first
            [~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            
            pause(5) % Give server time to register file

            % Get file details
            [file_detail, downloadUrl, response] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            
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
            [~, upload_url] = ndi.cloud.api.files.get_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            % Step 2: Upload file
            ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            
            pause(2)
            
            % Step 3: Get file details
            [file_detail, downloadUrl, ~] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            
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
            [~, upload_url] = ndi.cloud.api.files.get_raw_file_upload_url(...
                testCase.DatasetID, fileUID);
            
            % Step 2: Upload file
            ndi.cloud.api.files.put_files(...
                upload_url, testCase.TestFilePath);
            
            pause(5) % Todo: Use retry loop for getting download url

            % Step 3: Get file details
            [file_detail, downloadUrl, ~] = ndi.cloud.api.files.get_file_details(...
                testCase.DatasetID, fileUID);
            
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
    ndi.cloud.api.datasets.delete_dataset(datasetId);
end

function deleteFile(filePath)
    if exist(filePath, 'file')
        delete(filePath);
    end
end
