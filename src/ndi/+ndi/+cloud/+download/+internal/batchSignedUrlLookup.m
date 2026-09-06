function url = batchSignedUrlLookup(cloudDatasetId, cloudDocumentId, seriesName, uid, options)
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
    if isempty(CACHE) || options.clearCache
        CACHE = containers.Map('KeyType','char','ValueType','any');
    end

    url = "";

    % No document context -- e.g. a 2-arg handler call, or a caller that
    % hasn't got one -- means there is nothing to batch against.
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
        if ~ok || ~isstruct(answer) || ~isfield(answer,'files') || ...
                ~isa(answer.files,'containers.Map')
            % Any failure or unexpected shape -> no batch URL. Don't
            % cache a bad answer; do not raise. The caller falls back
            % to getFileDetails for this uid.
            return
        end
        entry = struct('map', answer.files, 'fetchedAt', now_utc);
        CACHE(cacheKey) = entry;
    end

    key = char(uid);
    if isKey(entry.map, key)
        url = entry.map(key);
        if isstring(url) && isscalar(url), url = char(url); end
    end
end
