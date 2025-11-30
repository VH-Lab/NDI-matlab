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
            % local_doc_1 should be uploaded
            testCase.verifyNumElements(report.uploaded_document_ids, 1);
            % remote_doc_2 should be deleted
            testCase.verifyNumElements(report.deleted_remote_document_ids, 1);

            % 3. Verify
            % Remote should now have doc1
            [success,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            testCase.verifyEqual(logical(success), true, "mirrorToRemote command was not successful.");
            % Expected docs: dataset doc, remote link doc, local_doc_1
            % Wait, does createRemoteDatasetDoc create a doc? Yes.
            % 'dataset' doc is created by createDataset? No, createDataset returns ID.
            % But listDatasetDocumentsAll returns what?
            % In BaseSyncTest, we add remote_doc to local.
            % If we mirror local to remote, we upload all local docs.
            % Local has: remote_doc (link), doc1.
            % Remote has: doc2.
            % After sync: Remote should have copy of local docs: remote_doc (link), doc1.
            % And doc2 should be deleted.

            % But wait, does createDataset create any initial documents? Often yes (dataset info).
            % listDatasetDocumentsAll usually returns everything.

            % Let's verify 'local_doc_1' is present and 'remote_doc_2' is absent.
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
