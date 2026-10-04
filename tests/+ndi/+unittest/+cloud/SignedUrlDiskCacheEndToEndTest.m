classdef SignedUrlDiskCacheEndToEndTest < matlab.unittest.TestCase
% SIGNEDURLDISKCACHEENDTOENDTEST - the persistent signed-URL disk cache
% seen through batchSignedUrlLookup, end-to-end.
%
% This is the "live cell" test-cloud-api.yml runs (testCloudApi ->
% ndi.unittest.cloud recursive). Placed in +cloud so the daily cloud
% CI picks it up alongside the async-job fixture test; the injected
% signer keeps it self-contained -- the disk cache is a client-side
% concern, so a real cloud round trip proves nothing the local run
% does not, and paying for a fresh lightsheet upload on every daily
% CI run to inject a counter around a signer we already control is
% pure cost.
%
% Proves: two consecutive batchSignedUrlLookup calls for the same
% scope cost ONE signer invocation. The first populates the disk
% cache; the second, with a fresh in-process cache, reads from disk
% and never touches the signer. Whether that signer would have been
% getSignedURLSetAll's paging walk or the createSignedURLSetJob
% async round-trip, the result is the same shape: signer counter
% doesn't move.

    properties
        TmpDir char = ''
        SavedCacheDirEnv char = ''
    end

    methods (TestMethodSetup)
        function isolateCacheDir(testCase)
            testCase.SavedCacheDirEnv = getenv('NDI_SIGNED_URL_CACHE_DIR');
            testCase.TmpDir = tempname;
            setenv('NDI_SIGNED_URL_CACHE_DIR', testCase.TmpDir);
            testCase.addTeardown(@() localCleanup( ...
                testCase.SavedCacheDirEnv, testCase.TmpDir));
        end
    end

    methods (Access = private)
        function [signer, counter] = countingSigner(~, filesMap)
            % Emitted as a NESTED handle (not an anonymous @()... wrap)
            % so nargout(signer) reads back as a fixed 2 rather than -1
            % -- which is what batchSignedUrlLookup's four-vs-two output
            % probe expects to see for an injected mock. The same
            % pattern BatchSignedUrlLookupTest already uses.
            counter = containers.Map('KeyType','char','ValueType','any');
            counter('n') = 0;
            % 23 h ahead of now mirrors the server's 24 h URL lifetime,
            % leaving the default 30 min safety buffer comfortably valid.
            futureDt = datetime('now','TimeZone','UTC') + hours(23);
            futureDt.Format = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            futureIso = char(futureDt);
            signer = @doSign;
            function [ok, answer] = doSign(~, ~, varargin) %#ok<INUSD>
                counter('n') = counter('n') + 1;
                ok = true;
                answer = struct( ...
                    'files',         filesMap, ...
                    'filesExpireAt', futureIso, ...
                    'expiresAt',     futureIso, ...
                    'generatedAt',   futureIso, ...
                    'fileCount',     double(filesMap.Count), ...
                    'pages',         1);
            end
        end
    end

    methods (Test)

        function testReopenPaysZeroSignerCallsFromDiskCache(testCase)
            % The end-to-end promise: sign the scope once, save it to
            % disk, then a reopen (fresh in-process cache) resolves
            % every uid without another signer round trip. For a
            % 121k-member chunk.bin series that means "one 85 min job
            % ever" instead of "one per viewer open all day".
            filesMap = containers.Map('KeyType','char','ValueType','any');
            filesMap('4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6') = 'https://s3/one';
            filesMap('4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6') = 'https://s3/two';
            [signer, counter] = testCase.countingSigner(filesMap);

            % --- Run 1: cold. Expect one signer call, both uids hit
            % the in-memory cache, and the disk file lands.
            u1a = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds-e2e", "doc-e2e", "chunk.bin", ...
                "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6", ...
                'signer', signer, 'clearCache', true, 'diskCache', true);
            u1b = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds-e2e", "doc-e2e", "chunk.bin", ...
                "4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6", ...
                'signer', signer, 'diskCache', true);
            testCase.verifyEqual(u1a, 'https://s3/one');
            testCase.verifyEqual(u1b, 'https://s3/two');
            testCase.verifyEqual(counter('n'), 1, ...
                'run 1 must cost exactly one signer call (in-memory batch)');

            diskFile = fullfile(testCase.TmpDir, 'ds-e2e', ...
                'doc-e2e_chunk.bin.json.gz');
            testCase.assertTrue(isfile(diskFile), ...
                'run 1 must have written the scope to disk');

            % --- Run 2: fresh in-process cache; disk should carry us.
            % clearCache wipes the persistent in-memory cache -- this
            % is what "a new viewer opens the same dataset" looks like
            % from the batch's point of view. If the disk cache is
            % working, the signer never runs again.
            u2a = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds-e2e", "doc-e2e", "chunk.bin", ...
                "4192a3c0dd1b4e00_3fe8a1b2c3d4e5f6", ...
                'signer', signer, 'clearCache', true, 'diskCache', true);
            u2b = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "ds-e2e", "doc-e2e", "chunk.bin", ...
                "4192a3c0dd1b4e00_4fe8a1b2c3d4e5f6", ...
                'signer', signer, 'diskCache', true);
            testCase.verifyEqual(u2a, 'https://s3/one');
            testCase.verifyEqual(u2b, 'https://s3/two');
            testCase.verifyEqual(counter('n'), 1, ...
                ['run 2 must have hit the disk cache -- no additional ' ...
                 'signer call, whether it was going to be a paging ' ...
                 'walk or an async job.']);
        end

        function testDiskOptOutStillCallsSignerOnEveryColdRun(testCase)
            % Guard: diskCache=false is the default, and it means "no
            % on-disk state, ever" -- existing tests and callers that
            % have not opted in must see the pre-cache behaviour where
            % a fresh in-process cache re-signs the scope.
            filesMap = containers.Map('KeyType','char','ValueType','any');
            filesMap('aa_bb') = 'https://s3/x';
            [signer, counter] = testCase.countingSigner(filesMap);

            for i = 1:3
                ndi.cloud.download.internal.batchSignedUrlLookup( ...
                    "ds-optout", "doc-optout", "", "aa_bb", ...
                    'signer', signer, 'clearCache', true);  % diskCache=false
            end
            testCase.verifyEqual(counter('n'), 3, ...
                'diskCache=false must call the signer per cold run');

            % And nothing should have landed on disk either.
            noFile = fullfile(testCase.TmpDir, 'ds-optout', 'doc-optout.json.gz');
            testCase.verifyFalse(isfile(noFile), ...
                'diskCache=false must not write any cache file');
        end
    end
end

function localCleanup(savedEnv, tmp)
    setenv('NDI_SIGNED_URL_CACHE_DIR', savedEnv);
    if ~isempty(tmp) && isfolder(tmp)
        try %#ok<TRYNC>
            rmdir(tmp, 's');
        end
    end
end
