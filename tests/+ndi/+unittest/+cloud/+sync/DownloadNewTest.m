classdef DownloadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %DownloadNewTest Test for ndi.cloud.sync.downloadNew

    methods(Test)

        function testInitialDownload(testCase)
            % Test initial download with no sync index

            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); global MOCK_CALLS; MOCK_CALLS.listRemoteDocumentIds = true; out = table(["ndi_id_1"], ["api_id_1"], ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.sync.internal.downloadNdiDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.downloadNdiDocuments = true; end');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', 'function [docs, ids] = f(varargin); docs = {}; ids = strings(0,1); end');

            ndi.cloud.sync.downloadNew(testCase.ndiDataset);

            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'listRemoteDocumentIds'));
            testCase.verifyTrue(isfield(MOCK_CALLS, 'downloadNdiDocuments'));
        end

        function testDryRun(testCase)
            % Test DryRun option

            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(["ndi_id_1"], ["api_id_1"], ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.sync.internal.downloadNdiDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.downloadNdiDocuments = true; end');

            ndi.cloud.sync.downloadNew(testCase.ndiDataset, "DryRun", true);

            global MOCK_CALLS;
            testCase.verifyFalse(isfield(MOCK_CALLS, 'downloadNdiDocuments'));
        end

        function testIncrementalDownload(testCase)
            % Test downloading only new documents

            % 1. Initial sync state
            syncIndex.remoteDocumentIdsLastSync = ["ndi_id_1"];
            ndi.cloud.sync.internal.index.writeSyncIndex(testCase.ndiDataset, syncIndex);

            % 2. Mocks
            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(["ndi_id_1"; "ndi_id_2"], ["api_id_1"; "api_id_2"], ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.sync.internal.downloadNdiDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.downloadNdiDocuments = true; MOCK_CALLS.downloadedApiIds = varargin{2}; end');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', 'function [docs, ids] = f(varargin); docs = {}; ids = strings(0,1); end');

            % 3. Execute
            ndi.cloud.sync.downloadNew(testCase.ndiDataset);

            % 4. Verify
            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'downloadNdiDocuments'));
            testCase.verifyNumElements(MOCK_CALLS.downloadedApiIds, 1);
            testCase.verifyEqual(MOCK_CALLS.downloadedApiIds{1}, 'api_id_2');
        end
    end
end
