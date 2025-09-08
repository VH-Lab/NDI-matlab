classdef DocumentsTest < matlab.unittest.TestCase
    % If running this on cloud, need to set password and username for
    % testing as environment variables.

    properties (Constant)
        DatasetName = 'NDI_UNITTEST_DATASET';
    end

    properties
        DatasetID (1,1) string = missing % ID of dataset used for all tests
        Narrative (1,:) string % Stores the narrative for each test
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            % This runs once before any tests.
            % It checks for credentials and aborts if they are missing.
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");

            if isempty(username) || isempty(password)
                testCase.fatalAssertFail(...
                    'Required environment variables NDI_CLOUD_USERNAME or NDI_CLOUD_PASSWORD are not set. Halting tests.');
            end
        end
    end

    methods (TestMethodSetup)
        % This now runs BEFORE EACH test method, creating a fresh dataset every time.
        function setupNewDataset(testCase)
            import matlab.unittest.fixtures.SuppressedWarningsFixture
            testCase.applyFixture(SuppressedWarningsFixture('MATLAB:structRefFromNonStruct'));

            unique_name = testCase.DatasetName + "_" + string(did.ido.unique_id());
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
        function testVerifyNoDocuments(testCase)
            testCase.Narrative = "Begin testVerifyNoDocuments";
            narrative = testCase.Narrative; % Make a local copy
            
            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;

            % Step 1: Call documentCount
            narrative(end+1) = "Preparing to call ndi.cloud.api.documents.documentCount.";
            [b_count, ans_count, resp_count, url_count] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count);
            narrative(end+1) = "Testing: Verifying the documentCount is 0 for a new dataset.";
            msg_count = ndi.unittest.cloud.APIMessage(narrative, b_count, ans_count, resp_count, url_count);
            testCase.verifyEqual(ans_count, 0, msg_count);
            narrative(end+1) = "Document count is correctly 0.";

            % Step 2: Call countDocuments
            narrative(end+1) = "Preparing to call ndi.cloud.api.documents.countDocuments.";
            [b_count2, ans_count2, resp_count2, url_count2] = ndi.cloud.api.documents.countDocuments(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count2);
            narrative(end+1) = "Testing: Verifying the countDocuments is 0 for a new dataset.";
            msg_count2 = ndi.unittest.cloud.APIMessage(narrative, b_count2, ans_count2, resp_count2, url_count2);
            testCase.verifyEqual(ans_count2, 0, msg_count2);
            narrative(end+1) = "CountDocuments is correctly 0.";
            testCase.Narrative = narrative; % Save back to property for teardown
        end
        
        function testAddGetDeleteDocumentLifecycle(testCase)
            testCase.Narrative = "Begin testAddGetDeleteDocumentLifecycle";
            narrative = testCase.Narrative;
            
            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;

            % Step 1: Add a document
            doc_to_add = ndi.document('base', 'base.name', 'My Test Document');
            json_doc = jsonencodenan(doc_to_add.document_properties);
            narrative(end+1) = "Preparing to add a new document.";
            [b_add, ans_add, resp_add, url_add] = ndi.cloud.api.documents.addDocument(testCase.DatasetID, json_doc);
            narrative(end+1) = "Attempted to call API with URL " + string(url_add);
            narrative(end+1) = "Testing: Verifying the add document API call was successful (APICallSuccessFlag should be true).";
            msg_add = ndi.unittest.cloud.APIMessage(narrative, b_add, ans_add, resp_add, url_add);
            testCase.verifyTrue(b_add, msg_add);
            narrative(end+1) = "Document added successfully. Cloud Document ID: " + ans_add.id;
            cloudDocumentID = ans_add.id;

            % Step 2: Verify count is 1
            narrative(end+1) = "Preparing to confirm document count is 1 after adding a document.";
            [b_count, ans_count, resp_count, url_count] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count);
            narrative(end+1) = "Testing: Verifying the document count is 1.";
            msg_count = ndi.unittest.cloud.APIMessage(narrative, b_count, ans_count, resp_count, url_count);
            testCase.verifyEqual(ans_count, 1, msg_count);
            narrative(end+1) = "Document count is correctly 1.";

            % Step 3: Get the document back and verify content
            narrative(end+1) = "Preparing to get the document back from the cloud.";
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.documents.getDocument(testCase.DatasetID, cloudDocumentID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_get);
            narrative(end+1) = "Testing: Verifying the get document API call was successful (APICallSuccessFlag should be true).";
            msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyTrue(b_get, msg_get);
            narrative(end+1) = "Testing: Verifying the content of the retrieved document.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyEqual(ans_get.base.name, 'My Test Document', msg_get_content);
            narrative(end+1) = "Retrieved document content is correct.";

            % Step 4: Delete the document
            narrative(end+1) = "Preparing to delete the document.";
            [b_del, ans_del, resp_del, url_del] = ndi.cloud.api.documents.deleteDocument(testCase.DatasetID, cloudDocumentID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_del);
            narrative(end+1) = "Testing: Verifying the delete document API call was successful (APICallSuccessFlag should be true).";
            msg_del = ndi.unittest.cloud.APIMessage(narrative, b_del, ans_del, resp_del, url_del);
            testCase.verifyTrue(b_del, msg_del);
            narrative(end+1) = "Document deleted successfully.";

            % Step 5: Verify count is 0
            narrative(end+1) = "Preparing to confirm document count is 0 after deleting a document.";
            [b_count_final, ans_count_final, resp_count_final, url_count_final] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count_final);
            narrative(end+1) = "Testing: Verifying the document count is 0.";
            msg_count_final = ndi.unittest.cloud.APIMessage(narrative, b_count_final, ans_count_final, resp_count_final, url_count_final);
            testCase.verifyEqual(ans_count_final, 0, msg_count_final);
            narrative(end+1) = "Document count is correctly 0.";
            testCase.Narrative = narrative; % Save back to property for teardown
        end
        
        function testUpdateDocument(testCase)
            testCase.Narrative = "Begin testUpdateDocument";
            narrative = testCase.Narrative;
            
            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;

            % Step 1: Add a document
            doc_to_add = ndi.document('base', 'base.name', 'Original Name');
            json_doc = jsonencodenan(doc_to_add.document_properties);
            narrative(end+1) = "Preparing to add an initial document for update test.";
            [b_add, ans_add, ~, ~] = ndi.cloud.api.documents.addDocument(testCase.DatasetID, json_doc);
            testCase.fatalAssertTrue(b_add, "Failed to add initial document for update test.");
            cloudDocumentID = ans_add.id;
            narrative(end+1) = "Initial document added with ID: " + cloudDocumentID;
            
            % Step 2: Update the document
            doc_updated = ndi.document('base', 'base.name', 'Updated Name');
            narrative(end+1) = "Preparing to update the document.";
            [b_upd, ans_upd, resp_upd, url_upd] = ndi.cloud.api.documents.updateDocument(testCase.DatasetID, cloudDocumentID, jsonencodenan(doc_updated.document_properties));
            narrative(end+1) = "Attempted to call API with URL " + string(url_upd);
            narrative(end+1) = "Testing: Verifying the update document API call was successful (APICallSuccessFlag should be true).";
            msg_upd = ndi.unittest.cloud.APIMessage(narrative, b_upd, ans_upd, resp_upd, url_upd);
            testCase.verifyTrue(b_upd, msg_upd);
            narrative(end+1) = "Document update call successful.";
            
            % Step 3: Get the document back and verify the new name
            narrative(end+1) = "Preparing to get the updated document to verify its content.";
            [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.documents.getDocument(testCase.DatasetID, cloudDocumentID);
            testCase.fatalAssertTrue(b_get, "Failed to get document after update.");
            narrative(end+1) = "Testing: Verifying the name of the retrieved document has been updated.";
            msg_get_content = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
            testCase.verifyEqual(ans_get.base.name, 'Updated Name', msg_get_content);
            narrative(end+1) = "Updated document content is correct.";
            testCase.Narrative = narrative; % Save back to property for teardown
        end

        function testBulkDocumentOperations(testCase)
            testCase.Narrative = "Begin testBulkDocumentOperations";
            narrative = testCase.Narrative;
            
            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;

            numDocs = 5;
            cloudDocIDs = strings(1, numDocs);

            % Step 1-5: Add 5 documents
            narrative(end+1) = "Preparing to add " + numDocs + " documents.";
            for i = 1:numDocs
                doc_to_add = ndi.document('base', 'base.name', "doc " + i);
                json_doc = jsonencodenan(doc_to_add.document_properties);
                [b_add, ans_add, ~, ~] = ndi.cloud.api.documents.addDocument(testCase.DatasetID, json_doc);
                testCase.fatalAssertTrue(b_add, "Failed to add document #" + i + " in bulk test.");
                cloudDocIDs(i) = ans_add.id;
            end
            narrative(end+1) = "Successfully added " + numDocs + " documents.";

            % Step 6: Test DocumentCount
            narrative(end+1) = "Preparing to confirm document count is " + numDocs + " after adding documents.";
            [b_count, ans_count, resp_count, url_count] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count);
            narrative(end+1) = "Testing: Verifying the document count is " + numDocs + ".";
            msg_count = ndi.unittest.cloud.APIMessage(narrative, b_count, ans_count, resp_count, url_count);
            testCase.verifyEqual(ans_count, numDocs, msg_count);
            narrative(end+1) = "Document count is correctly " + numDocs + ".";

            % Step 7: Test listDatasetDocuments (paginated)
            narrative(end+1) = "Preparing to test paginated document listing.";
            pageSize = 3;
            [b_list, ans_list, resp_list, url_list] = ndi.cloud.api.documents.listDatasetDocuments(testCase.DatasetID, 'pageSize', pageSize);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list);
            narrative(end+1) = "Testing: Verifying the paginated list API call was successful (APICallSuccessFlag should be true).";
            msg_list = ndi.unittest.cloud.APIMessage(narrative, b_list, ans_list, resp_list, url_list);
            testCase.verifyTrue(b_list, msg_list);
            narrative(end+1) = "Testing: Verifying the number of documents on the first page is correct.";
            testCase.verifyNumElements(ans_list.documents, pageSize, msg_list);
            narrative(end+1) = "Paginated list returned correct number of documents for the page size.";

            % Step 8: Test listDatasetDocumentsAll
            narrative(end+1) = "Preparing to test 'list all' documents functionality.";
            [b_list_all, ans_list_all, resp_list_all, url_list_all] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list_all(1)); % Show first URL of potentially many
            narrative(end+1) = "Testing: Verifying the 'list all' API call was successful (APICallSuccessFlag should be true).";
            msg_list_all = ndi.unittest.cloud.APIMessage(narrative, b_list_all, ans_list_all, resp_list_all, url_list_all);
            testCase.verifyTrue(b_list_all, msg_list_all);
            narrative(end+1) = "Testing: Verifying the total number of documents returned by 'list all' is correct.";
            testCase.verifyNumElements(ans_list_all.documents, numDocs, msg_list_all);
            narrative(end+1) = "'List all' returned the correct total number of documents.";

            % Step 9: Bulk delete all documents
            narrative(end+1) = "Preparing to bulk delete all documents.";
            [b_bulk_del, ans_bulk_del, resp_bulk_del, url_bulk_del] = ndi.cloud.api.documents.bulkDeleteDocuments(testCase.DatasetID, cloudDocIDs);
            narrative(end+1) = "Attempted to call API with URL " + string(url_bulk_del);
            narrative(end+1) = "Testing: Verifying the bulk delete API call was successful (APICallSuccessFlag should be true).";
            msg_bulk_del = ndi.unittest.cloud.APIMessage(narrative, b_bulk_del, ans_bulk_del, resp_bulk_del, url_bulk_del);
            testCase.verifyTrue(b_bulk_del, msg_bulk_del);
            narrative(end+1) = "Bulk delete call successful.";
            
            % Step 10: Confirm document lists are empty
            narrative(end+1) = "Preparing to confirm paginated document list is empty after deletion.";
            [b_list_final, ans_list_final, resp_list_final, url_list_final] = ndi.cloud.api.documents.listDatasetDocuments(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_list_final);
            narrative(end+1) = "Testing: Verifying the paginated list API call was successful (APICallSuccessFlag should be true).";
            msg_list_final = ndi.unittest.cloud.APIMessage(narrative, b_list_final, ans_list_final, resp_list_final, url_list_final);
            testCase.verifyTrue(b_list_final, msg_list_final);
            narrative(end+1) = "Testing: Verifying the paginated document list is empty.";
            testCase.verifyTrue(isempty(ans_list_final.documents), msg_list_final);
            narrative(end+1) = "Paginated document list is correctly empty.";

            narrative(end+1) = "Preparing to confirm 'list all' document list is empty after deletion.";
            [b_list_all_final, ans_list_all_final, resp_list_all_final, url_list_all_final] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API. Note: URL will be empty if there are no pages to fetch.";
            narrative(end+1) = "Testing: Verifying the 'list all' API call was successful (APICallSuccessFlag should be true).";
            msg_list_all_final = ndi.unittest.cloud.APIMessage(narrative, b_list_all_final, ans_list_all_final, resp_list_all_final, url_list_all_final);
            testCase.verifyTrue(b_list_all_final, msg_list_all_final);
            narrative(end+1) = "Testing: Verifying the 'list all' document list is empty.";
            testCase.verifyTrue(isempty(ans_list_all_final.documents), msg_list_all_final);
            narrative(end+1) = "'List all' document list is correctly empty.";

            % Step 11: Confirm document count is zero
            narrative(end+1) = "Preparing to confirm document count is zero after deletion.";
            [b_count_final, ans_count_final, resp_count_final, url_count_final] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count_final);
            narrative(end+1) = "Testing: Verifying the final document count is 0.";
            msg_count_final = ndi.unittest.cloud.APIMessage(narrative, b_count_final, ans_count_final, resp_count_final, url_count_final);
            testCase.verifyEqual(ans_count_final, 0, msg_count_final);
            narrative(end+1) = "Final document count is correctly 0.";
            testCase.Narrative = narrative; % Save back to property for teardown
        end

        function testBulkUploadAndDownload(testCase)
            testCase.Narrative = "Begin testBulkUploadAndDownload";
            narrative = testCase.Narrative;
            
            narrative(end+1) = "SETUP: Using temporary dataset ID: " + testCase.DatasetID;
            
            % Step 1: Create local test documents
            numDocs = 5;
            narrative(end+1) = "Preparing to create " + numDocs + " local test documents.";
            testDocuments = cell(1, numDocs);
            for i=1:numDocs
                testDocuments{i} = ndi.document('base', 'base.name', "Bulk Test Doc " + i);
            end
            narrative(end+1) = "Local test documents created successfully.";
            
            % Step 2: Upload the collection using the bulk zip method
            narrative(end+1) = "Preparing to upload document collection using the bulk zip method.";
            try
                [b_upload, ~] = ndi.cloud.upload.upload_document_collection(testCase.DatasetID, testDocuments);
                narrative(end+1) = "Bulk upload call completed.";
                testCase.fatalAssertTrue(b_upload, "The bulk upload helper function indicated a failure.");
            catch ME
                testCase.fatalAssertFail("The bulk upload helper function threw an unexpected error: " + ME.message);
            end
            
            % Step 3: Wait and verify the document count
            narrative(end+1) = "Pausing for 10 seconds to allow the server to process the bulk upload.";
            pause(10);
            
            narrative(end+1) = "Preparing to verify document count after bulk upload.";
            [b_count, ans_count, resp_count, url_count] = ndi.cloud.api.documents.documentCount(testCase.DatasetID);
            narrative(end+1) = "Attempted to call API with URL " + string(url_count);
            narrative(end+1) = "Testing: Verifying the document count is " + numDocs + ".";
            msg_count = ndi.unittest.cloud.APIMessage(narrative, b_count, ans_count, resp_count, url_count);
            testCase.verifyEqual(ans_count, numDocs, msg_count);
            narrative(end+1) = "Document count is correct after bulk upload.";
            
            % Step 4: List all documents to get their cloud IDs
            narrative(end+1) = "Listing all documents to retrieve their cloud IDs.";
            [b_list, ans_list, resp_list, url_list] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.DatasetID);
            testCase.fatalAssertTrue(b_list, "Failed to list documents after bulk upload.");
            cloudDocsSummary = ans_list.documents;
            testCase.verifyNumElements(cloudDocsSummary, numDocs, "List all did not return the correct number of documents.");
            cloudDocIDsFromList = string({cloudDocsSummary.id});
            narrative(end+1) = "Successfully listed document summaries.";

            % Step 5: Get each document individually and verify its content
            narrative(end+1) = "Getting each document individually to verify its content.";
            retrieved_names = strings(1, numDocs);
            for i=1:numel(cloudDocIDsFromList)
                doc_id = cloudDocIDsFromList(i);
                [b_get, ans_get, resp_get, url_get] = ndi.cloud.api.documents.getDocument(testCase.DatasetID, doc_id);
                msg_get = ndi.unittest.cloud.APIMessage(narrative, b_get, ans_get, resp_get, url_get);
                testCase.fatalAssertTrue(b_get, "Failed to get document with ID " + doc_id + ". " + msg_get);
                retrieved_names(i) = ans_get.base.name;
            end
            original_names_for_check = "Bulk Test Doc " + (1:numDocs);
            testCase.verifyTrue(isempty(setxor(retrieved_names, original_names_for_check)), ...
                "The names of the individually retrieved documents do not match the expected names.");
            narrative(end+1) = "Individually retrieved documents have been verified successfully.";

            % Step 6: Test Bulk Download
            narrative(end+1) = "Preparing to test bulk download of all documents.";
            try
                downloadedDocuments = ndi.cloud.download.download_document_collection(testCase.DatasetID);
                narrative(end+1) = "Bulk download call completed.";
            catch ME
                testCase.fatalAssertFail("The bulk download helper function threw an unexpected error: " + ME.message);
            end
            
            % Step 7: Verify the content of the bulk-downloaded documents
            narrative(end+1) = "Verifying the content of the bulk-downloaded documents.";
            testCase.verifyNumElements(downloadedDocuments, numDocs, "Bulk download did not return the correct number of documents.");
            
            original_names = cellfun(@(d) d.document_properties.base.name, testDocuments, 'UniformOutput', false);
            downloaded_names = cellfun(@(d) d.document_properties.base.name, downloadedDocuments, 'UniformOutput', false);
            
            testCase.verifyTrue(isempty(setxor(original_names, downloaded_names)), ...
                "The names of the bulk-downloaded documents do not match the names of the originally uploaded documents.");
            narrative(end+1) = "Bulk-downloaded documents have been verified successfully.";
            
            testCase.Narrative = narrative; % Save back to property for teardown
        end        
    end
end

