classdef TwoWaySyncTest < ndi.unittest.cloud.sync.BaseSyncTest
    %TwoWaySyncTest Test for ndi.cloud.sync.twoWaySync

    methods(Test)

        function testTwoWaySync(testCase)
            % Test two-way sync, including uploads and downloads

            % 1. Initial State: Local has doc1, remote has doc2
            testCase.addDocument('local_doc_1');

            doc2 = ndi.document('ndi_document_test.json');
            doc2 = doc2.set_properties('test.name', 'remote_doc_2');
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            % 2. Execute
            ndi.cloud.sync.twoWaySync(testCase.localDataset);

            % 3. Verify
            % Local should have doc1 and doc2
            local_docs = testCase.localDataset.database_search(ndi.query('','isa','ndi_document_test'));
            testCase.verifyNumElements(local_docs, 2);
            local_names = sort(cellfun(@(x) string(x.document_properties.test.name), local_docs, 'UniformOutput', false));
            testCase.verifyEqual(local_names{1}, "local_doc_1");
            testCase.verifyEqual(local_names{2}, "remote_doc_2");

            % Remote should have doc1 and doc2
            remote_docs = ndi.cloud.api.documents.listDatasetDocumentsAll(testCase.cloudDatasetId);
            testCase.verifyNumElements(remote_docs, 2);
            remote_names = sort({remote_docs.name});
            testCase.verifyEqual(remote_names{1}, "local_doc_1");
            testCase.verifyEqual(remote_names{2}, "remote_doc_2");
        end

    end
end
