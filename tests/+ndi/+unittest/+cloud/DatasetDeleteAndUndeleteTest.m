classdef DatasetDeleteAndUndeleteTest < matlab.unittest.TestCase
    % DatasetDeleteAndUndeleteTest - Test suite for dataset deletion and undeletion scenarios.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_DEL_UNDEL_';
    end

    properties
        Narrative (1,:) string
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.fatalAssertNotEmpty(username, 'NDI_CLOUD_USERNAME not set.');
            testCase.fatalAssertNotEmpty(password, 'NDI_CLOUD_PASSWORD not set.');
        end
    end

    methods (Test)
        function testImmediateDeletion(testCase)
            testCase.Narrative = "Begin testImmediateDeletion";
            narrative = testCase.Narrative;

            % 1. Create Dataset
            narrative(end+1) = "SETUP: Creating dataset for immediate deletion.";
            unique_name = testCase.DatasetNamePrefix + "NOW_" + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            testCase.fatalAssertTrue(b, "Failed to create dataset.");
            narrative(end+1) = "Dataset created: " + cloudDatasetID;

            % 2. Add a document
            narrative(end+1) = "SETUP: Adding a document.";
            doc_to_add = ndi.document('base', 'base.name', 'Test Document');
            json_doc = jsonencodenan(doc_to_add.document_properties);
            [b_add, ans_add] = ndi.cloud.api.documents.addDocument(cloudDatasetID, json_doc);
            testCase.fatalAssertTrue(b_add, "Failed to add document.");
            narrative(end+1) = "Document added.";

            % 3. Delete immediately (when='now')
            narrative(end+1) = "ACTION: Deleting dataset immediately.";
            [b_del, ans_del] = ndi.cloud.api.datasets.deleteDataset(cloudDatasetID, 'when', 'now');
            testCase.verifyTrue(b_del, "Failed to delete dataset.");
            narrative(end+1) = "Dataset deleted with when='now'.";

            % 4. Wait 10 seconds
            narrative(end+1) = "WAIT: Waiting 10 seconds...";
            pause(10);

            % 5. Try to Undelete (Should Fail)
            narrative(end+1) = "ACTION: Attempting to undelete dataset.";
            [b_undel, ans_undel, resp_undel] = ndi.cloud.api.datasets.undeleteDataset(cloudDatasetID);

            % Expect failure (404 Not Found or 400 Bad Request depending on implementation)
            narrative(end+1) = "VERIFICATION: Undelete should fail.";
            testCase.verifyFalse(b_undel, "Undelete succeeded but should have failed for immediate deletion.");

            if ~b_undel
                 % 404 is expected if it's gone.
                 testCase.verifyEqual(resp_undel.StatusCode, matlab.net.http.StatusCode.NotFound, "Expected 404 Not Found.");
            end

            testCase.Narrative = narrative;
        end

        function testSoftDeletionAndUndelete(testCase)
            testCase.Narrative = "Begin testSoftDeletionAndUndelete";
            narrative = testCase.Narrative;

            % 1. Create Dataset
            narrative(end+1) = "SETUP: Creating dataset for soft deletion.";
            unique_name = testCase.DatasetNamePrefix + "SOFT_" + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            testCase.fatalAssertTrue(b, "Failed to create dataset.");
            narrative(end+1) = "Dataset created: " + cloudDatasetID;

            % Ensure cleanup if test fails or after success (cleanly remove it)
            % Using 'now' to ensure it is really gone after test.
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID, 'when', 'now'));

            % 2. Add a document
            narrative(end+1) = "SETUP: Adding a document.";
            doc_to_add = ndi.document('base', 'base.name', 'Test Document');
            json_doc = jsonencodenan(doc_to_add.document_properties);
            [b_add, ans_add] = ndi.cloud.api.documents.addDocument(cloudDatasetID, json_doc);
            testCase.fatalAssertTrue(b_add, "Failed to add document.");
            narrative(end+1) = "Document added.";

            % 3. Delete with when='1d'
            narrative(end+1) = "ACTION: Deleting dataset with when='1d'.";
            [b_del, ans_del] = ndi.cloud.api.datasets.deleteDataset(cloudDatasetID, 'when', '1d');
            testCase.verifyTrue(b_del, "Failed to delete dataset.");
            narrative(end+1) = "Dataset deleted with when='1d'.";

            % 4. Undelete
            narrative(end+1) = "ACTION: Attempting to undelete dataset.";
            [b_undel, ans_undel] = ndi.cloud.api.datasets.undeleteDataset(cloudDatasetID);
            testCase.verifyTrue(b_undel, "Failed to undelete dataset.");
            narrative(end+1) = "Dataset undelete initiated.";

            % 5. Verify it is visible again
            narrative(end+1) = "VERIFICATION: Dataset should be visible.";
            pause(5);
            [b_get_after, ans_get_after] = ndi.cloud.api.datasets.getDataset(cloudDatasetID);
            testCase.verifyTrue(b_get_after, "Dataset not visible after undelete.");

            testCase.Narrative = narrative;
        end

        function testListDeletedItems(testCase)
            testCase.Narrative = "Begin testListDeletedItems";
            narrative = testCase.Narrative;

            % 1. Create Dataset
            narrative(end+1) = "SETUP: Creating dataset for deletion listing test.";
            unique_name = testCase.DatasetNamePrefix + "LIST_" + string(did.ido.unique_id());
            datasetInfo = struct("name", unique_name);
            [b, cloudDatasetID, resp, url] = ndi.cloud.api.datasets.createDataset(datasetInfo);
            testCase.fatalAssertTrue(b, "Failed to create dataset.");

            % Ensure cleanup
            testCase.addTeardown(@() ndi.cloud.api.datasets.deleteDataset(cloudDatasetID, 'when', 'now'));

            % 2. Add a document
            narrative(end+1) = "SETUP: Adding a document.";
            doc_to_add = ndi.document('base', 'base.name', 'Deleted Test Document');
            json_doc = jsonencodenan(doc_to_add.document_properties);
            [b_add, ans_add] = ndi.cloud.api.documents.addDocument(cloudDatasetID, json_doc);
            testCase.fatalAssertTrue(b_add, "Failed to add document.");
            cloudDocID = ans_add.id;

            % 3. Soft Delete Document
            narrative(end+1) = "ACTION: Soft deleting document.";
            [b_del_doc, ~] = ndi.cloud.api.documents.deleteDocument(cloudDatasetID, cloudDocID, 'when', '1d');
            testCase.verifyTrue(b_del_doc, "Failed to soft delete document.");

            pause(5);

            % 4. List Deleted Documents
            narrative(end+1) = "VERIFICATION: Listing deleted documents.";
            [b_list_docs, ans_list_docs] = ndi.cloud.api.documents.listDeletedDocuments(cloudDatasetID, 'pageSize', 100);
            testCase.verifyTrue(b_list_docs, "Failed to list deleted documents.");

            % Verify our document is in the list
            foundDoc = false;
            if isstruct(ans_list_docs) && isfield(ans_list_docs, 'documents')
                 docs = ans_list_docs.documents;
                 if isstruct(docs)
                     ids = {docs.id};
                     foundDoc = any(strcmp(ids, cloudDocID));
                 elseif iscell(docs)
                     ids = cellfun(@(x) x.id, docs, 'UniformOutput', false);
                     foundDoc = any(strcmp(ids, cloudDocID));
                 end
            end
            testCase.verifyTrue(foundDoc, "Deleted document not found in list.");

            % 5. Soft Delete Dataset
            narrative(end+1) = "ACTION: Soft deleting dataset.";
            [b_del_ds, ~] = ndi.cloud.api.datasets.deleteDataset(cloudDatasetID, 'when', '1d');
            testCase.verifyTrue(b_del_ds, "Failed to soft delete dataset.");

            pause(5);

            % 6. List Deleted Datasets
            narrative(end+1) = "VERIFICATION: Listing deleted datasets.";
            [b_list_ds, ans_list_ds] = ndi.cloud.api.datasets.listDeletedDatasets();
            testCase.verifyTrue(b_list_ds, "Failed to list deleted datasets.");

            % Verify our dataset is in the list
            foundDs = false;
            ids = {};
            if isstruct(ans_list_ds) && isfield(ans_list_ds, 'datasets')
                dss = ans_list_ds.datasets;
                if isstruct(dss)
                    ids = {dss.id};
                    foundDs = any(strcmp(ids, cloudDatasetID));
                elseif iscell(dss)
                    ids = cellfun(@(x) x.id, dss, 'UniformOutput', false);
                    foundDs = any(strcmp(ids, cloudDatasetID));
                end
            end

            if ~foundDs
                fprintf('Expected dataset ID: %s\n', cloudDatasetID);
                fprintf('Found dataset IDs:\n');
                for k=1:numel(ids)
                    fprintf('%s\n', ids{k});
                end
            end

            testCase.verifyTrue(foundDs, "Deleted dataset not found in list.");

            testCase.Narrative = narrative;
        end
    end
end
