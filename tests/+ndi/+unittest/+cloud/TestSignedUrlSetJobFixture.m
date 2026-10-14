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
% 121k-member production dataset (6ab034e430a0f8d0e461dfcc). See
% VH-Lab/NDI-matlab#1010 and the Python analog on the same branch
% of NDI-python (test_cloud_signed_url_set_job.py, commit 5ab9c04).
%
% This test builds its own fresh lightsheet fixture on each run --
% no hardcoded dataset id, no dependency on any environment's fixture
% state -- so it runs the same probe against whichever environment
% CLOUD_API_ENVIRONMENT / NDI_CLOUD_USERNAME points at.
%
% Diagnostics are narrated the same way FileSeriesRoundTripTest and
% ndi.unittest.cloud.APIMessage produce them: every step appends a
% string to Narrative, and any assertion that touches the cloud
% wraps the message in APIMessage so a failure prints as a JSON
% report the server-side team can read without a MATLAB session.
% See ndi.unittest.cloud.APIMessage and VH-Lab/NDI-matlab#945.

    properties (Constant)
        DatasetNamePrefix  = "NDI_UNITTEST_SIGNED_URL_FIXTURE_"
        LevelClassName     = "lightsheetZarrLevel"
        SeriesName         = "chunk.bin"
        WaitTimeoutSeconds = 120
    end

    properties
        WorkDir     char           = ''
        DatasetIDs  string         = string.empty
        Narrative   (1,:) string   = string.empty
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
            testCase.Narrative = "Begin TestSignedUrlSetJobFixture setup " + ...
                "in " + string(fx.Folder) + ".";
        end
    end

    methods (Test)

        function testLevelDocsAgreeOnManifestReachability(testCase)
            % Build and upload a fresh lightsheet fixture, then probe
            % every lightsheetZarrLevel document the upload produced
            % for the async-job vs. getFileDetails disagreement. On a
            % healthy environment every row should be ready+200. Any
            % row where async=failed but detail=200 IS the reported
            % server-side bug and this test fails with each offending
            % triplet named.

            cloudDatasetId = testCase.buildAndUploadTinyFixture();

            % --- 1. Enumerate lightsheetZarrLevel documents
            testCase.Narrative(end+1) = "Enumerating documents on the " + ...
                "freshly uploaded dataset via " + ...
                "ndi.cloud.api.documents.listDatasetDocumentsAll.";
            [okList, docSummaries, listResp, listUrl] = ...
                ndi.cloud.api.documents.listDatasetDocumentsAll(cloudDatasetId);
            listMsg = ndi.unittest.cloud.APIMessage(testCase.Narrative, ...
                okList, docSummaries, listResp, listUrl);
            testCase.assertTrue(okList, ...
                "listDatasetDocumentsAll failed for the freshly-uploaded " + ...
                "dataset. " + listMsg);

            classNames = arrayfun(@(s) string(safeField(s,'className','')), ...
                docSummaries);
            levelIdx = find(classNames == testCase.LevelClassName);
            testCase.Narrative(end+1) = "Filtered to " + numel(levelIdx) + ...
                " " + testCase.LevelClassName + " document(s) out of " + ...
                numel(docSummaries) + " total.";
            noneMsg = ndi.unittest.cloud.APIMessage(testCase.Narrative, ...
                true, docSummaries, listResp, listUrl);
            testCase.assertNotEmpty(levelIdx, ...
                "Uploaded dataset has no " + testCase.LevelClassName + ...
                " documents; fixture upload must have dropped them. " + noneMsg);

            disagreements = string.empty;

            for k = 1:numel(levelIdx)
                summary    = docSummaries(levelIdx(k));
                cloudDocId = string(safeField(summary, 'id',    ''));
                ndiDocId   = string(safeField(summary, 'ndiId', ''));

                testCase.Narrative(end+1) = "--- Probing " + ...
                    testCase.LevelClassName + " " + (k) + "/" + ...
                    numel(levelIdx) + " (cloud id " + cloudDocId + ...
                    ", ndi id " + ndiDocId + ") ---";

                [manifestUid, docNarrative, docFatal] = ...
                    testCase.resolveManifestUid(cloudDatasetId, cloudDocId);
                testCase.Narrative = docNarrative;
                if docFatal
                    % resolveManifestUid already appended a reason to
                    % the narrative; skip this doc without abandoning
                    % the whole test.
                    continue
                end

                [row, probeNarrative] = testCase.probeOneLevelDoc( ...
                    cloudDatasetId, ndiDocId, manifestUid, ...
                    cloudDocId, testCase.Narrative);
                testCase.Narrative = probeNarrative;

                printFixtureProbeRow(row);

                if row.jobOk && row.detailsOk
                    % Healthy: both paths agree. Real fileCount comes
                    % from the async job's result blob (fetched inside
                    % probeOneLevelDoc when the job was ready), so a
                    % ready-with-zero-files is legible.
                    successMsg = ndi.unittest.cloud.APIMessage( ...
                        testCase.Narrative, true, row.jobResultBlob, ...
                        row.jobResultResponse, row.jobResultUrl);
                    testCase.verifyGreaterThan(row.jobMapSize, 0, ...
                        "The async job reported 'ready' but its result " + ...
                        "blob's fileCount was " + row.jobMapSize + ...
                        ". A ready manifest scope should carry at least " + ...
                        "one member. " + successMsg);
                elseif ~row.jobOk && ~row.detailsOk
                    testCase.Narrative(end+1) = "Both paths refused the " + ...
                        "same manifest UID -- consistent, not the " + ...
                        "disagreement we are probing for.";
                elseif ~row.jobOk && row.detailsOk
                    disagreements(end+1) = sprintf( ...
                        'doc=%s ndi=%s manifestUid=%s: async job %s (%s) but getFileDetails returned 200', ...
                        char(cloudDocId), char(ndiDocId), char(manifestUid), ...
                        char(row.jobState), char(row.jobDetail)); %#ok<AGROW>
                    testCase.Narrative(end+1) = "DISAGREEMENT: " + ...
                        "async job state=" + row.jobState + ...
                        " (" + row.jobDetail + ") but getFileDetails " + ...
                        "returned 200 for manifest uid " + manifestUid + ".";
                else % row.jobOk && ~row.detailsOk
                    disagreements(end+1) = sprintf( ...
                        'doc=%s: async job ready but getFileDetails failed for manifestUid=%s (%s)', ...
                        char(cloudDocId), char(manifestUid), ...
                        char(row.detailsDetail)); %#ok<AGROW>
                    testCase.Narrative(end+1) = "INVERSE DISAGREEMENT: " + ...
                        "async job ready but getFileDetails FAILED for " + ...
                        "manifest uid " + manifestUid + " (" + ...
                        row.detailsDetail + ").";
                end
            end

            if ~isempty(disagreements)
                finalMsg = ndi.unittest.cloud.APIMessage( ...
                    testCase.Narrative, false, ...
                    struct('disagreements', {cellstr(disagreements)}, ...
                           'datasetId', char(cloudDatasetId)), ...
                    matlab.net.http.ResponseMessage.empty, ...
                    "createSignedURLSetJob and getFileDetails cross-check");
                testCase.verifyTrue(false, sprintf( ...
                    ['createSignedURLSetJob and getFileDetails disagree ' ...
                    'on %d document(s) of freshly-uploaded fixture %s. ' ...
                    'This is the server-side bug tracked in ' ...
                    'VH-Lab/NDI-matlab#1010.\n%s\n\n%s'], ...
                    numel(disagreements), char(cloudDatasetId), ...
                    strjoin("  " + disagreements, newline), finalMsg));
            end
        end

    end

    methods (Access = private)
        function cloudDatasetId = buildAndUploadTinyFixture(testCase)
            % Build a tiny lightsheet OME-Zarr on disk, ingest into a
            % fresh session, wrap in a dataset, upload uploadAsNew.
            % Small shape / small chunks -> a handful of level docs,
            % each carrying its own chunk.bin series -- enough surface
            % for the disagreement to fire on a per-level basis.

            zarrParent = fullfile(testCase.WorkDir, 'zarr');
            mkdir(zarrParent);
            testCase.Narrative(end+1) = "Building tiny lightsheet blob " + ...
                "fixture at " + string(zarrParent) + " " + ...
                "(Shape [32 32 32], NumChannels 1, NumLevels 3, " + ...
                "ChunkShape [16 16 16]).";
            [zarrPath, ~] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
                'Shape',       [32 32 32], ...
                'NumChannels', 1, ...
                'NumLevels',   3, ...
                'ChunkShape',  [16 16 16]);
            testCase.Narrative(end+1) = "Zarr fixture built at " + ...
                string(zarrPath) + ".";

            sessionDir = fullfile(testCase.WorkDir, 'session');
            mkdir(sessionDir);
            S = ndi.session.dir('probe', sessionDir);
            subject = ndi.document('subject', ...
                'base.session_id', S.id(), ...
                'subject.local_identifier', 'probe@vhlab');
            S.database_add(subject);
            testCase.Narrative(end+1) = "Session opened at " + ...
                string(sessionDir) + " with subject " + string(subject.id()) + ".";

            testCase.Narrative(end+1) = "Ingesting the OME-Zarr into the " + ...
                "session via ndi.fun.doc.lightsheet.fromOMEZarr " + ...
                "(materializeChunks=true, codec=raw).";
            ndi.fun.doc.lightsheet.fromOMEZarr(S, zarrPath, ...
                'subjectID',         subject.id(), ...
                'materializeChunks', true, ...
                'codec',             'raw');

            datasetDir = fullfile(testCase.WorkDir, 'dataset');
            mkdir(datasetDir);
            D = ndi.dataset.dir('probe_ds', datasetDir);
            D = D.add_ingested_session(S);
            testCase.Narrative(end+1) = "Dataset created at " + ...
                string(datasetDir) + "; ingested session " + string(S.id()) + ".";

            uniqueName = char(testCase.DatasetNamePrefix + ...
                string(did.ido.unique_id()));
            testCase.Narrative(end+1) = "Uploading to NDI Cloud as " + ...
                "remote name '" + string(uniqueName) + "' " + ...
                "(uploadAsNew=true, skipMetadataEditorMetadata=true).";
            [ok, cloudDatasetId, msg] = ndi.cloud.uploadDataset(D, ...
                'uploadAsNew',                true, ...
                'skipMetadataEditorMetadata', true, ...
                'remoteDatasetName',          uniqueName);
            uploadMsg = ndi.unittest.cloud.APIMessage(testCase.Narrative, ...
                ok, msg, matlab.net.http.ResponseMessage.empty, ...
                "ndi.cloud.uploadDataset");
            testCase.assertTrue(ok, ...
                "uploadDataset failed: " + string(msg) + ". " + uploadMsg);
            cloudDatasetId = string(cloudDatasetId);
            testCase.DatasetIDs(end+1) = cloudDatasetId;
            testCase.addTeardown(@() safeDeleteDataset(cloudDatasetId));
            testCase.Narrative(end+1) = "Upload accepted; cloud dataset id is " + ...
                cloudDatasetId + ".";

            testCase.Narrative(end+1) = "Waiting for server-side " + ...
                "bulk-upload extraction (waitForAllBulkUploads) " + ...
                "before probing files.";
            [waitOk, waitInfo, waitResp, waitUrl] = ...
                ndi.cloud.api.files.waitForAllBulkUploads(cloudDatasetId);
            waitMsg = ndi.unittest.cloud.APIMessage(testCase.Narrative, ...
                waitOk, waitInfo, waitResp, waitUrl);
            testCase.assertTrue(waitOk, ...
                "waitForAllBulkUploads did not confirm completion " + ...
                "(state=" + string(safeField(waitInfo,'state','')) + ", " + ...
                "elapsed=" + safeField(waitInfo,'elapsed',NaN) + "s). " + waitMsg);
            testCase.Narrative(end+1) = "Bulk-upload extraction " + ...
                "confirmed (elapsed=" + safeField(waitInfo,'elapsed',NaN) + "s).";
        end

        function [manifestUid, narrative, fatal] = resolveManifestUid( ...
                testCase, cloudDatasetId, cloudDocId)
            % Fetch the cloud document's files.file_info block and pull
            % the chunk.bin manifest UID out of it. If we can't reach
            % that state, append a narrative line and return fatal=true
            % so the caller skips this document without failing the
            % whole test.
            narrative = testCase.Narrative;
            manifestUid = "";
            fatal = false;

            narrative(end+1) = "Fetching full document via " + ...
                "ndi.cloud.api.documents.getDocument to read " + ...
                "files.file_info.";
            [okDoc, docProps, docResp, docUrl] = ...
                ndi.cloud.api.documents.getDocument(cloudDatasetId, cloudDocId);
            if ~okDoc
                docMsg = ndi.unittest.cloud.APIMessage(narrative, ...
                    okDoc, docProps, docResp, docUrl);
                narrative(end+1) = "getDocument failed for cloud id " + ...
                    cloudDocId + "; skipping this doc. Diagnostic: " + docMsg;
                fatal = true;
                return
            end
            manifestUid = extractManifestUidFromDoc(docProps, testCase.SeriesName);
            if strlength(manifestUid) == 0
                narrative(end+1) = "Document has no " + testCase.SeriesName + ...
                    " file_info entry; skipping (not a level with a " + ...
                    "materialized manifest).";
                fatal = true;
                return
            end
            narrative(end+1) = "Resolved manifest UID for series '" + ...
                testCase.SeriesName + "' = " + manifestUid + ".";
        end

        function [row, narrative] = probeOneLevelDoc(testCase, ...
                cloudDatasetId, ndiDocId, manifestUid, cloudDocId, narrative)
            % Do the two adjacent API calls: createSignedURLSetJob +
            % waitForSignedURLSetJob (async path) and getFileDetails
            % (single-uid path). Return a row struct summarising the
            % outcome, plus the extended narrative.

            row = struct( ...
                'cloudDocId',        cloudDocId, ...
                'ndiDocId',          ndiDocId, ...
                'manifestUid',       manifestUid, ...
                'jobId',             "", ...
                'jobState',          "unstarted", ...
                'jobDetail',         "", ...
                'jobElapsedSec',     0, ...
                'jobOk',             false, ...
                'jobMapSize',        NaN, ...
                'jobResultBlob',     [], ...
                'jobResultResponse', matlab.net.http.ResponseMessage.empty, ...
                'jobResultUrl',      "", ...
                'detailsOk',         false, ...
                'detailsDetail',     "");

            % --- Async job path
            narrative(end+1) = "Calling " + ...
                "ndi.cloud.api.files.createSignedURLSetJob(" + ...
                "idNamespace='ndi', fileSeries='" + testCase.SeriesName + ...
                "') on NDI doc id " + ndiDocId + ".";
            tStart = tic;
            [okCreate, createAnswer, createResp, createUrl] = ...
                ndi.cloud.api.files.createSignedURLSetJob( ...
                    cloudDatasetId, ndiDocId, ...
                    'idNamespace', "ndi", ...
                    'fileSeries',  testCase.SeriesName);
            if ~okCreate
                row.jobState = "createRejected";
                row.jobDetail = extractMessage(createAnswer);
                narrative(end+1) = "createSignedURLSetJob was REJECTED " + ...
                    "(HTTP-level). Detail: " + row.jobDetail;
            else
                row.jobId = string(createAnswer.jobId);
                narrative(end+1) = "Job accepted; jobId=" + row.jobId + ...
                    ". Polling with waitForSignedURLSetJob (timeout " + ...
                    testCase.WaitTimeoutSeconds + "s).";
                [okReady, jobAnswer, waitResp, waitUrl] = ...
                    ndi.cloud.api.files.waitForSignedURLSetJob( ...
                        row.jobId, 'timeout', testCase.WaitTimeoutSeconds);
                if okReady
                    row.jobState = "ready";
                    row.jobDetail = "";
                    row.jobResultUrl = string(safeField(jobAnswer, ...
                        'resultUrl', ''));
                    narrative(end+1) = "Job reached state 'ready'. " + ...
                        "Fetching the result blob via " + ...
                        "ndi.cloud.api.files.getSignedURLSetResult to " + ...
                        "read fileCount (the poll answer does not carry it).";
                    if strlength(row.jobResultUrl) > 0 && ...
                            ~isempty(which('ndi.cloud.api.files.getSignedURLSetResult'))
                        try
                            [okResult, resultBlob, resultResp, ~] = ...
                                ndi.cloud.api.files.getSignedURLSetResult( ...
                                    row.jobResultUrl);
                            row.jobResultBlob = resultBlob;
                            row.jobResultResponse = resultResp;
                            if okResult
                                row.jobMapSize = double(safeField( ...
                                    resultBlob, 'fileCount', NaN));
                                narrative(end+1) = "Result blob parsed; " + ...
                                    "fileCount=" + row.jobMapSize + ".";
                            else
                                narrative(end+1) = "Result blob fetch/parse " + ...
                                    "FAILED (blob URL " + row.jobResultUrl + ").";
                            end
                        catch resErr
                            narrative(end+1) = "Result blob fetch RAISED: " + ...
                                string(resErr.identifier) + " -- " + ...
                                string(resErr.message);
                        end
                    else
                        narrative(end+1) = "No resultUrl on the poll " + ...
                            "answer (or getSignedURLSetResult not on path); " + ...
                            "leaving fileCount unset.";
                    end
                else
                    row.jobState = string(safeField(jobAnswer, 'state', 'failed'));
                    row.jobDetail = extractMessage(jobAnswer);
                    narrative(end+1) = "Job reached terminal state '" + ...
                        row.jobState + "'. Detail: " + row.jobDetail;
                    % Keep the poll response around so the failure JSON
                    % carries the server's own words verbatim.
                    row.jobResultResponse = waitResp;
                    row.jobResultUrl = string(waitUrl);
                end
            end
            row.jobElapsedSec = toc(tStart);
            row.jobOk = row.jobState == "ready";

            % --- Single-uid detail path
            narrative(end+1) = "Independently calling " + ...
                "ndi.cloud.api.files.getFileDetails(datasetId, " + ...
                "manifestUid=" + manifestUid + ").";
            [detailsOk, detailsAnswer, detailsResp, detailsUrl] = ...
                ndi.cloud.api.files.getFileDetails( ...
                    cloudDatasetId, manifestUid);
            row.detailsOk = detailsOk;
            row.detailsDetail = extractMessage(detailsAnswer);
            if detailsOk
                narrative(end+1) = "getFileDetails returned 200 for " + ...
                    "manifest uid " + manifestUid + ".";
            else
                narrative(end+1) = "getFileDetails FAILED for manifest " + ...
                    "uid " + manifestUid + ". Detail: " + row.detailsDetail;
            end

            % Stash the createSignedURLSetJob response as a fallback for
            % the JSON report when the job path is the interesting one.
            if ~row.jobOk
                row.jobResultResponse = createResp;
                row.jobResultUrl = string(createUrl);
                if isempty(row.jobResultBlob)
                    row.jobResultBlob = createAnswer;
                end
            end

            % Also stash the details response when it is the interesting
            % one -- keeps the row self-contained even if the caller
            % never reaches the JSON assembly path.
            if ~row.detailsOk && isempty(row.jobResultBlob)
                row.jobResultBlob = detailsAnswer;
                row.jobResultResponse = detailsResp;
                row.jobResultUrl = string(detailsUrl);
            end
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

function printFixtureProbeRow(row)
    % Single-line summary per level doc, kept for grep-ability in CI
    % logs. The JSON narrative report is what a human reads on a
    % failed assertion; this line is the sequence marker.
    detail = char(string(row.jobDetail));
    if numel(detail) > 60, detail = [detail(1:57) '...']; end
    fprintf(['[fixture-probe] doc=%s ndi=%s manifestUid=%s ' ...
        'jobState=%s elapsed=%.1fs mapSize=%s manifestFetchable=%d ' ...
        'detail="%s"\n'], ...
        char(row.cloudDocId), char(row.ndiDocId), char(row.manifestUid), ...
        char(row.jobState), row.jobElapsedSec, mapSizeAsText(row.jobMapSize), ...
        row.detailsOk, detail);
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
