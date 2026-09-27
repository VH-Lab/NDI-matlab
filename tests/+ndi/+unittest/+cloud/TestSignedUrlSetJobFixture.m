classdef TestSignedUrlSetJobFixture < matlab.unittest.TestCase
% TESTSIGNEDURLSETJOBFIXTURE - pin the async signed-URL-set-job bug
% with a self-contained fresh upload.
%
% The bug: for a lightsheetZarrLevel document,
%   POST /datasets/{d}/documents/{doc}/signed-url-set-jobs
%       ?fileSeries=chunk.bin
% reaches state=failed with
%   "Manifest for file series 'chunk.bin' (uid <UID>) is not a file
%    of this dataset"
% while adjacent
%   GET /datasets/{d}/files/{UID}/detail
% for the same UID returns 200 OK. Two server code paths disagree
% on whether the manifest UID is a file of the dataset.
%
% Confirmed 2026-09-27 against both the tiny lightsheet fixture on
% User 1 prod (6ab84b549852a120dbcb22bc, 5-of-5 level docs) AND the
% 121k-member production dataset (6ab034e430a0f8d0e461dfcc). The
% failure is GLOBAL, not tied to that one dataset. See VH-Lab/
% NDI-matlab#1010 and the Python analog on the same branch of
% NDI-python (test_cloud_signed_url_set_job.py, commit 5ab9c04).
%
% This test builds its OWN fresh lightsheet fixture on each run --
% no hardcoded dataset id, no dependency on User 1 prod state -- so
% it runs the same probe against whichever environment
% CLOUD_API_ENVIRONMENT / NDI_CLOUD_USERNAME is currently pointed
% at. Uploads a tiny synthetic OME-Zarr (about 5 lightsheetZarrLevel
% documents), waits for bulk-upload extraction, then for each level
% doc:
%   * createSignedURLSetJob(idNamespace='ndi', fileSeries='chunk.bin')
%     + waitForSignedURLSetJob to a terminal state.
%   * INDEPENDENTLY getFileDetails(datasetId, manifestUid).
% Assert consistency: both ok, or both fail. Any row where the
% single-uid fetch returns 200 but the async job says "not a file
% of this dataset" IS the reproducer and fails the test with a
% message naming every offending (docId, ndiDocId, manifestUid)
% triplet so the API team's bug report can cite them.
%
% Every dataset the test creates is deleted on teardown so test
% accounts stay tidy.

    properties (Constant)
        DatasetNamePrefix  = "NDI_UNITTEST_SIGNED_URL_FIXTURE_"
        LevelClassName     = "lightsheetZarrLevel"
        SeriesName         = "chunk.bin"
        WaitTimeoutSeconds = 120
    end

    properties
        WorkDir     char   = ''
        DatasetIDs  string = string.empty
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            diagMsg = ['Missing NDI Cloud credentials ' ...
                '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). ' ...
                'Skipping TestSignedUrlSetJobFixture.'];
            testCase.assumeNotEmpty(username, diagMsg);
            testCase.assumeNotEmpty(password, diagMsg);
        end

        function checkLightsheetToolchain(testCase)
            % which() is the reliable probe for a package function's
            % presence on the path; exist(..., 'file') does not always
            % resolve dotted package names across MATLAB releases.
            testCase.assumeNotEmpty(...
                which('ndi.test.lightsheet.makeBlobFixture'), ...
                ['ndi.test.lightsheet.makeBlobFixture is not on the ' ...
                 'path. This test needs the lightsheet fixture builder.']);
            testCase.assumeNotEmpty(...
                which('ndi.fun.doc.lightsheet.fromOMEZarr'), ...
                ['ndi.fun.doc.lightsheet.fromOMEZarr is not on the path.']);
        end
    end

    methods (TestClassTeardown)
        function cleanupUploadedDatasets(testCase)
            % Sweep every dataset this class created, even if a
            % per-test teardown already tried; a failed run may have
            % left one behind. Best-effort, silent.
            for i = 1:numel(testCase.DatasetIDs)
                did = testCase.DatasetIDs(i);
                if strlength(did) == 0, continue, end
                try
                    ndi.cloud.api.datasets.deleteDataset(char(did), ...
                        'when', 'now'); %#ok<TRYNC>
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

    methods (Test)

        function testLevelDocsAgreeOnManifestReachability(testCase)
            % Build and upload a fresh lightsheet fixture, then run
            % the disagreement probe against every lightsheetZarrLevel
            % document the upload produced.

            cloudDatasetId = testCase.buildAndUploadTinyFixture();

            % Enumerate lightsheetZarrLevel documents from the cloud
            % side -- the same shape any client would use.
            [okList, docSummaries] = ndi.cloud.api.documents.listDatasetDocumentsAll( ...
                cloudDatasetId);
            testCase.assertTrue(okList, ...
                sprintf(['listDatasetDocumentsAll failed for freshly ' ...
                'uploaded dataset %s.'], char(cloudDatasetId)));

            classNames = arrayfun(@(s) string(safeField(s,'className','')), ...
                docSummaries);
            levelIdx = find(classNames == testCase.LevelClassName);
            testCase.assertNotEmpty(levelIdx, ...
                sprintf(['Uploaded dataset %s has no %s documents. ' ...
                'Fixture upload must have dropped them.'], ...
                char(cloudDatasetId), char(testCase.LevelClassName)));

            disagreements = string.empty;

            for k = 1:numel(levelIdx)
                summary    = docSummaries(levelIdx(k));
                cloudDocId = string(safeField(summary, 'id',    ''));
                ndiDocId   = string(safeField(summary, 'ndiId', ''));

                % files.file_info on the cloud document names the
                % manifest UID -- same shape ndi.cloud.sync.internal.
                % updateFileInfoForRemoteFiles reads on the download
                % side.
                [okDoc, docProps] = ndi.cloud.api.documents.getDocument( ...
                    cloudDatasetId, cloudDocId);
                if ~okDoc
                    fprintf(['[fixture-probe] doc=%s: getDocument ' ...
                        'failed; skipping.\n'], char(cloudDocId));
                    continue
                end
                manifestUid = extractManifestUidFromDoc(docProps, testCase.SeriesName);
                if strlength(manifestUid) == 0
                    fprintf(['[fixture-probe] doc=%s: no chunk.bin ' ...
                        'file_info entry; skipping.\n'], char(cloudDocId));
                    continue
                end

                % --- async job (the failing side, per Python + MATLAB)
                tStart = tic;
                [okCreate, createAnswer] = ndi.cloud.api.files.createSignedURLSetJob( ...
                    cloudDatasetId, ndiDocId, ...
                    'idNamespace', "ndi", ...
                    'fileSeries',  testCase.SeriesName);
                if ~okCreate
                    jobState   = "createRejected";
                    jobDetail  = extractMessage(createAnswer);
                    jobMapSize = NaN;
                else
                    jobId = string(createAnswer.jobId);
                    [okReady, jobAnswer] = ndi.cloud.api.files.waitForSignedURLSetJob( ...
                        jobId, 'timeout', testCase.WaitTimeoutSeconds);
                    if okReady
                        jobState   = "ready";
                        jobDetail  = "";
                        jobMapSize = double(safeField(jobAnswer, 'fileCount', NaN));
                    else
                        jobState   = string(safeField(jobAnswer, 'state', 'failed'));
                        jobDetail  = extractMessage(jobAnswer);
                        jobMapSize = NaN;
                    end
                end
                jobElapsedSec = toc(tStart);
                jobOk = jobState == "ready";

                % --- independent single-uid fetch (the succeeding side)
                [detailsOk, detailsAnswer] = ndi.cloud.api.files.getFileDetails( ...
                    cloudDatasetId, manifestUid);

                fprintf(['[fixture-probe] doc=%s ndi=%s manifestUid=%s ' ...
                    'jobState=%s elapsed=%.1fs mapSize=%s ' ...
                    'manifestFetchable=%d detail="%s"\n'], ...
                    char(cloudDocId), char(ndiDocId), char(manifestUid), ...
                    char(jobState), jobElapsedSec, mapSizeAsText(jobMapSize), ...
                    detailsOk, char(jobDetail));

                if jobOk && detailsOk
                    testCase.verifyGreaterThan(jobMapSize, 0, ...
                        sprintf(['jobMapSize should be > 0 for a ' ...
                        'ready job on doc %s.'], char(cloudDocId)));
                elseif ~jobOk && ~detailsOk
                    fprintf(['[fixture-probe] doc=%s: consistent ' ...
                        'failure (both paths say no).\n'], char(cloudDocId));
                elseif ~jobOk && detailsOk
                    disagreements(end+1) = sprintf( ...
                        'doc=%s ndi=%s manifestUid=%s: async job %s (%s) but getFileDetails returned 200', ...
                        char(cloudDocId), char(ndiDocId), char(manifestUid), ...
                        char(jobState), char(jobDetail)); %#ok<AGROW>
                else
                    disagreements(end+1) = sprintf( ...
                        'doc=%s: async job ready but getFileDetails failed for manifestUid=%s (%s)', ...
                        char(cloudDocId), char(manifestUid), ...
                        extractMessage(detailsAnswer)); %#ok<AGROW>
                end
            end

            if ~isempty(disagreements)
                testCase.verifyTrue(false, sprintf( ...
                    ['createSignedURLSetJob and getFileDetails disagree ' ...
                    'on %d document(s) of freshly-uploaded fixture %s. ' ...
                    'This is the server-side bug tracked in NDI-matlab' ...
                    '#1010: the async job says the manifest is not a ' ...
                    'file of the dataset while the single-uid fetch ' ...
                    'returns 200 for the same uid.\n%s'], ...
                    numel(disagreements), char(cloudDatasetId), ...
                    strjoin("  " + disagreements, newline)));
            end
        end

    end

    methods (Access = private)
        function cloudDatasetId = buildAndUploadTinyFixture(testCase)
            % Build a tiny lightsheet OME-Zarr on disk, ingest into a
            % fresh session, wrap in a dataset, upload uploadAsNew.
            % Small shape/small chunks -> ~5 spatial chunks per level
            % across a few levels; the disagreement fires per LEVEL
            % document (each carrying its own chunk.bin series), so
            % 5-ish level documents is plenty to probe.

            zarrParent = fullfile(testCase.WorkDir, 'zarr');
            mkdir(zarrParent);
            [zarrPath, ~] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
                'Shape',       [32 32 32], ...
                'NumChannels', 1, ...
                'NumLevels',   3, ...
                'ChunkShape',  [16 16 16]);

            sessionDir = fullfile(testCase.WorkDir, 'session');
            mkdir(sessionDir);
            S = ndi.session.dir('probe', sessionDir);

            subject = ndi.document('subject', ...
                'base.session_id', S.id(), ...
                'subject.local_identifier', 'probe@vhlab');
            S.database_add(subject);

            ndi.fun.doc.lightsheet.fromOMEZarr(S, zarrPath, ...
                'subjectID',         subject.id(), ...
                'materializeChunks', true, ...
                'codec',             'raw');

            datasetDir = fullfile(testCase.WorkDir, 'dataset');
            mkdir(datasetDir);
            D = ndi.dataset.dir('probe_ds', datasetDir);
            D = D.add_ingested_session(S);

            uniqueName = char(testCase.DatasetNamePrefix + ...
                string(did.ido.unique_id()));
            [ok, cloudDatasetId, msg] = ndi.cloud.uploadDataset(D, ...
                'uploadAsNew',                true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName',          uniqueName);
            testCase.assertTrue(ok, ...
                sprintf('uploadDataset failed: %s', char(string(msg))));
            cloudDatasetId = string(cloudDatasetId);
            testCase.DatasetIDs(end+1) = cloudDatasetId;
            % Per-test cleanup on top of the class-level sweep, so an
            % aborted test still tears its own dataset down.
            testCase.addTeardown(@() safeDeleteDataset(cloudDatasetId));

            [waitOk, waitInfo] = ndi.cloud.api.files.waitForAllBulkUploads( ...
                cloudDatasetId);
            testCase.assertTrue(waitOk, ...
                sprintf(['waitForAllBulkUploads did not confirm ' ...
                'completion (state=%s, elapsed=%.1fs).'], ...
                char(string(waitInfo.state)), waitInfo.elapsed));
        end
    end
end

function uid = extractManifestUidFromDoc(docProps, seriesName)
    % Manifest UID for a series named NAME lives at
    % document.files.file_info entry.name==NAME .locations(1).uid.
    uid = "";
    if ~isstruct(docProps), return, end
    files = safeField(docProps, 'files', struct());
    fileInfo = safeField(files, 'file_info', []);
    if isempty(fileInfo), return, end
    for i = 1:numel(fileInfo)
        entry = fileInfo(i);
        name = string(safeField(entry, 'name', ''));
        if name ~= seriesName, continue, end
        locs = safeField(entry, 'locations', []);
        if isempty(locs), return, end
        uid = string(safeField(locs(1), 'uid', ''));
        return
    end
end

function v = safeField(s, name, defaultValue)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = defaultValue;
    end
end

function m = extractMessage(payload)
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

function s = mapSizeAsText(value)
    if isnumeric(value) && isscalar(value) && ~isnan(value)
        s = sprintf('%d', round(value));
    else
        s = '-';
    end
end

function safeDeleteDataset(cloudDatasetId)
    try
        ndi.cloud.api.datasets.deleteDataset(char(cloudDatasetId), ...
            'when', 'now'); %#ok<TRYNC>
    catch
    end
end
