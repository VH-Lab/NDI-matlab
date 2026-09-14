%LIGHTSHEET_TEST_BLOB_INGEST_AND_VIEW - end-to-end smoke test on the synthetic blob
%
%   Builds a small OME-Zarr fixture on disk (a couple of MB), ingests it
%   into a fresh NDI session with the blosc-zstd fast path, and launches
%   the napari viewer on the resulting pyramid. Use this to sanity-check
%   the ingest -> document -> viewer pipeline without touching the real
%   SmartSPIM data. Runs in under a minute on a laptop.
%
%   Edit CONFIG below if you want to keep the fixture / session between
%   runs, change the blob size, or point at a different napari launcher.
%
%   See also: ndi.test.lightsheet.makeBlobFixture,
%             ndi.test.lightsheet.ingestBlobFixture,
%             ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.view

% -------------------- CONFIG -----------------------------------------
% Leave scratch dirs empty to land under tempname (fresh every run).
sessionDir  = '';                              % e.g. '~/ndi-sessions/blob-demo'
zarrDir     = '';                              % e.g. '~/ndi-sessions/blob-demo/zarr'
subjectName = 'blob@vhlab';

% Blob size / shape. 128^3 uint16 across 2 channels ~= 16 MB raw; small
% enough for a fast smoke test, big enough that the pyramid has real
% levels to look at.
shape       = [128 128 128];
numChannels = 2;
chunkShape  = [32 32 32];
numLevels   = 3;

% Ingest options. blosc-zstd exercises the encodeChunk fast path; keep
% clevel modest for a smoke test.
codec       = 'blosc-zstd';
clevel      = 5;

% Napari launcher. Same wrapper the real-data script uses.
launcher    = '/usr/local/bin/napariViewLightsheet';

% Which reduction to open ('mean' or 'max'). The pyramid stores both;
% napariViewLightsheet needs one picked at launch.
reduction   = 'mean';
% ---------------------------------------------------------------------

fprintf('Building blob fixture and ingesting ...\n');
[S, P, info] = ndi.test.lightsheet.ingestBlobFixture( ...
    'sessionDir',  sessionDir, ...
    'zarrDir',     zarrDir, ...
    'subject',     subjectName, ...
    'Shape',       shape, ...
    'NumChannels', numChannels, ...
    'ChunkShape',  chunkShape, ...
    'NumLevels',   numLevels, ...
    'codec',       codec, ...
    'clevel',      clevel);

fprintf('Session:  %s\n', char(S.path()));
fprintf('Zarr:     %s\n', info.zarrPath);
fprintf('Pyramid:  %s\n', P.id());

fprintf('Launching napari viewer ...\n');
ndi.fun.doc.lightsheet.view(S, P.id(), ...
    'launcher',  launcher, ...
    'reduction', reduction);
