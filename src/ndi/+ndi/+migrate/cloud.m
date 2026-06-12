function result = cloud(datasetId, options)
%CLOUD Migrate a cloud-hosted NDI dataset to V_epsilon.
%
%   RESULT = ndi.migrate.cloud(DATASETID) migrates the cloud-hosted
%   dataset DATASETID to the V_epsilon wire format. The migration runs
%   client-side: the documents are streamed down via the existing
%   list/bulk-fetch endpoints, each is converted with
%   did2.convert.v1_to_v2 (idempotent — already-V_epsilon docs are
%   skipped cheaply), and the surviving bodies are pushed back via the
%   existing bulk-upload endpoint. Because each successfully written
%   doc carries `base.schema_version: 'V_epsilon'`, an interrupted run
%   can resume by re-running this command — already-migrated docs
%   short-circuit through the conversion.
%
%   The cloud's per-dataset exclusive write lock (see issue
%   waltham-data-science/ndi-cloud-node#11) gates the migration:
%       1. acquire the lock with reason `did2-migration`;
%       2. periodically refresh it while the run is in flight;
%       3. release it on exit (success, failure, or Ctrl-C).
%   The migration refuses to proceed if the lock is held by anyone
%   else. Reads from other clients are NOT blocked during the run;
%   only writes are rejected with 423 Locked by the cloud.
%
%   Published-state handling:
%       Published datasets are immutable on the cloud, so the
%       migration refuses to run against a published dataset unless
%       the caller passes `ForceUnpublish: true`. When the option is
%       set, the migration:
%           a. records the prior publish state,
%           b. unpublishes the dataset,
%           c. runs the migration,
%           d. re-publishes the dataset on success.
%
%   Options (name-value):
%       DryRun           (1,1 logical, default false) - report what
%                        would change without acquiring the lock,
%                        unpublishing, or pushing converted docs
%                        back. The list+fetch+convert steps still
%                        run so the result struct carries an honest
%                        summary and references report.
%       ContinueOnError  (1,1 logical, default true)  - quarantine
%                        per-document conversion failures and keep
%                        going. When false, the function raises
%                        after the conversion pass if any document
%                        failed.
%       ForceUnpublish   (1,1 logical, default false) - opt-in to
%                        unpublish/publish a currently-published
%                        dataset around the migration.
%       Validate         (1,1 logical, default true)  - validate
%                        each converted document against its V_epsilon
%                        schema during conversion.
%       SchemaCache      ([] or a did2.schema.cache handle, default
%                        []) - override the shared schema cache.
%                        Used by tests.
%       PageSize         (1,1 double, default 1000) - listing
%                        page size for `listDatasetDocumentsAll`.
%       BulkFetchBatchSize  (1,1 double, default 500) - bulk-fetch
%                        size (server caps at 500).
%       UploadBatchSize  (1,1 double, default 500) - max docs per
%                        bulk-upload zip.
%       LockReason       (1,1 string, default "did2-migration") -
%                        reason recorded on the write lock.
%       LockTTLSeconds   (1,1 double, default 0) - override the
%                        server-side default TTL (~30 min). 0
%                        leaves the default.
%       Verbose          (1,1 logical, default false) - print the
%                        end-of-run summary to stdout.
%       Client           ([] or ndi.migrate.internal.cloudClient,
%                        default []) - inject a transport. Used by
%                        tests to drive the migration loop without
%                        contacting the real cloud.
%
%   RESULT is a struct with fields:
%       datasetId        - the input dataset id.
%       dryRun           - logical, mirrors the DryRun option.
%       publishState     - struct: `wasPublished` (logical), and
%                          `republished` (logical, true iff this run
%                          re-published at the end).
%       lock             - struct: `acquired` (logical), `released`
%                          (logical), and `info` (the lock state
%                          returned by the cloud on acquire).
%       summary          - the `summary` field returned by
%                          did2.convert.v1_to_v2 (`total`,
%                          `migrated_count`, `quarantine_count`,
%                          `by_class`).
%       quarantine       - struct array of per-doc failures (see
%                          did2.convert.v1_to_v2).
%       references       - report from did2.validate.references over
%                          the migrated corpus.
%       upload           - per-batch upload report (uploadType,
%                          manifest, status) or [] when nothing was
%                          pushed (DryRun, empty dataset, or no
%                          documents survived conversion).
%
%   Errors:
%       NDI:migrate:cloud:publishedRefuse - dataset is published and
%                                           ForceUnpublish is false.
%       NDI:migrate:cloud:lockHeld        - another client holds the
%                                           write lock; migration
%                                           cannot proceed.
%       NDI:migrate:cloud:hadQuarantine   - ContinueOnError=false and
%                                           at least one doc failed.
%
%   See also: ndi.migrate.local, did2.convert.v1_to_v2,
%             did2.validate.references,
%             ndi.cloud.api.datasets.acquireWriteLock.

    arguments
        datasetId (1,1) string
        options.DryRun (1,1) logical = false
        options.ContinueOnError (1,1) logical = true
        options.ForceUnpublish (1,1) logical = false
        options.Validate (1,1) logical = true
        options.SchemaCache = []
        options.PageSize (1,1) double = 1000
        options.BulkFetchBatchSize (1,1) double = 500
        options.UploadBatchSize (1,1) double = 500
        options.LockReason (1,1) string = "did2-migration"
        options.LockTTLSeconds (1,1) double = 0
        options.Verbose (1,1) logical = false
        options.Client = []
    end

    if isempty(options.Client)
        client = ndi.migrate.internal.cloudClient();
    else
        client = options.Client;
    end

    result = struct();
    result.datasetId = datasetId;
    result.dryRun = options.DryRun;
    result.publishState = struct('wasPublished', false, 'republished', false);
    result.lock = struct('acquired', false, 'released', false, 'info', []);
    result.summary = struct('total', 0, 'migrated_count', 0, ...
        'quarantine_count', 0, 'by_class', struct());
    result.quarantine = struct('original_body', {}, 'class_name', {}, ...
        'reason', {}, 'failed_at', {});
    result.references = struct('orphan_count', 0, 'edges_examined', 0);
    result.upload = [];

    datasetInfo = client.getDataset(datasetId);
    wasPublished = isPublished(datasetInfo);
    result.publishState.wasPublished = wasPublished;

    if wasPublished && ~options.ForceUnpublish
        error('NDI:migrate:cloud:publishedRefuse', ...
            ['Dataset "%s" is published; refusing to migrate. Pass ' ...
             '''ForceUnpublish'', true to unpublish/publish around ' ...
             'the migration.'], datasetId);
    end

    runStateHolder = ndi.migrate.internal.runStateRef();

    if ~options.DryRun
        lockInfo = client.acquireLock(datasetId, options.LockReason, ...
            options.LockTTLSeconds);
        result.lock.acquired = true;
        result.lock.info = lockInfo;
        lockHolder = onCleanup(@() safeReleaseLock(client, datasetId, runStateHolder));
    end

    if ~options.DryRun && wasPublished
        client.unpublishDataset(datasetId);
        publishCleanup = onCleanup(@() safeRepublish(client, datasetId, runStateHolder));
    end

    summaries = client.listAllDocuments(datasetId, options.PageSize);
    docIds = collectCloudIds(summaries);

    refreshFcn = makeRefresher(client, datasetId, options.DryRun);
    bodies = fetchAllBodies(client, datasetId, docIds, ...
        options.BulkFetchBatchSize, refreshFcn);
    refreshFcn();

    convertResult = did2.convert.v1_to_v2(bodies, ...
        'Validate', options.Validate, ...
        'SchemaCache', options.SchemaCache, ...
        'Verbose', false);

    result.summary = convertResult.summary;
    result.quarantine = convertResult.quarantine;

    migratedBodies = migratedAsStructs(convertResult.migrated);

    if ~options.DryRun && ~isempty(migratedBodies)
        result.upload = client.uploadBodies(datasetId, migratedBodies);
    end

    result.references = did2.validate.references(convertResult.migrated);

    if ~options.DryRun && wasPublished
        client.publishDataset(datasetId);
        result.publishState.republished = true;
        runStateHolder.set('republished', true);
    end

    if ~options.DryRun
        client.releaseLock(datasetId);
        result.lock.released = true;
        runStateHolder.set('lockReleased', true);
    end

    if options.Verbose
        printSummary(result);
    end

    if ~options.ContinueOnError && ~isempty(convertResult.quarantine)
        error('NDI:migrate:cloud:hadQuarantine', ...
            ['Migration of dataset "%s" quarantined %d document(s); ' ...
             'ContinueOnError was false.'], ...
            datasetId, numel(convertResult.quarantine));
    end
end

% ---- helpers ----------------------------------------------------------------

function tf = isPublished(datasetInfo)
    tf = false;
    if isstruct(datasetInfo) && isfield(datasetInfo, 'isPublished')
        tf = logical(datasetInfo.isPublished);
    end
end

function ids = collectCloudIds(summaries)
    if isempty(summaries)
        ids = strings(1, 0);
        return;
    end
    if isstruct(summaries)
        ids = string({summaries.id});
    elseif iscell(summaries)
        ids = string(cellfun(@(x) x.id, summaries, 'UniformOutput', false));
    else
        ids = strings(1, 0);
    end
end

function bodies = fetchAllBodies(client, datasetId, cloudIds, batchSize, refreshFcn)
    bodies = {};
    total = numel(cloudIds);
    for i = 1:batchSize:total
        startIdx = i;
        endIdx = min(i + batchSize - 1, total);
        chunkIds = cloudIds(startIdx:endIdx);
        chunk = client.bulkFetchDocuments(datasetId, chunkIds);
        bodies = [bodies extractBodies(chunk)]; %#ok<AGROW>
        refreshFcn();
    end
end

function fcn = makeRefresher(client, datasetId, dryRun)
    % Refreshing the cloud-side TTL every batch is the simplest way to
    % keep a long migration from losing the lock mid-run. A noop on
    % DryRun (the lock was never acquired) and tolerant of refresh
    % failures (a transient refresh failure should not kill an
    % otherwise-healthy run; the next batch will try again, and on
    % expiry the cloud's write rejection will surface the problem).
    if dryRun
        fcn = @() [];
        return;
    end
    fcn = @() tryRefresh(client, datasetId);
end

function tryRefresh(client, datasetId)
    try
        client.refreshLock(datasetId);
    catch
        % Best-effort; ignore transient refresh failures.
    end
end

function out = extractBodies(chunk)
    out = {};
    if isempty(chunk)
        return;
    end
    if isstruct(chunk)
        out = cell(1, numel(chunk));
        for k = 1:numel(chunk)
            out{k} = chunk(k).data;
        end
    elseif iscell(chunk)
        out = cellfun(@(x) x.data, chunk, 'UniformOutput', false);
    end
end

function structs = migratedAsStructs(migrated)
    structs = cell(1, numel(migrated));
    for k = 1:numel(migrated)
        m = migrated{k};
        if isa(m, 'did2.document')
            structs{k} = m.toStruct();
        elseif isstruct(m)
            structs{k} = m;
        else
            error('NDI:migrate:cloud:badMigratedShape', ...
                'Unexpected migrated entry of class %s.', class(m));
        end
    end
end

function safeReleaseLock(client, datasetId, runStateHolder)
    if runStateHolder.get('lockReleased')
        return;
    end
    try
        client.releaseLock(datasetId);
    catch
        % Best-effort release on the error path; the cloud's lock
        % auto-expires on the next write attempt anyway.
    end
end

function safeRepublish(client, datasetId, runStateHolder)
    if runStateHolder.get('republished')
        return;
    end
    try
        client.publishDataset(datasetId);
    catch
        % Best-effort republish on the error path; the caller's
        % result struct still records publishState.republished=false
        % so the human can re-publish manually.
    end
end

function printSummary(result)
    fprintf('ndi.migrate.cloud summary for "%s":\n', result.datasetId);
    fprintf('  dry-run:           %d\n', result.dryRun);
    fprintf('  was published:     %d\n', result.publishState.wasPublished);
    fprintf('  re-published:      %d\n', result.publishState.republished);
    fprintf('  lock acquired:     %d\n', result.lock.acquired);
    fprintf('  lock released:     %d\n', result.lock.released);
    fprintf('  total docs:        %d\n', result.summary.total);
    fprintf('  migrated:          %d\n', result.summary.migrated_count);
    fprintf('  quarantined:       %d\n', result.summary.quarantine_count);
    fprintf('  orphan refs:       %d (of %d edges)\n', ...
        result.references.orphan_count, result.references.edges_examined);
end
