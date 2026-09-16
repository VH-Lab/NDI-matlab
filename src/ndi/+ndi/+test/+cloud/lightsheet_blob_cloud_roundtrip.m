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
    end

    say = @(varargin) verboseNarrator(options.Verbose, varargin{:});

    % --- (a) three fresh temp directories -------------------------------
    sessionDir  = mustMakeTempDir();
    datasetDir  = mustMakeTempDir();
    downloadDir = mustMakeTempDir();
    zarrParent  = mustMakeTempDir();
    say('Temp session   : %s', sessionDir);
    say('Temp dataset   : %s', datasetDir);
    say('Temp download  : %s', downloadDir);
    say('Temp zarr root : %s', zarrParent);

    % --- (b) build the blob fixture -------------------------------------
    say('Building blob fixture ([shape=%dx%dx%d, channels=%d, chunks=%dx%dx%d, levels=%d])...', ...
        options.Shape(1), options.Shape(2), options.Shape(3), options.NumChannels, ...
        options.ChunkShape(1), options.ChunkShape(2), options.ChunkShape(3), ...
        options.NumLevels);
    [zarrPath, ~] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
        'Shape',       options.Shape, ...
        'NumChannels', options.NumChannels, ...
        'ChunkShape',  options.ChunkShape, ...
        'NumLevels',   options.NumLevels);
    say('Zarr fixture   : %s', zarrPath);

    % --- (c) ingest the fixture into a fresh session --------------------
    say('Opening session on %s ...', sessionDir);
    S = ndi.session.dir('blob', sessionDir);

    subjectName = 'blob@vhlab';
    sub = ndi.document('subject', ...
        'base.session_id', S.id(), ...
        'subject.local_identifier', subjectName);
    S.database_add(sub);
    say('Added subject document "%s".', subjectName);

    say('Running fromOMEZarr (codec=%s, clevel=%d)...', options.Codec, options.Clevel);
    [P, ~, ~] = ndi.fun.doc.lightsheet.fromOMEZarr(S, zarrPath, ...
        'subjectID',         sub.id(), ...
        'materializeChunks', true, ...
        'codec',             options.Codec, ...
        'clevel',            options.Clevel);
    say('Built lightsheetZarrPyramid %s.', P.id());

    % --- (d) view the local pyramid -------------------------------------
    if options.ViewLocal
        say('Launching napari viewer on the LOCAL session ...');
        ndi.fun.doc.lightsheet.view(S, P.id(), ...
            'launcher',  options.Launcher, ...
            'reduction', options.Reduction, ...
            'wait',      options.WaitViewer);
    else
        say('Skipping local view (ViewLocal=false).');
    end

    % --- (e) make a dataset, ingest the session -------------------------
    say('Building dataset at %s ...', datasetDir);
    D = ndi.dataset.dir('blob_dataset', datasetDir);
    if ~S.isIngested()
        error('lightsheet_blob_cloud_roundtrip:notIngested', ...
            ['Session %s is not fully ingested. A lightsheet-only session with no ' ...
             'daq systems should be trivially ingested; check whether an unexpected ' ...
             'daq system got attached during setup.'], S.id());
    end
    D = D.add_ingested_session(S);
    say('Added session %s to dataset (ingested).', S.id());

    % --- (f) upload to NDI Cloud ----------------------------------------
    cloudDatasetName = buildRemoteDatasetName();
    say('Uploading to NDI Cloud as remote name "%s" ...', cloudDatasetName);
    [ok, cloudDatasetId, msg] = ndi.cloud.uploadDataset(D, ...
        'uploadAsNew',                 true, ...
        'skipMetadataEditorMetadata',  true, ...
        'remoteDatasetName',           cloudDatasetName);
    if ~ok
        error('lightsheet_blob_cloud_roundtrip:uploadFailed', ...
            'ndi.cloud.uploadDataset failed: %s', msg);
    end
    say('Cloud dataset id: %s', cloudDatasetId);

    % --- (g) download it back into a fresh temp dir ---------------------
    say(['Downloading dataset back to %s (SyncFiles defaults false; the ' ...
        'DID-matlab#201 handler-fetch path installs manifests on demand) ...'], downloadDir);
    Ddown = ndi.cloud.downloadDataset(cloudDatasetId, downloadDir);
    say('Downloaded dataset opened at %s.', char(Ddown.path()));

    % --- (h) list and open the first session ----------------------------
    [refs, ids] = Ddown.session_list();
    if isempty(ids)
        error('lightsheet_blob_cloud_roundtrip:noSessions', ...
            'Downloaded dataset carries no sessions; upload must have dropped the ingested session.');
    end
    say('Downloaded dataset lists %d session(s): %s', numel(ids), strjoin(refs, ', '));
    firstId = ids{1};
    say('Opening the first session (%s) ...', firstId);
    Sdown = Ddown.open_session(firstId);

    % --- (i) find the pyramid doc and open it ---------------------------
    q = ndi.query('','isa','lightsheetZarrPyramid');
    pyramidDocs = Sdown.database_search(q);
    if isempty(pyramidDocs)
        error('lightsheet_blob_cloud_roundtrip:noPyramid', ...
            'No lightsheetZarrPyramid documents on the downloaded session %s.', firstId);
    end
    downloadedPyramidId = pyramidDocs{1}.id();
    say('Found lightsheetZarrPyramid %s on the downloaded session.', downloadedPyramidId);

    if options.ViewCloud
        say('Launching napari viewer on the DOWNLOADED session ...');
        ndi.fun.doc.lightsheet.view(Sdown, downloadedPyramidId, ...
            'launcher',  options.Launcher, ...
            'reduction', options.Reduction, ...
            'wait',      options.WaitViewer);
    else
        say('Skipping cloud view (ViewCloud=false).');
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
    say('Round trip complete.');
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

function verboseNarrator(verbose, fmt, varargin)
    if verbose
        fprintf(['[roundtrip] ' fmt '\n'], varargin{:});
    end
end
