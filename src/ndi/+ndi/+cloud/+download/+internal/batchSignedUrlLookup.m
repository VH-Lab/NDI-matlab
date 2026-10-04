function [url, stats] = batchSignedUrlLookup(cloudDatasetId, ndiDocumentId, seriesName, uid, options)
%BATCHSIGNEDURLLOOKUP Look one uid up in the per-document signed-URL cache.
%
%   URL = ndi.cloud.download.internal.batchSignedUrlLookup( ...
%             cloudDatasetId, ndiDocumentId, seriesName, uid)
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
%       ndiDocumentId   (1,1) string  - the NDI document id (data.base.id);
%                                       when empty, lookup is bypassed and
%                                       "" is returned (no document
%                                       context, nothing to batch against).
%
%                                       NDI, not cloud. Both callers hold
%                                       the NDI id -- the DID handler from
%                                       its context, downloadGenericFiles
%                                       from doc.id() -- and this helper
%                                       sends it to the ndi-documents route
%                                       (idNamespace "ndi"), which resolves
%                                       it server-side. Sent to the by-_id
%                                       route it is a 404, which is what
%                                       happened from #952 until #968:
%                                       every call failed and fell back to
%                                       one getFileDetails per uid, so the
%                                       bytes arrived and nothing looked
%                                       wrong.
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
%       partialMapRetryDelays - Row vector of waits, in seconds, between
%                    successive re-fetches of a scope whose previous
%                    answer was a populated map that did not name the
%                    requested uid. Default [1 3 9] -- one initial call
%                    plus up to three retries at 1 s / 3 s / 9 s, ~13 s
%                    of wall clock in the worst case. The retries give
%                    a lagged batch endpoint time to catch up after
%                    ``waitForAllBulkUploads`` returns; if the whole
%                    schedule is spent and the map still misses, the
%                    caller falls back per uid. See
%                    VH-Lab/NDI-matlab#991 and
%                    Waltham-Data-Science/NDI-python#309 and #320.
%       partialMapRetrySeconds - Deprecated single-wait scalar. NaN
%                    (default) means "use partialMapRetryDelays". Any
%                    other value replaces the schedule with a
%                    one-element one containing that wait, matching the
%                    pre-schedule contract where 0 still fires one
%                    retry (with no wait). Kept so tests pinned to that
%                    contract keep passing.
%       sleepFcn   - Function handle called as sleepFcn(seconds) to
%                    perform the pause before each partial-map retry.
%                    Defaults to @pause. Present so tests can
%                    short-circuit the wait without adding real
%                    latency to a suite that exercises the retry many
%                    times.
%       retryBackoffSeconds - Row vector of delays, in seconds,
%                    between successive scope-fetch attempts after a
%                    raise. Default [1 4 16] -- one initial call, up
%                    to three retries at 1 s / 4 s / 16 s, ~21 s of
%                    wall clock in the worst case. An exception here
%                    is a transient network condition
%                    (MATLAB:webservices:ConnectionFailed and the
%                    like); a signer that reports ok=false is a
%                    server-side no and is NOT retried. Pass [] to
%                    disable retries, or a vector of zeros to keep
%                    the retry count without adding real latency
%                    (used by tests). See VH-Lab/NDI-matlab#1010.
%
%   Outputs:
%       url         - The pre-signed URL for uid (char), or "" (string
%                     scalar) when no URL is available.
%       stats       - Cumulative counters since the cache was last cleared:
%                     .signerCalls  how many times the batch endpoint was
%                                   actually called (one per scope fetch,
%                                   plus one per partial-map retry)
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
%                     .partialMapRetries  how many scopes were re-fetched
%                                   because the first answer was populated
%                                   but did not name a requested uid. One
%                                   retry per scope, ever, whether it
%                                   settled or not; a caller that wants to
%                                   know "does this scope EVER answer for
%                                   this uid" gets that answer after the
%                                   retry. See VH-Lab/NDI-matlab#991 and
%                                   Waltham-Data-Science/NDI-python#309.
%                     .transientRetries  how many extra signer calls were
%                                   spent recovering from a raise (a
%                                   transient network error) before the
%                                   scope was cached or given up on. A
%                                   fresh scope fetch that raises is
%                                   retried with backoff so one blip
%                                   does not cascade to per-member
%                                   fallback across a 156k-member series.
%                                   See VH-Lab/NDI-matlab#1010 and
%                                   Waltham-Data-Science/NDI-python#322.
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
        ndiDocumentId   (1,1) string
        seriesName      (1,1) string
        uid             (1,1) string
        options.signer     = @ndi.cloud.api.files.getSignedURLSetAll
        options.clearCache (1,1) logical = false
        options.ttlSeconds (1,1) double  = 20*3600
        options.failureTtlSeconds (1,1) double = 60
        % PARTIAL-MAP retry schedule (bounded exponential backoff). Each
        % entry is a wait, in seconds, before the corresponding retry.
        % A scope whose Nth wave still returns a partial map falls back
        % per uid without another wave. Three waves at 1 s / 3 s / 9 s
        % cover the User-1-prod tail observed on
        % Waltham-Data-Science/NDI-python#320: one 0.5 s retry was not
        % enough to bridge the settle between bulk-upload extraction and
        % the signed-URL-set index catching up. See also
        % VH-Lab/NDI-matlab#991.
        options.partialMapRetryDelays (1,:) double = [1 3 9]
        % Back-compat scalar knob. If passed, replaces the schedule with
        % a single-element one containing that wait. NaN means "not
        % set", so partialMapRetryDelays wins. Preserves the pre-schedule
        % semantics where partialMapRetrySeconds=0 still fires one retry
        % (with no wait).
        options.partialMapRetrySeconds (1,1) double = NaN
        options.sleepFcn (1,1) function_handle = @pause
        options.retryBackoffSeconds (1,:) double = [1 4 16]
        % Disk cache off by default: only enable when we have a URL-set
        % source that will actually reduce cost on reopen (the async
        % signed-URL-set job, or a scope big enough to matter). Callers
        % that DO want it -- the DID chunk-download path for large
        % lightsheet series -- turn it on explicitly. Existing tests
        % that inject scripted signers see no disk activity, which is
        % what they want: the disk cache is a production optimisation,
        % not part of the batch contract.
        options.diskCache (1,1) logical = false
    end

    % The persistent cache. Keyed on 'datasetId/documentId/seriesName'.
    % Each entry is a struct with `.map` (containers.Map uid -> URL) and
    % `.fetchedAt` (datetime, UTC).
    persistent CACHE
    persistent STATS
    persistent WARNED
    persistent FAILEDSCOPES
    persistent RETRIEDSCOPES
    if isempty(CACHE) || options.clearCache
        CACHE = containers.Map('KeyType','char','ValueType','any');
    end
    if isempty(STATS) || options.clearCache
        STATS = struct('signerCalls', 0, 'uidHits', 0, 'uidMisses', 0, ...
            'lastMapSize', 0, 'lastMapUids', {{}}, 'lastFailureReason', "", ...
            'partialMapRetries', 0, 'transientRetries', 0);
    end
    if isempty(WARNED) || options.clearCache
        WARNED = containers.Map('KeyType','char','ValueType','logical');
    end
    if isempty(FAILEDSCOPES) || options.clearCache
        FAILEDSCOPES = containers.Map('KeyType','char','ValueType','any');
    end
    if isempty(RETRIEDSCOPES) || options.clearCache
        % Values are the number of retry waves already spent on this
        % scope, bounded by numel(effectiveDelays). Was a logical
        % "has been retried" set before the multi-wave rework.
        RETRIEDSCOPES = containers.Map('KeyType','char','ValueType','double');
    end

    % Resolve the effective partial-map schedule. A caller passing the
    % deprecated scalar partialMapRetrySeconds gets a one-element
    % schedule with that wait (scalar=0 still fires ONE retry, matching
    % the pre-schedule behaviour).
    if isnan(options.partialMapRetrySeconds)
        effectiveDelays = options.partialMapRetryDelays;
    else
        effectiveDelays = options.partialMapRetrySeconds;
    end

    url = "";
    stats = STATS;

    % No document context -- e.g. a 2-arg handler call, or a caller that
    % hasn't got one -- means there is nothing to batch against. Not a miss:
    % nothing was asked of the batch, so nothing failed. This is also the
    % call a test uses to read the counters without touching the cache.
    if strlength(ndiDocumentId) == 0
        return
    end

    cacheKey = sprintf('%s/%s/%s', ...
        char(cloudDatasetId), char(ndiDocumentId), char(seriesName));

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

    if isempty(entry) && options.diskCache
        entry = localTryDiskCache();
    end

    if isempty(entry)
        entry = localFetchScope(cacheKey);
        if isempty(entry)
            % localFetchScope already recorded the miss and warned.
            stats = STATS;
            return
        end
    end

    key = char(uid);
    if isKey(entry.map, key)
        url = entry.map(key);
        if isstring(url) && isscalar(url), url = char(url); end
        STATS.uidHits = STATS.uidHits + 1;
    else
        % The scope was fetched but does not name this uid. Two distinct
        % causes are possible: DATA DRIFT (the file was never in this
        % scope) or a LAGGED INDEX (the file IS in the scope on the
        % server, but the batch endpoint's map has not caught up with a
        % just-completed bulk upload). Falling back per uid on a lagged
        % index defeats the batch design -- a 28,000-member series that
        % took the fallback would issue 28,000 getFileDetails calls
        % where the batch would have taken one.
        %
        % Only the second cause is worth a retry, and this side has no
        % way to distinguish them a priori -- so retry ONCE per scope,
        % sleep briefly first, and if the second answer still does not
        % name the uid, take that as data drift and warn.
        %
        % Bounded and per-scope: a data-drift miss costs one extra
        % signer call for the whole scope, not one per uid. A lagged
        % index that recovers replaces the cache entry for every
        % subsequent uid in the same scope, so a whole series' worth of
        % misses becomes a whole series' worth of hits from one retry.
        % See VH-Lab/NDI-matlab#991 and Waltham-Data-Science/
        % NDI-python#309.
        % Multi-wave retry: each wave sleeps for effectiveDelays(n+1)
        % where n is the number of waves already spent, then refetches.
        % Stops as soon as a fresh map names the uid, or when the
        % schedule is exhausted.
        if isKey(RETRIEDSCOPES, cacheKey)
            attemptsSpent = RETRIEDSCOPES(cacheKey);
        else
            attemptsSpent = 0;
        end
        while attemptsSpent < numel(effectiveDelays)
            delay = effectiveDelays(attemptsSpent + 1);
            if delay > 0
                options.sleepFcn(delay);
            end
            % Drop the stale entry so localFetchScope replaces it fresh.
            remove(CACHE, cacheKey);
            STATS.partialMapRetries = STATS.partialMapRetries + 1;
            attemptsSpent = attemptsSpent + 1;
            RETRIEDSCOPES(cacheKey) = attemptsSpent;
            refreshed = localFetchScope(cacheKey);
            if isempty(refreshed)
                % localFetchScope already recorded the miss and warned;
                % do not double-count here.
                stats = STATS;
                return
            end
            entry = refreshed;
            if isKey(entry.map, key)
                url = entry.map(key);
                if isstring(url) && isscalar(url), url = char(url); end
                STATS.uidHits = STATS.uidHits + 1;
                stats = STATS;
                return
            end
        end

        STATS.uidMisses = STATS.uidMisses + 1;
        localWarnOnce(cacheKey);
    end
    stats = STATS;

    function e = localFetchScope(theCacheKey)
        % Fetch the scope's URL map from the signer and cache it. On any
        % failure or unexpected shape, record the miss, warn once for
        % the scope, and return []. Extracted so the partial-map retry
        % path can call it a second time without duplicating the
        % nargout/try dance.

        % A scope that just failed is not retried for every uid after it.
        %
        % Without this, a batch endpoint that cannot answer costs one FAILED
        % call per uid on top of the per-uid getFileDetails fallback -- so a
        % 28,000-member series makes 56,000 calls where the naive path would
        % have made 28,000. Measured: four members produced four signer
        % calls, zero hits (VH-Lab/NDI-matlab#968).
        %
        % Short-lived on purpose, and narrow: it suppresses the NEXT uid,
        % not a retry of the same one. The point is to stop hammering
        % within one sweep, not to give up on the scope -- see
        % testFailingSignerReturnsEmpty, which requires that a caller who
        % recovers on a later request still gets an answer.
        if isKey(FAILEDSCOPES, theCacheKey)
            lastFailure = FAILEDSCOPES(theCacheKey);
            % A caller asking again for THE SAME uid is retrying on purpose,
            % and gets a fresh attempt -- a failure must not be sticky for
            % someone who recovers on a later request. A sweep that moves on
            % to the NEXT uid is the case worth suppressing: that is the one
            % that would re-hammer a dead scope 28,000 times.
            sameUid = strcmp(char(uid), lastFailure.uid);
            if ~sameUid && seconds(now_utc - lastFailure.at) < options.failureTtlSeconds
                STATS.uidMisses = STATS.uidMisses + 1;
                localWarnOnce(theCacheKey);
                e = [];
                return
            end
            remove(FAILEDSCOPES, theCacheKey);
        end

        % Populate the cache for this scope. The signer is expected to
        % return `answer.files` as a containers.Map from uid to URL --
        % which is what getSignedURLSetAll produces via signedURLFileMap.
        % Ask for the HTTP response too when the signer can provide it.
        % ndi.cloud.api.files.getSignedURLSetAll returns four outputs; an
        % injected test signer usually returns two. nargout decides, rather
        % than calling twice -- a second call would double every side effect
        % the signer has, including a test's own call counter.
        try
            wantsFour = nargout(options.signer) >= 4;
        catch
            % nargout raises for some handle kinds; assume the two-output
            % form, which every signer supports.
            wantsFour = false;
        end

        % Fetch the scope with backoff on a raise. A transient network
        % blip (MATLAB:webservices:ConnectionFailed and the like) at the
        % start of a run would otherwise cascade: this scope is marked
        % failed, every subsequent uid in it falls back to a per-member
        % getFileDetails call, and a 156k-member series takes hours.
        % Retry the batch call itself first; the per-member fallback is
        % still there below as a safety net, just not triggered by
        % transients. See VH-Lab/NDI-matlab#1010 and Waltham-Data-Science/
        % NDI-python#322.
        %
        % Only a caught exception is retried. A signer that reports
        % ok=false is a server-side no (auth, 404, business-logic
        % refusal): retrying hammers a dead endpoint and adds cost with
        % no chance of recovery.
        ok = false;
        answer = [];
        apiResponse = [];
        failureReason = "";
        maxAttempts = 1 + numel(options.retryBackoffSeconds);
        for attempt = 1:maxAttempts
            apiResponse = [];
            failureReason = "";
            try
                if wantsFour
                    if strlength(seriesName) > 0
                        [ok, answer, apiResponse] = options.signer(cloudDatasetId, ...
                            ndiDocumentId, 'idNamespace', "ndi", ...
                            'fileSeries', seriesName);
                    else
                        [ok, answer, apiResponse] = options.signer(cloudDatasetId, ...
                            ndiDocumentId, 'idNamespace', "ndi");
                    end
                else
                    if strlength(seriesName) > 0
                        [ok, answer] = options.signer(cloudDatasetId, ndiDocumentId, ...
                            'idNamespace', "ndi", 'fileSeries', seriesName);
                    else
                        [ok, answer] = options.signer(cloudDatasetId, ndiDocumentId, ...
                            'idNamespace', "ndi");
                    end
                end
            catch signerError
                ok = false;
                answer = [];
                failureReason = "the call raised " + string(signerError.identifier) + ...
                    ": " + string(signerError.message);
            end
            STATS.signerCalls = STATS.signerCalls + 1;
            if ok
                break
            end
            % Retry only on a raise. An ok=false response is not
            % transient; break out and let the fallback path handle it.
            if strlength(failureReason) == 0
                break
            end
            if attempt >= maxAttempts
                break
            end
            STATS.transientRetries = STATS.transientRetries + 1;
            delay = options.retryBackoffSeconds(attempt);
            if delay > 0
                options.sleepFcn(delay);
            end
        end
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
            FAILEDSCOPES(theCacheKey) = struct('at', now_utc, 'uid', char(uid));
            localWarnOnce(theCacheKey);
            e = [];
            return
        end
        e = struct('map', answer.files, 'fetchedAt', now_utc);
        CACHE(theCacheKey) = e;
        STATS.lastMapSize = double(e.map.Count);
        STATS.lastMapUids = keys(e.map);

        % Persist to disk when the caller has opted in AND the payload
        % carries a server-signed expiry we can age-check off of. A
        % payload with neither expiresAt nor filesExpireAt is not
        % cacheable -- the disk cache refuses to invent a TTL, on
        % purpose (see signedUrlDiskCache.save). Best-effort: any I/O
        % failure is swallowed so a full disk does not break a read.
        if options.diskCache
            try %#ok<TRYNC>
                ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                    cloudDatasetId, ndiDocumentId, seriesName, answer);
            end
        end
    end

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

    function e = localTryDiskCache()
        % Consult the persistent (on-disk) cache before running the async
        % signed-URL-set job. On hit, populate the in-memory cache so
        % every uid in the scope resolves without another disk read. On
        % miss (no file, corrupt file, expired-or-within-safety-buffer),
        % return [] and let the caller fetch fresh.
        %
        % The disk cache lives one layer above DID's file-bytes cache
        % (which is a different, complementary concern) and its TTL is
        % keyed to the SERVER'S filesExpireAt, not a hardcoded value --
        % which is why a scientist reopening the same dataset over a
        % 24 h day pays the ~85 min sign cost once.
        e = [];
        try
            disk = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                cloudDatasetId, ndiDocumentId, seriesName);
        catch
            disk = [];
        end
        if isempty(disk) || ~isstruct(disk) || ~isfield(disk, 'files') || ...
                ~isa(disk.files, 'containers.Map')
            return
        end
        e = struct('map', disk.files, 'fetchedAt', now_utc);
        CACHE(cacheKey) = e;
        STATS.lastMapSize = double(e.map.Count);
        STATS.lastMapUids = keys(e.map);
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
