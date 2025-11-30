classdef MirrorToRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorToRemoteTest Test for ndi.cloud.sync.mirrorToRemote

    methods(Test)

        function testMirrorToRemote(testCase)
            % Test mirroring to remote, including uploads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            ndi.cloud.sync.mirrorToRemote(testCase.localDataset,"Verbose",true);

            % 3. Verify
            % Remote should now have doc1
               % this is a proper test but it will break the local dataset
               % because the dataset document and cloudId document are
               % deleted
            [success,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            testCase.verifyEqual(logical(success), true, "mirrorToRemote command was not successful.");
            testCase.verifyNumElements(remote_docs, 3, "Number of remote documents does not match expected");
            foundIt = false;
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,'local_doc_1')
                    foundIt = true;
                    break;
                end
            end
            testCase.verifyEqual(foundIt, true, "Failed to find expected doc local_doc_1");
        end

    end
end
