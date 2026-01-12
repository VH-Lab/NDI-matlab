classdef TwoWaySyncTest < ndi.unittest.cloud.sync.BaseSyncTest
    %TwoWaySyncTest Test for ndi.cloud.sync.twoWaySync

    properties
        Narrative (1,:) string
    end

    methods(Test)

        function testTwoWaySync(testCase)
            % Test two-way sync, including uploads and downloads

            testCase.Narrative = "Begin TwoWaySyncTest: testTwoWaySync";
            narrative = testCase.Narrative;

            % 1. Initial State: Local has doc1, remote has doc2
            narrative(end+1) = "SETUP: Creating local document 'local_doc_1' and adding to local dataset.";
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            narrative(end+1) = "SETUP: Creating remote document 'remote_doc_2' and uploading to remote dataset directly via API.";
            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());

            narrative(end+1) = "Preparing to call ndi.cloud.api.documents.addDocument for 'remote_doc_2'.";
            [b_add, res_add, apiResponse_add, apiURL_add] = ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_add);

            narrative(end+1) = "Testing: Verifying the manual document upload was successful (APICallSuccessFlag should be true).";
            add_message = ndi.unittest.cloud.APIMessage(narrative, b_add, res_add, apiResponse_add, apiURL_add);
            testCase.verifyTrue(b_add, add_message);

            % 2. Execute
            narrative(end+1) = "EXECUTE: Calling ndi.cloud.sync.twoWaySync on the local dataset.";
            [success, msg, report] = ndi.cloud.sync.twoWaySync(testCase.localDataset);

            % For local sync function, we don't have a single API response/URL. We use the report as the body.
            narrative(end+1) = "Testing: Verifying twoWaySync returned success.";
            sync_message = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.twoWaySync");
            testCase.verifyTrue(success, sync_message);

            narrative(end+1) = "Testing: Verifying twoWaySync returned an empty error message.";
            testCase.verifyEmpty(msg, sync_message);

            % Check report
            narrative(end+1) = "Testing: Verifying the report contains 'uploaded_document_ids' and 'downloaded_document_ids'.";
            testCase.verifyTrue(isfield(report, 'uploaded_document_ids'), "Report missing uploaded_document_ids field. " + sync_message);
            testCase.verifyTrue(isfield(report, 'downloaded_document_ids'), "Report missing downloaded_document_ids field. " + sync_message);

            % Verify specific IDs
            narrative(end+1) = "Testing: Verifying local_doc_1 ID is in uploaded_document_ids.";
            testCase.verifyTrue(any(strcmp(report.uploaded_document_ids, doc1.id())), ...
                "Local doc ID should be uploaded. " + sync_message);

            narrative(end+1) = "Testing: Verifying remote_doc_2 ID is in downloaded_document_ids.";
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc2.id())), ...
                "Remote doc ID should be downloaded. " + sync_message);

            % 3. Verify
            % Local should have doc1 and doc2 (plus the link doc, but regex filters)
            narrative(end+1) = "VERIFY: Searching local database for documents matching pattern '(.*)_doc_(.*)'.";
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','regexp','(.*)_doc_(.*)')); 

            narrative(end+1) = "Testing: Verifying exactly 2 documents found locally.";
            testCase.verifyNumElements(local_docs, 2, "Expected 2 documents locally. " + sync_message);

            if numel(local_docs)==2
                local_names = sort(cellfun(@(x) char(x.document_properties.base.name), local_docs, 'UniformOutput', false));
                testCase.verifyEqual(local_names{1}, 'local_doc_1', "Expected local_doc_1 to be present locally. " + sync_message);
                testCase.verifyEqual(local_names{2}, 'remote_doc_2', "Expected remote_doc_2 to be present locally. " + sync_message);
            end

            % Remote should have doc1 and doc2
            narrative(end+1) = "VERIFY: Listing all documents from remote dataset to verify sync results.";
            narrative(end+1) = "Preparing to call ndi.cloud.api.documents.listDatasetDocumentsAll.";
            [success_list, remoteDocs, apiResponse_list, apiURL_list] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            narrative(end+1) = "Attempted to call API with URL " + string(apiURL_list);

            narrative(end+1) = "Testing: Verifying remote list call was successful.";
            list_message = ndi.unittest.cloud.APIMessage(narrative, success_list, remoteDocs, apiResponse_list, apiURL_list);
            testCase.verifyEqual(logical(success_list), true, list_message);

            foundLocalDoc1 = false;
            foundRemoteDoc2 = false;
            for i=1:numel(remoteDocs)
                if strcmp(remoteDocs(i).name,"local_doc_1")
                    foundLocalDoc1 = true;
                end
                if strcmp(remoteDocs(i).name,"remote_doc_2")
                    foundRemoteDoc2 = true;
                end
            end

            narrative(end+1) = "Testing: Verifying local_doc_1 is found on remote.";
            testCase.verifyEqual(foundLocalDoc1, true, "Failed to find local_doc_1 on remote. " + list_message);

            narrative(end+1) = "Testing: Verifying remote_doc_2 is found on remote.";
            testCase.verifyEqual(foundRemoteDoc2, true, "Failed to find remote_doc_2 on remote. " + list_message);

            narrative(end+1) = "TwoWaySyncTest completed successfully.";
            testCase.Narrative = narrative;
        end

    end
end
