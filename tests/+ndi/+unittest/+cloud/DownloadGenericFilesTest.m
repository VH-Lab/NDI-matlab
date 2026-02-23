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

            % Use generic_file documents
            doc1_path = fullfile(tempFolder.Folder, 'test1.txt');
            fid = fopen(doc1_path, 'w');
            fprintf(fid, 'test content 1');
            fclose(fid);

            doc1 = testCase.LocalDataset.newdocument('generic_file', ...
                'base.name', 'test_doc_1', ...
                'generic_file.filename', 'renamed_test1.txt');
            doc1 = doc1.add_file('generic_file.ext', doc1_path);
            testCase.LocalDataset.database_add(doc1);

            % Create a document that depends on doc1
            doc2 = testCase.LocalDataset.newdocument('base', 'base.name', 'dependent_doc');
            doc2 = doc2.set_dependency_value('document_id', doc1.id());
            testCase.LocalDataset.database_add(doc2);

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

            pause(5); % allow server to process

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
            testCase.verifyMember('renamed_test1.txt', report.downloaded_filenames);

            % Check file existence and name
            downloadedFile = fullfile(destFolder, 'renamed_test1.txt');
            testCase.verifyTrue(isfile(downloadedFile), "File not found at expected location with correct extension.");

            content = fileread(downloadedFile);
            testCase.verifyEqual(content, 'test content 1');
        end

        function testDownloadWithDependencies(testCase)
            testCase.Narrative = "Begin testDownloadWithDependencies";

            % Get ID of the dependent document (which doesn't have files itself)
            q = ndi.query('base.name', 'exact_string', 'dependent_doc');
            docs = testCase.LocalDataset.database_search(q);
            testCase.fatalAssertNumElements(docs, 1);

            % doc1 depends on NOTHING
            % doc2 depends on doc1
            % findalldependencies(doc1) -> returns [doc2]
            % findalldependencies(doc2) -> returns []

            % The user wants: allDocuments = docinput2docs(doc2_id) -> returns doc2
            % allDependentDocs = findalldependencies(doc2) -> returns things that depend on doc2.

            % If the user wants to find doc1 given doc2, they should use findallantecedents.
            % But they explicitly said findalldependencies.
            % So I must ensure my test follows THEIR logic.

            % Let's create doc3 that depends on doc2 and is a generic_file.
            doc3_path = fullfile(testCase.LocalDataset.path, 'test3.dat');
            fid = fopen(doc3_path, 'w'); fprintf(fid, 'content 3'); fclose(fid);
            doc3 = testCase.LocalDataset.newdocument('generic_file', ...
                'base.name', 'test_doc_3', ...
                'generic_file.filename', 'file3.dat');
            doc3 = doc3.add_file('generic_file.ext', doc3_path);
            doc3 = doc3.set_dependency_value('document_id', docs{1}.id()); % doc3 depends on doc2
            testCase.LocalDataset.database_add(doc3);

            % Re-upload dataset to include doc3
            ndi.cloud.uploadDataset(testCase.LocalDataset);
            pause(5);

            destFolder = fullfile(testCase.LocalDataset.path, 'download_test_dep');
            mkdir(destFolder);

            % Call downloadGenericFiles with doc2 ID. It should find doc3 because doc3 depends on doc2.
            [success, ~, report] = ndi.cloud.download.downloadGenericFiles(...
                testCase.LocalDataset, docs{1}.id(), destFolder);

            testCase.verifyTrue(success);
            testCase.verifyMember('file3.dat', report.downloaded_filenames);
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
    end
end
