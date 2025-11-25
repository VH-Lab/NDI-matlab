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

            % 2. Mocks
            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');

            % Mock listLocalDocuments to be self-contained
            local_doc1 = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc1', 'test.value', 'A');
            local_doc2 = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc2', 'test.value', 'B');
            local_doc3 = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc3', 'test.value', 'C');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', ...
                sprintf('function [docs, ids] = f(varargin); docs = {%s, %s, %s}; ids = ["doc1", "doc2", "doc3"]; end', ...
                matlab.unittest.fixtures.ObjectSerializer.serialize(local_doc1), ...
                matlab.unittest.fixtures.ObjectSerializer.serialize(local_doc2), ...
                matlab.unittest.fixtures.ObjectSerializer.serialize(local_doc3)));

            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(["doc1"; "doc2"; "doc4"], ["api1"; "api2"; "api4"], ''VariableNames'', {''ndiId'', ''apiId''}); end');

            % Mock downloadDocumentCollection to be self-contained
            remote_doc1 = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc1', 'test.value', 'A');
            remote_doc2 = ndi.document('ndi_document_test.json').set_properties('test.name', 'doc2', 'test.value', 'Different');
            testCase.createMock('ndi.cloud.download.downloadDocumentCollection', ...
                sprintf('function out = f(varargin); out = {%s, %s}; end', ...
                matlab.unittest.fixtures.ObjectSerializer.serialize(remote_doc1), ...
                matlab.unittest.fixtures.ObjectSerializer.serialize(remote_doc2)));

            % 3. Execute
            report = ndi.cloud.sync.validate(testCase.ndiDataset);

            % 4. Verify
            testCase.verifyEqual(report.local_only_ids, ["doc3"]);
            testCase.verifyEqual(report.remote_only_ids, ["doc4"]);
            testCase.verifyEqual(sort(report.common_ids), ["doc1"; "doc2"]);
            testCase.verifyEqual(report.mismatched_ids, ["doc2"]);
        end

    end
end
