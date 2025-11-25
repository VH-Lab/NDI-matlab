classdef UploadNewTest < ndi.unittest.cloud.sync.BaseSyncTest
    %UploadNewTest Test for ndi.cloud.sync.uploadNew

    methods(Test)

        function testInitialUpload(testCase)
            % Test initial upload with no sync index
            testCase.addDocument('test_doc_1');

            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); global MOCK_CALLS; MOCK_CALLS.getCloudDatasetIdForLocalDataset = true; out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); global MOCK_CALLS; MOCK_CALLS.listRemoteDocumentIds = true; out = table(strings(0,1), strings(0,1), ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.upload.uploadDocumentCollection', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadDocumentCollection = true; end');
            testCase.createMock('ndi.cloud.sync.internal.uploadFilesForDatasetDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadFilesForDatasetDocuments = true; end');

            ndi.cloud.sync.uploadNew(testCase.ndiDataset);

            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'getCloudDatasetIdForLocalDataset'));
            testCase.verifyTrue(isfield(MOCK_CALLS, 'uploadDocumentCollection'));
            testCase.verifyTrue(isfield(MOCK_CALLS, 'uploadFilesForDatasetDocuments'));
        end

        function testDryRun(testCase)
            % Test DryRun option
            testCase.addDocument('test_doc_1');

            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listLocalDocuments', 'function [docs, ids] = f(varargin); docs={}; ids=["test_doc_1"]; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(strings(0,1), strings(0,1), ''VariableNames'', {''ndiId'', ''apiId''}); end');

            ndi.cloud.sync.uploadNew(testCase.ndiDataset, "DryRun", true);

            global MOCK_CALLS;
            testCase.verifyFalse(isfield(MOCK_CALLS, 'uploadDocumentCollection'));
            testCase.verifyFalse(isfield(MOCK_CALLS, 'uploadFilesForDatasetDocuments'));
        end

        function testNoSyncFiles(testCase)
            % Test with SyncFiles set to false
            testCase.addDocument('test_doc_1');

            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(strings(0,1), strings(0,1), ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.upload.uploadDocumentCollection', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadDocumentCollection = true; end');
            testCase.createMock('ndi.cloud.sync.internal.uploadFilesForDatasetDocuments', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadFilesForDatasetDocuments = true; end');

            ndi.cloud.sync.uploadNew(testCase.ndiDataset, "SyncFiles", false);

            global MOCK_CALLS;
            testCase.verifyTrue(isfield(MOCK_CALLS, 'uploadDocumentCollection'));
            testCase.verifyFalse(isfield(MOCK_CALLS, 'uploadFilesForDatasetDocuments'));
        end

        function testIncrementalUpload(testCase)
            % Test uploading only new documents

            % 1. Initial sync
            testCase.addDocument('test_doc_1');
            testCase.createMock('ndi.cloud.internal.getCloudDatasetIdForLocalDataset', 'function out = f(varargin); out = "cloud_id_123"; end');
            testCase.createMock('ndi.cloud.sync.internal.listRemoteDocumentIds', 'function out = f(varargin); out = table(strings(0,1), strings(0,1), ''VariableNames'', {''ndiId'', ''apiId''}); end');
            testCase.createMock('ndi.cloud.upload.uploadDocumentCollection', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadDocumentCollection = true; end');

            ndi.cloud.sync.uploadNew(testCase.ndiDataset);

            % 2. Add a new document and sync again
            testCase.addDocument('test_doc_2');

            % Reset mock calls and mock uploadDocumentCollection to capture input
            global MOCK_CALLS;
            MOCK_CALLS = struct();
            testCase.createMock('ndi.cloud.upload.uploadDocumentCollection', 'function f(varargin); global MOCK_CALLS; MOCK_CALLS.uploadDocumentCollection = true; MOCK_CALLS.uploadedDocs = varargin{2}; end');

            ndi.cloud.sync.uploadNew(testCase.ndiDataset);

            % 3. Verify that only the new document was uploaded
            testCase.verifyTrue(isfield(MOCK_CALLS, 'uploadDocumentCollection'));
            testCase.verifyNumElements(MOCK_CALLS.uploadedDocs, 1);
            testCase.verifyEqual(MOCK_CALLS.uploadedDocs{1}.document_properties.test.name, 'test_doc_2');
        end
    end
end
