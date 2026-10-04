function [zarrPath, gt] = makeBlobFixture(parentDir, options)
% NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE - synthetic lightsheet OME-Zarr with real bytes
%
%   [ZARRPATH, GT] = NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE()
%   [ZARRPATH, GT] = NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE(PARENTDIR, ...)
%
%   Writes a small OME-Zarr (NGFF v0.4) store on disk carrying a
%   deterministic uint16 lightsheet volume, downsampled into a mean +
%   max ladder that shares its raw level 0. Unlike the metadata-only
%   fixtures the unit tests use, this one writes REAL chunk bytes --
%   uncompressed raw (Zarr v2 with `compressor: null`), which every
%   zarr reader accepts -- so an end-to-end run can ingest it with
%   ndi.fun.doc.lightsheet.fromOMEZarr, materialize chunks onto
%   lightsheetZarrLevel documents, and be viewed by the napari client
%   that reads them back.
%
%   The store is multi-channel by default: axes 'c,z,y,x' with 2
%   channels labelled 'Ch1' and 'Ch2', chunks 1 x (spatial) so a
%   reader can address one channel per chunk. Napari can be told to
%   colour each channel independently via the OMERO metadata this
%   writer emits (Ch1 -> green, Ch2 -> magenta by default, extending
%   to the palette the client keeps in sync with).
%
%   Every channel carries the same three features at three spatial
%   scales, with per-channel offsets so they read differently in each
%   colour:
%     - a centred RING pattern: Gaussian envelope (sigma Shape/8)
%       modulated by a radial cosine of wavelength Shape/5, so
%       brightness oscillates in concentric shells around Shape/2.
%       Same for every channel -- makes a natural registration mark.
%     - a medium Gaussian at (2/3, 1/3, 1/2)*Shape in Ch1 and the
%       mirrored (1/3, 2/3, 1/2)*Shape in Ch2, sigma Shape/20,
%       peak ~30k -- a compact companion that stays a small ball at
%       every level. Positions rotate around the volume when more
%       channels are requested.
%     - a bright single-voxel spike of value 60k, placed at Shape/6
%       (Ch1) and Shape*5/6 (Ch2). Positions distribute along the
%       diagonal when more channels are requested.
%   The ring envelope is 3*sigma ~ 3/8 of a side, so the feature
%   stays well inside the box. The spike is much brighter than the
%   local Gaussian background and fills one voxel out of the whole
%   volume, so max downsampling holds it up while mean spreads it
%   over its block -- the mean-vs-max choice is visible at every
%   pyramid level.
%
%   PARENTDIR - char, directory to write into. Empty (default) puts
%               the store under a fresh tempname; the caller can pass
%               a stable path (e.g. under an S3-synced dir) to keep
%               the fixture between runs. The store lives at
%               fullfile(PARENTDIR, 'blob.ome.zarr').
%
%   Name-Value:
%     Shape (1,3) double   - [Z Y X] spatial shape, default
%                            [300 300 300]. Channels are added on top
%                            (see NumChannels).
%     NumChannels (1,1)    - number of channels (default 2). Set 1 to
%                            fall back to the old 3-D 'z,y,x' layout.
%     ChannelNames         - cellstr / string array, one label per
%                            channel. Empty (default) produces 'Ch1',
%                            'Ch2', ... Written into the OMERO block
%                            of .zattrs so napari picks them up.
%     NumLevels (1,1)      - number of pyramid levels (default 4)
%     ChunkShape (1,3)     - spatial chunk shape (default [64 64 64]).
%                            For a multi-channel store the on-disk
%                            chunk shape is [1, ChunkShape(:)'], so
%                            one chunk holds one channel.
%     VoxelSize (1,3)      - level 0 voxel size (default [1 1 1] um).
%                            Every subsequent level scales by 2x on
%                            the spatial axes.
%     Seed (1,1)           - reserved for future noisy fixtures; the
%                            default fixture is deterministic without
%                            it (default 42).
%
%   ZARRPATH - char, the absolute path to <PARENTDIR>/blob.ome.zarr
%   GT       - struct with fields:
%                shape        - level-0 [Z Y X]
%                numChannels  - number of channels written
%                channelNames - cellstr of channel labels
%                chunkShape   - spatial chunk shape
%                voxelSize    - level-0 voxel size
%                numLevels    - the ladder depth
%                levels       - 1xN struct(path, shape) for each level
%                               across mean and max (shape is the
%                               on-disk shape, i.e. includes the c dim)
%                volumes      - struct with fields:
%                                 level0 - the raw uint16 volume,
%                                          shape (C, Z, Y, X) when
%                                          NumChannels > 1
%                                 mean   - 1xN cell of mean downsamples
%                                 max    - 1xN cell of max downsamples
%
%   Example -- end to end round-trip on the local filesystem:
%     [zp, gt] = ndi.test.lightsheet.makeBlobFixture(pwd);
%     S = ndi.session.dir('demo', tempname);
%     sub = ndi.document('subject', 'base.session_id', S.id(), ...
%             'subject.local_identifier', 'blob@vhlab');
%     S.database_add(sub);
%     [pyr, lds] = ndi.fun.doc.lightsheet.fromOMEZarr(S, zp, ...
%             'subjectID', sub.id());
%     ndi.fun.doc.lightsheet.view(S, pyr.id());
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.makePyramid,
%             ndr.format.omezarr.listPyramids

    arguments
        parentDir char = ''
        options.Shape (1,3) double {mustBePositive, mustBeInteger} = [300 300 300]
        options.NumChannels (1,1) double {mustBePositive, mustBeInteger} = 2
        options.ChannelNames = {}
        options.NumLevels (1,1) double {mustBePositive, mustBeInteger} = 4
        options.ChunkShape (1,3) double {mustBePositive, mustBeInteger} = [64 64 64]
        options.VoxelSize (1,3) double {mustBePositive} = [1 1 1]
        options.Seed (1,1) double = 42
    end

    if isempty(parentDir)
        parentDir = tempname;
        mkdir(parentDir);
    elseif ~isfolder(parentDir)
        mkdir(parentDir);
    end
    zarrPath = fullfile(parentDir, 'blob.ome.zarr');
    if isfolder(zarrPath)
        rmdir(zarrPath, 's');
    end
    mkdir(zarrPath);

    channelNames = resolveChannelNames(options.ChannelNames, options.NumChannels);

    hasChannels = options.NumChannels > 1 || ~isempty(options.ChannelNames);
    if hasChannels
        onDiskChunkShape = [1, options.ChunkShape];
    else
        onDiskChunkShape = options.ChunkShape;
    end

    % Build level 0 and the two reduction ladders. Multi-channel path
    % keeps channels as a leading axis; single-channel path stays 3-D
    % so it stays compatible with anything reading the old layout.
    lvl0 = buildBlobVolume(options.Shape, options.NumChannels, hasChannels);
    meanLadder = cell(1, options.NumLevels);
    maxLadder  = cell(1, options.NumLevels);
    meanLadder{1} = lvl0;
    maxLadder{1}  = lvl0;
    for L = 2:options.NumLevels
        meanLadder{L} = downsampleSpatial(meanLadder{L-1}, 2, @meanReduce, hasChannels);
        maxLadder{L}  = downsampleSpatial(maxLadder{L-1},  2, @maxReduce,  hasChannels);
    end

    % Every Zarr v2 group node needs a .zgroup marker, or readers
    % refuse the store with "No group found". The root is one, and so
    % are the mean/ and max/ subdirectories that hold the coarser
    % levels for each reduction. Written before the array levels so
    % the reader sees a valid group tree.
    writeZGroup(zarrPath);
    if options.NumLevels > 1
        mkdir(fullfile(zarrPath, 'mean'));
        mkdir(fullfile(zarrPath, 'max'));
        writeZGroup(fullfile(zarrPath, 'mean'));
        writeZGroup(fullfile(zarrPath, 'max'));
    end

    % Write level 0 (shared) and each reduction's coarser levels.
    writeZarrLevel(fullfile(zarrPath, '0'), lvl0, onDiskChunkShape);
    for L = 2:options.NumLevels
        writeZarrLevel(fullfile(zarrPath, 'mean', sprintf('%d', L-1)), ...
            meanLadder{L}, onDiskChunkShape);
        writeZarrLevel(fullfile(zarrPath, 'max', sprintf('%d', L-1)), ...
            maxLadder{L}, onDiskChunkShape);
    end

    % .zattrs axes. The spatial 2x downsampling only applies to
    % spatial axes; the channel axis carries no scale.
    if hasChannels
        ax = {struct('name','c','type','channel'), ...
              struct('name','z','type','space','unit','micrometer'), ...
              struct('name','y','type','space','unit','micrometer'), ...
              struct('name','x','type','space','unit','micrometer')};
        scaleForLevel = @(L) [1, options.VoxelSize * 2^(L-1)];
    else
        ax = {struct('name','z','type','space','unit','micrometer'), ...
              struct('name','y','type','space','unit','micrometer'), ...
              struct('name','x','type','space','unit','micrometer')};
        scaleForLevel = @(L) options.VoxelSize * 2^(L-1);
    end

    meanDatasets = cell(1, options.NumLevels);
    maxDatasets  = cell(1, options.NumLevels);
    for L = 1:options.NumLevels
        scale = scaleForLevel(L);
        if L == 1
            meanDatasets{L} = zarrDataset('0', scale);
            maxDatasets{L}  = zarrDataset('0', scale);
        else
            meanDatasets{L} = zarrDataset(sprintf('mean/%d', L-1), scale);
            maxDatasets{L}  = zarrDataset(sprintf('max/%d',  L-1), scale);
        end
    end
    multiscales = { ...
        struct('name','mean','type','box', ...
               'axes', {ax}, 'datasets', {meanDatasets}), ...
        struct('name','max','type','max', ...
               'axes', {ax}, 'datasets', {maxDatasets}) };

    zattrs = struct('multiscales', {multiscales});
    if hasChannels
        zattrs.omero = struct('channels', {buildOmeroChannels(channelNames)});
    end
    writeJSON(fullfile(zarrPath, '.zattrs'), zattrs);

    % Level manifest for the ground truth.
    levels = struct('path', {}, 'shape', {});
    levels(end+1) = struct('path', '0', 'shape', size(lvl0));
    for L = 2:options.NumLevels
        levels(end+1) = struct('path', sprintf('mean/%d', L-1), ...
            'shape', size(meanLadder{L})); %#ok<AGROW>
        levels(end+1) = struct('path', sprintf('max/%d',  L-1), ...
            'shape', size(maxLadder{L})); %#ok<AGROW>
    end

    gt = struct( ...
        'shape',        options.Shape, ...
        'numChannels',  options.NumChannels, ...
        'channelNames', {channelNames}, ...
        'chunkShape',   options.ChunkShape, ...
        'voxelSize',    options.VoxelSize, ...
        'numLevels',    options.NumLevels, ...
        'levels',       levels, ...
        'volumes',      struct('level0', lvl0, ...
                               'mean',   {meanLadder}, ...
                               'max',    {maxLadder}));
end

% =====================================================================

function names = resolveChannelNames(userNames, numChannels)
    if isempty(userNames)
        names = arrayfun(@(k) sprintf('Ch%d', k), 1:numChannels, ...
            'UniformOutput', false);
        return;
    end
    if isstring(userNames)
        userNames = cellstr(userNames);
    end
    if ~iscellstr(userNames)
        error('NDI:lightsheet:makeBlobFixture:badChannelNames', ...
            'ChannelNames must be a cellstr or string array.');
    end
    if numel(userNames) ~= numChannels
        error('NDI:lightsheet:makeBlobFixture:channelCountMismatch', ...
            'ChannelNames has %d entries but NumChannels is %d.', ...
            numel(userNames), numChannels);
    end
    names = reshape(userNames, 1, []);
end

function vol = buildBlobVolume(shape, numChannels, hasChannels)
% Deterministic uint16 volume with three features at three spatial
% scales. Multi-channel path returns (C, Z, Y, X) with per-channel
% variations in the medium blob and spike positions so channels read
% differently in each napari colour. Single-channel path returns
% (Z, Y, X) that matches the pre-channel fixture byte-for-byte.
    if ~hasChannels
        vol = oneChannelVolume(shape, 1, 1);
        return;
    end
    vol = zeros([numChannels, shape], 'uint16');
    for ch = 1:numChannels
        one = oneChannelVolume(shape, ch, numChannels);
        vol(ch, :, :, :) = reshape(one, [1, shape]);
    end
end

function vol = oneChannelVolume(shape, ch, numChannels)
    Z = shape(1); Y = shape(2); X = shape(3);
    [zz, yy, xx] = ndgrid(1:Z, 1:Y, 1:X);
    sigmaWide   = mean(shape) / 8;
    sigmaMedium = mean(shape) / 20;
    lambdaWide  = mean(shape) / 5;

    % Wide ring pattern -- IDENTICAL across channels, so a viewer sees
    % it as a coincidence mark.
    c1 = shape / 2;
    r1  = sqrt((zz - c1(1)).^2 + (yy - c1(2)).^2 + (xx - c1(3)).^2);
    envelope = exp(-r1.^2 / (2 * sigmaWide^2));
    rings    = 0.5 + 0.5 * cos(2 * pi * r1 / lambdaWide);
    wide = envelope .* (25000 + 25000 * rings);

    % Medium blob position rotates around the volume so each channel
    % sits somewhere different. Ch1 lands at the pre-channel default
    % (2/3, 1/3, 1/2) for backward-compat, Ch2 mirrors it, N>2 fills
    % in between.
    if numChannels <= 1
        alpha = 1;
    else
        alpha = 1 - (ch - 1) / (numChannels - 1);   % 1, ..., 0
    end
    c2 = [shape(1) * lerp(1/3, 2/3, alpha), ...
          shape(2) * lerp(2/3, 1/3, alpha), ...
          shape(3) / 2];
    r2sq = (zz - c2(1)).^2 + (yy - c2(2)).^2 + (xx - c2(3)).^2;
    medium = 30000 * exp(-r2sq / (2 * sigmaMedium^2));

    % Spike positions spaced along the volume diagonal: Ch1 at Shape/6
    % (matches the pre-channel default), Ch2 at Shape*5/6, N>2
    % interpolates between them so no two spikes overlap.
    if numChannels <= 1
        spikeFrac = 1/6;
    else
        spikeFrac = lerp(1/6, 5/6, (ch - 1) / (numChannels - 1));
    end
    spikePos = max(1, min(shape, round(shape * spikeFrac)));
    spike = zeros(shape);
    spike(spikePos(1), spikePos(2), spikePos(3)) = 60000;

    vol = uint16(min(65535, wide + medium + spike));
end

function y = lerp(a, b, t)
    y = a + (b - a) * t;
end

function out = downsampleSpatial(vol, factor, reducer, hasChannels)
% Downsample by FACTOR on spatial axes only. When HASCHANNELS is
% true, the leading axis is the channel dim and is preserved
% verbatim; otherwise we fall back to the pre-channel 3-D reducer.
    if ~hasChannels
        out = downsampleBlockUint16(vol, factor, reducer);
        return;
    end
    C = size(vol, 1);
    sz3 = size(vol);
    sz3 = sz3(2:end);
    outShape3 = ceil(sz3 / factor);
    out = zeros([C, outShape3], 'like', vol);
    for c = 1:C
        one = reshape(vol(c, :, :, :), sz3);
        down = downsampleBlockUint16(one, factor, reducer);
        out(c, :, :, :) = reshape(down, [1, size(down)]);
    end
end

function out = downsampleBlockUint16(vol, factor, reducer)
% Reduce each factor x factor x factor block into one voxel using
% REDUCER (a function handle). Output shape is ceil(size / factor);
% trailing edge blocks are smaller. Mirrors what OME-Zarr writers
% commonly do (bioformats2raw, make_zarr_levels.py).
    sz = size(vol);
    out_shape = ceil(sz / factor);
    out = zeros(out_shape, 'like', vol);
    for zi = 1:out_shape(1)
        z0 = (zi - 1) * factor + 1;
        z1 = min(z0 + factor - 1, sz(1));
        for yi = 1:out_shape(2)
            y0 = (yi - 1) * factor + 1;
            y1 = min(y0 + factor - 1, sz(2));
            for xi = 1:out_shape(3)
                x0 = (xi - 1) * factor + 1;
                x1 = min(x0 + factor - 1, sz(3));
                block = vol(z0:z1, y0:y1, x0:x1);
                out(zi, yi, xi) = reducer(block);
            end
        end
    end
end

function v = meanReduce(block)
    v = uint16(round(mean(double(block(:)))));
end

function v = maxReduce(block)
    v = max(block(:));
end

function writeZarrLevel(arrayDir, vol, chunkShape)
% Write one Zarr v2 array: a .zarray metadata file plus one raw chunk
% file per non-empty tile. Handles both 3-D (z,y,x) and 4-D (c,z,y,x)
% layouts; chunkShape must match the array's dimensionality.
    if ~isfolder(arrayDir), mkdir(arrayDir); end
    shape = size(vol);
    if numel(shape) ~= numel(chunkShape)
        error('NDI:lightsheet:makeBlobFixture:chunkArity', ...
            'chunkShape length %d does not match array ndims %d.', ...
            numel(chunkShape), numel(shape));
    end
    writeJSON(fullfile(arrayDir, '.zarray'), struct( ...
        'zarr_format', 2, ...
        'shape',       shape, ...
        'chunks',      chunkShape, ...
        'dtype',       '<u2', ...
        'compressor',  [], ...
        'fill_value',  0, ...
        'order',       'C', ...
        'filters',     [], ...
        'dimension_separator', '.'));

    nChunks = ceil(shape ./ chunkShape);
    subs = cell(1, numel(shape));
    writeChunks(arrayDir, vol, shape, chunkShape, nChunks, subs, [], 1);
end

function writeChunks(arrayDir, vol, shape, chunkShape, nChunks, subs, key, dim)
% Recursively walk the chunk grid across all dimensions, so the writer
% is agnostic to how many axes the array has.
    if dim > numel(shape)
        lo = zeros(1, numel(shape));
        hi = zeros(1, numel(shape));
        for a = 1:numel(shape)
            lo(a) = (key(a) - 1) * chunkShape(a) + 1;
            hi(a) = min(lo(a) + chunkShape(a) - 1, shape(a));
            subs{a} = lo(a):hi(a);
        end
        % Pad edge tiles with zeros so on-disk chunks are all the same
        % size (Zarr v2 requires this).
        chunk = zeros(chunkShape, 'like', vol);
        localSubs = arrayfun(@(a) 1:(hi(a) - lo(a) + 1), 1:numel(shape), ...
            'UniformOutput', false);
        chunk(localSubs{:}) = vol(subs{:});
        % Zarr expects C-order bytes. MATLAB is column-major, so
        % permute the axes into reversed order before linearising.
        permuted = permute(chunk, numel(shape):-1:1);
        raw = typecast(permuted(:), 'uint8');

        keyStr = strjoin(arrayfun(@(k) num2str(k - 1), key, ...
            'UniformOutput', false), '.');
        fid = fopen(fullfile(arrayDir, keyStr), 'w');
        fwrite(fid, raw);
        fclose(fid);
        return;
    end
    for c = 1:nChunks(dim)
        writeChunks(arrayDir, vol, shape, chunkShape, nChunks, subs, ...
            [key c], dim + 1);
    end
end

function d = zarrDataset(pathStr, scale)
    d = struct('path', pathStr, ...
        'coordinateTransformations', {{ ...
            struct('type', 'scale', 'scale', scale) }});
end

function channels = buildOmeroChannels(channelNames)
% OMERO 'channels' block that napari-ome-zarr reads to pick up
% per-channel names + display colours. Palette matches the client's
% default (green, magenta, ...). Windows are wide-open so napari's
% auto-contrast still runs.
    palette = {'00FF00', 'FF00FF', '00FFFF', 'FFFF00', ...
               '0080FF', 'FF8000', '808080'};
    n = numel(channelNames);
    channels = cell(1, n);
    for i = 1:n
        color = palette{mod(i - 1, numel(palette)) + 1};
        channels{i} = struct( ...
            'label', channelNames{i}, ...
            'color', color, ...
            'active', true, ...
            'window', struct('start', 0, 'end', 65535, ...
                             'min', 0, 'max', 65535));
    end
end

function writeZGroup(dir)
    writeJSON(fullfile(dir, '.zgroup'), struct('zarr_format', 2));
end

function writeJSON(filePath, s)
    % MATLAB's jsonencode emits empty [] for MATLAB `[]`, but Zarr v2
    % expects null for `compressor` and `filters` -- a `[]` there is
    % refused by the zarr-python 3 reader with "Expected None, a
    % numcodecs.abc.Codec, or a dict ... Got <class 'list'> instead."
    % Post-process the string so those two fields become JSON null.
    txt = jsonencode(s);
    txt = regexprep(txt, '"compressor":\[\]', '"compressor":null');
    txt = regexprep(txt, '"filters":\[\]',    '"filters":null');
    fid = fopen(filePath, 'w');
    fwrite(fid, txt);
    fclose(fid);
end
