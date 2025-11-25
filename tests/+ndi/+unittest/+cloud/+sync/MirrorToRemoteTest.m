classdef MirrorToRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorToRemoteTest Test for ndi.cloud.sync.mirrorToRemote

    methods(Test)

        function testMirrorToRemote(testCase)
            % Test mirroring to remote, including uploads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            testCase.addDocument('local_doc_1');

            doc2 = ndi.document('ndi_document_test.json');
            doc2 = doc2.set_properties('test.name', 'remote_doc_2');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            ndi.cloud.sync.mirrorToRemote(testCase.localDataset);

            % 3. Verify
            % Remote should now have only doc1
            remote_docs = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId);
            testCase.verifyNumElements(remote_docs, 1);
            testCase.verifyEqual(remote_docs(1).name, "local_doc_1");
        end

    end
end
