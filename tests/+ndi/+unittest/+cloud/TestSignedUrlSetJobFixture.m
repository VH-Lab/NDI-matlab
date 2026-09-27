classdef TestSignedUrlSetJobFixture < matlab.unittest.TestCase
% TESTSIGNEDURLSETJOBFIXTURE - pin the async signed-URL-set-job bug
% against the existing tiny lightsheet fixture.
%
% Confirmed on 2026-09-27: the Python integration test raises the same
% BatchScopeUnreachable against the 15-file fixture
% (6ab84b549852a120dbcb22bc, User 1 prod) that it raises against the
% 121k-file production dataset -- so the failure is GLOBAL, not
% dataset-specific. getFileDetails(datasetId, manifestUid) returns
% 200 OK for the fixture's manifest uid in the same instant. Two
% server code paths disagree on whether the manifest is a file of
% the dataset.
%
% This test asserts the disagreement from the MATLAB side. For each
% lightsheetZarrLevel document in the fixture:
%   * createSignedURLSetJob(id_namespace='ndi', fileSeries='chunk.bin')
%     + waitForSignedURLSetJob to a terminal state.
%   * INDEPENDENTLY getFileDetails(datasetId, manifestUid).
% Assert consistency: either both succeed OR both fail. Any row where
% getFileDetails returns 200 but the async job says "not a file of
% this dataset" IS the reproducer, and fails the test with a message
% naming the datasetId / docId / manifestUid so the API bug report
% can cite it.
%
% Read-only against the fixture. No uploads, no cleanup.
%
% See VH-Lab/NDI-matlab#1010. The Python analog lives under
% NDI-python's tests/test_cloud_signed_url_set_job.py on the same
% branch.

    properties (Constant)
        FixtureDatasetId = "6ab84b549852a120dbcb22bc"
        LevelClassName   = "lightsheetZarrLevel"
        SeriesName       = "chunk.bin"
        % Cap the poll time per document. The fixture is tiny, so a
        % healthy run reaches terminal state in seconds; a run that
        % blows past this is diagnostic in its own right (job stuck vs
        % job failed) and the row records the "timeout" state.
        WaitTimeoutSeconds = 120
    end

    methods (TestClassSetup)
        function checkCredentials(testCase)
            username = getenv("NDI_CLOUD_USERNAME");
            password = getenv("NDI_CLOUD_PASSWORD");
            testCase.assumeNotEmpty(username, ...
                ['Missing NDI Cloud credentials ' ...
                 '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). ' ...
                 'Skipping TestSignedUrlSetJobFixture.']);
            testCase.assumeNotEmpty(password, ...
                ['Missing NDI Cloud credentials ' ...
                 '(NDI_CLOUD_USERNAME/NDI_CLOUD_PASSWORD). ' ...
                 'Skipping TestSignedUrlSetJobFixture.']);
        end
    end

    methods (Test)

        function testLevelDocsAgreeOnManifestReachability(testCase)
            % Enumerate the fixture's lightsheetZarrLevel documents,
            % probe each one's chunk.bin series through the two paths,
            % and fail on any disagreement.

            datasetId = testCase.FixtureDatasetId;

            [okList, docSummaries] = ndi.cloud.api.documents.listDatasetDocumentsAll(datasetId);
            testCase.assertTrue(okList, ...
                sprintf(['listDatasetDocumentsAll failed for fixture %s. ' ...
                    'The fixture must exist and be reachable for this ' ...
                    'test to run.'], char(datasetId)));

            % Filter to lightsheetZarrLevel docs. className comes back as
            % either "lightsheetZarrLevel" or char depending on the
            % server; compare as string.
            classNames = arrayfun(@(s) string(safeField(s, 'className', '')), ...
                docSummaries);
            levelIdx = find(classNames == testCase.LevelClassName);
            testCase.assertNotEmpty(levelIdx, ...
                sprintf(['Fixture %s has no %s documents. This test ' ...
                    'expects the tiny lightsheet fixture (15 files) to ' ...
                    'be present.'], char(datasetId), char(testCase.LevelClassName)));

            disagreements = string.empty;

            for k = 1:numel(levelIdx)
                summary = docSummaries(levelIdx(k));
                cloudDocId = string(safeField(summary, 'id',    ''));
                ndiDocId   = string(safeField(summary, 'ndiId', ''));

                % Full doc for its files.file_info -- that is where the
                % manifest uid for the chunk.bin series lives, in the
                % same shape ndi.cloud.sync.internal.updateFileInfoForRemoteFiles
                % reads server-side.
                [okDoc, docProps] = ndi.cloud.api.documents.getDocument( ...
                    datasetId, cloudDocId);
                if ~okDoc
                    fprintf(['[fixture-probe] doc=%s: getDocument ' ...
                        'failed; skipping.\n'], char(cloudDocId));
                    continue
                end
                manifestUid = extractManifestUidFromDoc(docProps, testCase.SeriesName);
                if strlength(manifestUid) == 0
                    fprintf(['[fixture-probe] doc=%s: no chunk.bin ' ...
                        'file_info entry; skipping (not a level with ' ...
                        'a materialized manifest).\n'], char(cloudDocId));
                    continue
                end

                % --- async job (the failing side, per Python)
                tStart = tic;
                [okCreate, createAnswer] = ndi.cloud.api.files.createSignedURLSetJob( ...
                    datasetId, ndiDocId, ...
                    'idNamespace', "ndi", ...
                    'fileSeries',  testCase.SeriesName);
                if ~okCreate
                    jobState = "createRejected";
                    jobDetail = extractMessage(createAnswer);
                    jobMapSize = NaN;
                else
                    jobId = string(createAnswer.jobId);
                    [okReady, jobAnswer] = ndi.cloud.api.files.waitForSignedURLSetJob( ...
                        jobId, 'timeout', testCase.WaitTimeoutSeconds);
                    if okReady
                        jobState = "ready";
                        jobDetail = "";
                        jobMapSize = double(safeField(jobAnswer, 'fileCount', NaN));
                    else
                        jobState = string(safeField(jobAnswer, 'state', 'failed'));
                        jobDetail = extractMessage(jobAnswer);
                        jobMapSize = NaN;
                    end
                end
                jobElapsedSec = toc(tStart);
                jobOk = jobState == "ready";

                % --- independent single-uid fetch (the succeeding side)
                [detailsOk, detailsAnswer] = ndi.cloud.api.files.getFileDetails( ...
                    datasetId, manifestUid);

                fprintf(['[fixture-probe] doc=%s ndi=%s manifestUid=%s ' ...
                    'jobState=%s elapsed=%.1fs mapSize=%s ' ...
                    'manifestFetchable=%d detail="%s"\n'], ...
                    char(cloudDocId), char(ndiDocId), char(manifestUid), ...
                    char(jobState), jobElapsedSec, mapSizeAsText(jobMapSize), ...
                    detailsOk, char(jobDetail));

                % Consistency assertion.
                if jobOk && detailsOk
                    % Healthy: both paths agree that the manifest is a
                    % file of the dataset. mapSize > 0 is a sanity
                    % check on the async blob.
                    testCase.verifyGreaterThan(jobMapSize, 0, ...
                        sprintf(['jobMapSize should be > 0 for a ' ...
                        'ready job on doc %s.'], char(cloudDocId)));
                elseif ~jobOk && ~detailsOk
                    % Consistent failure. Not the bug we are pinning.
                    fprintf(['[fixture-probe] doc=%s: consistent ' ...
                        'failure (both paths say no).\n'], char(cloudDocId));
                elseif ~jobOk && detailsOk
                    % THE BUG. Record for the summary assertion below.
                    disagreements(end+1) = sprintf( ...
                        'doc=%s ndi=%s manifestUid=%s: async job %s (%s) but getFileDetails returned 200', ...
                        char(cloudDocId), char(ndiDocId), char(manifestUid), ...
                        char(jobState), char(jobDetail)); %#ok<AGROW>
                else % jobOk && !detailsOk
                    disagreements(end+1) = sprintf( ...
                        'doc=%s: async job ready but getFileDetails failed for manifestUid=%s (%s)', ...
                        char(cloudDocId), char(manifestUid), ...
                        extractMessage(detailsAnswer)); %#ok<AGROW>
                end
            end

            if ~isempty(disagreements)
                testCase.verifyTrue(false, sprintf( ...
                    ['createSignedURLSetJob and getFileDetails disagree ' ...
                    'on %d document(s) of fixture %s. This is the ' ...
                    'server-side bug tracked in NDI-matlab#1010: ' ...
                    'the async job says the manifest is not a file ' ...
                    'of the dataset while the single-uid fetch ' ...
                    'returns 200 for the same uid.\n%s'], ...
                    numel(disagreements), char(datasetId), ...
                    strjoin("  " + disagreements, newline)));
            end
        end

    end
end

function uid = extractManifestUidFromDoc(docProps, seriesName)
    % The manifest uid for a series named NAME sits in
    % document.files.file_info as the locations(1).uid of the entry
    % whose name is NAME. Same shape ndi.cloud.sync.internal.
    % updateFileInfoForRemoteFiles reads on the download side.
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
