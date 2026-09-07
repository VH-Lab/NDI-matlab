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
%                     .lastFailureReason  why the last batch attempt did not
%                                   produce a usable map -- which of the four
%                                   unrelated causes it was, with the HTTP
%                                   status when the signer reports one. This
%                                   is what makes a client-side shape
%                                   mismatch distinguishable from a server
%                                   that refused.
%                     .lastMapUids  those entries' uids, which is what shows
%                                   whether a scope was honored: a
%                                   series-scoped answer names the series'
%                                   members, an unscoped one also names
%                                   every other file the document has
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
        options.failureTtlSeconds (1,1) double = 60
    end

    % The persistent cache. Keyed on 'datasetId/documentId/seriesName'.
    % Each entry is a struct with `.map` (containers.Map uid -> URL) and
    % `.fetchedAt` (datetime, UTC).
    persistent CACHE
    persistent STATS
    persistent WARNED
    persistent FAILEDSCOPES
    if isempty(CACHE) || options.clearCache
        CACHE = containers.Map('KeyType','char','ValueType','any');
    end
    if isempty(STATS) || options.clearCache
        STATS = struct('signerCalls', 0, 'uidHits', 0, 'uidMisses', 0, ...
            'lastMapSize', 0, 'lastMapUids', {{}}, 'lastFailureReason', "");
    end
    if isempty(WARNED) || options.clearCache
        WARNED = containers.Map('KeyType','char','ValueType','logical');
    end
    if isempty(FAILEDSCOPES) || options.clearCache
        FAILEDSCOPES = containers.Map('KeyType','char','ValueType','any');
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
        % A scope that just failed is not retried for every uid after it.
        %
        % Without this, a batch endpoint that cannot answer costs one FAILED
        % call per uid on top of the per-uid getFileDetails fallback -- so a
        % 28,000-member series makes 56,000 calls where the naive path would
        % have made 28,000. Measured: four members produced four signer
        % calls, zero hits (VH-Lab/NDI-matlab#968).
        %
        % Short-lived on purpose. A failure is usually transient, and the
        % point is to stop hammering within one read, not to give up on the
        % scope for the session.
        if isKey(FAILEDSCOPES, cacheKey)
            if seconds(now_utc - FAILEDSCOPES(cacheKey)) < options.failureTtlSeconds
                STATS.uidMisses = STATS.uidMisses + 1;
                localWarnOnce(cacheKey);
                stats = STATS;
                return
            end
            remove(FAILEDSCOPES, cacheKey);
        end

        % Populate the cache for this scope. The signer is expected to
        % return `answer.files` as a containers.Map from uid to URL --
        % which is what getSignedURLSetAll produces via signedURLFileMap.
        % Ask for the HTTP response too when the signer can provide it.
        % ndi.cloud.api.files.getSignedURLSetAll returns four outputs; an
        % injected test signer usually returns two. nargout decides, rather
        % than calling twice -- a second call would double every side effect
        % the signer has, including a test's own call counter.
        wantsFour = false;
        try
            wantsFour = nargout(options.signer) >= 4;
        catch
            wantsFour = false; %#ok<NASGU>
        end

        apiResponse = [];
        failureReason = "";
        try
            if wantsFour
                if strlength(seriesName) > 0
                    [ok, answer, apiResponse] = options.signer(cloudDatasetId, ...
                        cloudDocumentId, 'fileSeries', seriesName);
                else
                    [ok, answer, apiResponse] = options.signer(cloudDatasetId, ...
                        cloudDocumentId);
                end
            else
                if strlength(seriesName) > 0
                    [ok, answer] = options.signer(cloudDatasetId, cloudDocumentId, ...
                        'fileSeries', seriesName);
                else
                    [ok, answer] = options.signer(cloudDatasetId, cloudDocumentId);
                end
            end
        catch signerError
            ok = false;
            answer = [];
            failureReason = "the call raised " + string(signerError.identifier) + ...
                ": " + string(signerError.message);
        end
        STATS.signerCalls = STATS.signerCalls + 1;
        if ~ok || ~isstruct(answer) || ~isfield(answer,'files') || ...
                ~isa(answer.files,'containers.Map')
            % Any failure or unexpected shape -> no batch URL. Don't
            % cache a bad answer; do not raise. The caller falls back
            % to getFileDetails for this uid.
            %
            % SAY WHICH of those it was. Four unrelated causes end here --
            % the call raised, the server said no, the payload had no files
            % field, the files field was the wrong type -- and reporting
            % them as one silent miss leaves whoever owns the endpoint with
            % nothing to act on. See VH-Lab/NDI-matlab#968.
            if strlength(failureReason) == 0
                failureReason = localDescribeFailure(ok, answer, apiResponse);
            end
            STATS.lastFailureReason = failureReason;
            STATS.uidMisses = STATS.uidMisses + 1;
            FAILEDSCOPES(cacheKey) = now_utc;
            localWarnOnce(cacheKey);
            stats = STATS;
            return
        end
        entry = struct('map', answer.files, 'fetchedAt', now_utc);
        CACHE(cacheKey) = entry;
        STATS.lastMapSize = double(entry.map.Count);
        STATS.lastMapUids = keys(entry.map);
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
        localWarnOnce(cacheKey);
    end
    stats = STATS;

    function reason = localDescribeFailure(ok, answer, apiResponse)
        % Name the specific cause, so a report is actionable by whoever owns
        % the endpoint rather than just "it did not work".
        status = "";
        if isa(apiResponse, 'matlab.net.http.ResponseMessage') && ~isempty(apiResponse)
            status = " (HTTP " + string(apiResponse(end).StatusCode) + ")";
        end
        if ~ok
            detail = "";
            if isstruct(answer)
                if isfield(answer, 'message') && ~isempty(answer.message)
                    detail = ": " + string(answer.message);
                elseif isfield(answer, 'state') && ~isempty(answer.state)
                    detail = ": state=" + string(answer.state);
                end
            end
            reason = "the call reported failure" + status + detail;
        elseif ~isstruct(answer)
            reason = "the payload was a " + string(class(answer)) + ...
                ", not a struct" + status;
        elseif ~isfield(answer, 'files')
            reason = "the payload has no 'files' field" + status + ...
                "; fields present: " + strjoin(string(fieldnames(answer)), ", ");
        else
            reason = "'files' arrived as a " + string(class(answer.files)) + ...
                ", not a containers.Map" + status;
        end
    end

    function localWarnOnce(scopeKey)
        % Say it ONCE per scope, then stay quiet.
        %
        % The fallback is correct -- the bytes still arrive -- so nothing
        % fails and nothing is logged, and that is the problem. Reading a
        % 10,000-member series then costs 10,000 presign calls instead of
        % one, and what the user sees is not an error but NDI being slow.
        % They conclude the tool is like that and never report it. A single
        % line naming the scope turns "this is slow" into "this fell back,
        % and here is where". See VH-Lab/NDI-matlab#968.
        %
        % Once per scope, not once per uid: the case worth warning about is
        % exactly the one that would otherwise print 10,000 times.
        if isKey(WARNED, scopeKey), return, end
        WARNED(scopeKey) = true;
        why = STATS.lastFailureReason;
        if strlength(why) == 0
            why = "the batch answered but did not name this uid";
        end
        warning('NDI:Cloud:BatchPresign:FallbackToPerUid', ...
            ['The batch signed-URL lookup did not answer for scope "%s", so ' ...
             'files there are being resolved one API call at a time. This ' ...
             'still works, but for a large file series it is one call per ' ...
             'member rather than one per series. Cause: %s. Reported once ' ...
             'per scope.'], scopeKey, char(why));
    end
end
