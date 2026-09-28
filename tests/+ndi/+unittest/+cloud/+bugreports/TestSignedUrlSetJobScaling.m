classdef TestSignedUrlSetJobScaling < matlab.unittest.TestCase
% TESTSIGNEDURLSETJOBSCALING - reproducer for the async signed-URL-set-job bug.
%
% The bug (verified live): createSignedURLSetJob for a lightsheetZarrLevel
% chunk.bin series on a production dataset fails with
%   "Manifest for file series 'chunk.bin' (uid <UID>) is not a file of
%   this dataset"
% while getFileDetails(datasetId, <UID>) for the same uid returns 200 OK
% right before and right after. Two server code paths disagree on
% whether the manifest is a file of the dataset. The failing dataset has
% 121,441 members; the existing 15-file lightsheet fixture does NOT
% trigger it. This test walks N up in a bisectable ramp so the failure
% (if reproducible from a fresh upload at all) is bracketed.
%
% What each row does, per N:
%   a) Build a synthetic OME-Zarr blob whose level-0 chunk.bin series
%      has approximately N members (via ndi.test.lightsheet.makeBlobFixture),
%      ingest it into a fresh session and dataset, upload with
%      uploadAsNew, wait for server-side bulk-upload extraction.
%   b) Extract the manifest UID locally from the level document's
%      chunk.bin binary path (ndi.database.internal.list_binary_files
%      does the same thing at upload time).
%   c) Call createSignedURLSetJob(datasetId, docId, 'ndi', 'fileSeries',
%      'chunk.bin') and waitForSignedURLSetJob to a terminal state.
%   d) INDEPENDENTLY call getFileDetails(datasetId, manifestUid); a
%      200 here in the same instant createSignedURLSetJob says "not a
%      file of this dataset" is the disagreement we are bisecting.
%   e) Record: N (intended), actualMemberCount, jobId, jobState,
%      jobElapsedSec, mapSize (ready) or errorMessage (failed),
%      manifestFetchable, datasetId.
%
% Skips cleanly without NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD (same
% idiom as FileSeriesRoundTripTest). Every dataset the test creates is
% deleted on teardown so the test account does not accumulate cruft.
%
% What we want the run to tell us:
%   * If a size triggers the bug: this is a reproducer created by a
%     fresh upload using only test-account state -- attach the results
%     to the bug report and the API team can bisect on N.
%   * If no size triggers it: the failing dataset's issue is
%     upload-path-specific (workflow / MATLAB version / ingest history),
%     not size-specific. Compare its provenance to what this test does
%     to find the drift.
%
% Either outcome is actionable. Once the server bug is fixed the test
% becomes a permanent regression guard.
%
% See VH-Lab/NDI-matlab#1010 addendum. Related Python analog:
% Waltham-Data-Science/NDI-python 5ab9c04.

    properties (Constant)
        DatasetNamePrefix = 'NDI_UNITTEST_SIGNED_URL_SCALING_';
        % chunk.bin_# member ≈ (fixed) uint16 bytes per spatial chunk.
        % Shape is chosen at runtime per N so total spatial chunks ≈ N
        % for a single-channel, single-level blob store. See setupPer
        % method.
        BaseChunkShape = [16 16 16];
    end

    properties (TestParameter)
        % Intended member count. The actual count comes back from the
        % local level document after ingest and is what the table
        % reports -- Shape/ChunkShape only aims for the target.
        %
        % A run with credentials but a small time budget can restrict
        % via the MATLAB unittest -Selector infrastructure or just let
        % the small sizes run and Ctrl-C before the big one.
        %
        % Size regimes and their purpose:
        %   N5, N100, N500      -- exercise the plumbing (upload,
        %                          extract, signed-URL job) at
        %                          fixture-scale where the API path
        %                          used to time out on its own.
        %   N2000, N10000       -- push into the "signing rate
        %                          matters" regime where the earlier
        %                          fix (see NDI-matlab#1010 /
        %                          ndi-cloud-node#149) moved the
        %                          floor from ~24 URLs/s.
        %   N50000, N100000     -- exercise the >100k regime that
        %                          real lightsheet levels live in
        %                          (a level of a 121,441-URL pyramid
        %                          motivated Waltham-Data-Science/
        %                          NDI-python#320 / ndi-cloud-node
        %                          #151). Currently gated behind
        %                          NDI_SCALINGPROBE_HUGE=1 so the
        %                          default CI run does not swallow a
        %                          30+ minute upload per row: the
        %                          size is what proves the fix lands,
        %                          but the upload is a cloud-budget
        %                          hit until then. Flip the gate off
        %                          (i.e. remove the assumeTrue below)
        %                          once ndi-cloud-node#151 is fixed
        %                          AND the upload path is fast
        %                          enough that CI can afford these
        %                          rows on every push.
        targetMemberCount = struct( ...
            'N5',      5, ...
            'N100',    100, ...
            'N500',    500, ...
            'N2000',   2000, ...
            'N10000',  10000, ...
            'N50000',  50000, ...
            'N100000', 100000);
    end

    properties
        WorkDir char = ''
        DatasetIDs string = string.empty  % for class-level cleanup
        Results struct = struct( ...
            'N',                {}, ...
            'actualMemberCount',{}, ...
            'jobId',            {}, ...
            'jobState',         {}, ...
            'jobElapsedSec',    {}, ...
            'mapSize',          {}, ...
            'errorMessage',     {}, ...
            'manifestFetchable',{}, ...
            'manifestUid',      {}, ...
            'datasetId',        {})
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials ' ...
                '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). ' ...
                'Skipping TestSignedUrlSetJobScaling.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function checkLightsheetToolchain(testCase)
            % A run without the lightsheet builder skips rather than
            % errors: the fixture path leans on it heavily and the
            % failure mode we are hunting is server-side, not local.
            % which() is the reliable probe for a package function's
            % presence; exist(..., 'file') does not always resolve
            % dotted package names across MATLAB releases.
            testCase.assumeNotEmpty(...
                which('ndi.test.lightsheet.makeBlobFixture'), ...
                ['ndi.test.lightsheet.makeBlobFixture is not on the ' ...
                 'path. This test needs the lightsheet fixture builder.']);
            testCase.assumeNotEmpty(...
                which('ndi.fun.doc.lightsheet.fromOMEZarr'), ...
                ['ndi.fun.doc.lightsheet.fromOMEZarr is not on the ' ...
                 'path. This test needs the OME-Zarr -> pyramid+level ' ...
                 'ingest.']);
        end
    end

    methods (TestClassTeardown)
        function cleanupUploadedDatasets(testCase)
            % Belt-and-braces: every method's own teardown already tries
            % to delete its dataset, but a mid-method crash may leave
            % one behind. Sweep at class teardown too, silently.
            for i = 1:numel(testCase.DatasetIDs)
                did = testCase.DatasetIDs(i);
                if strlength(did) == 0, continue, end
                try
                    ndi.cloud.api.datasets.deleteDataset( ...
                        char(did), 'when', 'now'); %#ok<TRYNC>
                catch
                end
            end
        end
    end

    methods (TestMethodSetup)
        function setupWorkFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fx = testCase.applyFixture(TemporaryFolderFixture);
            testCase.WorkDir = fx.Folder;
        end
    end

    methods (Test, ParameterCombination = 'sequential')

        function testCreateSignedURLSetJobForNMemberSeries(testCase, targetMemberCount)
            % Runs one (build + upload + createSignedURLSetJob) round and
            % records the outcome. Assertions are DELIBERATELY LOOSE: a
            % failure is a DATA POINT, not a red test. The test only fails
            % if setup / upload / local extraction goes wrong, since those
            % would poison the row and mask the server-side outcome we are
            % here to observe. The row is what the reader reads.

            % Huge-N gate. 50k / 100k rows upload ~50-100k files each,
            % which currently takes tens of minutes and burns cloud
            % budget on every CI push; skip them unless
            % NDI_SCALINGPROBE_HUGE=1 is explicitly set. Retire this
            % gate once ndi-cloud-node#151 is fixed and CI can afford
            % the upload cost on every run.
            if targetMemberCount >= 50000
                hugeGate = getenv('NDI_SCALINGPROBE_HUGE');
                testCase.assumeTrue(strcmp(hugeGate, '1'), ...
                    sprintf(['N=%d skipped by default: set ' ...
                             'NDI_SCALINGPROBE_HUGE=1 to run the ' ...
                             '>=50k rows. See the comment on ' ...
                             'targetMemberCount for the rationale.'], ...
                        targetMemberCount));
            end

            row = testCase.freshRow(targetMemberCount);

            % --- 1. Build the fixture at the size that yields ~N members
            [shape, chunkShape] = pickShapeForTarget(targetMemberCount, ...
                testCase.BaseChunkShape);
            zarrParent = fullfile(testCase.WorkDir, 'zarr');
            mkdir(zarrParent);
            [zarrPath, ~] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
                'Shape',       shape, ...
                'NumChannels', 1, ...
                'NumLevels',   1, ...
                'ChunkShape',  chunkShape);

            % --- 2. Ingest into a fresh session + dataset
            sessionDir = fullfile(testCase.WorkDir, 'session');
            mkdir(sessionDir);
            S = ndi.session.dir('scaleprobe', sessionDir);
            subject = ndi.document('subject', ...
                'base.session_id', S.id(), ...
                'subject.local_identifier', 'scaleprobe@vhlab');
            S.database_add(subject);

            % Pass ``chunks`` through explicitly so makePyramid does
            % NOT fall through to chooseTileShape's default 8 MB
            % target. Without this the [16 16 16] chunk shape
            % pickShapeForTarget hands makeBlobFixture gets rechunked
            % downstream to a much larger tile (observed empirically
            % as [161 161 161], ~4 MB per chunk), so a "target 100000
            % members" fixture only produces ~125 members and the
            % scaling axis this test exists to sweep is silently
            % collapsed to a constant. Handing the same chunkShape to
            % fromOMEZarr keeps the level-0 chunk shape at what the
            % fixture wrote, so ceil(shape ./ chunkShape) member count
            % actually matches the target.
            [~, levelDocs, ~] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
                S, zarrPath, ...
                'subjectID', subject.id(), ...
                'materializeChunks', true, ...
                'codec', 'raw', ...
                'chunks', chunkShape);
            testCase.assertNotEmpty(levelDocs, ...
                'fromOMEZarr produced no level documents; bail before the cloud call.');

            % The bug is triggered by ONE chunk.bin series scope on ONE
            % level document, so pick level 0 (highest resolution -> most
            % members) and use it for the rest of the run.
            levelDoc = firstLevelDoc(levelDocs);

            % --- 3. Wrap in a dataset and upload
            datasetDir = fullfile(testCase.WorkDir, 'dataset');
            mkdir(datasetDir);
            D = ndi.dataset.dir('scaleprobe_ds', datasetDir);
            D = D.add_ingested_session(S);

            uniqueName = char(sprintf('%s%s', ...
                testCase.DatasetNamePrefix, did.ido.unique_id()));
            [ok, cloudDatasetId, msg] = ndi.cloud.uploadDataset(D, ...
                'uploadAsNew',                true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName',          uniqueName);
            testCase.assertTrue(ok, ...
                sprintf('uploadDataset failed for N=%d: %s', ...
                    targetMemberCount, char(string(msg))));
            testCase.DatasetIDs(end+1) = string(cloudDatasetId);
            row.datasetId = string(cloudDatasetId);
            % Register per-method cleanup so a failed run still tears
            % this dataset down.
            testCase.addTeardown(@() safeDeleteDataset(cloudDatasetId));

            % --- 4. Wait for the server to finish extracting the bulk zip
            [waitOk, waitInfo] = ndi.cloud.api.files.waitForAllBulkUploads( ...
                cloudDatasetId);
            testCase.assertTrue(waitOk, ...
                sprintf('waitForAllBulkUploads did not confirm completion (state=%s, elapsed=%.1fs).', ...
                    char(string(waitInfo.state)), waitInfo.elapsed));

            % --- 5. Extract the manifest uid from the LOCAL level doc
            [manifestExists, manifestLocalPath] = ...
                D.database_existbinarydoc(levelDoc.id(), 'chunk.bin');
            testCase.assertTrue(manifestExists, ...
                sprintf('chunk.bin manifest for level doc %s was not found locally.', ...
                    levelDoc.id()));
            [~, manifestUid, ~] = fileparts(char(manifestLocalPath));
            row.manifestUid = string(manifestUid);

            % Actual member count from the local manifest -- what the
            % table reports so N vs. reality is legible.
            try
                localManifest = did.file.readSeriesManifest(char(manifestLocalPath));
                row.actualMemberCount = localManifest.count;
            catch
                row.actualMemberCount = -1;
            end

            % Regression guard: an actual count far below target means
            % the fixture builder is silently rechunking (as it did
            % before we started passing ``chunks`` through to
            % fromOMEZarr), so the scaling axis is not being exercised
            % at the intended size and every row degenerates into a
            % test of the small-N case. Warn loudly so a future
            % regression is visible in the run log rather than only
            % legible by squinting at the [scaleprobe] rows.
            if targetMemberCount >= 100 && row.actualMemberCount > 0 && ...
                    row.actualMemberCount < 0.25 * targetMemberCount
                warning('NDI:test:SignedUrlSetJobScaling:FixtureCollapsed', ...
                    ['N=%d requested but fixture produced only %d members ' ...
                     '(< 25%%). The scaling axis is not being exercised as ' ...
                     'intended -- check that fromOMEZarr is honoring the ' ...
                     'requested chunk shape and not falling through to ' ...
                     'chooseTileShape''s default byte budget.'], ...
                    targetMemberCount, row.actualMemberCount);
            end

            % --- 6. createSignedURLSetJob + wait
            ndiDocumentId = levelDoc.id();
            tStart = tic;
            [createOk, createAnswer] = ndi.cloud.api.files.createSignedURLSetJob( ...
                string(cloudDatasetId), string(ndiDocumentId), ...
                'idNamespace', "ndi", ...
                'fileSeries',  "chunk.bin");
            if ~createOk
                row.jobState = "createRejected";
                row.jobId = "";
                row.errorMessage = extractMessage(createAnswer);
            else
                row.jobId = string(createAnswer.jobId);
                % Size-adaptive timeout. At the observed per-URL rate the
                % small sizes finish well inside 300 s; the >=50k rows
                % need a longer ceiling to reach 'ready' at all once the
                % server-side fix lands. A generous ceiling costs
                % nothing when the fix is fast (the wait returns as
                % soon as the job is ready) and lets the row report
                % the actual wall time rather than "timed out".
                jobTimeoutSec = max(300, ceil(targetMemberCount / 100));
                [readyOk, jobAnswer] = ndi.cloud.api.files.waitForSignedURLSetJob( ...
                    row.jobId, 'timeout', jobTimeoutSec);
                if readyOk
                    row.jobState = "ready";
                    if isfield(jobAnswer, 'fileCount') && ~isempty(jobAnswer.fileCount)
                        row.mapSize = double(jobAnswer.fileCount);
                    end
                    row.errorMessage = "";
                else
                    row.jobState = string(safeField(jobAnswer, 'state', 'failed'));
                    row.errorMessage = extractMessage(jobAnswer);
                end
            end
            row.jobElapsedSec = toc(tStart);

            % --- 7. Independent getFileDetails for the same manifest uid
            [detailsOk, ~] = ndi.cloud.api.files.getFileDetails( ...
                string(cloudDatasetId), row.manifestUid);
            row.manifestFetchable = detailsOk;

            testCase.Results(end+1) = row;
            printRow(row);

            % The test itself does not fail on a job failure -- that IS
            % the observation the run is here to make. Only a wildly
            % inconsistent state fails: the manifest is not fetchable AND
            % the job also failed, which contradicts the reported cloud
            % bug (job fails while manifest fetch works). That signals
            % the bug reproduction went sideways, not that the bug
            % reproduced.
            if strcmp(row.jobState, "failed") && ~row.manifestFetchable
                testCase.verifyTrue(false, ...
                    sprintf(['Both the job and the direct manifest ' ...
                    'fetch failed for uid %s (N=%d, actual=%d). ' ...
                    'The reported bug is a DISAGREEMENT between those ' ...
                    'two -- this row is not the disagreement, so ' ...
                    'something else broke setup.'], ...
                    char(row.manifestUid), targetMemberCount, ...
                    row.actualMemberCount));
            end
        end

    end

    methods (Access = private)
        function row = freshRow(testCase, N) %#ok<INUSL>
            row = struct( ...
                'N',                 N, ...
                'actualMemberCount', 0, ...
                'jobId',             "", ...
                'jobState',          "unstarted", ...
                'jobElapsedSec',     0, ...
                'mapSize',           NaN, ...
                'errorMessage',      "", ...
                'manifestFetchable', false, ...
                'manifestUid',       "", ...
                'datasetId',         "");
        end
    end
end

function [shape, chunkShape] = pickShapeForTarget(target, baseChunkShape)
    % Aim for level-0 spatial chunks ≈ target. NumChannels=1,
    % NumLevels=1 in the fixture builder, so total series members
    % ≈ prod(ceil(shape ./ chunkShape)).
    %
    % Factor target as k*k*(target/k^2) with k = round(target^(1/3))
    % so shapes stay roughly cubic. A cubic-ish layout matters because
    % the lightsheet levels the failing dataset carries are cubic-ish
    % too; a stringy 1xN layout could miss a shape-dependent bug the
    % server has.
    chunkShape = baseChunkShape;
    if target <= 1
        chunks = [1 1 1];
    else
        k = max(1, round(target^(1/3)));
        c1 = k;
        c2 = k;
        c3 = max(1, ceil(target / (c1*c2)));
        chunks = [c1 c2 c3];
    end
    shape = chunks .* chunkShape;
end

function d = firstLevelDoc(levelDocs)
    % levelDocs can be a cell array or a struct-of-arrays or a single
    % doc depending on the fromOMEZarr version. Normalize to a scalar
    % ndi.document.
    if iscell(levelDocs)
        d = levelDocs{1};
    elseif numel(levelDocs) > 1
        d = levelDocs(1);
    else
        d = levelDocs;
    end
end

function printRow(r)
    % One row per N to the MATLAB console. Printed immediately (not
    % held for a class-teardown summary) because parametrized test
    % cases run in fresh test instances -- rows do not accumulate on
    % one testCase across parameter values, so the log itself IS the
    % table. Grep for [scaleprobe] in a CI run to pull the rows out.
    detail = char(r.errorMessage);
    if numel(detail) > 60, detail = [detail(1:57) '...']; end
    fprintf(['[scaleprobe] N=%-6d actual=%-6d state=%-10s ' ...
        'elapsed=%6.1fs mapSize=%-8s manifestFetchable=%d ' ...
        'manifestUid=%s dataset=%s jobId=%s detail="%s"\n'], ...
        r.N, r.actualMemberCount, char(r.jobState), r.jobElapsedSec, ...
        mapSizeAsText(r.mapSize), r.manifestFetchable, ...
        char(r.manifestUid), char(r.datasetId), char(r.jobId), detail);
end

function s = mapSizeAsText(value)
    if isnumeric(value) && isscalar(value) && ~isnan(value)
        s = sprintf('%d', round(value));
    else
        s = '-';
    end
end

function m = extractMessage(payload)
    % Server-side error payloads travel in a few shapes. Try the common
    % ones so the table row carries whatever the server said, verbatim.
    m = "";
    if isstruct(payload)
        if isfield(payload, 'message') && ~isempty(payload.message)
            m = string(payload.message);
        elseif isfield(payload, 'error') && ~isempty(payload.error)
            m = string(payload.error);
        elseif isfield(payload, 'state') && ~isempty(payload.state)
            m = string(payload.state);
        end
    elseif ischar(payload) || isstring(payload)
        m = string(payload);
    end
end

function v = safeField(s, name, defaultValue)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultValue;
    end
end

function safeDeleteDataset(cloudDatasetId)
    try
        ndi.cloud.api.datasets.deleteDataset(char(cloudDatasetId), ...
            'when', 'now'); %#ok<TRYNC>
    catch
    end
end
