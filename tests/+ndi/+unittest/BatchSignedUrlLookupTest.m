classdef BatchSignedUrlLookupTest < matlab.unittest.TestCase
% BATCHSIGNEDURLLOOKUPTEST - the per-document signed-URL cache.
%
% Tests the helper that turns "one API round trip per uid" into "one per
% document (or per fileSeries scope)": NDI-matlab#952, closing DID
% #173's step 3 for the read path. All tests inject a scripted signer
% (a function handle mimicking getSignedURLSetAll) so nothing hits the
% network; the batch API's own paging and merging live in
% SignedURLSetMockTest.

    methods (TestMethodSetup)
        function quietTheExpectedFallbackWarning(testCase)
            % Most tests here deliberately drive the miss and failure paths,
            % so the fallback warning fires every time and says nothing a
            % reader of this suite needs. Left on, it teaches whoever reads
            % the log to skim past that warning -- which is exactly the
            % warning that matters in a real run. Silenced here and asserted
            % on its own in testTheFallbackWarnsOncePerScope.
            w = warning('off', 'NDI:Cloud:BatchPresign:FallbackToPerUid');
            testCase.addTeardown(@() warning(w));
        end
    end

    methods (Access = private)
        function signer = countingSigner(~, filesMap, counterHandle)
            % A signer that returns `filesMap` verbatim and bumps
            % counterHandle('n') on each call. counterHandle is a
            % containers.Map used as a mutable scalar so mutation is
            % visible across returned closures.
            signer = @doSign;
            function [ok, answer] = doSign(~, ~, varargin)
                counterHandle('n') = counterHandle('n') + 1;
                counterHandle('lastArgs') = varargin;
                ok = true;
                answer = struct('files', filesMap, ...
                                'pages', 1, ...
                                'expiresAt', '2026-12-31T00:00:00Z');
            end
        end

        function m = mapOf(~, uidUrlPairs)
            m = containers.Map('KeyType','char','ValueType','any');
            for i = 1:size(uidUrlPairs,1)
                m(uidUrlPairs{i,1}) = uidUrlPairs{i,2};
            end
        end
    end

    methods (Test)

        function testOneCallCoversEveryUidInADocument(testCase)
            % The whole point. Two uids in the same document; the batch
            % signer is called ONCE and both uids resolve.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            filesMap = testCase.mapOf({ ...
                '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6', 'https://s3/one'; ...
                '4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6', 'https://s3/two'});
            signer = testCase.countingSigner(filesMap, counter);

            u1 = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6", ...
                'signer', signer, 'clearCache', true);
            u2 = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6", ...
                'signer', signer);

            testCase.verifyEqual(u1, 'https://s3/one');
            testCase.verifyEqual(u2, 'https://s3/two');
            testCase.verifyEqual(counter('n'), 1, ...
                'Two uids in one document must cost one batch call.');
        end

        function testTheCountersRecordHitsAndFallbacks(testCase)
            % The counters exist so the CLOUD test can insist the batch path
            % answered, rather than passing on the per-uid getFileDetails
            % fallback that would have fetched the same bytes with N calls
            % (VH-Lab/NDI-matlab#968). Untested counters would just move the
            % blind spot, so they are checked here where a scripted signer
            % makes the answer knowable.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            filesMap = testCase.mapOf({'uidA', 'https://example.invalid/a'; ...
                                       'uidB', 'https://example.invalid/b'});
            signer = testCase.countingSigner(filesMap, counter);

            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "chunk.bin", "uidA", ...
                'signer', signer, 'clearCache', true);
            [~, stats] = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "chunk.bin", "uidB", 'signer', signer);

            testCase.verifyEqual(stats.signerCalls, 1, ...
                'two uids in one scope should cost one endpoint call');
            testCase.verifyEqual(stats.uidHits, 2, 'both uids came from the batch');
            testCase.verifyEqual(stats.uidMisses, 0, 'neither uid needed a fallback');
            testCase.verifyEqual(stats.lastMapSize, 2, ...
                'lastMapSize is what shows an unscoped answer: a whole-document map is bigger');

            % A uid the map does not name is the fallback case, and must be
            % counted as one -- it is the whole reason the counter exists.
            [url, stats] = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "chunk.bin", "uidMissing", 'signer', signer);
            testCase.verifyEqual(strlength(url), 0, ...
                'an unknown uid yields no URL, so the caller falls back');
            testCase.verifyEqual(stats.uidMisses, 1, 'the fallback must be counted');
            testCase.verifyEqual(stats.signerCalls, 1, ...
                'a cached scope should not be refetched for an unknown uid');
        end

        function testCountersAreReadableWithoutDisturbingTheCache(testCase)
            % The cloud test reads the counters mid-run by calling with an
            % empty documentId. That must return the counters unchanged and
            % must not count as a miss -- nothing was asked of the batch.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            filesMap = testCase.mapOf({'uidA', 'https://example.invalid/a'});
            signer = testCase.countingSigner(filesMap, counter);

            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "uidA", 'signer', signer, 'clearCache', true);

            [url, stats] = ndi.cloud.download.internal.batchSignedUrlLookup("", "", "", "");
            testCase.verifyEqual(strlength(url), 0);
            testCase.verifyEqual(stats.uidHits, 1);
            testCase.verifyEqual(stats.uidMisses, 0, ...
                'reading the counters must not register as a fallback');
            testCase.verifyEqual(stats.signerCalls, 1);
        end

        function testTheFallbackWarnsOncePerScope(testCase)
            % The warning exists because the fallback is otherwise invisible:
            % the bytes arrive, nothing fails, nothing is logged, and a
            % 10,000-member series just reads slowly. A user concludes the
            % tool is slow rather than that something regressed.
            %
            % Once per scope, not once per uid -- the situation worth warning
            % about is precisely the one that would otherwise print 10,000
            % times, and a warning that floods gets silenced.
            warning('on', 'NDI:Cloud:BatchPresign:FallbackToPerUid');

            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            emptyMap = testCase.mapOf({});
            signer = testCase.countingSigner(emptyMap, counter);

            % First uid in this scope: the batch answers with a map that does
            % not name it, so the caller falls back -- and is told.
            testCase.verifyWarning(@() ...
                ndi.cloud.download.internal.batchSignedUrlLookup( ...
                    "ds", "doc", "chunk.bin", "uid1", ...
                    'signer', signer, 'clearCache', true), ...
                'NDI:Cloud:BatchPresign:FallbackToPerUid');

            % Second uid, same scope: still a fallback, but silent.
            testCase.verifyWarningFree(@() ...
                ndi.cloud.download.internal.batchSignedUrlLookup( ...
                    "ds", "doc", "chunk.bin", "uid2", 'signer', signer));
        end

        function testSeriesNameIsPassedToTheSigner(testCase)
            % A series-scoped call must reach the endpoint with
            % ?fileSeries=<name>, so the server can return only that
            % series' members. Without this, a 28,000-chunk series
            % would page through every other file in the document.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            counter('lastArgs') = {};
            filesMap = testCase.mapOf({'aa_bb', 'https://s3/x'});
            signer = testCase.countingSigner(filesMap, counter);

            url = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "chunkdata.bin", "aa_bb", ...
                'signer', signer, 'clearCache', true);

            testCase.verifyEqual(url, 'https://s3/x');
            % Found by name, not by position. The order of name-value
            % arguments is not a contract, and asserting args{1} made this
            % test fail the moment a second pair was added ahead of it.
            args = counter('lastArgs');
            seriesIdx = find(strcmp(args, 'fileSeries'), 1);
            testCase.assertNotEmpty(seriesIdx, ...
                'The fileSeries pair must reach the signer.');
            testCase.verifyEqual(char(args{seriesIdx+1}), 'chunkdata.bin');

            % And the signer must be told which id namespace it is being
            % handed, since NDI passes an NDI document id and the by-_id
            % route would 404 on it (VH-Lab/NDI-matlab#968).
            namespaceIdx = find(strcmp(args, 'idNamespace'), 1);
            testCase.assertNotEmpty(namespaceIdx, ...
                'The idNamespace pair must reach the signer.');
            testCase.verifyEqual(char(args{namespaceIdx+1}), 'ndi', ...
                'the batch lookup is always given an NDI document id');
        end

        function testDifferentScopesGetDifferentCacheEntries(testCase)
            % Two different (dataset, document, series) scopes are
            % independent cache entries: each pays its own batch call,
            % neither pollutes the other.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            map1 = testCase.mapOf({'aa_bb', 'https://s3/a'});
            signer = testCase.countingSigner(map1, counter);

            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc1", "", "aa_bb", ...
                'signer', signer, 'clearCache', true);
            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc2", "", "aa_bb", ...
                'signer', signer);

            testCase.verifyEqual(counter('n'), 2, ...
                'Two documents must each pay their own batch call.');
        end

        function testMissingDocumentIdBypassesTheBatch(testCase)
            % A 2-arg handler dispatch or a context with no documentId
            % gives us nothing to key on. The lookup must return "" so
            % the caller falls back to per-uid getFileDetails.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            signer = testCase.countingSigner(testCase.mapOf({}), counter);

            url = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "", "", "aa_bb", ...
                'signer', signer, 'clearCache', true);

            testCase.verifyEqual(url, "");
            testCase.verifyEqual(counter('n'), 0, ...
                'No documentId => no wasted batch call.');
        end

        function testUidNotInBatchResponseReturnsEmpty(testCase)
            % Data drift: the batch call succeeds but names a uid the
            % caller didn't ask about. The lookup returns "" and lets
            % the caller fall back rather than making up an answer.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            filesMap = testCase.mapOf({'other_uid', 'https://s3/other'});
            signer = testCase.countingSigner(filesMap, counter);

            url = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "aa_bb", ...
                'signer', signer, 'clearCache', true);

            testCase.verifyEqual(url, "");
        end

        function testFailingSignerReturnsEmpty(testCase)
            % A signer that reports ok=false leaves the caller in the
            % same state a totally missing batch endpoint would: "".
            % Nothing is cached, and the next call retries -- callers
            % that recover on a subsequent request must be able to.
            function [ok, answer] = failingSigner(varargin) %#ok<INUSD>
                ok = false;
                answer = struct('message','oops');
            end

            url1 = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "aa_bb", ...
                'signer', @failingSigner, 'clearCache', true);
            testCase.verifyEqual(url1, "");

            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            goodSigner = testCase.countingSigner( ...
                testCase.mapOf({'aa_bb','https://s3/ok'}), counter);
            url2 = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "aa_bb", ...
                'signer', goodSigner);
            testCase.verifyEqual(url2, 'https://s3/ok', ...
                'A previous failure must not poison the cache.');
        end

        function testExpiredEntryIsRefetched(testCase)
            % Once TTL has elapsed a cached scope is dropped and the
            % next call goes back to the signer, so a MATLAB session
            % that outlives the pre-signed window still gets fresh URLs.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            signer = testCase.countingSigner( ...
                testCase.mapOf({'aa_bb','https://s3/x'}), counter);

            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "aa_bb", ...
                'signer', signer, 'clearCache', true, 'ttlSeconds', 0);
            % Any non-zero delay makes the ttl=0 entry stale; even in
            % the same clock second, seconds(...) > 0 for datetime('now').
            pause(0.01);
            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds", "doc", "", "aa_bb", ...
                'signer', signer, 'ttlSeconds', 0);

            testCase.verifyEqual(counter('n'), 2, ...
                'An expired scope must refetch on the next miss.');
        end
    end
end
