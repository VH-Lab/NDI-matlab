classdef MirrorFromRemoteTest < ndi.unittest.cloud.sync.BaseSyncTest
    %MirrorFromRemoteTest Test for ndi.cloud.sync.mirrorFromRemote

    methods(Test)

        function testMirrorFromRemote(testCase)
            % Test mirroring from remote, including downloads and deletions

            % 1. Initial State: Local has doc1, remote has doc2
            testCase.addDocument('local_doc_1');

            % 2. Mocks
            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', 'function [docs, ids] = f(varargin); docs = {}; ids = ["local_doc_1"]; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(["remote_doc_2"], ["api_id_2"], ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.sync.internal.downloadNdiDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.downloadNdiDocuments = true; MOCK_CALLS.downloadedApiIds = varargin{2}; end');
            testCase.createMock('ndi.cloud.sync.internal.deleteLocalDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.deleteLocalDocuments = true; MOCK_CALLS.deletedLocalIds = varargin{2}; end');

            % 3. Execute
            ndi.cloud.sync.mirrorFromRemote(testCase.ndiDataset);

            % 4. Verify
            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'downloadNdiDocuments'));
            testCase.verifyEqual(MOCK_CALLS.downloadedApiIds{1}, 'api_id_2');

            testCase.verifyTrue(isfield(MOCK_CALLS, 'deleteLocalDocuments'));
            testCase.verifyEqual(MOCK_CALLS.deletedLocalIds, ["local_doc_1"]);
        end

    end
end
