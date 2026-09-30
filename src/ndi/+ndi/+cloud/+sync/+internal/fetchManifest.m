function fetchManifest(destPath, cloudDatasetId, manifestUid, documentId, ...
        seriesName, customFileHandler, options)
%FETCHMANIFEST Download a single series manifest to a local path.
%
%   Extracted from ndi.cloud.sync.internal.updateFileInfoForRemoteFiles
%   so the manifest fetch can be exercised in a test without dragging
%   the whole reconstruction path in behind it.
%
%   A manifest is a SINGLE KNOWN uid, so the URL is resolved with one
%   direct getFileDetails call. Going through the per-document batch
%   cache (ndi.cloud.download.internal.batchSignedUrlLookup) here would
%   force the batch to walk the whole document's signed-URL set to
%   answer a question that has one correct answer: for a 121k-chunk
%   lightsheet level that is ~243 pages at ~25 s each -- roughly
%   100 min per manifest fetch, seven levels ≈ 12 h before any bytes
%   hit disk. The batch is worth its cost when many uids share the
%   document; for a single uid it is pure overhead. See
%   VH-Lab/NDI-matlab#1010 and Waltham-Data-Science/NDI-python
%   commit 5ab9c04 (the Python analog fix).
%
%   Inputs:
%       destPath          - Local file to write the manifest bytes to.
%       cloudDatasetId    - The cloud dataset id.
%       manifestUid       - The manifest file's uid.
%       documentId        - The NDI document id (passed to the
%                           customFileHandler context; ignored on the
%                           direct-fetch path).
%       seriesName        - The series' name (passed to the handler
%                           context so it can identify the series
%                           whose manifest is being fetched).
%       customFileHandler - When non-empty, the fetch is dispatched
%                           through DID's customFileHandler contract
%                           (same shape DID#201's fetchSeriesManifest
%                           uses on the read side). Otherwise a signed
%                           URL is minted and the file downloaded
%                           directly, matching didsqlite.m's own
%                           download_file_from_cloud path.
%
%   Name-Value Pairs:
%       DetailsFetcher - Function handle called as
%                        [ok, answer] = fcn(datasetId, fileUid) to
%                        resolve one uid's signed URL. Defaults to
%                        @ndi.cloud.api.files.getFileDetails. Present
%                        so a test can inject a scripted answer and
%                        prove which single-uid function was called
%                        with which uid, without hitting the network.
%       FileFetcher    - Function handle called as
%                        [ok, msg] = fcn(url, path, 'useCurl', true)
%                        to write the manifest bytes to disk. Defaults
%                        to @ndi.cloud.api.files.getFile. Same
%                        injection point for tests.
%
%   See also: ndi.cloud.api.files.getFileDetails,
%             ndi.cloud.api.files.getFile,
%             ndi.cloud.download.internal.batchSignedUrlLookup

    arguments
        destPath          (1,1) string
        cloudDatasetId    (1,1) string
        manifestUid       (1,1) string
        documentId        (1,1) string
        seriesName        (1,1) string
        customFileHandler
        options.DetailsFetcher (1,1) function_handle = ...
            @ndi.cloud.api.files.getFileDetails
        options.FileFetcher    (1,1) function_handle = ...
            @ndi.cloud.api.files.getFile
    end

    % seriesName is deliberately '' in the ctx: this is the manifest
    % itself, not a member. On the DID contract, a non-empty
    % seriesName marks a MEMBER fetch, where sourcePath names the
    % manifest and context.uid names the member -- the handler must
    % then treat context.uid as the file to retrieve, not the manifest
    % again. A manifest fetch has no such switch: sourcePath names the
    % manifest and context.uid names the same manifest.
    sourcePath = sprintf('ndic://%s/%s', char(cloudDatasetId), char(manifestUid));

    if ~isempty(customFileHandler)
        ctx = struct( ...
            'documentId', char(documentId), ...
            'filename',   char(seriesName), ...
            'seriesName', '', ...
            'uid',        char(manifestUid), ...
            'mode',       'open');
        did.implementations.sqlitedb.dispatchCustomFileHandler( ...
            customFileHandler, char(destPath), sourcePath, ctx);
        return
    end

    [success, answer] = options.DetailsFetcher( ...
        char(cloudDatasetId), char(manifestUid));
    if ~success
        message = '';
        if isstruct(answer) && isfield(answer, 'message')
            message = char(string(answer.message));
        end
        error('NDI:cloud:sync:ManifestFetchFailed', ...
            'Failed to get file details for manifest %s: %s', ...
            char(manifestUid), message);
    end
    fileUrl = answer.downloadUrl;

    [success2, answer2] = options.FileFetcher( ...
        char(fileUrl), char(destPath), 'useCurl', true);
    if ~success2
        error('NDI:cloud:sync:ManifestFetchFailed', ...
            'Failed to download manifest %s from cloud: %s', ...
            char(manifestUid), char(string(answer2)));
    end
end
