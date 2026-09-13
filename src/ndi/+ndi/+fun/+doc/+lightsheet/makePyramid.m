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
        options.clevel (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.clevel, 1), mustBeLessThanOrEqual(options.clevel, 9)} = 5
        % progressFcn(fraction, text) is called before and after each
        % chunk write. Empty = no reporting. Keep this cheap; it fires
        % once per chunk on a real ingest, which is many times.
        options.progressFcn = []
        % Number of parallel workers to use for compression.
        %   -1  (default) - use whatever parpool is already open;
        %                    if none is open, run serially. This lets
        %                    the caller size and manage the pool once
        %                    at the top of their script, and every
        %                    subsequent ingest just uses it.
        %    0 / 1        - force serial (the original path, no
        %                    toolbox dependency).
        %    N > 1        - open (or replace) a parpool of size N and
        %                    use it. Requires the Parallel Computing
        %                    Toolbox; falls back to serial with a
        %                    warning if unavailable.
        % Reads stay strictly serial in all modes; a batch of
        % effective-pool-size chunks is read into memory, then
        % compression fans out. Ingestion order into DID is preserved.
        options.numWorkers (1,1) double {mustBeInteger, mustBeGreaterThanOrEqual(options.numWorkers, -1)} = -1
        % How much source data to pull into RAM per readArray call, in
        % bytes uncompressed. One "super-block" of chunks is read at a
        % time, then compressed by the worker pool in sub-batches. A
        % bigger prefetch amortises the fixed cost of a seek + NDR
        % subprocess round-trip over more voxels, which matters on any
        % drive slow enough for I/O to dominate. Default 512 MB is a
        % sensible compromise for a modern workstation; passing 1e9 or
        % 2e9 is fine on a machine with plenty of RAM. Peak MATLAB
        % memory is prefetchBytes (uncompressed).
        options.prefetchBytes (1,1) double {mustBePositive} = 512 * 2^20
        % Overlap disk reads with compression via parfeval. The next
        % super-block starts reading on a pool worker while the parfor
        % is still compressing the current one, so total time
        % approaches max(read_time, compress_time) instead of their
        % sum. Requires a parpool (falls back to synchronous reads
        % otherwise). Peak RAM is ~2 * prefetchBytes (two super-
        % blocks in flight).
        options.asyncPrefetch (1,1) logical = true
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

    % PROGRESS ACCOUNTING. Chunk-count planning happens up front so
    % progressFcn can report overall fraction, not per-level fraction:
    % a viewer wants "3 of 24000 chunks done", not a bar that resets at
    % every level. chooseTileShape is cheap (metadata only), so running
    % it twice -- once here, once inside makeOneLevel -- costs nothing.
    levelChunks = cell(numel(pathOrder), 1);
    levelGrids  = cell(numel(pathOrder), 1);
    totalChunks = 0;
    for idx = 1:numel(pathOrder)
        p = pathOrder{idx};
        rep = representative(p);
        entry = pyramids(rep.entryIdx);
        level = entry.levels(rep.levelIdx);
        axesOrder = joinAxisNames(entry.axes);
        if isempty(options.chunks)
            chunks_i = ndi.fun.doc.lightsheet.chooseTileShape(level.shape, ...
                axesOrder, level.scale, char(level.dtype), ...
                options.tileBudgetBytes);
        else
            chunks_i = clampChunksToShape(ensureRow(options.chunks), level.shape);
        end
        levelChunks{idx} = chunks_i;
        levelGrids{idx}  = ceil(level.shape ./ chunks_i);
        if options.materializeChunks
            totalChunks = totalChunks + prod(levelGrids{idx});
        end
    end

    % Announce the run configuration. Users have hit "the parfor did
    % nothing" because MATLAB had cached the old .m file, or because
    % no parpool was open at call time. A single up-front print says
    % which path is really running.
    if options.materializeChunks
        [effWorkers, workerSource] = describeParallelPool(options.numWorkers);
        asyncStr = 'off';
        if options.asyncPrefetch && effWorkers > 1
            asyncStr = 'on (read overlaps compress)';
        end
        fprintf(['[makePyramid] Parallel workers: %d (%s). ' ...
            'Prefetch budget: %.0f MB per read. Async prefetch: %s. ' ...
            'Total chunks: %d across %d level path(s). Codec: %s.\n'], ...
            effWorkers, workerSource, ...
            options.prefetchBytes / 2^20, asyncStr, ...
            totalChunks, numel(pathOrder), options.codec);
    end

    % Assign each unique path a 0-based level index in the ORDER it
    % first appears (finest first, since listPyramids is finest-first).
    levelDocs = cell(numel(pathOrder), 1);
    sharedLevel0 = false;
    doneChunks = 0;
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
        if options.materializeChunks
            nChunksLvl = prod(levelGrids{idx});
            fprintf(['[makePyramid] Level %d/%d (%s, %s): shape=%s, ' ...
                'chunks=%s, %d chunks to write.\n'], ...
                idx, numel(pathOrder), char(entry.name), reductionFn, ...
                mat2str(double(level.shape)), ...
                mat2str(double(levelChunks{idx})), nChunksLvl);
        end
        reportProgress(options.progressFcn, doneChunks, totalChunks, ...
            sprintf('Level %d/%d (%s, %s): starting', ...
                idx, numel(pathOrder), char(entry.name), reductionFn));
        [levelDocs{idx}, doneChunks] = makeOneLevel(session, pyramidDoc, ...
            entry, level, idx - 1, reductionFn, options, ...
            levelChunks{idx}, levelGrids{idx}, ...
            doneChunks, totalChunks);
    end
    reportProgress(options.progressFcn, max(doneChunks, totalChunks), ...
        max(totalChunks, 1), 'Done.');
end

function [levelDoc, doneChunks] = makeOneLevel(session, pyramidDoc, pyramidEntry, level, levelIndex, reductionFn, options, chunks, chunkGrid, doneChunks, totalChunks)

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

    tmpRoot = '';
    if options.materializeChunks
        levelLabel = sprintf('Level %d (%s)', levelIndex, reductionFn);
        [levelDoc, tmpRoot, doneChunks] = attachChunkFiles(levelDoc, ...
            options.sourceZarrPath, pyramidEntry, level, chunks, chunkGrid, ...
            options.codec, options.clevel, ...
            options.progressFcn, doneChunks, totalChunks, levelLabel, ...
            options.numWorkers, options.prefetchBytes, options.asyncPrefetch);
    end
    tmpCleaner = onCleanup(@() cleanupTmp(tmpRoot));

    session.database_add(levelDoc);
end

function [levelDoc, tmpRoot, doneChunks] = attachChunkFiles(levelDoc, sourceZarrPath, pyramidEntry, level, chunks, chunkGrid, codec, clevel, progressFcn, doneChunks, totalChunks, levelLabel, numWorkers, prefetchBytes, asyncPrefetch)
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

    % STREAMING per-chunk read. We call readArray with `Region` per
    % target chunk instead of loading the whole level up front. Previous
    % versions did `data = readArray(...)` and sliced `data(subs{:})`
    % per chunk; that reads O(level bytes) into one MATLAB allocation
    % and crashes on lab-scale volumes (a stitched SmartSPIM level 0
    % can be hundreds of GB). Reading a single target chunk touches
    % only the source chunks that overlap that region, so peak memory
    % scales with target chunk size, not level size.
    shape = ensureRow(level.shape);
    if numel(shape) < numel(chunks)
        % Singleton trailing axes: pad shape to axis count.
        shape(end+1:numel(chunks)) = 1;
    end

    % 1-based linear index goes into the chunk.bin_# filename.
    tmpRoot = tempname;
    mkdir(tmpRoot);
    % No onCleanup here: tmpRoot is returned so the CALLER can register
    % the cleanup AFTER session.database_add has ingested the files. If
    % we cleaned up on return, database_add would find the paths already
    % deleted.
    linearOrder = allChunkIndices(chunkGrid);   % rows are (c1, c2, c3, ...) 1-based
    nChunks = size(linearOrder, 1);
    typesize = elementSizeBytes(char(level.dtype));

    % BATCHED SERIAL-READ / PARALLEL-COMPRESS. On a slow spinning drive
    % we cannot afford concurrent seeks, so reads stay strictly serial;
    % but Zstd at clevel=9 is single-core CPU-bound and easy to fan out
    % across a parallel pool. A batch of `poolSize` chunks is read from
    % the source, then handed to the workers to compress and write, in
    % parallel; add_file into the level document happens serially in
    % chunk-index order so the DID SQLite write is not a contention
    % point and the on-disk chunk numbering is unchanged. poolSize == 1
    % is the original serial path with no toolbox dependency.
    poolSize = resolveParallelPool(numWorkers);

    % How many target chunks fit inside the prefetch budget, sized
    % by uncompressed chunk bytes. Never smaller than the parfor
    % pool (a super-block below poolSize would leave workers idle);
    % never larger than the level itself.
    chunkBytes = prod(chunks) * typesize;
    prefetchChunkCount = max(poolSize, ...
        floor(double(prefetchBytes) / max(chunkBytes, 1)));
    prefetchChunkCount = min(prefetchChunkCount, nChunks);

    % Plan every super-block up front (chunk indices + per-chunk lo/hi
    % + union bbox) so the async pipeline can dispatch the next read
    % while the current one is still compressing.
    nSuperBlocks = ceil(nChunks / prefetchChunkCount);
    superBlocks = cell(nSuperBlocks, 1);
    for s = 1:nSuperBlocks
        s0 = (s - 1) * prefetchChunkCount + 1;
        s1 = min(s0 + prefetchChunkCount - 1, nChunks);
        idxs = s0:s1;
        bs = numel(idxs);
        lo = zeros(bs, numel(shape));
        hi = zeros(bs, numel(shape));
        for j = 1:bs
            c = linearOrder(idxs(j), :);
            for a = 1:numel(chunkGrid)
                lo(j, a) = (c(a) - 1) * chunks(a) + 1;
                hi(j, a) = min(lo(j, a) + chunks(a) - 1, shape(a));
            end
        end
        superBlocks{s} = struct('idxs', idxs, ...
            'loRows', lo, 'hiRows', hi, ...
            'loBBox', min(lo, [], 1), 'hiBBox', max(hi, [], 1));
    end

    % ASYNC PIPELINE. If a parpool is available and asyncPrefetch is
    % on, the next super-block's read runs concurrently on a pool
    % worker while the parfor is compressing the current one. Total
    % time approaches max(read_time, compress_time) instead of their
    % sum. Peak RAM ~ 2 * prefetchBytes (two blocks in flight).
    useAsync = asyncPrefetch && poolSize > 1 && nSuperBlocks > 1;
    if useAsync
        pool = gcp();
        nextFut = parfeval(pool, @readSuperBlockRegion, 1, ...
            sourceZarrPath, pyramidName, kInEntry, ...
            superBlocks{1}.loBBox, superBlocks{1}.hiBBox);
    end

    for s = 1:nSuperBlocks
        sb = superBlocks{s};
        bs = numel(sb.idxs);

        % ---- READ current super-block, DISPATCH the next -----------
        if useAsync
            bigTile = fetchOutputs(nextFut);
            if s < nSuperBlocks
                nb = superBlocks{s + 1};
                nextFut = parfeval(pool, @readSuperBlockRegion, 1, ...
                    sourceZarrPath, pyramidName, kInEntry, ...
                    nb.loBBox, nb.hiBBox);
            end
        else
            bigTile = readSuperBlockRegion(sourceZarrPath, ...
                pyramidName, kInEntry, sb.loBBox, sb.hiBBox);
        end

        % ---- SLICE the entire super-block into per-chunk raw bytes -
        % Done once, up front, for the whole super-block instead of
        % per sub-batch. This lets us fire ONE parfor across every
        % chunk in the super-block and pay MATLAB's parfor
        % coordination overhead once instead of ceil(bs/poolSize)
        % times. Peak memory during this phase is bigTile + raws
        % (~equal size; both released before the compression pool
        % begins).
        raws = cell(1, bs);
        chunkIdxs = zeros(1, bs);
        for j = 1:bs
            chunkIdxs(j) = sb.idxs(j);
            subs = cell(1, numel(shape));
            for a = 1:numel(shape)
                subs{a} = (sb.loRows(j, a) - sb.loBBox(a) + 1) : ...
                          (sb.hiRows(j, a) - sb.loBBox(a) + 1);
            end
            srcTile = bigTile(subs{:});
            padded = zeros(chunks, class(srcTile));
            localSubs = arrayfun(@(k) 1:size(srcTile, k), ...
                1:numel(chunks), 'UniformOutput', false);
            padded(localSubs{:}) = srcTile;
            % Zarr expects C-order bytes; MATLAB is column-major, so
            % permute the axes into reversed order before
            % serialising, mirroring the fixture writer.
            permuted = permute(padded, numel(chunks):-1:1);
            raws{j} = typecast(permuted(:), 'uint8');
        end
        % Release the source buffer as soon as raws holds copies.
        clear bigTile;

        % ---- ONE PARFOR ACROSS THE ENTIRE SUPER-BLOCK -------------
        tempPaths = cell(1, bs);
        if poolSize > 1 && bs > 1
            parfor j = 1:bs
                tempPaths{j} = encodeAndWrite(raws{j}, codec, clevel, ...
                    typesize, tmpRoot, chunkIdxs(j)); %#ok<PFBNS>
            end
        else
            for j = 1:bs
                tempPaths{j} = encodeAndWrite(raws{j}, codec, clevel, ...
                    typesize, tmpRoot, chunkIdxs(j));
            end
        end
        % raws is no longer needed after the pool has produced the
        % tempfiles. Peak RAM stays bounded before the next super-
        % block's read materialises via the async future.
        clear raws;

        % ---- SERIAL ADD_FILE + BATCHED PROGRESS ------------------
        % In-memory metadata registration; still ordered by chunk
        % index so the on-disk chunk numbering is unchanged. Progress
        % ticks fire ONCE at the end of each super-block instead of
        % per chunk: 18 workers producing a burst of 18 nearly-
        % simultaneous updateBar calls was making the bar's
        % redraw/ETA-recompute path a measurable fraction of the
        % gap. One tick per super-block is more than enough
        % granularity on a multi-hour ingest.
        for j = 1:bs
            levelDoc = levelDoc.add_file( ...
                sprintf('chunk.bin_%d', chunkIdxs(j)), tempPaths{j});
        end
        doneChunks = doneChunks + bs;
        reportProgress(progressFcn, doneChunks, totalChunks, ...
            sprintf('%s: super-block %d/%d, chunk %d/%d', ...
                levelLabel, s, nSuperBlocks, ...
                chunkIdxs(end), nChunks));
    end
end

function bigTile = readSuperBlockRegion(sourceZarrPath, pyramidName, kInEntry, loBBox, hiBBox)
% READSUPERBLOCKREGION - fetch one super-block region from the source
%
%   Wraps ndr.format.omezarr.readArray so parfeval can dispatch it as
%   a background read on a pool worker. Kept as a plain subfunction
%   (not nested) so the worker can serialise it without pulling the
%   caller's workspace.
    bigTile = ndr.format.omezarr.readArray(sourceZarrPath, ...
        pyramidName, kInEntry, 'Region', [loBBox; hiBBox]);
end

function tmp = encodeAndWrite(raw, codec, clevel, typesize, tmpRoot, chunkIdx)
% ENCODEANDWRITE - compress one chunk and drop it in tmpRoot
%
%   Pure per-chunk work: whatever runs in a parfor iteration lives
%   here so the parallel worker has no dependency on outer-function
%   state beyond the arguments it receives. Returns the tempfile path
%   that add_file will consume.
    switch codec
        case 'raw'
            payload = raw;
        case 'blosc-zstd'
            payload = ndr.format.blosc.encode(raw, ...
                'typesize', typesize, ...
                'cname',    'zstd', ...
                'clevel',   clevel, ...
                'shuffle',  1);
        otherwise
            error('NDI:lightsheet:makePyramid:unknownCodec', ...
                'Unknown codec %s.', codec);
    end
    tmp = fullfile(tmpRoot, sprintf('chunk_%d.bin', chunkIdx));
    fid = fopen(tmp, 'w');
    fwrite(fid, payload);
    fclose(fid);
end

function [n, src] = describeParallelPool(numWorkers)
% DESCRIBEPARALLELPOOL - peek at the effective pool without side effects
%
%   Returns [n, src] where n is the worker count that resolveParallelPool
%   would end up with, and src is a short human string naming why.
%   No pool is created; used only to print the run banner before the
%   pyramid loop starts.
    if numWorkers == 0 || numWorkers == 1
        n = 1; src = 'serial, forced by numWorkers'; return;
    end
    if isempty(ver('parallel'))
        n = 1; src = 'serial, Parallel Computing Toolbox not installed'; return;
    end
    p = gcp('nocreate');
    if numWorkers < 0
        if isempty(p)
            n = 1; src = 'serial, no parpool open (call parpool(N) to enable)';
        else
            n = p.NumWorkers; src = 'from existing parpool';
        end
        return;
    end
    if isempty(p) || p.NumWorkers ~= numWorkers
        n = numWorkers; src = 'will open a new parpool';
    else
        n = numWorkers; src = 'from existing parpool';
    end
end

function n = resolveParallelPool(numWorkers)
% RESOLVEPARALLELPOOL - resolve numWorkers into an effective batch size
%
%   -1 -> the size of any parpool already open, else 1 (serial). This
%         is the default so a caller who ran `parpool(8)` once at the
%         top of their session gets 8-way compression without having
%         to name a number in every ingest call.
%   0 or 1 -> serial.
%   N > 1 -> ensure a parpool of size N is running (create it or
%         restart the existing one at a different size), returning N.
%
%   In every case a missing PCT or a failed parpool startup degrades
%   to serial with a warning: a broken pool must not stop an ingest
%   that may already be hours in.
    if numWorkers == 0 || numWorkers == 1
        n = 1;
        return;
    end
    if isempty(ver('parallel'))
        if numWorkers > 1
            warning('NDI:lightsheet:makePyramid:noPCT', ...
                ['numWorkers=%d requested but Parallel Computing ' ...
                 'Toolbox is not available. Running serially.'], ...
                numWorkers);
        end
        n = 1;
        return;
    end
    try
        p = gcp('nocreate');
        if numWorkers < 0    % 'auto' -> reuse open pool, else serial
            if isempty(p)
                n = 1;
            else
                n = p.NumWorkers;
            end
            return;
        end
        if isempty(p) || p.NumWorkers ~= numWorkers
            if ~isempty(p)
                delete(p);
            end
            parpool('local', numWorkers);
        end
        n = numWorkers;
    catch ME
        warning('NDI:lightsheet:makePyramid:parpoolFailed', ...
            ['Could not use a parpool of %d workers (%s). ' ...
             'Running serially.'], numWorkers, ME.message);
        n = 1;
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

function reportProgress(fcn, done, total, text)
% REPORTPROGRESS - call the caller's progress callback, if any
%
%   Fraction is done/total, clamped into [0,1]. Total==0 (no chunks
%   materialized) reports 0 rather than dividing, so the caller's bar
%   still gets its label refreshed. Any exception is swallowed: a bar
%   that stopped drawing must not stop an ingest.
    if isempty(fcn), return; end
    frac = 0;
    if total > 0
        frac = max(0, min(1, double(done) / double(total)));
    end
    try
        fcn(frac, char(text));
    catch
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

