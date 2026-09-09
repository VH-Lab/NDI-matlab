function chunks = chooseTileShape(shape, axesOrder, voxelSize, dtype, budgetBytes)
% NDI.FUN.DOC.LIGHTSHEET.CHOOSETILESHAPE - pick a chunk shape that hits a byte budget
%
%   CHUNKS = NDI.FUN.DOC.LIGHTSHEET.CHOOSETILESHAPE( ...
%       SHAPE, AXESORDER, VOXELSIZE, DTYPE, BUDGETBYTES)
%
%   Sizes an OME-Zarr chunk to land near BUDGETBYTES (uncompressed)
%   and to be ISOTROPIC IN WORLD SPACE: each spatial axis gets a
%   chunk length inversely proportional to its voxel size, so a
%   lightsheet volume with 1 um XY and 5 um Z produces pancake tiles
%   rather than voxel cubes.
%
%   SHAPE       - row vector, axis lengths in AXESORDER
%   AXESORDER   - char row like 'tczyx' (one letter per axis)
%   VOXELSIZE   - row vector, one per axis, same order (may include
%                 zeros or NaNs on t/c)
%   DTYPE       - char, NGFF-style ('uint16', 'float32', '<u2', ...)
%   BUDGETBYTES - target uncompressed bytes for one chunk. Default
%                 chosen by MAKEPYRAMID is 8*2^20 (8 MB), sized for a
%                 viewer over an ~200 MB/s link fetching ~4 tiles in
%                 parallel per pan gesture.
%
%   Non-spatial axes (t, c) get chunk = 1 regardless of budget. The
%   spatial axes share the budget from
%
%       s = (voxelsPerTile * prod(voxel_i))^(1/nSpatial)
%       chunk_i = round(s / voxel_i)
%
%   Each chunk is clamped to the level's shape, so a coarse level
%   whose spatial axes are already smaller than the ideal tile ends
%   up as one whole chunk. When any axis clamps, the leftover budget
%   is redistributed across the still-slack axes in one pass.
%
%   Example (uint16, 8 MB budget, isotropic 1 um):
%       chooseTileShape([1200 2000 2000], 'zyx', [1 1 1], 'uint16', ...
%           8*2^20)
%       -> [161 161 161]   % ~161^3 * 2 bytes ~= 8.3 MB
%
%   Example (uint16, 8 MB, anisotropic 1/1/5 um):
%       chooseTileShape([1200 2000 2000], 'zyx', [5 1 1], 'uint16', ...
%           8*2^20)
%       -> [55 275 275]    % ~55*275*275*2 ~= 7.9 MB, world-cube
%
%   See also: ndi.fun.doc.lightsheet.makePyramid

    arguments
        shape (1,:) double {mustBePositive, mustBeInteger}
        axesOrder (1,:) char
        voxelSize double
        dtype (1,:) char
        budgetBytes (1,1) double {mustBePositive} = 8 * 2^20
    end

    shape = double(shape);
    n = numel(shape);
    if numel(axesOrder) ~= n
        error('NDI:lightsheet:chooseTileShape:axesShapeMismatch', ...
            'axes_order length %d does not match shape length %d.', ...
            numel(axesOrder), n);
    end

    isSpatial = ~ismember(lower(axesOrder(1:n)), {'t','c'});
    isSpatial = reshape(isSpatial, 1, n);
    chunks = ones(1, n);
    if ~any(isSpatial)
        chunks = min(chunks, shape);
        return;
    end

    vs = reshape(double(voxelSize), 1, []);
    if numel(vs) ~= n || any(vs(isSpatial) <= 0) || any(~isfinite(vs(isSpatial)))
        % No usable voxel size on spatial axes -- fall back to
        % isotropic in voxel space (a raw n-th root of the budget).
        vs = ones(1, n);
    end

    bpv = bytesPerVoxel(dtype);
    voxelsPerTile = budgetBytes / bpv;
    if voxelsPerTile < 1
        voxelsPerTile = 1;
    end

    vsSpatial = vs(isSpatial);
    ns = numel(vsSpatial);
    s = (voxelsPerTile * prod(vsSpatial))^(1/ns);
    chunks(isSpatial) = max(1, round(s ./ vsSpatial));
    chunks = min(chunks, shape);

    % One redistribution pass: if any spatial axis clamped to its
    % shape, spread the leftover budget across the axes still below
    % their shape. Cheap and useful at coarser pyramid levels where
    % one dim collapses first.
    slack = isSpatial & (chunks < shape);
    stuck = isSpatial & ~slack;
    if any(slack) && any(stuck)
        used = prod(chunks(stuck));
        if used < 1, used = 1; end
        remaining = voxelsPerTile / used;
        vsSlack = vs(slack);
        s2 = (remaining * prod(vsSlack))^(1/numel(vsSlack));
        chunks(slack) = max(1, round(s2 ./ vsSlack));
        chunks = min(chunks, shape);
    end
end

function b = bytesPerVoxel(dtype)
    d = lower(strtrim(char(dtype)));
    if ~isempty(d) && any(d(1) == '<>|=')
        d = d(2:end);
    end
    switch d
        case {'uint8','int8','u1','i1','bool','?'}
            b = 1;
        case {'uint16','int16','u2','i2','float16','f2','half'}
            b = 2;
        case {'uint32','int32','u4','i4','float32','f4','single'}
            b = 4;
        case {'uint64','int64','u8','i8','float64','f8','double'}
            b = 8;
        case {'complex64','c8'}
            b = 8;
        case {'complex128','c16'}
            b = 16;
        otherwise
            % Unknown dtype: assume uint16 (2 bytes), the common
            % lightsheet case. Better than raising for a novel probe.
            b = 2;
    end
end
