classdef DownloadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %DownloadNewTest Test for ndi.cloud.sync.downloadNew

    methods(Test)

        function testInitialDownload(testCase)
            % Test initial download with no sync index

            % Add a document to the remote
            doc = ndi.document('ndi_document_test.json');
            doc = doc.set_properties('test.name', 'remote_doc_1');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));

            ndi.cloud.sync.downloadNew(testCase.localDataset);

            % Verify that the document is now on the local
            local_docs = testCase.localDataset.database_search(ndi.query('','isa','ndi_document_test'));
            testCase.verifyNumElements(local_docs, 1);
            testCase.verifyEqual(local_docs{1}.document_properties.test.name, 'remote_doc_1');
        end

        function testDryRun(testCase)
            % Test DryRun option

            % Add a document to the remote
            doc = ndi.document('ndi_document_test.json');
            doc = doc.set_properties('test.name', 'remote_doc_1');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));

            ndi.cloud.sync.downloadNew(testCase.localDataset, "DryRun", true);

            % Verify that the document is NOT on the local
            local_docs = testCase.localDataset.database_search(ndi.query('','isa','ndi_document_test'));
            testCase.verifyEmpty(local_docs);
        end

        function testIncrementalDownload(testCase)
            % Test downloading only new documents

            % 1. Initial sync
            doc1 = ndi.document('ndi_document_test.json');
            doc1 = doc1.set_properties('test.name', 'remote_doc_1');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc1.document_properties));
            ndi.cloud.sync.downloadNew(testCase.localDataset);

            % 2. Add a new document to remote and sync again
            doc2 = ndi.document('ndi_document_test.json');
            doc2 = doc2.set_properties('test.name', 'remote_doc_2');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));
            ndi.cloud.sync.downloadNew(testCase.localDataset);

            % 3. Verify that both documents are on the local
            local_docs = testCase.localDataset.database_search(ndi.query('','isa','ndi_document_test'));
            testCase.verifyNumElements(local_docs, 2);
            names = sort(cellfun(@(x) string(x.document_properties.test.name), local_docs, 'UniformOutput', false));
            testCase.verifyEqual(names{1}, "remote_doc_1");
            testCase.verifyEqual(names{2}, "remote_doc_2");
        end
    end
end
