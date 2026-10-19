function [pyramidDoc, levelDocs, info] = fromSPIM(session, rootDir, options)
% NDI.FUN.DOC.LIGHTSHEET.FROMSPIM - build a lightsheet pyramid straight from a SmartSPIM acquisition
%
%   [PYRAMIDDOC, LEVELDOCS, INFO] = ndi.fun.doc.lightsheet.FROMSPIM(SESSION, ROOTDIR, ...
%       'subjectID', SUBJECTID)
%
%   Reads the stitched, harmonized volume in ROOTDIR/All_Channels -- the
%   output of SmartSPIM AutoStitch, which ndr.format.smartspim reads in
%   preference to the per-tile Ex_* folders -- and writes the same
%   documents ndi.fun.doc.lightsheet.fromOMEZarr writes for an OME-Zarr
%   store: one lightsheetZarrPyramid and its lightsheetZarrLevel
%   children, with chunk bytes materialized. No intermediate OME-Zarr
%   (spim2zarr) step is needed.
%
%   THE LADDER IS BUILT HERE. An OME-Zarr store arrives with its coarser
%   levels already computed; a SmartSPIM folder has only full resolution.
%   Level 0 (all channels, axes t,c,z,y,x) is read from the All_Channels
%   slices. Each coarser level is then made by block-reducing the level
%   just written -- once with 'mean' and once with 'max', the two
%   ladders spim2zarr makes -- so no level re-reads full resolution and
%   memory stays near prefetchBytes. Level 0 is shared by both ladders
%   (reduction_function 'none'), exactly as fromOMEZarr dedupes it.
%
%   A spatial axis is halved at a level only while its voxel size is at
%   most 1.5x the finest voxel size among the axes still longer than one
%   voxel, so an anisotropic stack
%   (coarse z) is first evened out in x and y. Levels are added until
%   every spatial axis is at most minLevelSize voxels (or maxLevels).
%
%   All the chunking, encoding, parallel compression and file-series
%   installation is ndi.fun.doc.lightsheet.makePyramid's, via its
%   levelSources option; see makePyramid for numWorkers, prefetchBytes,
%   asyncPrefetch and debugLog.
%
%   Optional Name-Value Arguments:
%   subjectID       - REQUIRED. id of the subject the volume depends on.
%   elementID       - id of the imaging element (may be empty).
%   label           - label for the pyramid. Default: ROOTDIR's folder name.
%   channels        - channel directory names (e.g. "Ex_561_Em_561F_Ch2")
%                     to include, in the order wanted. Default: all, in
%                     the All_Channels ch<k> order.
%   reductions      - ladders to build: any of "mean", "max". Default both.
%   voxelSizeUm     - [z y x] voxel size in micrometers. Default: from the
%                     acquisition's metadata.json; required if it has none.
%   minLevelSize    - stop adding levels once every spatial axis is at
%                     most this many voxels. Default 512.
%   maxLevels       - most levels per ladder, level 0 included. Default 10.
%   tileBudgetBytes, chunks, codec, clevel, progressFcn, numWorkers,
%   prefetchBytes, asyncPrefetch, debugLog, pipelineVersion, sourceFileID
%                   - as in ndi.fun.doc.lightsheet.fromOMEZarr, except
%                     that codec defaults to 'blosc-zstd': chunks are
%                     always materialized here.
%
%   INFO returns a struct with fields:
%     rootDir       - ROOTDIR
%     channelNames  - cellstr, the channels on the c axis, in order
%     levels        - struct array (path, reduction, shape, voxelSize, factor)
%     sourceFileID  - id of the fileReference document for ROOTDIR
%     sharedLevel0  - logical, true when level 0 is shared by the ladders
%
%   Example:
%     S = ndi.session.dir('/path/to/session');
%     [P, L] = ndi.fun.doc.lightsheet.fromSPIM(S, '/data/ferret42_SmartSPIM', ...
%         'subjectID', subj.id(), 'numWorkers', 8);
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.makePyramid,
%             ndi.fun.doc.lightsheet.reduceBlocks,
%             ndr.format.smartspim.readAllChannelsInfo,
%             ndr.format.smartspim.hasAllChannels

    arguments
        session (1,1)
        rootDir (1,:) char
        options.subjectID char = ''
        options.elementID char = ''
        options.label char = ''
        options.channels = {}
        options.reductions = {'mean', 'max'}
        options.voxelSizeUm double = []
        options.minLevelSize (1,1) double {mustBePositive} = 512
        options.maxLevels (1,1) double {mustBeInteger, mustBePositive} = 10
        options.pipelineVersion char = ''
        options.sourceFileID char = ''
        options.tileBudgetBytes (1,1) double {mustBePositive} = 32 * 2^20
        options.chunks double = []
        options.codec (1,:) char {mustBeMember(options.codec, {'raw','blosc-zstd'})} = 'blosc-zstd'
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 9)} = 5
        options.progressFcn = 'default'
        options.numWorkers (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.numWorkers, -1)} = -1
        options.prefetchBytes (1,1) double {mustBePositive} = 512 * 2^20
        options.asyncPrefetch (1,1) logical = true
        options.debugLog (1,:) char = ''
    end

    if isempty(strtrim(options.subjectID))
        error('NDI:lightsheet:fromSPIM:noSubject', ...
            'A lightsheetZarrPyramid depends_on a subject; pass ''subjectID''.');
    end
    if ~isfolder(rootDir)
        error('NDI:lightsheet:fromSPIM:noSuchFolder', ...
            'SmartSPIM folder not found at %s.', rootDir);
    end
    if ~ndr.format.smartspim.hasAllChannels(rootDir)
        error('NDI:lightsheet:fromSPIM:noAllChannels', ...
            ['%s has no usable All_Channels folder (SmartSPIM AutoStitch ' ...
             'output, with slices for every channel). Run AutoStitch, or ' ...
             'convert the per-tile data with spim2zarr and use fromOMEZarr.'], ...
            rootDir);
    end
    reductions = cellstr(options.reductions);
    reductions = reductions(:);
    if isempty(reductions) || ~all(ismember(reductions, {'mean', 'max'}))
        error('NDI:lightsheet:fromSPIM:badReductions', ...
            'reductions must be a non-empty subset of {"mean", "max"}.');
    end

    % ---- what is on disk ---------------------------------------------
    spim = ndr.format.smartspim.readAllChannelsInfo(rootDir);
    [chans, channelNames] = pickChannels(spim, options.channels);
    nSlices = arrayfun(@(c) c.numSlices, chans);
    nz = min(nSlices);
    if any(nSlices ~= nz)
        warning('NDI:lightsheet:fromSPIM:unevenSlices', ...
            ['Channels have different slice counts (%s); using the first ' ...
             '%d slices of each.'], mat2str(nSlices), nz);
    end
    slicePaths = arrayfun(@(c) c.slicePaths(1:nz), chans, 'UniformOutput', false);
    slicePaths = slicePaths(:);

    voxel = options.voxelSizeUm;
    if isempty(voxel)
        voxel = spim.voxelSizeUm;
    end
    if numel(voxel) ~= 3 || any(~isfinite(voxel)) || any(voxel <= 0)
        error('NDI:lightsheet:fromSPIM:noVoxelSize', ...
            ['No [z y x] voxel size: the acquisition metadata.json does ' ...
             'not give one. Pass ''voxelSizeUm'', [z y x].']);
    end
    dtype = char(spim.dtype);
    shape0 = [1, numel(chans), nz, spim.height, spim.width];
    scale0 = [1, 1, double(voxel(:).')];

    % ---- the ladder ----------------------------------------------------
    steps = planLadder(shape0, scale0, options.minLevelSize, options.maxLevels);

    axesDesc = struct('name', {'t', 'c', 'z', 'y', 'x'}, ...
        'type', {'time', 'channel', 'space', 'space', 'space'}, ...
        'unit', {'', '', 'micrometer', 'micrometer', 'micrometer'});
    level0 = levelEntry('0', shape0, scale0, dtype);

    levelSources = containers.Map();
    levelSources('0') = struct('kind', 'smartspim', ...
        'slicePaths', {slicePaths}, 'dtype', dtype);

    pyramids = repmat(struct('name', '', 'type', '', 'axes', axesDesc, ...
        'levels', level0), numel(reductions), 1);
    nSteps = numel(steps);
    levelInfo = repmat(struct('path', '0', 'reduction', 'none', ...
        'shape', shape0, 'voxelSize', scale0, 'factor', ones(1, 5)), ...
        1, 1 + numel(reductions) * nSteps);
    for r = 1:numel(reductions)
        red = reductions{r};
        levels = repmat(level0, 1, 1 + nSteps);
        prevPath = '0';
        for k = 1:nSteps
            levelPath = sprintf('%s/%d', red, k);
            levels(1 + k) = levelEntry(levelPath, steps(k).shape, steps(k).scale, dtype);
            levelSources(levelPath) = struct('kind', 'reduce', 'fromPath', prevPath, ...
                'factor', steps(k).factor, 'reduction', red);
            levelInfo(1 + (r - 1) * nSteps + k) = struct('path', levelPath, ...
                'reduction', red, 'shape', steps(k).shape, ...
                'voxelSize', steps(k).scale, 'factor', steps(k).factor);
            prevPath = levelPath;
        end
        pyramids(r).name = red;
        pyramids(r).type = red;
        pyramids(r).levels = levels;
    end

    % ---- source description + progress ---------------------------------
    sourceFileID = options.sourceFileID;
    if isempty(sourceFileID)
        srcDoc = ndi.fun.doc.lightsheet.makeSourceFile(session, rootDir);
        session.database_add(srcDoc);
        sourceFileID = srcDoc.id();
    end
    label = options.label;
    if isempty(label)
        [~, label] = fileparts(strip(rootDir, 'right', filesep));
    end
    progressFcn = resolveProgressCallback(options.progressFcn, label);

    [pyramidDoc, levelDocs, sharedLevel0] = ndi.fun.doc.lightsheet.makePyramid( ...
        session, pyramids, reductions, ...
        'subjectID', options.subjectID, ...
        'elementID', options.elementID, ...
        'sourceFileID', sourceFileID, ...
        'pipelineVersion', options.pipelineVersion, ...
        'label', label, ...
        'channelNames', strjoin(channelNames, ','), ...
        'tileBudgetBytes', options.tileBudgetBytes, ...
        'chunks', options.chunks, ...
        'materializeChunks', true, ...
        'levelSources', levelSources, ...
        'codec', options.codec, ...
        'clevel', options.clevel, ...
        'progressFcn', progressFcn, ...
        'numWorkers', options.numWorkers, ...
        'prefetchBytes', options.prefetchBytes, ...
        'asyncPrefetch', options.asyncPrefetch, ...
        'debugLog', options.debugLog);

    info = struct( ...
        'rootDir', char(rootDir), ...
        'channelNames', {channelNames}, ...
        'levels', levelInfo, ...
        'sourceFileID', sourceFileID, ...
        'sharedLevel0', sharedLevel0);
end

function steps = planLadder(shape0, scale0, minLevelSize, maxLevels)
% PLANLADDER - the coarser levels below level 0: shape, voxel size, factor
%
%   Axes t,c,z,y,x; only z, y, x are reduced. At each step a spatial
%   axis is halved if it is longer than 1 and its voxel size is at most
%   1.5x the finest spatial voxel size (so coarse-z stacks catch up in
%   x, y first; "finest" counts only axes longer than 1). Stops when
%   every spatial axis is <= minLevelSize, when
%   no axis can be halved, or at maxLevels levels (level 0 included).
    arguments
        shape0 {mustBeNumeric}
        scale0 {mustBeNumeric}
        minLevelSize (1,1) double
        maxLevels (1,1) double
    end
    steps = struct('shape', {}, 'scale', {}, 'factor', {});
    shape = shape0;
    scale = scale0;
    while numel(steps) + 1 < maxLevels && max(shape(3:5)) > minLevelSize
        f = ones(1, 5);
        % Finest among the axes that can still be halved: an axis
        % already down to one voxel must not hold the others back.
        live = find(shape(3:5) > 1) + 2;
        if isempty(live)
            break;
        end
        finest = min(scale(live));
        for a = 3:5
            if shape(a) > 1 && scale(a) <= 1.5 * finest
                f(a) = 2;
            end
        end
        if all(f == 1)
            break;
        end
        shape = ceil(shape ./ f);
        scale = scale .* f;
        steps(end+1) = struct('shape', shape, 'scale', scale, 'factor', f); %#ok<AGROW>
    end
end

function L = levelEntry(path, shape, scale, dtype)
% One level in the shape ndr.format.omezarr.listPyramids reports.
    arguments
        path {mustBeText}
        shape {mustBeNumeric}
        scale {mustBeNumeric}
        dtype {mustBeText}
    end
    L = struct('path', path, 'shape', double(shape), 'chunks', [], ...
        'dtype', dtype, 'scale', double(scale), 'translation', zeros(1, 5));
end

function [chans, names] = pickChannels(spim, wanted)
% The channels to put on the c axis, in order.
    arguments
        spim % the struct ndr.format.smartspim.readAllChannelsInfo returns
        wanted % channel names (text or a cell array of text), or empty for all
    end
    chans = spim.channels(:);
    if isempty(wanted)
        names = {chans.name};
        return;
    end
    wanted = cellstr(wanted);
    have = {chans.name};
    idx = zeros(1, numel(wanted));
    for i = 1:numel(wanted)
        j = find(strcmp(have, wanted{i}), 1);
        if isempty(j)
            error('NDI:lightsheet:fromSPIM:noSuchChannel', ...
                'No channel %s in All_Channels. Available: %s.', ...
                wanted{i}, strjoin(have, ', '));
        end
        idx(i) = j;
    end
    chans = chans(idx);
    names = {chans.name};
end

function fcn = resolveProgressCallback(spec, label)
% 'default' -> an NDI ProgressBarWindow; a function handle -> as is;
% [] -> silent. Same contract as fromOMEZarr's; a bar that cannot draw
% itself never stops the ingest.
    arguments
        spec % 'default'/'auto', a function handle, or []
        label {mustBeText}
    end
    if isa(spec, 'function_handle')
        fcn = spec;
        return;
    end
    fcn = [];
    if isempty(spec)
        return;
    end
    if ~((ischar(spec) || (isstring(spec) && isscalar(spec))) ...
            && any(strcmpi(char(spec), {'default', 'auto'})))
        error('NDI:lightsheet:fromSPIM:badProgressFcn', ...
            'progressFcn must be ''default'', a function handle, or [].');
    end
    try
        tag = sprintf('lightsheet-spim-%s', char(did.ido.unique_id()));
        pbw = ndi.gui.component.ProgressBarWindow('NDI lightsheet ingest');
        pbw.addBar('Label', sprintf('Building pyramid: %s', label), ...
            'Tag', tag, 'Auto', true);
        fcn = @(frac, txt) pbw.updateBar(tag, min(1, max(0, frac)));
    catch
        fcn = [];
    end
end
