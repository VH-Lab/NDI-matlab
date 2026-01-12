classdef UploadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %UploadNewTest Test for ndi.cloud.sync.uploadNew

    properties
        Narrative (1,:) string
    end

    methods(Test)

        function testInitialUpload(testCase)
            testCase.Narrative = "Begin UploadNewTest: testInitialUpload";
            narrative = testCase.Narrative;

            % Test initial upload with no sync index
            narrative(end+1) = "SETUP: Creating local document 'test_doc_1' in dataset " + testCase.localDataset.id();
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            narrative(end+1) = "Calling ndi.cloud.sync.uploadNew...";
            [success, msg, report] = ndi.cloud.sync.uploadNew(testCase.localDataset);

            narrative(end+1) = "Verifying uploadNew success...";
            % For internal sync functions, we mimic the API response structure for APIMessage
            sync_message = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.uploadNew");

            testCase.verifyTrue(success, sync_message);
            testCase.verifyEmpty(msg, "Error message should be empty. " + sync_message);
            testCase.verifyTrue(isfield(report, 'uploaded_document_ids'), "Report should have 'uploaded_document_ids'. " + sync_message);

            % Verify doc ID is uploaded
            narrative(end+1) = "Verifying doc ID is in uploaded_document_ids...";
            testCase.verifyTrue(any(strcmp(report.uploaded_document_ids, doc1.id())), ...
                "Local doc ID should be uploaded. " + sync_message);

            % Verify that the document is now on the remote
            narrative(end+1) = "Calling listDatasetDocumentsAll to verify remote state...";
            [b, remote_docs, resp, url] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);

            narrative(end+1) = "Verifying listDatasetDocumentsAll success...";
            list_message = ndi.unittest.cloud.APIMessage(narrative, b, remote_docs, resp, url);
            testCase.verifyTrue(b, list_message);

            foundTestDoc = false;
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,"test_doc_1")
                    foundTestDoc = true;
                    break;
                end
            end

            narrative(end+1) = "Verifying test_doc_1 is found on remote...";
            testCase.verifyEqual(foundTestDoc, true, "test_doc_1 not found on remote. " + list_message);

            narrative(end+1) = "testInitialUpload completed successfully.";
            testCase.Narrative = narrative;
        end

        function testDryRun(testCase)
            testCase.Narrative = "Begin UploadNewTest: testDryRun";
            narrative = testCase.Narrative;

            % Test DryRun option
            narrative(end+1) = "SETUP: Creating local document 'test_doc_1'...";
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            narrative(end+1) = "Calling ndi.cloud.sync.uploadNew with DryRun=true...";
            [success, msg, report] = ndi.cloud.sync.uploadNew(testCase.localDataset, "DryRun", true);

            narrative(end+1) = "Verifying uploadNew success...";
            sync_message = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.uploadNew(DryRun)");

            testCase.verifyTrue(success, sync_message);
            testCase.verifyEmpty(msg, "Error message should be empty. " + sync_message);
            testCase.verifyEmpty(report.uploaded_document_ids, "Uploaded IDs should be empty for DryRun. " + sync_message);

            % Verify that the document is NOT on the remote
            narrative(end+1) = "Calling listDatasetDocumentsAll to verify remote state (should be empty of test doc)...";
            [b, remote_docs, resp, url] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);

            list_message = ndi.unittest.cloud.APIMessage(narrative, b, remote_docs, resp, url);
            testCase.verifyTrue(b, list_message);

            foundTestDoc = false;
            if ~isempty(remote_docs)
                for i=1:numel(remote_docs)
                    if strcmp(remote_docs(i).name,"test_doc_1")
                        foundTestDoc = true;
                        break;
                    end
                end
            end

            narrative(end+1) = "Verifying test_doc_1 is NOT found on remote...";
            testCase.verifyEqual(foundTestDoc, false, "test_doc_1 was found, should not have been added during DryRun. " + list_message);

            narrative(end+1) = "testDryRun completed successfully.";
            testCase.Narrative = narrative;
        end

        function testIncrementalUpload(testCase)
            testCase.Narrative = "Begin UploadNewTest: testIncrementalUpload";
            narrative = testCase.Narrative;

            % Test uploading only new documents

            % 1. Initial sync
            narrative(end+1) = "SETUP: Creating first local document and performing initial sync...";
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);
            
            % We don't verify the first sync in detail as it's just setup for the incremental part,
            % but we should check it succeeded.
            [s1, m1, r1] = ndi.cloud.sync.uploadNew(testCase.localDataset);
            if ~s1
                sync_message = ndi.unittest.cloud.APIMessage(narrative, s1, r1, [], "ndi.cloud.sync.uploadNew(Initial)");
                testCase.verifyTrue(s1, "Initial sync failed. " + sync_message);
            end

            % 2. Add a new document and sync again
            narrative(end+1) = "SETUP: Creating second local document 'test_doc_2'...";
            doc2 = ndi.document('base', 'base.name', 'test_doc_2','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc2);

            narrative(end+1) = "Calling ndi.cloud.sync.uploadNew (Incremental)...";
            [success, msg, report] = ndi.cloud.sync.uploadNew(testCase.localDataset);

            narrative(end+1) = "Verifying incremental uploadNew success...";
            sync_message = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.uploadNew(Incremental)");

            testCase.verifyTrue(success, sync_message);
            testCase.verifyEmpty(msg, "Error message should be empty. " + sync_message);

            % Verify doc2 ID is uploaded
            narrative(end+1) = "Verifying new doc ID is in uploaded_document_ids...";
            testCase.verifyTrue(any(strcmp(report.uploaded_document_ids, doc2.id())), ...
                "New local doc ID should be uploaded. " + sync_message);

            % 3. Verify that both documents are on the remote
            narrative(end+1) = "Calling listDatasetDocumentsAll to verify remote state...";
            [b, remote_docs, resp, url] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);

            list_message = ndi.unittest.cloud.APIMessage(narrative, b, remote_docs, resp, url);
            testCase.verifyTrue(b, list_message);

            foundTestDoc1 = false;
            foundTestDoc2 = false;
            if ~isempty(remote_docs)
                for i=1:numel(remote_docs)
                    if strcmp(remote_docs(i).name,"test_doc_1")
                        foundTestDoc1 = true;
                    end
                    if strcmp(remote_docs(i).name,"test_doc_2")
                        foundTestDoc2 = true;
                    end
                end
            end

            narrative(end+1) = "Verifying both documents are found on remote...";
            testCase.verifyEqual(foundTestDoc1, true, "test_doc_1 not found. " + list_message);
            testCase.verifyEqual(foundTestDoc2, true, "test_doc_2 not found. " + list_message);

            narrative(end+1) = "testIncrementalUpload completed successfully.";
            testCase.Narrative = narrative;
        end
    end
end
