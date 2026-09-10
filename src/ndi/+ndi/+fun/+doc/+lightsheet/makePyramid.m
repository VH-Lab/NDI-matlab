function [pyramidDoc, levelDocs, sharedLevel0] = makePyramid(session, pyramids, perEntryReduction, options)
% NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID - write one pyramid parent and its deduped level children
%
%   [PYRAMIDDOC, LEVELDOCS, SHAREDLEVEL0] = ...
%       NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID(SESSION, PYRAMIDS, ...
%           PEREDUCTION, options)
%
%   Given the multiscales entries reported by
%   NDR.FORMAT.OMEZARR.LISTPYRAMIDS and a per-entry reduction label,
%   writes ONE lightsheetZarrPyramid parent (the source volume) and
%   one lightsheetZarrLevel per UNIQUE array path across all entries.
%
%   Dedupe rule: two entries whose levels(k).path is the same NGFF
%   string refer to the same underlying array. Typical case: level 0
%   shared across mean and max pyramids. One level document is
%   written and its reduction_function is 'none'.
%
%   Non-shared levels get reduction_function equal to the reduction
%   of the (single) entry that names them.
%
%   PYRAMIDS         - struct array from listPyramids
%   PEREDUCTION      - cellstr, one label per entry ('mean','max',...)
%
%   Name-Value:
%     subjectID       - char, depended-on subject id
%     elementID       - char, depended-on element id (may be '')
%     sourceFileID    - char, id of the fileReference doc for the store
%     pipelineVersion - char, tag for the pyramid
%     label           - char, human-readable label for the pyramid
%     tileBudgetBytes - target UNCOMPRESSED bytes per chunk when the
%                       chunk shape is chosen automatically. Default
%                       8*2^20 (8 MB). Sized for a viewer over an
%                       ~200 MB/s link fetching ~4 parallel tiles per
%                       pan gesture. Chunks land near this budget but
%                       are clamped by the level's own shape, so a
%                       small coarse level may end up as one whole
%                       chunk.
%     chunks          - optional explicit chunk shape (row vector in
%                       axes_order). Empty (default) means auto: pick
%                       a shape ISOTROPIC IN WORLD SPACE from the
%                       level's voxel size, the dtype and
%                       tileBudgetBytes. Non-empty overrides the
%                       budget entirely and is used verbatim on every
%                       level (clamped by shape).
%
%   The chosen chunk shape is what a future materializer will
%   re-tile source bytes to; it is stamped onto the level document
%   here so a reader can compute chunk_grid and index chunk.bin_#
%   without consulting the source store. Source-store chunk shape is
%   NOT preserved.
%
%   Metadata only. n_chunks_stored is 0 on every level document in
%   this PR; materializing chunk bytes into `chunk.bin_#` is follow-up
%   work.
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.levelTable,
%             ndi.fun.doc.lightsheet.chooseLevel

    arguments
        session (1,1)
        pyramids (:,1) struct
        perEntryReduction (:,1) cell
        options.subjectID (1,:) char
        options.elementID char = ''
        options.sourceFileID char = ''
        options.pipelineVersion char = ''
        options.label char = ''
        options.tileBudgetBytes (1,1) double {mustBePositive} = 8 * 2^20
        options.chunks double = []
        options.materializeChunks (1,1) logical = false
        options.sourceZarrPath char = ''
        options.codec (1,:) char {mustBeMember(options.codec, {'raw','blosc-zstd'})} = 'raw'
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 22)} = 5
    end

    if options.materializeChunks && isempty(options.sourceZarrPath)
        error('NDI:lightsheet:makePyramid:noSource', ...
            ['materializeChunks=true requires sourceZarrPath so ' ...
             'chunks can be read from the source store.']);
    end

    if numel(pyramids) ~= numel(perEntryReduction)
        error('NDI:lightsheet:makePyramid:reductionArity', ...
            'perEntryReduction (%d) must have one entry per pyramid (%d).', ...
            numel(perEntryReduction), numel(pyramids));
    end

    % Group levels by NGFF path. entries at the same path share bytes.
    % pathReductions maps path -> set of reductions that use it.
    pathIndex = containers.Map();
    pathOrder = {};
    pathReductions = containers.Map();
    representative = containers.Map();  % path -> struct(entryIdx, levelIdx)
    for i = 1:numel(pyramids)
        levels = pyramids(i).levels;
        for k = 1:numel(levels)
            p = char(levels(k).path);
            if ~isKey(pathIndex, p)
                pathIndex(p) = numel(pathOrder) + 1;
                pathOrder{end+1} = p; %#ok<AGROW>
                pathReductions(p) = perEntryReduction(i);
                representative(p) = struct('entryIdx', i, 'levelIdx', k);
            else
                cur = pathReductions(p);
                if ~any(strcmp(cur, perEntryReduction{i}))
                    cur{end+1} = perEntryReduction{i}; %#ok<AGROW>
                    pathReductions(p) = cur;
                end
            end
        end
    end

    % Pick the source volume's identity from the first entry, first level.
    firstEntry = pyramids(1);
    firstLevel = firstEntry.levels(1);
    axesOrder = joinAxisNames(firstEntry.axes);
    axesUnits = collectAxisUnits(firstEntry.axes);
    label = options.label;
    if isempty(label)
        label = firstEntry.name;
    end

    pyramidDoc = session.newdocument('lightsheetZarrPyramid', ...
        'lightsheetZarrPyramid', struct( ...
            'label', label, ...
            'pyramid_name', char(firstEntry.name), ...
            'pyramid_type', char(firstEntry.type), ...
            'axes_order', axesOrder, ...
            'axes_units', strjoin(axesUnits, ','), ...
            'channel_names', '', ...
            'n_channels', channelCount(firstLevel.shape, axesOrder), ...
            'shape_level0', firstLevel.shape, ...
            'voxel_size_level0', ensureRow(firstLevel.scale), ...
            'voxel_size_units', 'micrometer', ...
            'translation_level0', ensureRow(firstLevel.translation), ...
            'dtype', char(firstLevel.dtype), ...
            'pipeline_version', options.pipelineVersion, ...
            'byte_order', 'little'));

    pyramidDoc = pyramidDoc.set_dependency_value('subject_id', options.subjectID);
    if ~isempty(options.elementID)
        pyramidDoc = pyramidDoc.set_dependency_value('element_id', options.elementID);
    end
    if ~isempty(options.sourceFileID)
        pyramidDoc = pyramidDoc.set_dependency_value('source_file_id', options.sourceFileID);
    end

    session.database_add(pyramidDoc);

    % Assign each unique path a 0-based level index in the ORDER it
    % first appears (finest first, since listPyramids is finest-first).
    levelDocs = cell(numel(pathOrder), 1);
    sharedLevel0 = false;
    for idx = 1:numel(pathOrder)
        p = pathOrder{idx};
        rep = representative(p);
        entry = pyramids(rep.entryIdx);
        level = entry.levels(rep.levelIdx);
        rlist = pathReductions(p);
        if numel(rlist) > 1
            reductionFn = 'none';
            if idx == 1
                sharedLevel0 = true;
            end
        else
            reductionFn = rlist{1};
        end
        levelDocs{idx} = makeOneLevel(session, pyramidDoc, entry, ...
            level, idx - 1, reductionFn, options);
    end
end

function levelDoc = makeOneLevel(session, pyramidDoc, pyramidEntry, level, levelIndex, reductionFn, options)
    axesOrder = joinAxisNames(pyramidEntry.axes);
    if isempty(options.chunks)
        chunks = ndi.fun.doc.lightsheet.chooseTileShape(level.shape, ...
            axesOrder, level.scale, char(level.dtype), ...
            options.tileBudgetBytes);
    else
        chunks = clampChunksToShape(ensureRow(options.chunks), level.shape);
    end
    chunkGrid = ceil(level.shape ./ chunks);

    if options.materializeChunks
        nChunksStored = prod(chunkGrid);
    else
        nChunksStored = 0;
    end

    props = struct( ...
        'label', sprintf('%s level %d (%s)', pyramidEntry.name, levelIndex, reductionFn), ...
        'level', levelIndex, ...
        'reduction_function', reductionFn, ...
        'axes_order', joinAxisNames(pyramidEntry.axes), ...
        'shape', level.shape, ...
        'chunks', chunks, ...
        'chunk_grid', chunkGrid, ...
        'n_chunks_stored', nChunksStored, ...
        'chunk_index_origin', 1, ...
        'chunk_order', 'C', ...
        'dtype', char(level.dtype), ...
        'fill_value', 0, ...
        'byte_order', 'little', ...
        'codec', options.codec, ...
        'codec_params', codecParamsJSON(options), ...
        'voxel_size', ensureRow(level.scale), ...
        'voxel_size_units', 'micrometer', ...
        'translation', ensureRow(level.translation));

    levelDoc = session.newdocument('lightsheetZarrLevel', ...
        'lightsheetZarrLevel', props);

    levelDoc = levelDoc.set_dependency_value('lightsheetZarrPyramid_id', pyramidDoc.id());
    levelDoc = levelDoc.set_dependency_value('subject_id', options.subjectID);
    if ~isempty(options.sourceFileID)
        levelDoc = levelDoc.set_dependency_value('source_file_id', options.sourceFileID);
    end

    if options.materializeChunks
        levelDoc = attachChunkFiles(levelDoc, options.sourceZarrPath, ...
            pyramidEntry, level, chunks, chunkGrid, ...
            options.codec, options.clevel);
    end

    session.database_add(levelDoc);
end

function levelDoc = attachChunkFiles(levelDoc, sourceZarrPath, pyramidEntry, level, chunks, chunkGrid, codec, clevel)
% Read the source zarr level as a whole array, then re-tile into the
% level document's chunk shape and attach each chunk as chunk.bin_<idx>
% (1-based, C-order over chunkGrid). Files are ingested into DID, which
% deletes the temp original as it copies -- so we build each chunk in a
% new tempname and hand it to add_file.
    pyramidName = char(pyramidEntry.name);
    % Which position in this pyramid's datasets holds this level? The
    % `level` struct came from listPyramids(entry).levels; its index is
    % the 1-based position we need for readArray.
    kInEntry = find(arrayfun(@(L) strcmp(char(L.path), char(level.path)), ...
        pyramidEntry.levels), 1);
    if isempty(kInEntry)
        error('NDI:lightsheet:makePyramid:missingLevelInEntry', ...
            'level path %s not found in pyramid %s.', level.path, pyramidName);
    end

    % Read the full array. For a fixture-scale volume (~54 MB uint16)
    % this is a single allocation; a lab-scale volume will need a
    % streaming reader later, but the level doc's chunk shape is fixed
    % here either way.
    data = ndr.format.omezarr.readArray(sourceZarrPath, pyramidName, kInEntry);

    shape  = size(data);
    if numel(shape) < numel(chunks)
        % Singleton trailing axes: pad shape to axis count.
        shape(end+1:numel(chunks)) = 1;
    end

    % Iterate chunks in C-order (last axis fastest). 1-based linear
    % index goes into the chunk.bin_# filename.
    idx = 0;
    tmpRoot = tempname;
    mkdir(tmpRoot);
    cleaner = onCleanup(@() cleanupTmp(tmpRoot));
    subs = cell(1, numel(chunkGrid));
    linearOrder = allChunkIndices(chunkGrid);   % rows are (c1, c2, c3, ...) 1-based
    for r = 1:size(linearOrder, 1)
        idx = idx + 1;
        cIdx = linearOrder(r, :);
        % Compute the source slice and the padded chunk.
        for a = 1:numel(chunkGrid)
            lo = (cIdx(a) - 1) * chunks(a) + 1;
            hi = min(lo + chunks(a) - 1, shape(a));
            subs{a} = lo:hi;
        end
        srcTile = data(subs{:});
        padded = zeros(chunks, 'like', data);
        localSubs = arrayfun(@(k) 1:size(srcTile, k), 1:numel(chunks), ...
            'UniformOutput', false);
        padded(localSubs{:}) = srcTile;

        % Zarr expects C-order bytes: last axis varies fastest. MATLAB
        % is column-major, so permute the axes into reversed order
        % before serialising, mirroring the fixture writer.
        permuted = permute(padded, numel(chunks):-1:1);
        raw = typecast(permuted(:), 'uint8');

        switch codec
            case 'raw'
                payload = raw;
            case 'blosc-zstd'
                typesize = elementSizeBytes(class(padded));
                payload = ndr.format.blosc.encode(raw, ...
                    'typesize', typesize, ...
                    'cname',    'zstd', ...
                    'clevel',   clevel, ...
                    'shuffle',  1);
            otherwise
                error('NDI:lightsheet:makePyramid:unknownCodec', ...
                    'Unknown codec %s.', codec);
        end

        tmp = fullfile(tmpRoot, sprintf('chunk_%d.bin', idx));
        fid = fopen(tmp, 'w');
        fwrite(fid, payload);
        fclose(fid);

        levelDoc = levelDoc.add_file(sprintf('chunk.bin_%d', idx), tmp);
    end
end

function s = codecParamsJSON(options)
% JSON string stamped into the level document so a reader knows how to
% decode. For 'raw' the params are empty; for Blosc-Zstd they name the
% codec identity numcodecs.Blosc expects.
    switch options.codec
        case 'raw'
            s = '{}';
        case 'blosc-zstd'
            s = sprintf(['{"cname":"zstd","clevel":%d,"shuffle":1,' ...
                '"blocksize":0}'], options.clevel);
        otherwise
            s = '{}';
    end
end

function b = elementSizeBytes(className)
    switch className
        case {'uint8','int8','logical'}
            b = 1;
        case {'uint16','int16'}
            b = 2;
        case {'uint32','int32','single'}
            b = 4;
        case {'uint64','int64','double'}
            b = 8;
        otherwise
            b = 2;
    end
end

function cleanupTmp(d)
    if isfolder(d)
        try
            rmdir(d, 's');
        catch
        end
    end
end

function idx = allChunkIndices(chunkGrid)
% Return a matrix whose rows enumerate every 1-based chunk index tuple
% in C-order (last axis fastest, so the LINEAR order matches
% index = c1*n2*n3*... + c2*n3*... + ... + cn + 1).
    n = numel(chunkGrid);
    counts = cumprod(fliplr(chunkGrid));
    total = counts(end);
    idx = zeros(total, n);
    for r = 1:total
        rem = r - 1;
        for a = 1:n
            % last axis is fastest
            stride = 1;
            for b = a+1:n
                stride = stride * chunkGrid(b);
            end
            idx(r, a) = floor(rem / stride) + 1;
            rem = mod(rem, stride);
        end
    end
end

function s = joinAxisNames(axes)
    if isempty(axes)
        s = '';
        return;
    end
    names = arrayfun(@(a) char(a.name), axes, 'UniformOutput', false);
    s = strjoin(names, '');
end

function u = collectAxisUnits(axes)
    if isempty(axes)
        u = {};
        return;
    end
    u = arrayfun(@(a) char(a.unit), axes, 'UniformOutput', false);
end

function n = channelCount(shape, axesOrder)
    c = strfind(axesOrder, 'c');
    if isempty(c) || numel(shape) < c(1)
        n = 1;
    else
        n = shape(c(1));
    end
end

function v = ensureRow(x)
    if isempty(x)
        v = [];
    else
        v = reshape(double(x), 1, []);
    end
end

function chunks = clampChunksToShape(chunks, shape)
    shape = double(shape(:).');
    chunks = double(chunks(:).');
    if numel(chunks) ~= numel(shape)
        error('NDI:lightsheet:makePyramid:chunksArity', ...
            'Explicit chunks length %d does not match level shape length %d.', ...
            numel(chunks), numel(shape));
    end
    if any(chunks < 1) || any(chunks ~= fix(chunks))
        error('NDI:lightsheet:makePyramid:badChunks', ...
            'Explicit chunks must be positive integers.');
    end
    chunks = min(chunks, shape);
end

