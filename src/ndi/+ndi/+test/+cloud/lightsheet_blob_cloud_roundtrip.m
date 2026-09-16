function info = lightsheet_blob_cloud_roundtrip(options)
%NDI.TEST.CLOUD.LIGHTSHEET_BLOB_CLOUD_ROUNDTRIP - end-to-end cloud round trip for the blob fixture.
%
%   INFO = ndi.test.cloud.LIGHTSHEET_BLOB_CLOUD_ROUNDTRIP(...)
%
%   Manual test (not part of the automated suite). Set
%   NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD in the shell, then call
%   this from a MATLAB prompt to smoke-test the whole cloud pipeline.
%
%   Full pipeline in one call, staged entirely in the OS temp directory
%   so a run leaves no artefacts behind on the caller's project tree:
%
%     a) Fresh temp directories for the session, the dataset, and the
%        eventual download.
%     b) Build a small synthetic OME-Zarr fixture on disk via
%        ndi.test.lightsheet.makeBlobFixture.
%     c) Open an ndi.session on the session temp dir and ingest the
%        fixture into it via ndi.fun.doc.lightsheet.fromOMEZarr (writes
%        the lightsheetZarrPyramid + level documents).
%     d) Launch napariViewLightsheet on the just-built pyramid.
%     e) Create an ndi.dataset.dir on the dataset temp dir and attach the
%        session via add_ingested_session (a lightsheet-only session is
%        trivially ingested -- it declares no daq systems, so
%        isIngested() returns true without a further ingest() call).
%     f) ndi.cloud.uploadDataset with 'uploadAsNew', 'skipMetadataEditorMetadata',
%        and 'remoteDatasetName' set to "Blob Test Dataset <yyyymmddTHHMMSS> <rand 0-1000>".
%     g) ndi.cloud.downloadDataset the cloud dataset back into a THIRD
%        temp dir (SyncFiles defaults to false, which now works end-to-end
%        via DID-matlab#201's fetchSeriesManifestBytes contract).
%     h) List the sessions on the downloaded dataset and open the first
%        one.
%     i) Search that session for lightsheetZarrPyramid documents and
%        launch napariViewLightsheet on the first hit.
%
%   Name-Value Arguments:
%     Launcher - char, path to napariViewLightsheet. Default
%                '/usr/local/bin/napariViewLightsheet'.
%     Shape        - fixture spatial shape, default [128 128 128].
%     NumChannels  - default 2.
%     ChunkShape   - default [32 32 32].
%     NumLevels    - default 3.
%     Codec        - 'raw' or 'blosc-zstd'. Default 'blosc-zstd' (exercises
%                    the encodeChunk MEX fast path).
%     Clevel       - default 5.
%     Reduction    - 'mean' or 'max'. Default 'mean'.
%     ViewLocal    - launch napari on the local session too (step d).
%                    Default true. Set false to skip the local view and go
%                    straight to the cloud path.
%     ViewCloud    - launch napari on the downloaded session (step i).
%                    Default true. Both viewers block for a moment while
%                    they open; if you are running headless, set both to
%                    false.
%     WaitViewer   - forward to ndi.fun.doc.lightsheet.view. Default false
%                    (viewer backgrounds; MATLAB stays interactive).
%     Verbose      - print progress narration. Default true.
%
%   Returns a struct with everything the run produced:
%     .sessionDir           - the session's temp dir
%     .zarrPath             - the on-disk OME-Zarr store
%     .datasetDir           - the local dataset's temp dir
%     .downloadDir          - where downloadDataset copied the cloud state
%     .cloudDatasetId       - the id returned by uploadDataset
%     .cloudDatasetName     - the "Blob Test Dataset ..." label sent up
%     .localSession         - the freshly-built session (post-ingest)
%     .localPyramidId       - the pyramid document id from step (c)
%     .downloadedDataset    - the ndi.dataset.dir opened from downloadDir
%     .downloadedSession    - the first session on the downloaded dataset
%     .downloadedPyramidId  - the pyramid id we opened in step (i)
%
%   Set NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD before calling; the upload
%   and download steps will fail without them.
%
%   See also: ndi.test.lightsheet.makeBlobFixture,
%             ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.view,
%             ndi.cloud.uploadDataset,
%             ndi.cloud.downloadDataset

    arguments
        options.Launcher (1,:) char = '/usr/local/bin/napariViewLightsheet'
        options.Shape (1,3) double {mustBePositive, mustBeInteger} = [128 128 128]
        options.NumChannels (1,1) double {mustBePositive, mustBeInteger} = 2
        options.ChunkShape (1,3) double {mustBePositive, mustBeInteger} = [32 32 32]
        options.NumLevels (1,1) double {mustBePositive, mustBeInteger} = 3
        options.Codec (1,:) char {mustBeMember(options.Codec, {'raw','blosc-zstd'})} = 'blosc-zstd'
        options.Clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.Clevel,1), mustBeLessThanOrEqual(options.Clevel,9)} = 5
        options.Reduction (1,:) char {mustBeMember(options.Reduction, {'mean','max'})} = 'mean'
        options.ViewLocal (1,1) logical = true
        options.ViewCloud (1,1) logical = true
        options.WaitViewer (1,1) logical = false
        options.Verbose (1,1) logical = true
        options.DebugLogFile (1,:) char = fullfile(tempdir, 'NapariLightSheetDebugging.txt')
    end

    verbose = options.Verbose;
    function narrate(fmt, varargin)
        if verbose
            fprintf(['[roundtrip] ' fmt '\n'], varargin{:});
        end
    end

    % ndi.document.readblankdefinition keeps a persistent containers.Map
    % of parsed JSON per document type. A MATLAB session that had the
    % pre-fix lightsheetZarrLevel schema loaded (before chunk.bin became
    % a DID file_series) hands the stale definition to every later
    % construction, and addFileSeries('chunk.bin', ...) then refuses the
    % write with "chunk.bin is not declared as a file series". Nuke the
    % cache up front so a re-run of this demo cannot inherit a stale
    % session state.
    try
        ndi.document.readblankdefinition('--clear-cache');
    catch
        % Older NDI without the sentinel; safe to skip -- the definition
        % cache is a persistent inside the same file, so a `clear
        % functions` at the caller resolves the same way.
    end

    % --- (a) three fresh temp directories -------------------------------
    sessionDir  = mustMakeTempDir();
    datasetDir  = mustMakeTempDir();
    downloadDir = mustMakeTempDir();
    zarrParent  = mustMakeTempDir();
    narrate('Temp session   : %s', sessionDir);
    narrate('Temp dataset   : %s', datasetDir);
    narrate('Temp download  : %s', downloadDir);
    narrate('Temp zarr root : %s', zarrParent);

    % --- (b) build the blob fixture -------------------------------------
    narrate('Building blob fixture ([shape=%dx%dx%d, channels=%d, chunks=%dx%dx%d, levels=%d])...', ...
        options.Shape(1), options.Shape(2), options.Shape(3), options.NumChannels, ...
        options.ChunkShape(1), options.ChunkShape(2), options.ChunkShape(3), ...
        options.NumLevels);
    [zarrPath, ~] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
        'Shape',       options.Shape, ...
        'NumChannels', options.NumChannels, ...
        'ChunkShape',  options.ChunkShape, ...
        'NumLevels',   options.NumLevels);
    narrate('Zarr fixture   : %s', zarrPath);

    % --- (c) ingest the fixture into a fresh session --------------------
    narrate('Opening session on %s ...', sessionDir);
    S = ndi.session.dir('blob', sessionDir);

    subjectName = 'blob@vhlab';
    sub = ndi.document('subject', ...
        'base.session_id', S.id(), ...
        'subject.local_identifier', subjectName);
    S.database_add(sub);
    narrate('Added subject document "%s".', subjectName);

    narrate('Running fromOMEZarr (codec=%s, clevel=%d)...', options.Codec, options.Clevel);
    [P, ~, ~] = ndi.fun.doc.lightsheet.fromOMEZarr(S, zarrPath, ...
        'subjectID',         sub.id(), ...
        'materializeChunks', true, ...
        'codec',             options.Codec, ...
        'clevel',            options.Clevel);
    narrate('Built lightsheetZarrPyramid %s.', P.id());

    % Set up the shared debug log. Truncate on entry so a run's log is
    % just that run's log; both viewer subprocesses append their
    % NDI_LIGHTSHEET_DEBUG stderr into it with clear === LOCAL === /
    % === CLOUD === separators so the file reads as one narrative.
    initDebugLog(options.DebugLogFile);
    narrate('Napari debug log: %s', options.DebugLogFile);

    % --- (d) view the local pyramid -------------------------------------
    if options.ViewLocal
        narrate('Launching napari viewer on the LOCAL session ...');
        launchDebugView(S, P.id(), options.Launcher, options.Reduction, ...
            options.WaitViewer, options.DebugLogFile, 'LOCAL');
    else
        narrate('Skipping local view (ViewLocal=false).');
    end

    % --- (e) make a dataset, ingest the session -------------------------
    narrate('Building dataset at %s ...', datasetDir);
    D = ndi.dataset.dir('blob_dataset', datasetDir);
    if ~S.isIngested()
        error('lightsheet_blob_cloud_roundtrip:notIngested', ...
            ['Session %s is not fully ingested. A lightsheet-only session with no ' ...
             'daq systems should be trivially ingested; check whether an unexpected ' ...
             'daq system got attached during setup.'], S.id());
    end
    D = D.add_ingested_session(S);
    narrate('Added session %s to dataset (ingested).', S.id());

    % --- (f) upload to NDI Cloud ----------------------------------------
    cloudDatasetName = buildRemoteDatasetName();
    narrate('Uploading to NDI Cloud as remote name "%s" ...', cloudDatasetName);
    [ok, cloudDatasetId, msg] = ndi.cloud.uploadDataset(D, ...
        'uploadAsNew',                 true, ...
        'skipMetadataEditorMetadata',  true, ...
        'remoteDatasetName',           cloudDatasetName);
    if ~ok
        error('lightsheet_blob_cloud_roundtrip:uploadFailed', ...
            'ndi.cloud.uploadDataset failed: %s', msg);
    end
    narrate('Cloud dataset id: %s', cloudDatasetId);

    % --- (g) download it back into a fresh temp dir ---------------------
    narrate(['Downloading dataset back to %s (SyncFiles defaults false; the ' ...
        'DID-matlab#201 handler-fetch path installs manifests on demand) ...'], downloadDir);
    Ddown = ndi.cloud.downloadDataset(cloudDatasetId, downloadDir);
    narrate('Downloaded dataset opened at %s.', char(Ddown.path));

    % --- (h) list and open the first session ----------------------------
    [refs, ids] = Ddown.session_list();
    if isempty(ids)
        error('lightsheet_blob_cloud_roundtrip:noSessions', ...
            'Downloaded dataset carries no sessions; upload must have dropped the ingested session.');
    end
    narrate('Downloaded dataset lists %d session(s): %s', numel(ids), strjoin(refs, ', '));
    firstId = ids{1};
    narrate('Opening the first session (%s) ...', firstId);
    Sdown = Ddown.open_session(firstId);

    % --- (i) find the pyramid doc and open it ---------------------------
    q = ndi.query('','isa','lightsheetZarrPyramid');
    pyramidDocs = Sdown.database_search(q);
    if isempty(pyramidDocs)
        error('lightsheet_blob_cloud_roundtrip:noPyramid', ...
            'No lightsheetZarrPyramid documents on the downloaded session %s.', firstId);
    end
    downloadedPyramidId = pyramidDocs{1}.id();
    narrate('Found lightsheetZarrPyramid %s on the downloaded session.', downloadedPyramidId);

    if options.ViewCloud
        narrate('Launching napari viewer on the DOWNLOADED session ...');
        launchDebugView(Sdown, downloadedPyramidId, options.Launcher, ...
            options.Reduction, options.WaitViewer, options.DebugLogFile, 'CLOUD');
        % Give napari + the customFileHandler a moment to try the first
        % chunk fetches, then surface the tail so a black canvas comes
        % with its cause on the MATLAB console instead of just a
        % pointer to the log file. Only runs on non-blocking viewers
        % (WaitViewer=false) -- otherwise the launcher hasn't
        % returned yet and we'd read an empty log.
        if ~options.WaitViewer
            narrate('Sleeping 10 s so napari can attempt its first chunk fetches ...');
            pause(10);
            dumpLogTail(options.DebugLogFile, 100);
        end
    else
        narrate('Skipping cloud view (ViewCloud=false).');
    end

    info = struct( ...
        'sessionDir',           sessionDir, ...
        'zarrPath',             zarrPath, ...
        'datasetDir',           datasetDir, ...
        'downloadDir',          downloadDir, ...
        'cloudDatasetId',       cloudDatasetId, ...
        'cloudDatasetName',     cloudDatasetName, ...
        'localSession',         S, ...
        'localPyramidId',       P.id(), ...
        'downloadedDataset',    Ddown, ...
        'downloadedSession',    Sdown, ...
        'downloadedPyramidId',  downloadedPyramidId);
    narrate('Round trip complete.');
end

% =====================================================================

function d = mustMakeTempDir()
    d = tempname;
    if ~mkdir(d)
        error('lightsheet_blob_cloud_roundtrip:tempMkdirFailed', ...
            'Could not create temp directory at %s.', d);
    end
end

function name = buildRemoteDatasetName()
    % "Blob Test Dataset yyyymmddTHHMMSS RRR" where RRR is 0-1000 inclusive.
    % Compact timestamp avoids embedded spaces / colons the cloud UI is
    % happier with; still round-trips as a valid dataset label.
    dstr = datestr(datetime('now'), 'yyyymmddTHHMMSS'); %#ok<DATST>
    r = randi([0 1000]);
    name = sprintf('Blob Test Dataset %s %d', dstr, r);
end

function initDebugLog(logfile)
% Truncate the shared debug log so a rerun starts clean, then write a
% header row so the file is never zero bytes (Finder / editors show it
% cleanly). The log lands in an OS-writable dir by default (tempdir),
% but any caller-supplied path works as long as its parent exists.
    parent = fileparts(logfile);
    if ~isempty(parent) && ~isfolder(parent)
        mkdir(parent);
    end
    fid = fopen(logfile, 'w');
    if fid < 0
        error('lightsheet_blob_cloud_roundtrip:debugLogOpen', ...
            'Cannot open debug log %s for writing.', logfile);
    end
    fprintf(fid, '=== napariViewLightsheet debug log ===\n');
    fprintf(fid, 'started at %s\n\n', char(datetime('now')));
    fclose(fid);
end

function dumpLogTail(logfile, nlines)
% Read the last NLINES of LOGFILE and print them to the MATLAB console
% under a clear separator. Runs via `tail -n <n> <file>` in a
% subprocess so a huge log costs one syscall, not a MATLAB-side file
% read. Falls back silently if the log does not exist yet.
    if ~isfile(logfile)
        fprintf('[roundtrip] debug log %s not written yet; nothing to dump.\n', logfile);
        return;
    end
    quotedLog = ['''' strrep(logfile, '''', '''\''''') ''''];
    tailCmd = sprintf('tail -n %d %s', nlines, quotedLog);
    fprintf('\n===== last %d lines of %s =====\n', nlines, logfile);
    system(tailCmd);
    fprintf('===== end of debug log tail =====\n\n');
end

function launchDebugView(session, pyramidId, launcher, reduction, waitForIt, logfile, tag)
% Build the viewer command via ndi.fun.doc.lightsheet.viewCommand, then
% run it via system() with NDI_LIGHTSHEET_DEBUG=1 in the environment
% and stderr+stdout appended to logfile. Bypasses
% ndi.fun.doc.lightsheet.view because that helper does not expose a
% redirect hook -- we want the Python side's [lightsheet] chunk fetch
% failures written where the user can grep them after the run.
%
% TAG is a short label (e.g. 'LOCAL' / 'CLOUD') that lands as a
% separator in the log, so a single log file can hold both viewer
% invocations from one run.

    sessionPath = char(session.path);
    cmd = ndi.fun.doc.lightsheet.viewCommand(launcher, sessionPath, pyramidId, ...
        'reduction', reduction);

    % Append a header into the log identifying this invocation.
    fid = fopen(logfile, 'a');
    if fid >= 0
        fprintf(fid, '\n=== %s : %s ===\n', tag, char(datetime('now')));
        fprintf(fid, 'session : %s\n', sessionPath);
        fprintf(fid, 'pyramid : %s\n', pyramidId);
        fprintf(fid, 'command : %s\n\n', cmd);
        fclose(fid);
    end

    % Route Python-side debug prints (NDI_LIGHTSHEET_DEBUG=1 triggers
    % the [lightsheet] chunk-fetch failure lines) into the log file.
    % Redirect both stdout and stderr; the launcher wrapper's own
    % output lands in the same file so a chunk miss and its cause
    % (auth, HTTP status, missing manifest) sit adjacent.
    quotedLog = ['''' strrep(logfile, '''', '''\''''') ''''];
    if ~waitForIt && ~ispc
        fullCmd = ['NDI_LIGHTSHEET_DEBUG=1 ' cmd ' >>' quotedLog ' 2>&1 &'];
    else
        fullCmd = ['NDI_LIGHTSHEET_DEBUG=1 ' cmd ' >>' quotedLog ' 2>&1'];
    end
    fprintf('Executing: %s\n', fullCmd);
    status = system(fullCmd);
    if status ~= 0 && waitForIt
        warning('lightsheet_blob_cloud_roundtrip:viewerNonZeroExit', ...
            'Viewer returned status %d; see %s for stderr.', status, logfile);
    end
end

