function [url, stats] = batchSignedUrlLookup(cloudDatasetId, cloudDocumentId, seriesName, uid, options)
%BATCHSIGNEDURLLOOKUP Look one uid up in the per-document signed-URL cache.
%
%   URL = ndi.cloud.download.internal.batchSignedUrlLookup( ...
%             cloudDatasetId, cloudDocumentId, seriesName, uid)
%
%   Returns the pre-signed GET URL for one file uid inside a given
%   (dataset, document [, series]) scope, or "" when no URL could be
%   obtained. On a cache miss for the scope, the whole scope is fetched
%   with ndi.cloud.api.files.getSignedURLSetAll -- one API round trip
%   for every uid the document (or the named file series) references --
%   and cached in-process for the returned URLs' lifetime. Subsequent
%   uids in the same scope resolve from the cache without another
%   round trip.
%
%   Motivation: DID's customFileHandler previously called
%   ndi.cloud.api.files.getFileDetails once per uid, so opening a
%   28,000-member lightsheet series cost 28,000 API round trips
%   (VH-Lab/DID-matlab#173 step 3, tracked here as
%   VH-Lab/NDI-matlab#952). This helper turns that into one call per
%   document (or one per series scope) plus the S3 GETs that were
%   always going to happen.
%
%   Empty return values are legitimate answers, not errors: the batch
%   call may fail (network, auth, timeout) or the map it returns may
%   not name this uid (data drift). The caller falls back to
%   getFileDetails in either case. The batch is an optimization, not
%   an authority.
%
%   Inputs:
%       cloudDatasetId  (1,1) string  - the dataset id
%       cloudDocumentId (1,1) string  - the document id; when empty,
%                                       lookup is bypassed and "" is
%                                       returned (no document context,
%                                       nothing to batch against).
%       seriesName      (1,1) string  - "" for a whole-document scope,
%                                       or a file-series name to scope
%                                       the batch to that series only
%                                       (the endpoint accepts this).
%       uid             (1,1) string  - the file uid to resolve.
%
%   Name-Value Pairs:
%       signer     - Function handle overriding the batch API call.
%                    Called as [ok, answer] = signer(datasetId,
%                    documentId, 'fileSeries', seriesName). Defaults to
%                    @ndi.cloud.api.files.getSignedURLSetAll. Present
%                    so tests can inject a scripted response without a
%                    live server.
%       clearCache - If true, drop the in-process cache before doing
%                    anything else. Present for test isolation.
%       ttlSeconds - How long a cached scope stays valid, in seconds.
%                    Default 20*3600 (the server currently signs URLs
%                    for 24 h, leaving a buffer). A scope past its
%                    TTL is refetched on the next miss.
%
%   Outputs:
%       url         - The pre-signed URL for uid (char), or "" (string
%                     scalar) when no URL is available.
%       stats       - Cumulative counters since the cache was last cleared:
%                     .signerCalls  how many times the batch endpoint was
%                                   actually called (one per scope fetch)
%                     .uidHits      uids answered from a batch map
%                     .uidMisses    uids the batch could NOT answer, each of
%                                   which sends the caller to the per-uid
%                                   getFileDetails fallback
%                     .lastMapSize  entries in the most recent batch map
%
%                     These exist to make the fallback VISIBLE. It is
%                     deliberate at runtime -- a reader opening one file
%                     should not fail because a batch endpoint hiccuped --
%                     and it is precisely wrong as a test property: a test
%                     of the batch path that silently falls back to N per-uid
%                     calls still passes, having proved nothing about the
%                     path it was written for. See VH-Lab/NDI-matlab#968.
%
%                     Read them without disturbing the cache by calling with
%                     an empty documentId, which returns early:
%                         [~, s] = batchSignedUrlLookup("", "", "", "");
%
%                     NOTE what uidMisses does and does not distinguish. It
%                     catches a fallback. It does NOT catch a server that
%                     ignores the 'fileSeries' scope and returns the whole
%                     DOCUMENT's URL set, since that map contains the member
%                     uids too and answers every one of them. lastMapSize is
%                     the handle on that: a scoped answer names the series'
%                     members, an unscoped one also names every other file
%                     the document has.
%
%   See also: ndi.cloud.api.files.getSignedURLSetAll,
%             ndi.cloud.api.files.getFileDetails
    arguments
        cloudDatasetId  (1,1) string
        cloudDocumentId (1,1) string
        seriesName      (1,1) string
        uid             (1,1) string
        options.signer     = @ndi.cloud.api.files.getSignedURLSetAll
        options.clearCache (1,1) logical = false
        options.ttlSeconds (1,1) double  = 20*3600
    end

    % The persistent cache. Keyed on 'datasetId/documentId/seriesName'.
    % Each entry is a struct with `.map` (containers.Map uid -> URL) and
    % `.fetchedAt` (datetime, UTC).
    persistent CACHE
    persistent STATS
    if isempty(CACHE) || options.clearCache
        CACHE = containers.Map('KeyType','char','ValueType','any');
    end
    if isempty(STATS) || options.clearCache
        STATS = struct('signerCalls', 0, 'uidHits', 0, 'uidMisses', 0, ...
            'lastMapSize', 0);
    end

    url = "";
    stats = STATS;

    % No document context -- e.g. a 2-arg handler call, or a caller that
    % hasn't got one -- means there is nothing to batch against. Not a miss:
    % nothing was asked of the batch, so nothing failed. This is also the
    % call a test uses to read the counters without touching the cache.
    if strlength(cloudDocumentId) == 0
        return
    end

    cacheKey = sprintf('%s/%s/%s', ...
        char(cloudDatasetId), char(cloudDocumentId), char(seriesName));

    now_utc = datetime('now','TimeZone','UTC');

    entry = [];
    if isKey(CACHE, cacheKey)
        e = CACHE(cacheKey);
        if seconds(now_utc - e.fetchedAt) < options.ttlSeconds
            entry = e;
        else
            % Stale; drop and refetch.
            remove(CACHE, cacheKey);
        end
    end

    if isempty(entry)
        % Populate the cache for this scope. The signer is expected to
        % return `answer.files` as a containers.Map from uid to URL --
        % which is what getSignedURLSetAll produces via signedURLFileMap.
        try
            if strlength(seriesName) > 0
                [ok, answer] = options.signer(cloudDatasetId, cloudDocumentId, ...
                    'fileSeries', seriesName);
            else
                [ok, answer] = options.signer(cloudDatasetId, cloudDocumentId);
            end
        catch
            ok = false;
            answer = [];
        end
        STATS.signerCalls = STATS.signerCalls + 1;
        if ~ok || ~isstruct(answer) || ~isfield(answer,'files') || ...
                ~isa(answer.files,'containers.Map')
            % Any failure or unexpected shape -> no batch URL. Don't
            % cache a bad answer; do not raise. The caller falls back
            % to getFileDetails for this uid.
            STATS.uidMisses = STATS.uidMisses + 1;
            stats = STATS;
            return
        end
        entry = struct('map', answer.files, 'fetchedAt', now_utc);
        CACHE(cacheKey) = entry;
        STATS.lastMapSize = double(entry.map.Count);
    end

    key = char(uid);
    if isKey(entry.map, key)
        url = entry.map(key);
        if isstring(url) && isscalar(url), url = char(url); end
        STATS.uidHits = STATS.uidHits + 1;
    else
        % The scope was fetched but does not name this uid -- data drift, or
        % a scope that does not actually cover the file. The caller falls
        % back per uid.
        STATS.uidMisses = STATS.uidMisses + 1;
    end
    stats = STATS;
end
