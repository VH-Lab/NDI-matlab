classdef DownloadGenericFilesTest < matlab.unittest.TestCase
% DownloadGenericFilesTest - Test suite for ndi.cloud.download.downloadGenericFiles
%
%   This test class verifies the functionality of downloading generic_file
%   documents and their associated data files from the NDI Cloud.
%
    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_GENERIC_FILES_';
    end

    properties
        DatasetID (1,1) string = missing
        LocalDataset
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            diagMsg = 'Missing NDI Cloud credentials (NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). Skipping cloud-dependent tests.';
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end
    end

    methods (TestMethodSetup)
        function setupLocalDatasetAndCloud(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));

            % 1. Create a local dataset with generic files
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            testCase.LocalDataset = ndi.dataset.dir('test_ds', tempFolder.Folder);

            % 1a. Create a target document (using base, which doesn't depend on anything)
            doc_target = ndi.document('base', ...
                'base.name', 'test_target', ...
                'base.session_id', testCase.LocalDataset.id());
            testCase.LocalDataset.database_add(doc_target);

            % 1b. Create a generic_file document that depends on the target
            doc1_path = fullfile(tempFolder.Folder, 'test1.txt');
            fid = fopen(doc1_path, 'w');
            fprintf(fid, 'test content 1');
            fclose(fid);

            doc1 = ndi.document('generic_file', ...
                'base.name', 'test_doc_1', ...
                'generic_file.filename', 'renamed_test1.txt', ...
                'generic_file.dateCreated', 0, ...
                'generic_file.dateUpdated', 0, ...
                'base.session_id', testCase.LocalDataset.id());
            doc1 = doc1.add_file('generic_file.ext', doc1_path);
            doc1 = doc1.set_dependency_value('document_id', doc_target.id(), 'ErrorIfNotFound', 0);
            testCase.LocalDataset.database_add(doc1);

            % 2. Create cloud dataset
            unique_name = testCase.DatasetNamePrefix + string(did.ido.unique_id());
            [b, cloudId] = ndi.cloud.api.datasets.createDataset(struct("name", unique_name));
            testCase.fatalAssertTrue(b, "Failed to create cloud dataset.");
            testCase.DatasetID = cloudId;

            % Link local to cloud
            remoteDoc = ndi.cloud.internal.createRemoteDatasetDoc(cloudId, testCase.LocalDataset);
            testCase.LocalDataset.database_add(remoteDoc);

            % 3. Upload to cloud
            [success_upload] = ndi.cloud.uploadDataset(testCase.LocalDataset);
            testCase.fatalAssertTrue(success_upload, "Failed to upload test dataset to cloud.");

            % Wait for server-side bulk extraction of the just-uploaded
            % files to finish before any test reads them back. Without
            % this, listFiles can report uploaded=true while the per-file
            % objects in the upload bucket don't yet exist (issue #755).
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            testCase.addTeardown(@() testCase.cleanupCloudDataset());
        end
    end

    methods (Access = private)
        function cleanupCloudDataset(testCase)
            if ~ismissing(testCase.DatasetID)
                ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
            end
        end
    end

    methods (Test)
        function testDownloadGenericFiles(testCase)
            testCase.Narrative = "Begin testDownloadGenericFiles";

            % Get NDI IDs
            q = ndi.query('base.name', 'exact_string', 'test_doc_1');
            docs = testCase.LocalDataset.database_search(q);
            testCase.fatalAssertNumElements(docs, 1);
            docId = docs{1}.id();

            % Create destination folder
            destFolder = fullfile(testCase.LocalDataset.path, 'download_test');
            mkdir(destFolder);

            % Call downloadGenericFiles
            [success, errMsg, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, docId, destFolder);

            testCase.verifyTrue(success, "Function returned failure: " + errMsg);
            testCase.verifyTrue(ismember('renamed_test1.txt', report.downloaded_filenames));

            % Check file existence and name
            downloadedFile = fullfile(destFolder, 'renamed_test1.txt');
            testCase.verifyTrue(isfile(downloadedFile), "File not found at expected location with correct extension.");

            content = fileread(downloadedFile);
            testCase.verifyEqual(content, 'test content 1');
        end

        function testDownloadWithDependencies(testCase)
            testCase.Narrative = "Begin testDownloadWithDependencies";

            % Get ID of the target document (which doesn't have files itself)
            q = ndi.query('base.name', 'exact_string', 'test_target');
            docs = testCase.LocalDataset.database_search(q);
            testCase.fatalAssertNumElements(docs, 1);
            targetId = docs{1}.id();

            % We already have doc1 (generic_file) that depends on this target.
            % Let's create another one, doc3, that also depends on it.
            doc3_path = fullfile(testCase.LocalDataset.path, 'test3.dat');
            fid = fopen(doc3_path, 'w'); fprintf(fid, 'content 3'); fclose(fid);
            doc3 = ndi.document('generic_file', ...
                'base.name', 'test_doc_3', ...
                'generic_file.filename', 'file3.dat', ...
                'generic_file.dateCreated', 0, ...
                'generic_file.dateUpdated', 0, ...
                'base.session_id', testCase.LocalDataset.id());
            doc3 = doc3.add_file('generic_file.ext', doc3_path);
            doc3 = doc3.set_dependency_value('document_id', targetId, 'ErrorIfNotFound', 0);
            testCase.LocalDataset.database_add(doc3);

            % Re-upload dataset to include doc3
            ndi.cloud.uploadDataset(testCase.LocalDataset);
            ndi.cloud.api.files.waitForAllBulkUploads(testCase.DatasetID);

            destFolder = fullfile(testCase.LocalDataset.path, 'download_test_dep');
            mkdir(destFolder);

            % Call downloadGenericFiles with target ID.
            % It should find doc1 and doc3 because they depend on the target.
            [success, ~, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, targetId, destFolder);

            testCase.verifyTrue(success);
            testCase.verifyTrue(ismember('renamed_test1.txt', report.downloaded_filenames));
            testCase.verifyTrue(ismember('file3.dat', report.downloaded_filenames));
            testCase.verifyTrue(isfile(fullfile(destFolder, 'renamed_test1.txt')));
            testCase.verifyTrue(isfile(fullfile(destFolder, 'file3.dat')));
        end

        function testDownloadWithZip(testCase)
            testCase.Narrative = "Begin testDownloadWithZip";

            q = ndi.query('base.name', 'exact_string', 'test_doc_1');
            docs = testCase.LocalDataset.database_search(q);
            docId = docs{1}.id();

            destFolder = fullfile(testCase.LocalDataset.path, 'download_test_zip');
            mkdir(destFolder);

            [success, ~, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, docId, destFolder, 'Zip', true);

            testCase.verifyTrue(success);
            testCase.verifyNotEmpty(report.zip_file);
            testCase.verifyTrue(isfile(report.zip_file));
        end

        function testNamingStrategies(testCase)
            testCase.Narrative = "Begin testNamingStrategies";

            q = ndi.query('base.name', 'exact_string', 'test_doc_1');
            docs = testCase.LocalDataset.database_search(q);
            docId = docs{1}.id();

            % 1. Test 'id' strategy
            destFolderId = fullfile(testCase.LocalDataset.path, 'download_test_id');
            mkdir(destFolderId);
            [success, ~, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, docId, destFolderId, 'NamingStrategy', 'id');
            testCase.verifyTrue(success);
            expectedName = [docId '.txt'];
            testCase.verifyTrue(ismember(expectedName, report.downloaded_filenames));
            testCase.verifyTrue(isfile(fullfile(destFolderId, expectedName)));

            % 2. Test 'id_original' strategy
            destFolderBoth = fullfile(testCase.LocalDataset.path, 'download_test_both');
            mkdir(destFolderBoth);
            [success, ~, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, docId, destFolderBoth, 'NamingStrategy', 'id_original');
            testCase.verifyTrue(success);
            expectedName = [docId '_renamed_test1.txt'];
            testCase.verifyTrue(ismember(expectedName, report.downloaded_filenames));
            testCase.verifyTrue(isfile(fullfile(destFolderBoth, expectedName)));
        end
    end
end
