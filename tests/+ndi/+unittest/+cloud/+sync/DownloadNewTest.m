classdef DownloadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %DownloadNewTest Test for ndi.cloud.sync.downloadNew

    methods(Test)

        function testInitialDownload(testCase)
            % Test initial download with no sync index

            % Add a document to the remote
            doc = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));

            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset);

            testCase.verifyTrue(success);
            testCase.verifyEmpty(msg);
            testCase.verifyTrue(isfield(report, 'downloaded_document_ids'));

            % Verify the specific document ID is in the report
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc.id())), ...
                'Remote document ID should be in downloaded_document_ids');

            % Verify that the document is now on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_1'));
            testCase.verifyNumElements(local_docs, 1);
            testCase.verifyEqual(local_docs{1}.document_properties.base.name, 'remote_doc_1');
        end

        function testDryRun(testCase)
            % Test DryRun option

            % Add a document to the remote
            doc = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));

            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset, "DryRun", true);

            testCase.verifyTrue(success);
            testCase.verifyEmpty(msg);
            testCase.verifyEmpty(report.downloaded_document_ids);

            % Verify that the document is NOT on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_1'));
            testCase.verifyEmpty(local_docs);
        end

        function testIncrementalDownload(testCase)
            % Test downloading only new documents

            % 1. Initial sync
            doc1 = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc1.document_properties));
            ndi.cloud.sync.downloadNew(testCase.localDataset);

            % 2. Add a new document to remote and sync again
            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id',testCase.localDataset.id());
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));

            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset);

            testCase.verifyTrue(success);
            testCase.verifyEmpty(msg);

            % Verify doc2 ID is in the report
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc2.id())), ...
                'New remote document ID should be in downloaded_document_ids');

            % 3. Verify that both documents are on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','regexp','remote_doc_.*'));
            testCase.verifyNumElements(local_docs, 2);
            names = sort(cellfun(@(x) char(x.document_properties.base.name), local_docs, 'UniformOutput', false));
            testCase.verifyEqual(names{1}, 'remote_doc_1');
            testCase.verifyEqual(names{2}, 'remote_doc_2');
        end
    end
end
