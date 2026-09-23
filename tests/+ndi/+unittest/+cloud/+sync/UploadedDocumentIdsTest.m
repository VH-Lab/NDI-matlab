classdef UploadedDocumentIdsTest < matlab.unittest.TestCase
    % UPLOADEDDOCUMENTIDSTEST - regression tests for the sync upload-id accounting
    %
    % Guards ndi.cloud.sync.internal.uploadedDocumentIds, which mirrorToRemote
    % and twoWaySync now use to report only the documents that were actually
    % uploaded (never the intended list) when uploadDocumentCollection partially
    % or fully fails.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (Test)

        function testSerialAllSuccess(testCase)
            report = struct('uploadType', 'serial', ...
                'manifest', {{'id1', 'id2', 'id3'}}, ...
                'status',   {{'success', 'success', 'success'}});
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(report);
            testCase.verifyEqual(sort(ids), sort(["id1", "id2", "id3"]));
        end

        function testSerialPartialFailure(testCase)
            report = struct('uploadType', 'serial', ...
                'manifest', {{'id1', 'id2', 'id3'}}, ...
                'status',   {{'success', 'failure', 'success'}});
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(report);
            testCase.verifyEqual(sort(ids), sort(["id1", "id3"]));
        end

        function testSerialAllFailureYieldsEmpty(testCase)
            report = struct('uploadType', 'serial', ...
                'manifest', {{'id1', 'id2'}}, ...
                'status',   {{'failure', 'failure'}});
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(report);
            testCase.verifyEmpty(ids);
        end

        function testBatchSuccessFlattensManifest(testCase)
            % A successful batch entry is itself a cell array of IDs.
            report = struct('uploadType', 'batch', ...
                'manifest', {{{'a', 'b'}, {'c', 'd'}}}, ...
                'status',   {{'success', 'failure'}});
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(report);
            % Only the first (successful) batch's IDs count.
            testCase.verifyEqual(sort(ids), sort(["a", "b"]));
        end

        function testEmptyReportYieldsEmpty(testCase)
            report = struct('uploadType', 'none', 'manifest', {{}}, 'status', {{}});
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(report);
            testCase.verifyEmpty(ids);
        end

        function testMissingFieldsYieldEmpty(testCase)
            ids = ndi.cloud.sync.internal.uploadedDocumentIds(struct());
            testCase.verifyEmpty(ids);
        end

    end

end
