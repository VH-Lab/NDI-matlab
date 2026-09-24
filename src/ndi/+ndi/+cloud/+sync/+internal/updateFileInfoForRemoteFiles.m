function document = updateFileInfoForRemoteFiles(document, cloudDatasetId, options)
% updateFileInfoForRemoteFiles - Update file info of document for remote (cloud-only) files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId)
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles( ...
%       document, cloudDatasetId, 'customFileHandler', HANDLER)
%
%   This function updates the file information in the provided document
%   object for files that are stored remotely in NDI cloud.
%
%   The following changes are made to the file location structure:
%       1. set the 'delete_original' and 'ingest' fields to false.
%       2. set the location field using the template "ndic://{dataset_id}/{file_uid}"
%       3. set the location_type field to "ndicloud"
%
%   In addition, for any file series the document declares with
%   `n_present > 0` and no `ingest_locations`, this reconstructs
%   `ingest_locations` in the shape SyncFiles=true produces (via
%   reconstructSeriesIngestLocations), by fetching the manifest bytes
%   dynamically and reading the member uids from them. The manifest
%   bytes are dropped when the function returns, so no local files
%   persist -- the manifest is expected to land in the file cache on
%   the next member open, through DID-matlab #201's handler-fetch path
%   (fetchSeriesManifestBytes). If the cache is ever evicted, the same
%   path re-fetches. This satisfies DID-matlab #185's MembersNotLocatable
%   guard on the following add_docs, which was hitting every
%   SyncFiles=false download that carried a series document
%   (VH-Lab/NDI-matlab#986).
%
%   The manifest fetch goes through the same DID customFileHandler
%   contract DID uses on the read side, so a caller (test or
%   otherwise) that has a handler already -- a mock, or a shared
%   cloud fetcher -- can pass it in and both sides use the same one.
%   With no handler passed, this calls into ndi.cloud.api.files.*
%   directly, matching what the read-side didsqlite handler does
%   when a manifest is asked for by uid.
%
% Input Arguments:
%   document          - The document object containing file information.
%   cloudDatasetId    - The unique identifier for the cloud dataset.
%
% Optional Name-Value Arguments:
%   customFileHandler - A function handle following DID's
%                       customFileHandler contract (destPath, sourcePath[,
%                       context]) that resolves ndic:// URIs. When provided,
%                       used for the manifest fetch. When empty (default),
%                       the manifest is fetched by minting a signed URL
%                       against ndi.cloud.api.files, matching didsqlite's
%                       own download_file_from_cloud handler.
%
% Output Arguments:
%   document          - The updated document object with modified file info.
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForLocalFiles,
%   ndi.cloud.sync.internal.reconstructSeriesIngestLocations,
%   did.implementations.sqlitedb.dispatchCustomFileHandler

    arguments
        document
        cloudDatasetId (1,1) string
        options.customFileHandler = []
        % A containers.Map of uid -> logical uploaded flag, precomputed
        % once at the caller from ndi.cloud.api.files.listFilesAll (the
        % paginated whole-dataset listing landed in main via NDI-matlab
        % #1004). When supplied, this function uses it to skip the manifest
        % fetch for series whose manifest uid isn't uploaded on the
        % server, and to warn on file_info uids that name unuploaded
        % files. Empty (the default) preserves the previous behavior.
        options.uploadedUidMap = []
    end

    if ~document.has_files(), return, end

    updatedFileInfo = document.document_properties.files.file_info;

    missingFileUidCount = 0;
    firstMissingFileUid = '';
    for i = 1:numel(updatedFileInfo)
        % Replace/override 1st file location
        updatedFileInfo(i).locations(1).delete_original = 0;
        updatedFileInfo(i).locations(1).ingest = 0;

        fileUid = updatedFileInfo(i).locations(1).uid;
        fileLocation = sprintf('ndic://%s/%s', cloudDatasetId, fileUid);
        updatedFileInfo(i).locations(1).location = fileLocation;
        updatedFileInfo(i).locations(1).location_type = 'ndicloud';

        % Optional integrity check: a file_info entry pointing at a uid
        % the server does not yet report as uploaded produces a broken
        % ndic:// location -- DID's later member/file open will fail
        % obscurely. Count them now and warn once at the end of the doc
        % rather than spamming per file.
        if ~isUploaded(options.uploadedUidMap, fileUid)
            missingFileUidCount = missingFileUidCount + 1;
            if isempty(firstMissingFileUid)
                firstMissingFileUid = char(fileUid);
            end
        end
    end
    document = document.setproperties('files.file_info', updatedFileInfo);

    if missingFileUidCount > 0
        warning('NDI:cloud:sync:UnuploadedFileUid', ...
            ['%d file_info entry/entries in document reference uids the ', ...
             'cloud does not report as uploaded (first: %s). A member/file ', ...
             'open will fail on those.'], missingFileUidCount, firstMissingFileUid);
    end

    % Rebuild series ingest_locations for any series that came back with
    % n_present > 0 but empty ingest_locations. Without this, DID's
    % MembersNotLocatable guard (DID-matlab#185) refuses the document on
    % the following add_docs -- the whole SyncFiles=false path was
    % blocked on this. Members are still remote; the fetch here only
    % reads the manifest, and only long enough to know each present
    % slot's uid.
    hasSeriesInfo = isfield(document.document_properties.files, 'series_info');
    if hasSeriesInfo
        seriesInfo = document.document_properties.files.series_info;
        if needsReconstruction(seriesInfo)
            documentId = "";
            try
                documentId = string(document.document_properties.base.id);
            catch
            end
            seriesInfo = reconstructFromCloud(seriesInfo, updatedFileInfo, ...
                cloudDatasetId, documentId, options.customFileHandler, ...
                options.uploadedUidMap);
            document = document.setproperties('files.series_info', seriesInfo);
        end
    end
end


function tf = needsReconstruction(seriesInfo)
    % Any entry with n_present > 0 and no ingest_locations qualifies for
    % reconstruction. Same predicate reconstructSeriesIngestLocations uses
    % internally, hoisted so an all-good document skips the whole fetch.
    tf = false;
    if isempty(seriesInfo), return, end
    for k = 1:numel(seriesInfo)
        entry = seriesInfo(k);
        if ~isfield(entry, 'n_present') || isempty(entry.n_present) || ...
                entry.n_present <= 0
            continue
        end
        if isfield(entry, 'ingest_locations') && ~isempty(entry.ingest_locations)
            continue
        end
        tf = true;
        return
    end
end


function seriesInfo = reconstructFromCloud(seriesInfo, fileInfo, ...
        cloudDatasetId, documentId, customFileHandler, uploadedUidMap)
    % Fetch each qualifying series' manifest bytes into a scratch dir,
    % reconstruct ingest_locations from them via reconstructSeriesIngestLocations,
    % then delete the scratch dir. Manifests do NOT land in the DID file
    % cache here -- a subsequent member open trips DID#201's lazy fetch,
    % which is what populates the cache. That's the design: the manifest
    % is never a persistent local file the caller depends on, and cache
    % eviction on a later session is answered by the same re-fetch path.

    tmpDir = fullfile(did.common.PathConstants.temppath, ...
        ['ndi-manifest-fetch-' did.ido.unique_id()]);
    if ~isfolder(tmpDir), mkdir(tmpDir); end
    cleanup = onCleanup(@() safeRmdir(tmpDir));

    % Count qualifying series up front so the progress bar has a
    % denominator. A doc with 10 pyramid levels has 10 series that each
    % require one HTTPS round trip for the manifest, then one linear pass
    % over the manifest's members; without a bar the whole "Updating
    % document file info to reflect remote files." step looks hung on a
    % large lightsheet dataset.
    qualifyingIdx = [];
    for k = 1:numel(seriesInfo)
        entry = seriesInfo(k);
        if ~isfield(entry, 'n_present') || isempty(entry.n_present) || ...
                entry.n_present <= 0
            continue
        end
        if isfield(entry, 'ingest_locations') && ~isempty(entry.ingest_locations)
            continue
        end
        qualifyingIdx(end+1) = k; %#ok<AGROW>
    end

    progressApp = [];
    fetchBarId = '';
    if numel(qualifyingIdx) > 0
        try
            progressApp = ndi.gui.component.ProgressBarWindow('NDI tasks');
            fetchBarId  = did.ido.unique_id();
            progressApp.addBar( ...
                'Label', sprintf('Fetching %d series manifest(s) from cloud', ...
                    numel(qualifyingIdx)), ...
                'tag', fetchBarId, ...
                'Auto', true, ...
                'Timeout', minutes(Inf));
        catch
            progressApp = [];
        end
    end

    for j = 1:numel(qualifyingIdx)
        k = qualifyingIdx(j);
        entry = seriesInfo(k);

        manifestUid = lookupManifestUid(fileInfo, entry.name);
        if isempty(manifestUid)
            tickBar(progressApp, fetchBarId, j / numel(qualifyingIdx));
            continue
        end

        % Skip the fetch when the caller-provided uploaded-uid map says
        % the manifest itself is not uploaded on the server. Attempting
        % the fetch would only turn into a wasted HTTPS round trip whose
        % 404/403 landed in the catch below; no reconstruction happens
        % either way. When no map was passed, this is a no-op.
        if ~isUploaded(uploadedUidMap, manifestUid)
            tickBar(progressApp, fetchBarId, j / numel(qualifyingIdx));
            continue
        end

        destPath = fullfile(tmpDir, manifestUid);
        try
            fetchManifest(destPath, cloudDatasetId, string(manifestUid), ...
                documentId, char(entry.name), customFileHandler);
        catch
            % A manifest that cannot be fetched leaves the entry
            % un-reconstructed; DID#185's guard will then fire on
            % add_docs with the document's own identity, which is the
            % signal a partial download deserves. No warning here --
            % add_docs is the right voice.
        end
        tickBar(progressApp, fetchBarId, j / numel(qualifyingIdx));
    end

    seriesInfo = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
        seriesInfo, fileInfo, tmpDir, cloudDatasetId);
end


function fetchManifest(destPath, cloudDatasetId, manifestUid, documentId, ...
        seriesName, customFileHandler)
    % Fetch one manifest by uid. If a customFileHandler was passed in,
    % offer the fetch through the DID contract -- same shape DID#201's
    % fetchSeriesManifestBytes uses on the read side -- so tests can
    % inject a mock and the two sides share their fetcher. Otherwise
    % mint a signed URL and fetch directly, matching didsqlite.m's own
    % download_file_from_cloud for a non-member ndic:// file.
    %
    % seriesName is deliberately '' in the context: this is the manifest
    % itself, not a member. On the DID contract, a non-empty seriesName
    % marks a MEMBER fetch, where sourcePath names the manifest and
    % context.uid names the member -- the handler must then treat
    % context.uid as the file to retrieve, not the manifest again. A
    % manifest fetch has no such switch: sourcePath names the manifest
    % and context.uid names the same manifest.

    sourcePath = sprintf('ndic://%s/%s', char(cloudDatasetId), char(manifestUid));

    if ~isempty(customFileHandler)
        ctx = struct( ...
            'documentId', char(documentId), ...
            'filename',   char(seriesName), ...
            'seriesName', '', ...
            'uid',        char(manifestUid), ...
            'mode',       'open');
        did.implementations.sqlitedb.dispatchCustomFileHandler( ...
            customFileHandler, destPath, sourcePath, ctx);
        return
    end

    fileUrl = ndi.cloud.download.internal.batchSignedUrlLookup( ...
        string(cloudDatasetId), documentId, "", manifestUid);
    if strlength(fileUrl) == 0
        [success, answer] = ndi.cloud.api.files.getFileDetails( ...
            char(cloudDatasetId), char(manifestUid));
        if ~success
            error('NDI:cloud:sync:ManifestFetchFailed', ...
                'Failed to get file details for manifest %s: %s', ...
                char(manifestUid), answer.message);
        end
        fileUrl = answer.downloadUrl;
    end
    [success2, answer2] = ndi.cloud.api.files.getFile( ...
        char(fileUrl), char(destPath), 'useCurl', true);
    if ~success2
        error('NDI:cloud:sync:ManifestFetchFailed', ...
            'Failed to download manifest %s from cloud: %s', ...
            char(manifestUid), answer2);
    end
end


function uid = lookupManifestUid(fileInfo, seriesName)
    % A series named NAME has an ordinary file_info entry whose `name` is
    % NAME; that entry's locations(1).uid is the manifest's uid.
    uid = '';
    seriesName = char(seriesName);
    for m = 1:numel(fileInfo)
        if ~strcmp(char(fileInfo(m).name), seriesName), continue, end
        if isempty(fileInfo(m).locations), return, end
        uid = char(fileInfo(m).locations(1).uid);
        return
    end
end


function safeRmdir(d)
    if isfolder(d)
        try
            rmdir(d, 's');
        catch
        end
    end
end

function tf = isUploaded(map, uid)
    % True when the caller passed no map (default open answer -- preserves
    % the previous no-check behavior), or when the map says this uid is
    % on the server as uploaded=true. False only when the map is present
    % AND names this uid as not uploaded (or does not name it at all).
    if isempty(map)
        tf = true;
        return
    end
    try
        key = char(uid);
        if ~isKey(map, key)
            tf = false;
            return
        end
        tf = logical(map(key));
    catch
        tf = false;
    end
end

function tickBar(app, tag, progress)
    % Guarded progress update. If the bar / window has been closed or
    % culled, drop the update silently rather than crash the download
    % pipeline. Same defensive contract list_binary_files uses.
    if isempty(app) || ~isvalid(app) || isempty(tag)
        return
    end
    try
        app.updateBar(tag, progress);
    catch
    end
end
