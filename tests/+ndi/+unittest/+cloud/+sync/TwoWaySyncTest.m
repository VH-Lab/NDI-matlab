classdef TwoWaySyncTest < ndi.unittest.cloud.sync.BaseSyncTest
    %TwoWaySyncTest Test for ndi.cloud.sync.twoWaySync

    methods(Test)

        function testTwoWaySync(testCase)
            % Test two-way sync, including uploads and downloads

            % 1. Initial State: Local has doc1, remote has doc2
            doc1 = ndi.document('base', 'base.name', 'local_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id', testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            ndi.cloud.sync.twoWaySync(testCase.localDataset);

            % 3. Verify
            % Local should have doc1 and doc2
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','regexp','(.*)_doc_(.*)')); 
            testCase.verifyNumElements(local_docs, 2);
            if numel(local_docs)==2
                local_names = sort(cellfun(@(x) char(x.document_properties.base.name), local_docs, 'UniformOutput', false));
                testCase.verifyEqual(local_names{1}, 'local_doc_1');
                testCase.verifyEqual(local_names{2}, 'remote_doc_2');
            end

            % Remote should have doc1 and doc2
            [success,remoteDocs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            testCase.verifyEqual(logical(success),true,"Failed to list the documents in the remote dataset after syncing.")

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
            testCase.verifyEqual(foundLocalDoc1, true, "Failed to find local_doc_1");
            testCase.verifyEqual(foundRemoteDoc2, true, "Failed to find remote_doc_2");
        end

    end
end
