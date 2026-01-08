classdef MirrorFromRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorFromRemoteTest Test for ndi.cloud.sync.mirrorFromRemote

    properties
        Narrative (1,:) string
    end

    methods(Test)

        function testMirrorFromRemote(testCase)
            % Test mirroring from remote, including downloads and deletions

            testCase.Narrative = "Begin MirrorFromRemoteTest: testMirrorFromRemote";
            narrative = testCase.Narrative;

            % 1. Initial State: Local has doc1, remote has doc2
            narrative(end+1) = "SETUP: Creating local document 'local_doc_1' and remote document 'remote_doc_2'.";
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            narrative(end+1) = "Preparing to call ndi.cloud.sync.mirrorFromRemote.";
            [success, msg, report] = ndi.cloud.sync.mirrorFromRemote(testCase.localDataset);
            narrative(end+1) = "Called ndi.cloud.sync.mirrorFromRemote.";

            narrative(end+1) = "Testing: Verifying the function call was successful.";
            api_msg = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.mirrorFromRemote");
            testCase.verifyTrue(success, api_msg);

            narrative(end+1) = "Testing: Verifying the returned error message is empty.";
            api_msg = ndi.unittest.cloud.APIMessage(narrative, success, msg, [], "ndi.cloud.sync.mirrorFromRemote");
            testCase.verifyEmpty(msg, api_msg);

            % Check report
            narrative(end+1) = "Testing: Verifying report contains 'downloaded_document_ids' and 'deleted_local_document_ids'.";
            api_msg = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.mirrorFromRemote");
            testCase.verifyTrue(isfield(report, 'downloaded_document_ids'), api_msg);
            testCase.verifyTrue(isfield(report, 'deleted_local_document_ids'), api_msg);

            % Verify specific IDs
            narrative(end+1) = "Testing: Verifying remote document ID was downloaded.";
            api_msg = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.mirrorFromRemote");
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc2.id())), ...
                "Remote doc ID should be downloaded. " + api_msg);

            narrative(end+1) = "Testing: Verifying local document ID was deleted.";
            api_msg = ndi.unittest.cloud.APIMessage(narrative, success, report, [], "ndi.cloud.sync.mirrorFromRemote");
            testCase.verifyTrue(any(strcmp(report.deleted_local_document_ids, doc1.id())), ...
                "Local doc ID should be deleted. " + api_msg);

            % 3. Verify
            % Local should now have only doc2
            narrative(end+1) = "Testing: Verifying local database state (should only contain 'remote_doc_2').";
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_2'));

            testCase.verifyNumElements(local_docs, 1, "Should find 1 document named 'remote_doc_2'. Narrative: " + join(narrative, newline));
            if ~isempty(local_docs)
                testCase.verifyEqual(local_docs{1}.document_properties.base.name, 'remote_doc_2', "Document name should match. Narrative: " + join(narrative, newline));
            end

            % doc1 should be deleted
            narrative(end+1) = "Testing: Verifying 'local_doc_1' is gone.";
            local_docs_1 = testCase.localDataset.database_search(ndi.query('base.name','exact_string','local_doc_1'));
            testCase.verifyEmpty(local_docs_1, "Should not find 'local_doc_1'. Narrative: " + join(narrative, newline));

            testCase.Narrative = narrative;
        end

    end
end
