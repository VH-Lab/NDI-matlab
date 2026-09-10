function [session, pyramidDoc, info] = ingestBlobFixture(options)
% NDI.TEST.LIGHTSHEET.INGESTBLOBFIXTURE - one-line end-to-end blob demo
%
%   [SESSION, PYRAMIDDOC, INFO] = NDI.TEST.LIGHTSHEET.INGESTBLOBFIXTURE()
%   [SESSION, PYRAMIDDOC, INFO] = NDI.TEST.LIGHTSHEET.INGESTBLOBFIXTURE( ...
%       'sessionDir', '/path/to/session', 'zarrDir', '/path/to/store', ...)
%
%   Writes the 300x300x300 blob fixture (see makeBlobFixture) into a
%   session, calls fromOMEZarr to build the pyramid and level
%   documents, and returns the ready-to-view result. Meant for a
%   copy-paste smoke test of the whole ingest -> document -> viewer
%   pathway.
%
%   Name-Value:
%     sessionDir - char, where to build the session. Empty (default)
%                  puts it under a fresh tempname.
%     zarrDir    - char, parent directory for the OME-Zarr store.
%                  Empty (default) uses tempname; the store lives at
%                  fullfile(zarrDir, 'blob.ome.zarr'). Pass a stable
%                  path here to keep the fixture between runs (e.g.
%                  for repeated cloud-upload experiments).
%     subject    - char, local_identifier for the subject document
%                  created inside the session (default 'blob@vhlab').
%     Shape      - passed through to makeBlobFixture (default
%                  [300 300 300]).
%     ChunkShape - passed through to makeBlobFixture (default
%                  [64 64 64]).
%     NumLevels  - passed through to makeBlobFixture (default 4).
%     VoxelSize  - passed through to makeBlobFixture (default
%                  [1 1 1]).
%
%   Returns:
%     SESSION    - ndi.session.dir opened at sessionDir.
%     PYRAMIDDOC - the lightsheetZarrPyramid parent document.
%     INFO       - the struct fromOMEZarr's third output would return
%                  (zarrPath, pyramids, reductions, sourceFileID,
%                  sharedLevel0), plus:
%                    subjectID    - the subject document's id
%                    fixture      - the ground-truth struct that
%                                   makeBlobFixture returned
%
%   Example:
%     [S, P] = ndi.test.lightsheet.ingestBlobFixture();
%     ndi.gui.app.LightsheetZarrManager(S);
%
%   See also: ndi.test.lightsheet.makeBlobFixture,
%             ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.gui.app.LightsheetZarrManager

    arguments
        options.sessionDir char = ''
        options.zarrDir char = ''
        options.subject (1,:) char = 'blob@vhlab'
        options.Shape (1,3) double {mustBePositive, mustBeInteger} = [300 300 300]
        options.ChunkShape (1,3) double {mustBePositive, mustBeInteger} = [64 64 64]
        options.NumLevels (1,1) double {mustBePositive, mustBeInteger} = 4
        options.VoxelSize (1,3) double {mustBePositive} = [1 1 1]
        options.materializeChunks (1,1) logical = true
    end

    sessionDir = options.sessionDir;
    if isempty(sessionDir)
        sessionDir = tempname;
    end
    if ~isfolder(sessionDir)
        mkdir(sessionDir);
    end

    zarrParent = options.zarrDir;
    if isempty(zarrParent)
        zarrParent = tempname;
        mkdir(zarrParent);
    elseif ~isfolder(zarrParent)
        mkdir(zarrParent);
    end

    [zarrPath, gt] = ndi.test.lightsheet.makeBlobFixture(zarrParent, ...
        'Shape',      options.Shape, ...
        'NumLevels',  options.NumLevels, ...
        'ChunkShape', options.ChunkShape, ...
        'VoxelSize',  options.VoxelSize);

    session = ndi.session.dir('blob', sessionDir);
    sub = ndi.document('subject', 'base.session_id', session.id(), ...
        'subject.local_identifier', options.subject);
    session.database_add(sub);

    [pyramidDoc, ~, info] = ndi.fun.doc.lightsheet.fromOMEZarr( ...
        session, zarrPath, ...
        'subjectID', sub.id(), ...
        'materializeChunks', options.materializeChunks);

    info.subjectID = sub.id();
    info.fixture   = gt;
end
