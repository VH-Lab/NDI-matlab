classdef cloudClient < handle
%CLOUDCLIENT Default cloud transport used by ndi.migrate.cloud.
%
%   ndi.migrate.cloud delegates every cloud-side operation it needs
%   (lock acquire/refresh/release, dataset state, listing/fetching
%   documents, uploading converted documents back, publish flips) to
%   a small handle class. The default implementation in this file
%   wraps the real `ndi.cloud.api.*` calls. Tests can subclass and
%   override individual methods to drive the migration loop without
%   contacting the real cloud.
%
%   Each method returns plain data so the migration loop can be the
%   only place that worries about cloud-shape vs. struct-shape. The
%   methods are also defensive about how the wrapped API call's error
%   bodies look: every method either succeeds (returns the data) or
%   raises a classed error.
%
%   See also: ndi.migrate.cloud.

    methods
        function info = getDataset(this, datasetId) %#ok<INUSL>
            %GETDATASET Return the dataset state struct.
            [b, answer] = ndi.cloud.api.datasets.getDataset(datasetId);
            if ~b
                error('NDI:migrate:cloud:getDatasetFailed', ...
                    'Could not fetch dataset "%s": %s', ...
                    datasetId, formatErr(answer));
            end
            info = answer;
        end

        function lockInfo = acquireLock(this, datasetId, reason, ttlSeconds) %#ok<INUSL>
            %ACQUIRELOCK Acquire the write lock; error on 409 from a
            %  concurrent holder.
            [b, answer] = ndi.cloud.api.datasets.acquireWriteLock( ...
                datasetId, 'reason', reason, 'ttlSeconds', ttlSeconds);
            if ~b
                error('NDI:migrate:cloud:lockHeld', ...
                    'Could not acquire write lock on "%s": %s', ...
                    datasetId, formatErr(answer));
            end
            lockInfo = answer;
        end

        function lockInfo = refreshLock(this, datasetId) %#ok<INUSL>
            [b, answer] = ndi.cloud.api.datasets.refreshWriteLock(datasetId);
            if ~b
                error('NDI:migrate:cloud:lockRefreshFailed', ...
                    'Could not refresh write lock on "%s": %s', ...
                    datasetId, formatErr(answer));
            end
            lockInfo = answer;
        end

        function releaseLock(this, datasetId) %#ok<INUSL>
            [b, answer] = ndi.cloud.api.datasets.releaseWriteLock(datasetId);
            if ~b
                error('NDI:migrate:cloud:lockReleaseFailed', ...
                    'Could not release write lock on "%s": %s', ...
                    datasetId, formatErr(answer));
            end
        end

        function summaries = listAllDocuments(this, datasetId, pageSize) %#ok<INUSL>
            %LISTALLDOCUMENTS Return a struct array of doc summaries.
            [b, answer] = ndi.cloud.api.documents.listDatasetDocumentsAll( ...
                datasetId, 'pageSize', pageSize);
            if ~b
                error('NDI:migrate:cloud:listFailed', ...
                    'Could not list documents in "%s": %s', ...
                    datasetId, formatErr(answer));
            end
            summaries = answer;
        end

        function docs = bulkFetchDocuments(this, datasetId, cloudDocumentIDs) %#ok<INUSL>
            %BULKFETCHDOCUMENTS Fetch full document bodies for ids.
            [b, answer] = ndi.cloud.api.documents.bulkFetch( ...
                datasetId, cloudDocumentIDs);
            if ~b
                error('NDI:migrate:cloud:bulkFetchFailed', ...
                    'Bulk fetch failed for "%s": %s', ...
                    datasetId, formatErr(answer));
            end
            docs = answer;
        end

        function report = uploadBodies(this, datasetId, vDeltaBodies) %#ok<INUSL>
            %UPLOADBODIES Push converted V_delta bodies back to the cloud.
            %
            %   VDELTABODIES is a cell array of struct V_delta bodies
            %   (one per migrated document). Uses the existing bulk
            %   upload endpoint (zip-then-PUT).
            report = ndi.migrate.internal.uploadVDeltaBodies( ...
                datasetId, vDeltaBodies);
        end

        function unpublishDataset(this, datasetId) %#ok<INUSL>
            [b, answer] = ndi.cloud.api.datasets.unpublishDataset(datasetId);
            if ~b
                error('NDI:migrate:cloud:unpublishFailed', ...
                    'Could not unpublish "%s": %s', ...
                    datasetId, formatErr(answer));
            end
        end

        function publishDataset(this, datasetId) %#ok<INUSL>
            [b, answer] = ndi.cloud.api.datasets.publishDataset(datasetId);
            if ~b
                error('NDI:migrate:cloud:publishFailed', ...
                    'Could not publish "%s": %s', ...
                    datasetId, formatErr(answer));
            end
        end
    end
end

function s = formatErr(answer)
    if isstruct(answer) && isfield(answer, 'message')
        s = char(answer.message);
    elseif ischar(answer) || isstring(answer)
        s = char(answer);
    else
        try
            s = jsonencode(answer);
        catch
            s = '<unprintable error body>';
        end
    end
end
