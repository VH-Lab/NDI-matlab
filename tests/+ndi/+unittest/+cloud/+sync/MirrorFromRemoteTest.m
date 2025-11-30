classdef MirrorFromRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorFromRemoteTest Test for ndi.cloud.sync.mirrorFromRemote

    methods(Test)

        function testMirrorFromRemote(testCase)
            % Test mirroring from remote, including downloads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            [success, msg, report] = ndi.cloud.sync.mirrorFromRemote(testCase.localDataset);

            testCase.verifyTrue(success);
            testCase.verifyEmpty(msg);

            % Check report
            testCase.verifyTrue(isfield(report, 'downloaded_document_ids'));
            testCase.verifyTrue(isfield(report, 'deleted_local_document_ids'));
            testCase.verifyNumElements(report.downloaded_document_ids, 1);
            testCase.verifyNumElements(report.deleted_local_document_ids, 1);

            % 3. Verify
            % Local should now have only doc2
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_2'));
            testCase.verifyNumElements(local_docs, 1);
            testCase.verifyEqual(local_docs{1}.document_properties.base.name, 'remote_doc_2');

            % doc1 should be deleted
             local_docs_1 = testCase.localDataset.database_search(ndi.query('base.name','exact_string','local_doc_1'));
             testCase.verifyEmpty(local_docs_1);
        end

    end
end
