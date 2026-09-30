classdef SignedUrlDiskCacheTest < matlab.unittest.TestCase
% SIGNEDURLDISKCACHETEST - the on-disk signed-URL-set cache.
%
% Persistent layer that sits beneath the in-process cache inside
% ndi.cloud.download.internal.batchSignedUrlLookup and turns a
% dataset-reopen "still ~85 min to sign 121k URLs" into "read a file".
% See ndi.cloud.download.internal.signedUrlDiskCache and the task
% brief on VH-Lab/NDI-matlab#1010 follow-on / Waltham-Data-Science/
% NDI-python#322.
%
% Nothing here hits the network or the user's real cache directory:
% the class setup points NDI_SIGNED_URL_CACHE_DIR at a per-run temp
% dir and the teardown removes it.

    properties
        TmpDir char = ''
        SavedCacheDirEnv    char = ''
        SavedSafetyEnv      char = ''
    end

    methods (TestMethodSetup)
        function isolateCacheDir(testCase)
            % One temp dir per test so a leaked file cannot leak across
            % assertions -- the class runs a save + load round-trip and
            % a concurrent-write case in the same suite.
            testCase.SavedCacheDirEnv = getenv('NDI_SIGNED_URL_CACHE_DIR');
            testCase.SavedSafetyEnv   = getenv('NDI_SIGNED_URL_CACHE_SAFETY_SECONDS');
            testCase.TmpDir = tempname;
            setenv('NDI_SIGNED_URL_CACHE_DIR', testCase.TmpDir);
            % Clear the safety-seconds override so each test starts
            % from the documented default (1800 s) unless it sets its
            % own; a leftover override from a previous run of this
            % suite would silently corrupt an expiry assertion.
            setenv('NDI_SIGNED_URL_CACHE_SAFETY_SECONDS', '');
        end

        function restoreOnTeardown(testCase)
            envKey     = 'NDI_SIGNED_URL_CACHE_DIR';
            savedDir   = testCase.SavedCacheDirEnv;
            safetyKey  = 'NDI_SIGNED_URL_CACHE_SAFETY_SECONDS';
            savedSaf   = testCase.SavedSafetyEnv;
            tmp        = testCase.TmpDir;
            testCase.addTeardown(@() localCleanup( ...
                envKey, savedDir, safetyKey, savedSaf, tmp));
        end
    end

    methods (Access = private)
        function m = mapOf(~, uidUrlPairs)
            m = containers.Map('KeyType','char','ValueType','any');
            for i = 1:size(uidUrlPairs, 1)
                m(uidUrlPairs{i, 1}) = uidUrlPairs{i, 2};
            end
        end

        function s = futureIso(~, secondsAhead)
            % ISO-8601 UTC N seconds from now, in the same format the
            % server uses in the getSignedURLSetJob ready-state payload.
            dt = datetime('now','TimeZone','UTC') + seconds(secondsAhead);
            dt.Format = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            s = char(dt);
        end
    end

    methods (Test)

        function testSaveLoadRoundTripPreservesFields(testCase)
            % The point of the disk cache: what goes in comes back out
            % byte-for-byte on the fields callers actually consume --
            % the uid->URL map, the server's authoritative expiry, and
            % the generatedAt provenance.
            m = testCase.mapOf({ ...
                '4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6', 'https://s3/one'; ...
                '4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6', 'https://s3/two?sig=abc%2F123'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', testCase.futureIso(23*3600), ...
                'expiresAt',     testCase.futureIso(23*3600), ...
                'generatedAt',   testCase.futureIso(-30), ...
                'fileCount',     2);
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", "chunk.bin", payload);

            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "chunk.bin");

            testCase.assertNotEmpty(got, 'a just-written scope should load');
            testCase.verifyEqual(sort(keys(got.files)), ...
                sort({'4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6', '4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6'}));
            testCase.verifyEqual(got.files('4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6'), ...
                'https://s3/one');
            testCase.verifyEqual(got.files('4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6'), ...
                'https://s3/two?sig=abc%2F123', ...
                'URL with url-escaped bytes must survive JSON encoding');
            testCase.verifyEqual(char(got.filesExpireAt), payload.filesExpireAt);
            testCase.verifyEqual(double(got.fileCount), 2);
        end

        function testExpiredPayloadIsATreatedAsAMiss(testCase)
            % A cached scope whose filesExpireAt is in the past must
            % NOT be served -- the URLs are dead and would 403 on use.
            m = testCase.mapOf({'aa_bb', 'https://s3/expired'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', testCase.futureIso(-3600), ... % 1 h ago
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", "", payload);

            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "");
            testCase.verifyEmpty(got, ...
                'a filesExpireAt in the past is a miss');
        end

        function testSafetyBufferGuardsAgainstAlmostExpired(testCase)
            % The whole point of the buffer: a URL that will expire in
            % 20 minutes is a miss even though it is still technically
            % valid, because a viewer opened with it will 403 before
            % they get through the file.
            m = testCase.mapOf({'aa_bb', 'https://s3/almost'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', testCase.futureIso(20*60), ...
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", "", payload);

            % Default safety is 30 min (1800 s), so 20 min is inside
            % the buffer and load must miss.
            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "");
            testCase.verifyEmpty(got, ...
                '20 min < 30 min safety buffer must be a miss');

            % With a shorter buffer the same file loads -- proving the
            % check is the buffer, not the write, doing the work.
            setenv('NDI_SIGNED_URL_CACHE_SAFETY_SECONDS', '60');
            got2 = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "");
            testCase.verifyNotEmpty(got2, ...
                'with a 60 s buffer the same payload loads');
        end

        function testMissingExpiryIsNotCacheable(testCase)
            % save() refuses to persist a payload with no expiry -- the
            % cache would then have no way to age-check it. Load must
            % see nothing on disk.
            m = testCase.mapOf({'aa_bb', 'https://s3/no-expiry'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', "", ...
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", "", payload);

            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "");
            testCase.verifyEmpty(got);
        end

        function testForgetRemovesTheFile(testCase)
            % forget is the S3-403 hook: an S3 refusal means the
            % scope's cached URLs are dead, so drop them before the
            % next uid in the scope pays the same 403.
            m = testCase.mapOf({'aa_bb', 'https://s3/ok'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', testCase.futureIso(3600), ...
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", "chunk.bin", payload);
            testCase.assertNotEmpty( ...
                ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                    "ds1", "doc1", "chunk.bin"), ...
                'sanity: the scope should be on disk before forget');

            ndi.cloud.download.internal.signedUrlDiskCache.forget( ...
                "ds1", "doc1", "chunk.bin");

            testCase.verifyEmpty( ...
                ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                    "ds1", "doc1", "chunk.bin"), ...
                'forget must remove the scope from disk');
        end

        function testForgetOnUnknownScopeDoesNotRaise(testCase)
            % Best-effort: a forget on a scope we never cached must
            % succeed silently so the S3-403 recovery path doesn't
            % need to check-first.
            testCase.verifyWarningFree(@() ...
                ndi.cloud.download.internal.signedUrlDiskCache.forget( ...
                    "nosuch-ds", "nosuch-doc", "nosuch-series"));
        end

        function testCacheDirRespectsEnvVar(testCase)
            % The env-var override lets NDI-python and the MATLAB tests
            % point the cache anywhere; the default falls under
            % ~/.ndi/. Both are documented on-disk contract.
            actual = ndi.cloud.download.internal.signedUrlDiskCache.cacheDir();
            testCase.verifyEqual(actual, testCase.TmpDir);
        end

        function testConcurrentSavesDoNotCorruptTheFile(testCase)
            % Two viewers signing the same scope back-to-back is the
            % expected shape: last write wins, both reads afterward see
            % a valid file. atomic rename is what makes this true.
            baseMap = testCase.mapOf({'aa_bb', 'https://s3/first'});
            payload1 = struct( ...
                'files',         baseMap, ...
                'filesExpireAt', testCase.futureIso(3600), ...
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);
            payload2 = payload1;
            payload2.files = testCase.mapOf({'cc_dd', 'https://s3/second'});

            for i = 1:10
                ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                    "ds1", "doc1", "chunks", payload1);
                ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                    "ds1", "doc1", "chunks", payload2);
            end

            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", "chunks");
            testCase.assertNotEmpty(got, ...
                'after alternating writes, the file must still be valid');
            % Whichever payload landed last is fine (last-writer wins);
            % what matters is that we did NOT get a half-written blob.
            testCase.verifyTrue(isa(got.files, 'containers.Map'));
            testCase.verifyEqual(double(got.files.Count), 1);
        end

        function testSeriesNameEscapingHandlesPathySpaces(testCase)
            % Real series names can hold '/', spaces, unicode; the
            % filesystem can't. The escape rule NDI-python mirrors is
            % percent-encoding for non-safe bytes and a SHA-1 fallback
            % above 96 chars.
            m = testCase.mapOf({'aa_bb', 'https://s3/x'});
            payload = struct( ...
                'files',         m, ...
                'filesExpireAt', testCase.futureIso(3600), ...
                'expiresAt',     "", ...
                'generatedAt',   "", ...
                'fileCount',     1);

            pathy = "level 3/chunk.bin";
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", pathy, payload);
            got = ndi.cloud.download.internal.signedUrlDiskCache.load( ...
                "ds1", "doc1", pathy);
            testCase.assertNotEmpty(got, ...
                'a series name with a slash and a space must save and load');

            % Two different names must land in two different files.
            other = "level 3_chunk.bin";
            ndi.cloud.download.internal.signedUrlDiskCache.save( ...
                "ds1", "doc1", other, payload);
            listing = dir(fullfile(testCase.TmpDir, 'ds1'));
            names = {listing(~[listing.isdir]).name};
            testCase.verifyEqual(sum(endsWith(names, '.json.gz')), 2, ...
                'two distinct series names must produce two distinct cache files');
        end
    end
end

function localCleanup(envKey, savedDir, safetyKey, savedSaf, tmp)
    setenv(envKey, savedDir);
    setenv(safetyKey, savedSaf);
    if ~isempty(tmp) && isfolder(tmp)
        try %#ok<TRYNC>
            rmdir(tmp, 's');
        end
    end
end
