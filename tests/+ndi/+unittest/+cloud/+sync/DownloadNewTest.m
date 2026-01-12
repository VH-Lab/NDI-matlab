classdef DownloadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %DownloadNewTest Test for ndi.cloud.sync.downloadNew

    properties
        narrative % a string that contains a running narrative of the test
    end

    methods(Test)

        function testInitialDownload(testCase)
            % Test initial download with no sync index
            testCase.narrative = 'TESTINITIALDOWNLOAD: Test initial download with no sync index.';
            testCase.narrative = [testCase.narrative newline 'Step 1: Add a document to the remote'];

            % Add a document to the remote
            doc = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            [success, msg, resp, url] = ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));
            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, resp, url));

            testCase.narrative = [testCase.narrative newline 'Step 2: Download new documents'];
            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset);

            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, [], []));
            testCase.verifyEmpty(msg, ndi.unittest.cloud.APIMessage(testCase.narrative, success, ['Message is not empty: ' msg], [], []));
            testCase.verifyTrue(isfield(report, 'downloaded_document_ids'), ndi.unittest.cloud.APIMessage(testCase.narrative, success, 'Report missing downloaded_document_ids field', report, []));

            testCase.narrative = [testCase.narrative newline 'Step 3: Verify the specific document ID is in the report'];
            % Verify the specific document ID is in the report
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc.id())), ...
                ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Remote document ID should be in downloaded_document_ids', report, []));

            testCase.narrative = [testCase.narrative newline 'Step 4: Verify that the document is now on the local'];
            % Verify that the document is now on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_1'));
            testCase.verifyNumElements(local_docs, 1, ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Expected 1 local document', [], []));
            if ~isempty(local_docs)
                testCase.verifyEqual(local_docs{1}.document_properties.base.name, 'remote_doc_1', ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Local document name mismatch', [], []));
            end
        end

        function testDryRun(testCase)
            % Test DryRun option
            testCase.narrative = 'TESTDRYRUN: Test DryRun option.';
            testCase.narrative = [testCase.narrative newline 'Step 1: Add a document to the remote'];

            % Add a document to the remote
            doc = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            [success, msg, resp, url] = ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc.document_properties));
            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, resp, url));

            testCase.narrative = [testCase.narrative newline 'Step 2: Run downloadNew with DryRun=true'];
            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset, "DryRun", true);

            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, [], []));
            testCase.verifyEmpty(msg, ndi.unittest.cloud.APIMessage(testCase.narrative, success, ['Message is not empty: ' msg], [], []));

            if isstruct(report) && isfield(report, 'downloaded_document_ids')
                testCase.verifyEmpty(report.downloaded_document_ids, ndi.unittest.cloud.APIMessage(testCase.narrative, success, 'DryRun should not download documents', report, []));
            else
                 testCase.verifyTrue(isfield(report, 'downloaded_document_ids'), ndi.unittest.cloud.APIMessage(testCase.narrative, success, 'Report missing downloaded_document_ids field', report, []));
            end

            testCase.narrative = [testCase.narrative newline 'Step 3: Verify that the document is NOT on the local'];
            % Verify that the document is NOT on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','exact_string','remote_doc_1'));
            testCase.verifyEmpty(local_docs, ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Document should not be present locally', [], []));
        end

        function testIncrementalDownload(testCase)
            % Test downloading only new documents
            testCase.narrative = 'TESTINCREMENTALDOWNLOAD: Test downloading only new documents.';

            testCase.narrative = [testCase.narrative newline 'Step 1: Initial sync'];
            % 1. Initial sync
            doc1 = ndi.document('base', 'base.name', 'remote_doc_1','base.session_id',testCase.localDataset.id());
            [success, msg, resp, url] = ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc1.document_properties));
            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, resp, url));

            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset);
            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, ['Initial sync failed: ' msg], report, []));

            testCase.narrative = [testCase.narrative newline 'Step 2: Add a new document to remote and sync again'];
            % 2. Add a new document to remote and sync again
            doc2 = ndi.document('base', 'base.name', 'remote_doc_2','base.session_id',testCase.localDataset.id());
            [success, msg, resp, url] = ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2.document_properties));
            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, resp, url));

            [success, msg, report] = ndi.cloud.sync.downloadNew(testCase.localDataset);

            testCase.verifyTrue(success, ndi.unittest.cloud.APIMessage(testCase.narrative, success, msg, [], []));
            testCase.verifyEmpty(msg, ndi.unittest.cloud.APIMessage(testCase.narrative, success, ['Message is not empty: ' msg], [], []));

            testCase.narrative = [testCase.narrative newline 'Step 3: Verify doc2 ID is in the report'];
            % Verify doc2 ID is in the report
            testCase.verifyTrue(any(strcmp(report.downloaded_document_ids, doc2.id())), ...
                ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'New remote document ID should be in downloaded_document_ids', report, []));

            testCase.narrative = [testCase.narrative newline 'Step 4: Verify that both documents are on the local'];
            % 3. Verify that both documents are on the local
            local_docs = testCase.localDataset.database_search(ndi.query('base.name','regexp','remote_doc_.*'));
            testCase.verifyNumElements(local_docs, 2, ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Expected 2 local documents', [], []));

            if numel(local_docs) == 2
                names = sort(cellfun(@(x) char(x.document_properties.base.name), local_docs, 'UniformOutput', false));
                testCase.verifyEqual(names{1}, 'remote_doc_1', ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'First document name mismatch', [], []));
                testCase.verifyEqual(names{2}, 'remote_doc_2', ndi.unittest.cloud.APIMessage(testCase.narrative, true, 'Second document name mismatch', [], []));
            end
        end
    end
end
