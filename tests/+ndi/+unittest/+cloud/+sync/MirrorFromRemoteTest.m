classdef MirrorFromRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorFromRemoteTest Test for ndi.cloud.sync.mirrorFromRemote

    methods(Test)

        function testMirrorFromRemote(testCase)
            % Test mirroring from remote, including downloads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            testCase.addDocument('local_doc_1');

            doc2 = ndi.document('base', 'base.name', 'remote_doc_2');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            ndi.cloud.sync.mirrorFromRemote(testCase.localDataset);

            % 3. Verify
            % Local should now have only doc2
            local_docs = testCase.localDataset.database_search(ndi.query('','isa','base'));
            testCase.verifyNumElements(local_docs, 1);
            testCase.verifyEqual(local_docs{1}.document_properties.base.name, 'remote_doc_2');
        end

    end
end
