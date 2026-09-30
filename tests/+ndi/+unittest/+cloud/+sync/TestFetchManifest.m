classdef TestFetchManifest < matlab.unittest.TestCase
% TESTFETCHMANIFEST - manifest fetch bypasses the batch cache.
%
% A manifest is a SINGLE KNOWN uid, so its URL is resolved by ONE direct
% getFileDetails call. Going through the per-document
% batchSignedUrlLookup here would force the batch to walk the whole
% document's signed-URL set -- ~243 pages at ~25 s each for a 121k-chunk
% lightsheet level (~100 min per manifest, seven levels ≈ 12 h before any
% bytes hit disk). The batch is worth its cost when many uids share the
% document; for a single known uid it is pure overhead. See
% VH-Lab/NDI-matlab#1010 and Waltham-Data-Science/NDI-python commit
% 5ab9c04 (the Python analog fix).

    properties
        WorkDir
    end

    methods (TestMethodSetup)
        function useWorkingFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.WorkingFolderFixture);
            testCase.WorkDir = pwd;
            % Clear the batch cache so a prior test's signer calls
            % cannot show up in this test's counters. Reading the
            % counters back with an empty documentId does not disturb
            % the cache.
            ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "", "", "", "", 'clearCache', true);
        end
    end

    methods (Test)

        function testManifestFetchGoesDirectAndSkipsTheBatch(testCase)
            % The whole point: fetchManifest for a single known uid
            % must issue exactly one getFileDetails call and must NOT
            % call batchSignedUrlLookup at all. Before this fix the
            % batch would answer that one-uid question by paging the
            % whole document's signed-URL set -- a ~12 h hang on a
            % lightsheet level's manifest (NDI-matlab#1010).
            destPath = fullfile(testCase.WorkDir, 'manifest.bin');
            recorded = containers.Map('KeyType','char','ValueType','any');
            recorded('detailsCalls') = 0;
            recorded('detailsArgs')  = {};
            recorded('fileCalls')    = 0;
            recorded('fileArgs')     = {};
            detailsFcn = @(datasetId, fileUid) localScriptedDetails( ...
                recorded, datasetId, fileUid, 'https://s3.example/manifest');
            fileFcn = @(url, path, varargin) localScriptedFile( ...
                recorded, url, path, varargin);

            ndi.cloud.sync.internal.fetchManifest( ...
                string(destPath), "ds1", "manifest_uid_A", ...
                "doc1", "chunkdata.bin", [], ...
                'DetailsFetcher', detailsFcn, ...
                'FileFetcher',    fileFcn);

            testCase.verifyEqual(recorded('detailsCalls'), 1, ...
                'exactly one getFileDetails call for one manifest uid');
            args = recorded('detailsArgs');
            testCase.verifyEqual(char(args{1}), 'ds1');
            testCase.verifyEqual(char(args{2}), 'manifest_uid_A', ...
                'the direct call must carry the manifest uid');

            testCase.verifyEqual(recorded('fileCalls'), 1, ...
                'the resolved URL must be fetched once');
            fargs = recorded('fileArgs');
            testCase.verifyEqual(char(fargs{1}), 'https://s3.example/manifest');
            testCase.verifyEqual(char(fargs{2}), char(destPath));

            % The batch must not have been touched. Read the counters
            % back with an empty documentId -- that path returns early
            % without incrementing anything, so it is safe to call as a
            % pure read.
            [~, batchStats] = ndi.cloud.download.internal.batchSignedUrlLookup( ...
                "", "", "", "");
            testCase.verifyEqual(batchStats.signerCalls, 0, ...
                'batchSignedUrlLookup must NOT be reached on a manifest fetch');
            testCase.verifyEqual(batchStats.uidHits, 0);
            testCase.verifyEqual(batchStats.uidMisses, 0);
        end

        function testManifestFetchGoesThroughHandlerWhenProvided(testCase)
            % When a customFileHandler is provided (DID contract), the
            % fetch is dispatched through it and neither getFileDetails
            % nor getFile is called. This preserves the existing DID
            % #201 shape and is what the offline manifest-resolution
            % test in TestSeriesWithCloudOnlyManifestResolvesThroughHandler
            % exercises at the integration layer. Asserted here at the
            % unit layer so a regression in the branch order shows up
            % without spinning up the full DID stack.
            destPath = fullfile(testCase.WorkDir, 'manifest.bin');
            recorded = containers.Map('KeyType','char','ValueType','any');
            recorded('detailsCalls') = 0;
            recorded('fileCalls')    = 0;
            recorded('handlerCalls') = 0;
            recorded('handlerCtx')   = {};

            detailsFcn = @(varargin) localFailUnexpectedCall(recorded, 'detailsCalls'); %#ok<NASGU>
            fileFcn    = @(varargin) localFailUnexpectedCall(recorded, 'fileCalls'); %#ok<NASGU>

            handler = @(dest, src, ctx) localRecordHandlerCall( ...
                recorded, dest, src, ctx);

            ndi.cloud.sync.internal.fetchManifest( ...
                string(destPath), "ds1", "manifest_uid_B", ...
                "docB", "chunkdata.bin", handler);

            testCase.verifyEqual(recorded('handlerCalls'), 1, ...
                'the handler path must fire when a handler is supplied');
            testCase.verifyEqual(recorded('detailsCalls'), 0, ...
                'getFileDetails must not be called on the handler path');
            testCase.verifyEqual(recorded('fileCalls'), 0, ...
                'getFile must not be called on the handler path');

            ctx = recorded('handlerCtx');
            testCase.verifyEqual(char(ctx.uid), 'manifest_uid_B');
            testCase.verifyEqual(char(ctx.filename), 'chunkdata.bin');
            testCase.verifyEqual(char(ctx.seriesName), '', ...
                'the manifest context must carry seriesName="" so the handler treats uid as the manifest itself, not a member');
            testCase.verifyEqual(char(ctx.mode), 'open');
        end

        function testDetailsFetcherFailureIsReported(testCase)
            % Preserve the pre-existing error shape: a getFileDetails
            % that says ok=false raises NDI:cloud:sync:ManifestFetchFailed
            % with the manifest uid in the message. Callers upstream
            % (updateFileInfoForRemoteFiles) rely on catching this to
            % leave the entry un-reconstructed so DID#185's guard fires
            % on add_docs.
            destPath = fullfile(testCase.WorkDir, 'manifest.bin');
            failingFcn = @(varargin) deal(false, ...
                struct('message','server said no'));

            testCase.verifyError(@() ndi.cloud.sync.internal.fetchManifest( ...
                string(destPath), "ds1", "manifest_uid_C", ...
                "docC", "chunkdata.bin", [], ...
                'DetailsFetcher', failingFcn), ...
                'NDI:cloud:sync:ManifestFetchFailed');
        end

    end
end

function [ok, answer] = localScriptedDetails(recorded, datasetId, fileUid, url)
    recorded('detailsCalls') = recorded('detailsCalls') + 1;
    recorded('detailsArgs')  = {datasetId, fileUid};
    ok = true;
    answer = struct('downloadUrl', url);
end

function [ok, msg] = localScriptedFile(recorded, url, path, varargin)
    recorded('fileCalls') = recorded('fileCalls') + 1;
    recorded('fileArgs')  = {url, path, varargin};
    ok = true;
    msg = 'ok';
end

function [ok, msg] = localFailUnexpectedCall(recorded, key)
    % A stub that any test using the handler path expects NOT to be
    % called. Record it so the assertion fires with a clear counter,
    % rather than raising here (which would leave the test in a less
    % informative state).
    recorded(key) = recorded(key) + 1;
    ok = false;
    msg = 'unexpected call';
end

function localRecordHandlerCall(recorded, dest, src, ctx) %#ok<INUSL>
    recorded('handlerCalls') = recorded('handlerCalls') + 1;
    recorded('handlerCtx')   = ctx;
    % Write a tiny placeholder so the caller sees the handler landed
    % something at destPath.
    fid = fopen(char(dest), 'w');
    if fid > 0
        fwrite(fid, uint8(0), 'uint8');
        fclose(fid);
    end
end
