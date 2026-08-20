classdef FakeCloudClient < ndi.migrate.internal.cloudClient
%FAKECLOUDCLIENT In-memory cloud client used by TestMigrateCloud.
%
%   Subclasses the production cloudClient so ndi.migrate.cloud calls
%   the test methods instead of hitting the real cloud. Tracks call
%   counts and ordering so tests can assert on the orchestration
%   sequence (unpublish before upload, republish after, lock released
%   on both success and failure paths).

    properties
        DatasetInfo struct = struct()
        Documents cell = {}            % cell of bodies (struct or JSON char)
        LockHeldByOther (1,1) logical = false
        FailUpload (1,1) logical = false

        AcquireLockCalls (1,1) double = 0
        RefreshLockCalls (1,1) double = 0
        ReleaseLockCalls (1,1) double = 0
        ListCalls (1,1) double = 0
        FetchCalls (1,1) double = 0
        UploadCalls (1,1) double = 0
        UnpublishCalls (1,1) double = 0
        PublishCalls (1,1) double = 0

        UnpublishOrder (1,1) double = NaN
        UploadOrder (1,1) double = NaN
        PublishOrder (1,1) double = NaN
    end

    properties (Access = private)
        OperationCounter (1,1) double = 0
    end

    methods
        function obj = FakeCloudClient(args)
            arguments
                args.datasetInfo struct = struct('isPublished', false)
                args.documents cell = {}
                args.lockHeldByOther (1,1) logical = false
                args.failUpload (1,1) logical = false
            end
            obj.DatasetInfo = args.datasetInfo;
            obj.Documents = args.documents;
            obj.LockHeldByOther = args.lockHeldByOther;
            obj.FailUpload = args.failUpload;
        end

        function info = getDataset(obj, ~)
            info = obj.DatasetInfo;
        end

        function lockInfo = acquireLock(obj, ~, reason, ~)
            if obj.LockHeldByOther
                error('NDI:migrate:cloud:lockHeld', ...
                    'Fake cloud: lock already held by another client.');
            end
            obj.AcquireLockCalls = obj.AcquireLockCalls + 1;
            lockInfo = struct('state', 'held', 'reason', char(reason));
        end

        function lockInfo = refreshLock(obj, ~)
            obj.RefreshLockCalls = obj.RefreshLockCalls + 1;
            lockInfo = struct('state', 'held');
        end

        function releaseLock(obj, ~)
            obj.ReleaseLockCalls = obj.ReleaseLockCalls + 1;
        end

        function summaries = listAllDocuments(obj, ~, ~)
            obj.ListCalls = obj.ListCalls + 1;
            n = numel(obj.Documents);
            if n == 0
                summaries = struct('id', {}, 'ndiId', {}, ...
                    'name', {}, 'className', {});
                return;
            end
            entries = cell(1, n);
            for k = 1:n
                entries{k} = struct( ...
                    'id', sprintf('cloud_%04d', k), ...
                    'ndiId', sprintf('ndi_%04d', k), ...
                    'name', '', 'className', '');
            end
            summaries = [entries{:}];
        end

        function docs = bulkFetchDocuments(obj, ~, cloudDocumentIDs)
            obj.FetchCalls = obj.FetchCalls + 1;
            n = numel(cloudDocumentIDs);
            % Return a cell array of entries; ndi.migrate.cloud's
            % extractBodies helper handles both struct-array and cell
            % shapes for forwards-compatibility with the real cloud
            % API's response normalisation.
            entries = cell(1, n);
            for k = 1:n
                key = char(cloudDocumentIDs(k));
                idx = sscanf(key, 'cloud_%d');
                if isempty(idx) || idx < 1 || idx > numel(obj.Documents)
                    error('FakeCloud:unknownId', ...
                        'Unknown cloud id "%s".', key);
                end
                body = obj.Documents{idx};
                entries{k} = struct( ...
                    'id', key, ...
                    'ndiId', sprintf('ndi_%04d', idx), ...
                    'name', '', ...
                    'className', '', ...
                    'datasetId', '', ...
                    'data', body);
            end
            docs = entries;
        end

        function report = uploadBodies(obj, ~, vDeltaBodies)
            if obj.FailUpload
                error('FakeCloud:uploadFailed', ...
                    'Fake cloud: upload deliberately failed.');
            end
            obj.UploadCalls = obj.UploadCalls + 1;
            obj.OperationCounter = obj.OperationCounter + 1;
            obj.UploadOrder = obj.OperationCounter;
            ids = cell(1, numel(vDeltaBodies));
            for k = 1:numel(vDeltaBodies)
                if isstruct(vDeltaBodies{k}) ...
                        && isfield(vDeltaBodies{k}, 'base') ...
                        && isfield(vDeltaBodies{k}.base, 'id')
                    ids{k} = char(vDeltaBodies{k}.base.id);
                else
                    ids{k} = '';
                end
            end
            report = struct( ...
                'uploadType', 'batch', ...
                'manifest', {{ids}}, ...
                'status', {{'success'}}, ...
                'url', 'fake://upload');
        end

        function unpublishDataset(obj, ~)
            obj.UnpublishCalls = obj.UnpublishCalls + 1;
            obj.OperationCounter = obj.OperationCounter + 1;
            obj.UnpublishOrder = obj.OperationCounter;
        end

        function publishDataset(obj, ~)
            obj.PublishCalls = obj.PublishCalls + 1;
            obj.OperationCounter = obj.OperationCounter + 1;
            obj.PublishOrder = obj.OperationCounter;
        end
    end
end
