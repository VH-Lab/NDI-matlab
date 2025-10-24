classdef TestPublishWithDocsAndFiles < matlab.unittest.TestCase
% TestPublishWithDocsAndFiles - Test suite for publishing datasets with documents and files.
%
%   This test class verifies that a dataset with a moderate number of documents and
%   files can be successfully published, read, and unpublished. It is designed to
%   catch potential race conditions or processing failures in the cloud backend
%   that might not be apparent in tests with only a single document or file.
%
%   It follows a narrative-driven approach to provide clear, actionable feedback
%   for both MATLAB and API developers.
%
    properties (Constant)
        % A unique prefix for test datasets to easily identify them.
        DatasetNamePrefix = 'NDI_UNITTEST_PUB_';
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
        Narrative (1,:) string % Stores the narrative for each test
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            % This fatal assertion runs once before any tests in this class.
            % It ensures that the necessary credentials are set as environment variables,
            % preventing the test suite from running if the basic configuration is missing.
            %
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_USERNAME environment variable is not set. This is not an API problem.');
            testCase.fatalAssertNotEmpty(password, ...
                'LOCAL CONFIGURATION ERROR: The NDI_CLOUD_PASSWORD environment variable is not set. This is not an API problem.');
        end
    end

    methods (TestMethodSetup)
        % This now runs BEFORE EACH test method, creating a fresh dataset every time.
        function setupNewDataset(testCase)
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
            % The teardown is queued to run after the test method completes.
            testCase.addTeardown(@() testCase.deleteDatasetAfterTest());
        end
    end

    methods (Access = private)
        % This is now a private helper method, not a teardown method.
        function deleteDatasetAfterTest(testCase)
            if ~ismissing(testCase.DatasetID)
                narrative = testCase.Narrative; % Make a local copy
                narrative(end+1) = "TEARDOWN: Deleting temporary dataset ID: " + testCase.DatasetID;
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID);
                if ~b
                    msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_del, resp_del, url_del);
                    % Use assert instead of verify in teardown to ensure it's noted
                    testCase.assertTrue(b, "Failed to delete dataset in TestMethodTeardown. " + msg);
                end
            end
        end
    end

    methods (Test)

        function testSerialUploadPublishDownload(testCase)
            testCase.Narrative = "Begin testSerialUploadPublishDownload";
            narrative = testCase.Narrative;

            numDocs = 10;
            numFiles = 10;

            % Step 1: Create and upload documents serially
            narrative(end+1) = "SETUP: Serially uploading " + numDocs + " documents.";
            cloudDocIDs = strings(1, numDocs);
            for i = 1:numDocs
                doc_to_add = ndi.document('base', 'base.name', "serial_doc_" + i);
                json_doc = jsonencodenan(doc_to_add.document_properties);
                [b_add, ans_add, resp_add, url_add] = ndi.cloud.api.documents.addDocument(testCase.DatasetID, json_doc);
                msg_add = ndi.unittest.cloud.APIMessage(narrative, b_add, ans_add, resp_add, url_add);
                testCase.fatalAssertTrue(b_add, "Failed to add document #" + i + ". " + msg_add);
                cloudDocIDs(i) = ans_add.id;
            end
            narrative(end+1) = "All documents uploaded successfully.";

            % Step 2: Create and upload files serially
            narrative(end+1) = "SETUP: Serially uploading " + numFiles + " files.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            fileUIDs = strings(1, numFiles);
            for i = 1:numFiles
                fileUIDs(i) = string(did.ido.unique_id());
                localFilePath = fullfile(tempFolder.Folder, fileUIDs(i));
                fileContent = "This is test file #" + i;

                fid = fopen(localFilePath, 'w');
                fprintf(fid, '%s', fileContent);
                fclose(fid);

                [b_url, uploadURL, resp_url, url_url] = ndi.cloud.api.files.getFileUploadURL(testCase.DatasetID, fileUIDs(i));
                msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, uploadURL, resp_url, url_url);
                testCase.fatalAssertTrue(b_url, "Failed to get upload URL for file #" + i + ". " + msg_url);

                [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, localFilePath, "useCurl", true);
                msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
                testCase.fatalAssertTrue(b_put, "Failed to upload file #" + i + ". " + msg_put);
            end
            narrative(end+1) = "All files uploaded successfully.";

            % Step 3: Publish the dataset
            narrative(end+1) = "ACTION: Publishing the dataset.";
            [b_pub, ans_pub, resp_pub, url_pub] = ndi.cloud.api.datasets.publishDataset(testCase.DatasetID);
            msg_pub = ndi.unittest.cloud.APIMessage(narrative, b_pub, ans_pub, resp_pub, url_pub);
            testCase.fatalAssertTrue(b_pub, "Failed to publish dataset. " + msg_pub);
            narrative(end+1) = "Dataset published. Waiting 30 seconds for processing...";

            pause(30);

            narrative(end+1) = "VERIFICATION: Checking published documents.";
            [b_docs, ans_docs, resp_docs, url_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID);
            msg_docs = ndi.unittest.cloud.APIMessage(narrative, b_docs, ans_docs, resp_docs, url_docs);
            testCase.verifyTrue(b_docs, "Failed to list documents of published dataset. " + msg_docs);
            testCase.verifyNumElements(ans_docs.documents, numDocs, "Incorrect number of documents found in published dataset. " + msg_docs);

            narrative(end+1) = "VERIFICATION: Checking published files.";
            [b_dset, ans_dset, resp_dset, url_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            msg_dset = ndi.unittest.cloud.APIMessage(narrative, b_dset, ans_dset, resp_dset, url_dset);
            testCase.verifyTrue(b_dset, "Failed to get dataset info. " + msg_dset);
            testCase.verifyNumElements(ans_dset.files, numFiles, "Incorrect number of files found in published dataset. " + msg_dset);

            % Step 4: Unpublish the dataset
            narrative(end+1) = "ACTION: Unpublishing the dataset.";
            [b_unpub, ans_unpub, resp_unpub, url_unpub] = ndi.cloud.api.datasets.unpublishDataset(testCase.DatasetID);
            msg_unpub = ndi.unittest.cloud.APIMessage(narrative, b_unpub, ans_unpub, resp_unpub, url_unpub);
            testCase.verifyTrue(b_unpub, "Failed to unpublish dataset. " + msg_unpub);
            narrative(end+1) = "Dataset unpublished successfully.";

            testCase.Narrative = narrative;
        end

        function testBulkUploadPublishDownload(testCase)
            testCase.Narrative = "Begin testBulkUploadPublishDownload";
            narrative = testCase.Narrative;

            numDocs = 10;
            numFiles = 10;

            % Step 1: Create and upload documents in bulk
            narrative(end+1) = "SETUP: Bulk uploading " + numDocs + " documents.";
            docs_to_upload = cell(1, numDocs);
            for i = 1:numDocs
                docs_to_upload{i} = ndi.document('base', 'base.name', "bulk_doc_" + i);
            end
            [b_upload_docs, report_upload] = ndi.cloud.upload.upload_document_collection(testCase.DatasetID, docs_to_upload);
            msg_upload_docs = "Bulk document upload verification failed. Report: " + jsonencode(report_upload);
            testCase.fatalAssertTrue(b_upload_docs, msg_upload_docs);
            narrative(end+1) = "All documents uploaded successfully in bulk.";

            % Step 2: Create and upload files in bulk
            narrative(end+1) = "SETUP: Bulk uploading " + numFiles + " files.";
            import matlab.unittest.fixtures.TemporaryFolderFixture;
            tempFolder = testCase.applyFixture(TemporaryFolderFixture);
            localFilePaths = strings(1, numFiles);
            fileUIDs = strings(1, numFiles);

            for i = 1:numFiles
                fileUIDs(i) = string(did.ido.unique_id());
                localFilePaths(i) = fullfile(tempFolder.Folder, fileUIDs(i));
                fileContent = "This is bulk test file #" + i;
                fid = fopen(localFilePaths(i), 'w');
                fprintf(fid, '%s', fileContent);
                fclose(fid);
            end

            [b_url, uploadURL, resp_url, url_url] = ndi.cloud.api.files.getFileCollectionUploadURL(testCase.DatasetID);
            msg_url = ndi.unittest.cloud.APIMessage(narrative, b_url, uploadURL, resp_url, url_url);
            testCase.fatalAssertTrue(b_url, "Failed to get bulk file upload URL. " + msg_url);

            zipFileName = testCase.DatasetID + "." + string(did.ido.unique_id()) + ".zip";
            zipFilePath = fullfile(tempFolder.Folder, zipFileName);
            zip(zipFilePath, localFilePaths);

            [b_put, ans_put, resp_put, url_put] = ndi.cloud.api.files.putFiles(uploadURL, zipFilePath);
            msg_put = ndi.unittest.cloud.APIMessage(narrative, b_put, ans_put, resp_put, url_put);
            testCase.fatalAssertTrue(b_put, "Bulk file upload (PUT request) failed. " + msg_put);
            narrative(end+1) = "All files uploaded successfully in bulk.";

            % Step 3: Publish the dataset
            narrative(end+1) = "ACTION: Publishing the dataset.";
            [b_pub, ans_pub, resp_pub, url_pub] = ndi.cloud.api.datasets.publishDataset(testCase.DatasetID);
            msg_pub = ndi.unittest.cloud.APIMessage(narrative, b_pub, ans_pub, resp_pub, url_pub);
            testCase.fatalAssertTrue(b_pub, "Failed to publish dataset. " + msg_pub);
            narrative(end+1) = "Dataset published. Waiting 30 seconds for processing...";

            pause(30);

            narrative(end+1) = "VERIFICATION: Checking published documents.";
            [b_docs, ans_docs, resp_docs, url_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID);
            msg_docs = ndi.unittest.cloud.APIMessage(narrative, b_docs, ans_docs, resp_docs, url_docs);
            testCase.verifyTrue(b_docs, "Failed to list documents of published dataset. " + msg_docs);
            testCase.verifyNumElements(ans_docs.documents, numDocs, "Incorrect number of documents found in published dataset. " + msg_docs);

            narrative(end+1) = "VERIFICATION: Checking published files.";
            [b_dset, ans_dset, resp_dset, url_dset] = ndi.cloud.api.datasets.getDataset(testCase.DatasetID);
            msg_dset = ndi.unittest.cloud.APIMessage(narrative, b_dset, ans_dset, resp_dset, url_dset);
            testCase.verifyTrue(b_dset, "Failed to get dataset info. " + msg_dset);
            testCase.verifyNumElements(ans_dset.files, numFiles, "Incorrect number of files found in published dataset. " + msg_dset);

            % Step 4: Unpublish the dataset
            narrative(end+1) = "ACTION: Unpublishing the dataset.";
            [b_unpub, ans_unpub, resp_unpub, url_unpub] = ndi.cloud.api.datasets.unpublishDataset(testCase.DatasetID);
            msg_unpub = ndi.unittest.cloud.APIMessage(narrative, b_unpub, ans_unpub, resp_unpub, url_unpub);
            testCase.verifyTrue(b_unpub, "Failed to unpublish dataset. " + msg_unpub);
            narrative(end+1) = "Dataset unpublished successfully.";

            testCase.Narrative = narrative;
        end

    end

end
