classdef MirrorToRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorToRemoteTest Test for ndi.cloud.sync.mirrorToRemote

    methods(Test)

        function testMirrorToRemote(testCase)
            % Test mirroring to remote, including uploads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            testCase.addDocument('local_doc_1');

            % 2. Mocks
            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', 'function [docs, ids] = f(varargin); doc = ndi.document(''ndi_document_test.json''); doc = doc.set_properties(''test.name'', ''local_doc_1''); docs = {doc}; ids = ["local_doc_1"]; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(["remote_doc_2"], ["api_id_2"], ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.upload.uploadDocumentCollection', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadDocumentCollection = true; MOCK_CALLS.uploadedDocs = varargin{2}; end');
            testCase.createMock('ndi.cloud.sync.internal.deleteRemoteDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.deleteRemoteDocuments = true; MOCK_CALLS.deletedRemoteApiIds = varargin{2}; end');

            % 3. Execute
            ndi.cloud.sync.mirrorToRemote(testCase.ndiDataset);

            % 4. Verify
            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'uploadDocumentCollection'));
            testCase.verifyEqual(MOCK_CALLS.uploadedDocs{1}.document_properties.test.name, 'local_doc_1');

            testCase.verifyTrue(isfield(MOCK_CALLS, 'deleteRemoteDocuments'));
            testCase.verifyEqual(MOCK_CALLS.deletedRemoteApiIds, "api_id_2");
        end

    end
end
