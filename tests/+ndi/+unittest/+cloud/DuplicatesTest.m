classdef DuplicatesTest < matlab.unittest.TestCase
% DuplicatesTest - Test suite for the ndi.cloud.internal.duplicateDocuments function
%
%   This test class verifies that the duplicate document detection and removal
%   functionality works as expected. It uses a narrative-driven approach to
%   provide clear, actionable feedback for developers.
%
    properties (Constant)
        % A unique prefix for test datasets to easily identify them.
        DatasetNamePrefix = 'NDI_UNITTEST_DUPLICATES_DATASET_';
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
        % This runs BEFORE EACH test method, creating a fresh dataset every time.
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
        % This is a private helper method to clean up the dataset after a test.
        function deleteDatasetAfterTest(testCase)
            if ~ismissing(testCase.DatasetID)
                narrative = testCase.Narrative; % Make a local copy
                narrative(end+1) = "TEARDOWN: Deleting temporary dataset ID: " + testCase.DatasetID;
                [b, ans_del, resp_del, url_del] = ndi.cloud.api.datasets.deleteDataset(testCase.DatasetID, 'when', 'now');
                if ~b
                    msg = ndi.unittest.cloud.APIMessage(narrative, b, ans_del, resp_del, url_del);
                    % Use assert instead of verify in teardown to ensure it's noted
                    testCase.assertTrue(b, "Failed to delete dataset in TestMethodTeardown. " + msg);
                end
            end
        end
    end

    methods (Test)
        function testDuplicateDocumentDetectionAndRemoval(testCase)
            testCase.Narrative = "Begin testDuplicateDocumentDetectionAndRemoval";
            narrative = testCase.Narrative;

            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;
            numDocs = 10;

            % Step 1: Create local document objects
            narrative(end+1) = "Preparing to create " + numDocs + " local ndi.document objects.";
            docs_to_upload = cell(1, numDocs);
            for i = 1:numDocs
                docs_to_upload{i} = ndi.document('base', 'base.name', "duplicate_test_doc_" + i);
            end
            narrative(end+1) = "Local documents created.";

            % Step 2: Perform first bulk upload
            narrative(end+1) = "Preparing to perform the first bulk document upload.";
            [b_upload1, report_upload1] = ndi.cloud.upload.uploadDocumentCollection(testCase.DatasetID, docs_to_upload);
            msg_upload1 = ndi.unittest.cloud.APIMessage(narrative, b_upload1, report_upload1, [], []);
            testCase.fatalAssertTrue(b_upload1, "First bulk upload failed. " + msg_upload1);
            narrative(end+1) = "First bulk upload successful.";

            pause(5); % Pause to allow the server to process the first batch

            % Step 3: Perform second bulk upload to create duplicates
            narrative(end+1) = "Preparing to perform the second bulk document upload to create duplicates.";
            [b_upload2, report_upload2] = ndi.cloud.upload.uploadDocumentCollection(testCase.DatasetID, docs_to_upload, 'onlyUploadMissing', false);
            msg_upload2 = ndi.unittest.cloud.APIMessage(narrative, b_upload2, report_upload2, [], []);
            testCase.fatalAssertTrue(b_upload2, "Second bulk upload failed. " + msg_upload2);
            narrative(end+1) = "Second bulk upload successful.";

            pause(5); % Pause to allow the server to process the second batch

            % Step 4: Verify count is 2 * numDocs
            narrative(end+1) = "Preparing to verify document count after creating duplicates.";
            [b_count, ans_count, resp_count, url_count] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            msg_count = ndi.unittest.cloud.APIMessage(narrative, b_count, ans_count, resp_count, url_count);
            testCase.fatalAssertTrue(b_count, "Failed to get document count. " + msg_count);
            testCase.verifyEqual(ans_count, 2 * numDocs, "Document count is not double the initial upload. " + msg_count);
            narrative(end+1) = "Document count is correctly " + (2 * numDocs) + ".";

            % Step 5: Call duplicateDocuments to find and remove duplicates
            narrative(end+1) = "Preparing to call ndi.cloud.internal.duplicateDocuments.";
            [duplicateDocs, originalDocs] = ndi.cloud.internal.duplicateDocuments(testCase.DatasetID, 'verbose', true);
            narrative(end+1) = "duplicateDocuments function call completed.";

            % Step 6: Verify the number of duplicates and originals
            narrative(end+1) = "Testing: Verifying the number of identified duplicate documents.";
            testCase.verifyNumElements(duplicateDocs, numDocs, "Incorrect number of duplicate documents found.");
            narrative(end+1) = "Correctly identified " + numDocs + " duplicate documents.";

            narrative(end+1) = "Testing: Verifying the number of identified original documents.";
            testCase.verifyNumElements(originalDocs, numDocs, "Incorrect number of original documents found.");
            narrative(end+1) = "Correctly identified " + numDocs + " original documents.";

            % Step 7: Verify final count is numDocs
            narrative(end+1) = "Preparing to verify final document count after duplicate removal.";
            [b_count_final, ans_count_final, resp_count_final, url_count_final] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            msg_count_final = ndi.unittest.cloud.APIMessage(narrative, b_count_final, ans_count_final, resp_count_final, url_count_final);
            testCase.fatalAssertTrue(b_count_final, "Failed to get final document count. " + msg_count_final);
            testCase.verifyEqual(ans_count_final, numDocs, "Final document count is incorrect after duplicate removal. " + msg_count_final);
            narrative(end+1) = "Final document count is correctly " + numDocs + ".";

            testCase.Narrative = narrative;
        end
    end
end
