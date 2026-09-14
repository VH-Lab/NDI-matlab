function document = updateFileInfoForRemoteFiles(document, cloudDatasetId)
% updateFileInfoForRemoteFiles - Update file info of document for remote (cloud-only) files
%
% Syntax:
%   document = ndi.cloud.sync.internal.updateFileInfoForRemoteFiles(document, cloudDatasetId)
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
%   dynamically from NDI Cloud and reading the member uids from them. The
%   manifest bytes are dropped when the function returns, so no local
%   files persist -- the manifest is expected to land in the file cache
%   on the next member open, through DID-matlab #201's handler-fetch path
%   (fetchSeriesManifestBytes). If the cache is ever evicted, the same
%   path re-fetches. This satisfies DID-matlab #185's MembersNotLocatable
%   guard on the following add_docs, which was hitting every
%   SyncFiles=false download that carried a series document
%   (VH-Lab/NDI-matlab#986).
%
% Input Arguments:
%   document          - The document object containing file information.
%   cloudDatasetId    - The unique identifier for the cloud dataset.
%
% Output Arguments:
%   document          - The updated document object with modified file info.
%
% See also:
%   ndi.cloud.sync.internal.updateFileInfoForLocalFiles,
%   ndi.cloud.sync.internal.reconstructSeriesIngestLocations

    arguments
        document
        cloudDatasetId (1,1) string
    end

    if ~document.has_files(), return, end

    updatedFileInfo = document.document_properties.files.file_info;

    for i = 1:numel(updatedFileInfo)
        % Replace/override 1st file location
        updatedFileInfo(i).locations(1).delete_original = 0;
        updatedFileInfo(i).locations(1).ingest = 0;

        fileUid = updatedFileInfo(i).locations(1).uid;
        fileLocation = sprintf('ndic://%s/%s', cloudDatasetId, fileUid);
        updatedFileInfo(i).locations(1).location = fileLocation;
        updatedFileInfo(i).locations(1).location_type = 'ndicloud';
    end
    document = document.setproperties('files.file_info', updatedFileInfo);

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
                cloudDatasetId, documentId);
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
        cloudDatasetId, documentId)
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

    for k = 1:numel(seriesInfo)
        entry = seriesInfo(k);
        if ~isfield(entry, 'n_present') || isempty(entry.n_present) || ...
                entry.n_present <= 0
            continue
        end
        if isfield(entry, 'ingest_locations') && ~isempty(entry.ingest_locations)
            continue
        end

        manifestUid = lookupManifestUid(fileInfo, entry.name);
        if isempty(manifestUid), continue, end

        destPath = fullfile(tmpDir, manifestUid);
        try
            fetchManifestFromCloud(destPath, cloudDatasetId, ...
                string(manifestUid), documentId);
        catch
            % A manifest that cannot be fetched leaves the entry
            % un-reconstructed; DID#185's guard will then fire on
            % add_docs with the document's own identity, which is the
            % signal a partial download deserves. No warning here --
            % add_docs is the right voice.
            continue
        end
    end

    seriesInfo = ndi.cloud.sync.internal.reconstructSeriesIngestLocations( ...
        seriesInfo, fileInfo, tmpDir, cloudDatasetId);
end


function fetchManifestFromCloud(destPath, cloudDatasetId, manifestUid, documentId)
    % Ordinary ndic:// fetch by uid. Same mint-URL-then-getFile that
    % didsqlite.m's `download_file_from_cloud` runs for a non-member file,
    % kept local to this file rather than shared: the read-side handler
    % has a three-arg DID contract and a manifest-vs-member uid switch
    % that a download-time caller does not need, and lifting the shared
    % piece into its own helper would widen this fix beyond the
    % SyncFiles=false gap it closes.
    %
    % seriesName is empty on purpose: the manifest is a document-scope
    % file, not part of a member scope. Whole-document batches will still
    % answer for it if the caller passed a documentId; otherwise the
    % per-uid getFileDetails fallback below handles it.

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
