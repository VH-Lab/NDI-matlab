classdef UploadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %UploadNewTest Test for ndi.cloud.sync.uploadNew

    methods(Test)

        function testInitialUpload(testCase)
            % Test initial upload with no sync index
            testCase.addDocument('test_doc_1');

            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % Verify that the document is now on the remote
            remote_docs = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId);
            testCase.verifyNumElements(remote_docs, 1);
            testCase.verifyEqual(remote_docs(1).name, "test_doc_1");
        end

        function testDryRun(testCase)
            % Test DryRun option
            testCase.addDocument('test_doc_1');

            ndi.cloud.sync.uploadNew(testCase.localDataset, "DryRun", true);

            % Verify that the document is NOT on the remote
            remote_docs = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId);
            testCase.verifyEmpty(remote_docs);
        end

        function testIncrementalUpload(testCase)
            % Test uploading only new documents

            % 1. Initial sync
            testCase.addDocument('test_doc_1');
            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % 2. Add a new document and sync again
            testCase.addDocument('test_doc_2');
            ndi.cloud.sync.uploadNew(testCase.localDataset);

            % 3. Verify that both documents are on the remote
            remote_docs = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId);
            testCase.verifyNumElements(remote_docs, 2);
            names = sort({remote_docs.name});
            testCase.verifyEqual(names{1}, "test_doc_1");
            testCase.verifyEqual(names{2}, "test_doc_2");
        end
    end
end
