classdef UploadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %UploadNewTest Test for ndi.cloud.sync.uploadNew

    methods(Test)

        function testInitialUpload(testCase)
            % Test initial upload with no sync index
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % Verify that the document is now on the remote
            [b,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            foundTestDoc = false;
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,"test_doc_1")
                    foundTestDoc = true;
                    break;
                end
            end

            testCase.verifyEqual(foundTestDoc, true, "test_doc_1 not found");
        end

        function testDryRun(testCase)
            % Test DryRun option
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);

            ndi.cloud.sync.uploadNew(testCase.localDataset, "DryRun", true);

            % Verify that the document is NOT on the remote
            [b,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            foundTestDoc = false;
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,"test_doc_1")
                    foundTestDoc = true;
                    break;
                end
            end
            testCase.verifyEqual(foundTestDoc, false, "test_doc_1 was found, should not have been added during DryRun");            
        end

        function testIncrementalUpload(testCase)
            % Test uploading only new documents

            % 1. Initial sync
            doc1 = ndi.document('base', 'base.name', 'test_doc_1','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc1);
            
            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % 2. Add a new document and sync again
            doc2 = ndi.document('base', 'base.name', 'test_doc_2','base.session_id', testCase.localDataset.id());           
            testCase.localDataset.database_add(doc2);
            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % 3. Verify that both documents are on the remote
            [b,remote_docs] = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId,"checkForUpdates",true);
            foundTestDoc1 = false;
            foundTestDoc2 = false;            
            for i=1:numel(remote_docs)
                if strcmp(remote_docs(i).name,"test_doc_1")
                    foundTestDoc1 = true;
                end
                if strcmp(remote_docs(i).name,"test_doc_2")
                    foundTestDoc2 = true;
                end
            end

            testCase.verifyEqual(foundTestDoc1, true, "test_doc_1 not found");
            testCase.verifyEqual(foundTestDoc2, true, "test_doc_2 not found");
        end
    end
end
