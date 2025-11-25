classdef ValidateTest < ndi.unittest.cloud.sync.BaseSyncTest
    %ValidateTest Test for ndi.cloud.sync.validate

    methods(Test)

        function testValidation(testCase)
            % Test validation logic

            % 1. Initial State:
            % Local: doc1 (match), doc2 (mismatch), doc3 (local-only)
            % Remote: doc1 (match), doc2 (mismatch), doc4 (remote-only)
            testCase.addDocument('doc1', 'A');
            testCase.addDocument('doc2', 'B');
            testCase.addDocument('doc3', 'C');

            doc1_remote = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc1', 'test.value', 'A');
            doc2_remote = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc2', 'test.value', 'Different');
            doc4_remote = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc4', 'test.value', 'D');

            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc1_remote.document_properties));
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc2_remote.document_properties));
            ndi.cloud.api.documents.addDocument(testCase.cloudDatasetId, jsonencodenan(doc4_remote.document_properties));

            % 2. Execute
            report = ndi.cloud.sync.validate(testCase.localDataset);

            % 3. Verify
            testCase.verifyEqual(report.local_only_ids, ["doc3"]);
            testCase.verifyEqual(report.remote_only_ids, ["doc4"]);
            testCase.verifyEqual(sort(report.common_ids), ["doc1"; "doc2"]);
            testCase.verifyEqual(report.mismatched_ids, ["doc2"]);
        end

    end
end
