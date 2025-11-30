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
            [success, msg, report] = ndi.cloud.sync.mirrorToRemote(testCase.localDataset,"Verbose",true);

            testCase.verifyTrue(success);
            testCase.verifyEmpty(msg);

            % Check report
            testCase.verifyTrue(isfield(report, 'uploaded_document_ids'));
            testCase.verifyTrue(isfield(report, 'deleted_remote_document_ids'));

            % Verify specific IDs
            testCase.verifyTrue(any(strcmp(report.uploaded_document_ids, doc1.id())), ...
                'Local doc ID should be uploaded');
            % Note: doc2.id() is the LOCAL ID if we created it locally, but here we created it directly on remote.
            % But ndi.document constructor generates an ID.
            % Does addDocument use that ID? Yes, usually.
            testCase.verifyTrue(any(strcmp(report.deleted_remote_document_ids, doc2.id())), ...
                'Remote doc ID should be deleted');

            % 3. Verify
            % Remote should now have doc1
            [success,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            testCase.verifyEqual(logical(success), true, "mirrorToRemote command was not successful.");

            found_local_doc_1 = false;
            found_remote_doc_2 = false;
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,'local_doc_1')
                    found_local_doc_1 = true;
                elseif strcmp(remote_docs(i).name,'remote_doc_2')
                    found_remote_doc_2 = true;
                end
            end
            testCase.verifyTrue(found_local_doc_1, "Failed to find expected doc local_doc_1");
            testCase.verifyFalse(found_remote_doc_2, "Found unexpected doc remote_doc_2");
        end

    end
end
