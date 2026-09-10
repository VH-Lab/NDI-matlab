function [zarrPath, gt] = makeBlobFixture(parentDir, options)
% NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE - synthetic lightsheet OME-Zarr with real bytes
%
%   [ZARRPATH, GT] = NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE()
%   [ZARRPATH, GT] = NDI.TEST.LIGHTSHEET.MAKEBLOBFIXTURE(PARENTDIR, ...)
%
%   Writes a small OME-Zarr (NGFF v0.4) store on disk carrying a
%   deterministic 300x300x300 uint16 volume, downsampled into a
%   mean + max ladder that shares its raw level 0. Unlike the
%   metadata-only fixtures the unit tests use, this one writes REAL
%   chunk bytes -- uncompressed raw (Zarr v2 with `compressor: null`),
%   which every zarr reader accepts -- so an end-to-end run can
%   ingest it with ndi.fun.doc.lightsheet.fromOMEZarr, materialize
%   chunks onto lightsheetZarrLevel documents when that lands, and be
%   viewed by the napari client that reads them back.
%
%   The volume itself is three features at three spatial scales, so a
%   viewer can tell the pyramid levels apart at a glance. Positions
%   scale with Shape so the fixture is well-defined at any size:
%     - a wide Gaussian ball at Shape/2, sigma Shape/8, peak ~50k
%     - a medium Gaussian at (2/3, 1/3, 1/2)*Shape, sigma Shape/20,
%       peak ~30k
%     - a bright single-voxel spike of value 60k at Shape/6
%   The spike is much brighter than the local Gaussian background and
%   fills one voxel out of the whole volume, so max downsampling
%   holds it up while mean spreads it out over its block -- the
%   mean-vs-max choice is visible at every pyramid level.
%
%   PARENTDIR - char, directory to write into. Empty (default) puts
%               the store under a fresh tempname; the caller can pass
%               a stable path (e.g. under an S3-synced dir) to keep
%               the fixture between runs. The store lives at
%               fullfile(PARENTDIR, 'blob.ome.zarr').
%
%   Name-Value:
%     Shape (1,3) double   - [Z Y X], default [300 300 300]
%     NumLevels (1,1)      - number of pyramid levels (default 4)
%     ChunkShape (1,3)     - per-level Zarr chunk shape (default
%                            [64 64 64]; every level uses the same
%                            chunk shape, edge chunks pad with 0)
%     VoxelSize (1,3)      - level 0 voxel size (default [1 1 1] um).
%                            Every subsequent level scales by 2x.
%     Seed (1,1)           - reserved for future noisy fixtures; the
%                            default fixture is deterministic without
%                            it (default 42).
%
%   ZARRPATH - char, the absolute path to <PARENTDIR>/blob.ome.zarr
%   GT       - struct with fields:
%                shape       - level-0 [Z Y X]
%                chunkShape  - the chunk shape used
%                voxelSize   - level-0 voxel size
%                numLevels   - the ladder depth
%                levels      - 1xN struct(path, shape) for each level
%                              across mean and max
%                volumes     - struct with fields:
%                                level0 - the raw uint16 volume
%                                mean   - 1xN cell of mean downsamples
%                                max    - 1xN cell of max downsamples
%              Use GT to compare a reader's output against ground
%              truth. The full uint16 volume is a modest ~54 MB at
%              the default shape; do NOT return it unrequested.
%
%   Example -- end to end round-trip on the local filesystem:
%     [zp, gt] = ndi.test.lightsheet.makeBlobFixture(pwd);
%     S = ndi.session.dir('demo', tempname);
%     sub = ndi.document('subject', 'base.session_id', S.id(), ...
%             'subject.local_identifier', 'blob@vhlab');
%     S.database_add(sub);
%     [pyr, lds] = ndi.fun.doc.lightsheet.fromOMEZarr(S, zp, ...
%             'subjectID', sub.id());
%     ndi.gui.app.LightsheetZarrManager(S);
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.makePyramid,
%             ndr.format.omezarr.listPyramids

    arguments
        parentDir char = ''
        options.Shape (1,3) double {mustBePositive, mustBeInteger} = [300 300 300]
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

    % Build level 0 and the two reduction ladders.
    lvl0 = buildBlobVolume(options.Shape);
    meanLadder = cell(1, options.NumLevels);
    maxLadder  = cell(1, options.NumLevels);
    meanLadder{1} = lvl0;
    maxLadder{1}  = lvl0;
    for L = 2:options.NumLevels
        meanLadder{L} = downsampleBlockUint16(meanLadder{L-1}, 2, @meanReduce);
        maxLadder{L}  = downsampleBlockUint16(maxLadder{L-1},  2, @maxReduce);
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
    writeZarrLevel(fullfile(zarrPath, '0'), lvl0, options.ChunkShape);
    for L = 2:options.NumLevels
        writeZarrLevel(fullfile(zarrPath, 'mean', sprintf('%d', L-1)), ...
            meanLadder{L}, options.ChunkShape);
        writeZarrLevel(fullfile(zarrPath, 'max', sprintf('%d', L-1)), ...
            maxLadder{L}, options.ChunkShape);
    end

    % Write .zattrs.
    ax = {struct('name','z','type','space','unit','micrometer'), ...
          struct('name','y','type','space','unit','micrometer'), ...
          struct('name','x','type','space','unit','micrometer')};
    meanDatasets = cell(1, options.NumLevels);
    maxDatasets  = cell(1, options.NumLevels);
    for L = 1:options.NumLevels
        scale = options.VoxelSize * 2^(L-1);
        if L == 1
            path0 = '0';
        else
            pMean = sprintf('mean/%d', L-1);
            pMax  = sprintf('max/%d',  L-1);
        end
        if L == 1
            meanDatasets{L} = zarrDataset(path0, scale);
            maxDatasets{L}  = zarrDataset(path0, scale);
        else
            meanDatasets{L} = zarrDataset(pMean, scale);
            maxDatasets{L}  = zarrDataset(pMax,  scale);
        end
    end
    multiscales = { ...
        struct('name','mean','type','box', ...
               'axes', {ax}, 'datasets', {meanDatasets}), ...
        struct('name','max','type','max', ...
               'axes', {ax}, 'datasets', {maxDatasets}) };
    writeJSON(fullfile(zarrPath, '.zattrs'), ...
        struct('multiscales', {multiscales}));

    % Level manifest for the ground truth.
    levels = struct('path', {}, 'shape', {});
    levels(end+1) = struct('path', '0', 'shape', options.Shape);
    for L = 2:options.NumLevels
        s = size(meanLadder{L});
        levels(end+1) = struct('path', sprintf('mean/%d', L-1), 'shape', s); %#ok<AGROW>
        levels(end+1) = struct('path', sprintf('max/%d',  L-1), 'shape', s); %#ok<AGROW>
    end

    gt = struct( ...
        'shape',      options.Shape, ...
        'chunkShape', options.ChunkShape, ...
        'voxelSize',  options.VoxelSize, ...
        'numLevels',  options.NumLevels, ...
        'levels',     levels, ...
        'volumes',    struct('level0', lvl0, ...
                             'mean',   {meanLadder}, ...
                             'max',    {maxLadder}));
end

% =====================================================================

function vol = buildBlobVolume(shape)
% Deterministic 3D uint16 volume with three features at three scales.
% Everything is closed-form so the fixture is reproducible without
% touching random state.
    Z = shape(1); Y = shape(2); X = shape(3);
    [zz, yy, xx] = ndgrid(1:Z, 1:Y, 1:X);
    % Widths scale with the volume so the two Gaussians stay visible
    % at every Shape; sigma_wide ~ Shape/8, sigma_medium ~ Shape/20.
    sigmaWide   = mean(shape) / 8;
    sigmaMedium = mean(shape) / 20;
    % A wide ball centred in the volume.
    c1 = shape / 2;
    r1sq = (zz - c1(1)).^2 + (yy - c1(2)).^2 + (xx - c1(3)).^2;
    wide = 50000 * exp(-r1sq / (2 * sigmaWide^2));
    % A medium blob offset toward one corner.
    c2 = [shape(1)*2/3 shape(2)/3 shape(3)/2];
    r2sq = (zz - c2(1)).^2 + (yy - c2(2)).^2 + (xx - c2(3)).^2;
    medium = 30000 * exp(-r2sq / (2 * sigmaMedium^2));
    % One bright voxel: max keeps its value at every level, mean
    % spreads it across the block. Position scales with Shape so a
    % small test fixture puts the spike inside the volume too.
    spikePos = max(1, round(shape / 6));
    spike = zeros(shape);
    spike(spikePos(1), spikePos(2), spikePos(3)) = 60000;

    vol = uint16(min(65535, wide + medium + spike));
end

function out = downsampleBlockUint16(vol, factor, reducer)
% Reduce each factor x factor x factor block into one voxel using
% REDUCER (a function handle). Output shape is ceil(size / factor);
% odd trailing indices reuse the last available block ("edge pad" --
% simple, and mirrors what OME-Zarr writers commonly do).
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
% file per non-empty tile, keyed as z.y.x (default dimension_separator
% for Zarr v2).
    if ~isfolder(arrayDir), mkdir(arrayDir); end
    shape = size(vol);
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
    for cz = 0:nChunks(1)-1
        for cy = 0:nChunks(2)-1
            for cx = 0:nChunks(3)-1
                z0 = cz * chunkShape(1) + 1;
                y0 = cy * chunkShape(2) + 1;
                x0 = cx * chunkShape(3) + 1;
                z1 = min(z0 + chunkShape(1) - 1, shape(1));
                y1 = min(y0 + chunkShape(2) - 1, shape(2));
                x1 = min(x0 + chunkShape(3) - 1, shape(3));

                % Pad edge tiles with zeros so on-disk chunks are all
                % the same size (Zarr v2 requires this).
                chunk = zeros(chunkShape, 'uint16');
                chunk(1:(z1-z0+1), 1:(y1-y0+1), 1:(x1-x0+1)) = ...
                    vol(z0:z1, y0:y1, x0:x1);

                % Zarr expects C-order bytes. MATLAB is column-major,
                % so permute the axes into reversed order before
                % linearising (matches NDR's reader inverse).
                permuted = permute(chunk, ndims(chunk):-1:1);
                raw = typecast(permuted(:), 'uint8');

                key = sprintf('%d.%d.%d', cz, cy, cx);
                fid = fopen(fullfile(arrayDir, key), 'w');
                fwrite(fid, raw);
                fclose(fid);
            end
        end
    end
end

function d = zarrDataset(pathStr, scale)
    d = struct('path', pathStr, ...
        'coordinateTransformations', {{ ...
            struct('type', 'scale', 'scale', scale) }});
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
