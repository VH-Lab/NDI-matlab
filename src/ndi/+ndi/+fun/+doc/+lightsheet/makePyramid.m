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
%                       32*2^20 (32 MB). Sized to the measured
%                       signing+fetch+decode sweet spot for a viewer
%                       on an ~200 MB/s link: large enough that the
%                       per-chunk round trip is amortised and the
%                       chunk count stays bounded (121k-chunk level 0
%                       at 8 MB -> ~30k at 32 MB on a whole-brain
%                       lightsheet), small enough that per-chunk
%                       decode stays under ~200 ms and the renderer
%                       can stream chunks without stalls. Chunks land
%                       near this budget but are clamped by the
%                       level's own shape, so a small coarse level
%                       may end up as one whole chunk.
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
%   With materializeChunks=false this is metadata only and
%   n_chunks_stored is 0 on every level document. With
%   materializeChunks=true each level's bytes are read, re-tiled,
%   encoded and installed as the `chunk.bin_#` file series.
%
%   WHERE THE BYTES COME FROM. By default every level is read from the
%   OME-Zarr store at sourceZarrPath (the level's own array in it).
%   levelSources overrides that per level path, for sources that are
%   not an OME-Zarr store -- ndi.fun.doc.lightsheet.fromSPIM uses it to
%   read level 0 from SmartSPIM's stitched All_Channels slices and to
%   build every coarser level by block-reducing the level just written:
%
%     levelSources - containers.Map from level path (the levels(k).path
%                    string in PYRAMIDS) to a source struct:
%         struct('kind','omezarr')        the default, from sourceZarrPath
%         struct('kind','smartspim', 'slicePaths', {C x 1 cell of
%                Z x 1 cellstr}, 'dtype', CLASS)
%                                         2-D TIFF slices, one per (c, z),
%                                         axes t,c,z,y,x
%         struct('kind','reduce', 'fromPath', PATH, 'factor', F,
%                'reduction', 'mean'|'max')
%                                         block-reduce the level at PATH
%                                         (written earlier in this call)
%                                         by per-axis factor F
%         struct('kind','reduceSmartspim', 'slicePaths', ..., 'sourceDtype',
%                CLASS, 'fromShape', SHAPE, 'factor', F, 'reduction', R)
%                                         block-reduce the SmartSPIM slices
%                                         themselves (full resolution, of
%                                         shape SHAPE) by F, for a level
%                                         whose finer level is not kept
%                    A path not in the map falls back to 'omezarr'.
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.fromSPIM,
%             ndi.fun.doc.lightsheet.reduceBlocks,
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
        options.tileBudgetBytes (1,1) double {mustBePositive} = 32 * 2^20
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
        % Path to a text log file the ingest will append per-super-block
        % memory diagnostics to (timestamp, level index, super-block
        % index, chunks done, main-process RSS in MB, `whos` sizes of
        % the big variables, parpool live-future count). Empty (default)
        % disables logging. Intended for diagnosing memory growth
        % without affecting the hot path -- one line per super-block is
        % negligible on a multi-hour ingest.
        options.debugLog (1,:) char = ''
        % PROFILING (ndi.fun.doc.lightsheet.BuildProfile). Every
        % super-block is timed -- waiting for its read, assembling its
        % chunks, compressing them (and how busy the workers were),
        % handing them to the session (for a cloud target: signed URLs,
        % staging and CRC-32, waiting for the upload, checking with the
        % cloud), the progress callback -- and a summary of where the
        % time went is printed every profileEverySeconds and at the end
        % of each level. profileLog, if given, gets one CSV row per
        % super-block (appended, so a resumed build adds to it).
        options.profileLog (1,:) char = ''
        % How many pool workers read one super-block of SmartSPIM slices
        % at once, each a slab along z. Slices are read one file at a
        % time, and over a network each file costs a round trip, so
        % several readers at once keep the network busy. With numWorkers
        % above 1 and asyncPrefetch, the pool gets this many workers more
        % than numWorkers, so reading the next region never takes workers
        % from compressing this one.
        options.readWorkers (1,1) double {mustBeInteger, mustBePositive} = 8
        % Test hook: read slices in readWorkers slabs one after another
        % when there is no pool, so the split-and-join is exercised where
        % no parallel pool can be had.
        options.splitReadsWithoutPool (1,1) logical = false
        % FOLDING (streaming SmartSPIM builds). Levels block-reduced
        % straight from the slices (level 1 of each ladder) are built
        % during level 0, from its own reads of the slices, so the slices
        % are read once in all (see buildFolded). False builds them
        % afterwards, both ladders together from one more read.
        options.foldLevel1 (1,1) logical = true
        options.profileEverySeconds (1,1) double {mustBePositive} = 600
        % Per-level-path byte sources; see "WHERE THE BYTES COME FROM"
        % above. Empty (default) reads every level from sourceZarrPath.
        options.levelSources = []
        % Comma-separated channel names written to the pyramid document.
        options.channelNames (1,:) char = ''
        % RESUMING an interrupted streamed build: a struct with fields
        %   pyramidDoc - the pyramid document the earlier run uploaded
        %   levelDocs  - cell of the level documents it declared (as
        %                declared, with their series member uids)
        % The pyramid is adopted rather than created; a level already
        % declared is adopted and only its chunks the cloud does not have
        % are built; a level not declared yet is built as usual. Needs a
        % streaming target (see STREAMING below). Empty (default): a new
        % pyramid.
        options.resume = []
    end

    if isempty(options.levelSources)
        options.levelSources = containers.Map();
    end
    if options.materializeChunks && isempty(options.sourceZarrPath) ...
            && options.levelSources.Count == 0
        error('NDI:lightsheet:makePyramid:noSource', ...
            ['materializeChunks=true requires sourceZarrPath (or ' ...
             'levelSources) so chunks can be read from a source.']);
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

    % STREAMING (a target such as ndi.cloud.upload.SessionWriter that
    % has streamMembers): each level is declared -- uploaded with every
    % chunk's uid in its manifest -- before its chunks exist, and the
    % chunks are sent as each super-block is written, so the disk holds
    % only what is in flight plus the one level a later level is reduced
    % from. The pyramid goes up first, labelled "(uploading)" until the
    % last chunk is in; the target replaces it with the real label at
    % commit.
    streaming = options.materializeChunks && ismethod(session, 'streamMembers');
    resuming = ~isempty(options.resume);
    if resuming && ~streaming
        error('NDI:lightsheet:makePyramid:resumeNeedsStreaming', ...
            'Only a streamed build (to a target such as ndi.cloud.upload.SessionWriter) can resume.');
    end
    docLabel = label;
    if streaming
        docLabel = [char(label) ' (uploading)'];
    end

    pyramidDoc = session.newdocument('lightsheetZarrPyramid', ...
        'lightsheetZarrPyramid', struct( ...
            'label', docLabel, ...
            'pyramid_name', char(firstEntry.name), ...
            'pyramid_type', char(firstEntry.type), ...
            'axes_order', axesOrder, ...
            'axes_units', strjoin(axesUnits, ','), ...
            'channel_names', options.channelNames, ...
            'n_channels', channelCount(firstLevel.shape, axesOrder), ...
            'shape_level0', firstLevel.shape, ...
            'voxel_size_level0', ensureRow(firstLevel.scale), ...
            'voxel_size_units', 'micrometer', ...
            'translation_level0', ensureRow(firstLevel.translation), ...
            'dtype', ndi.fun.doc.lightsheet.dtypeName(firstLevel.dtype, 'zarr'), ...
            'pipeline_version', options.pipelineVersion, ...
            'byte_order', 'little'));

    pyramidDoc = pyramidDoc.set_dependency_value('subject_id', options.subjectID);
    if ~isempty(options.elementID)
        pyramidDoc = pyramidDoc.set_dependency_value('element_id', options.elementID);
    end
    if ~isempty(options.sourceFileID)
        pyramidDoc = pyramidDoc.set_dependency_value('source_file_id', options.sourceFileID);
    end

    if resuming
        % The pyramid the earlier run put in the cloud, not a new one.
        pyramidDoc = options.resume.pyramidDoc;
        session.adopt(pyramidDoc);
    else
        session.database_add(pyramidDoc);
    end

    % PROGRESS ACCOUNTING. Chunk-count planning happens up front so
    % progressFcn can report overall fraction, not per-level fraction:
    % a viewer wants "3 of 24000 chunks done", not a bar that resets at
    % every level. chooseTileShape is cheap (metadata only), so running
    % it twice -- once here, once inside makeOneLevel -- costs nothing.
    %
    % The fraction is of WORK, not of chunks: a chunk reduced straight
    % from the SmartSPIM slices reads prod(factor) source chunks' worth
    % of them, so it counts that many times (see chunkWeight). Counting
    % chunks alone made a build look nearly done once level 0 was, with
    % the slowest part -- each ladder's pass over the slices -- still to
    % come.
    levelChunks = cell(numel(pathOrder), 1);
    levelGrids  = cell(numel(pathOrder), 1);
    totalChunks = 0;       % work units (see chunkWeight)
    nChunksAll = 0;        % chunks, for the announcement
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
            w = 1;
            if isa(options.levelSources, 'containers.Map') && isKey(options.levelSources, p)
                w = chunkWeight(options.levelSources(p));
            end
            totalChunks = totalChunks + prod(levelGrids{idx}) * w;
            nChunksAll = nChunksAll + prod(levelGrids{idx});
        end
    end

    % Folded levels (built during level 0) cost no read of their own.
    if streaming && options.foldLevel1 && options.materializeChunks
        for fk = foldCandidates(false(1, numel(pathOrder)))
            totalChunks = totalChunks - prod(levelGrids{fk}) * ...
                (chunkWeight(options.levelSources(pathOrder{fk})) - 1);
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
            nChunksAll, numel(pathOrder), options.codec);
    end
    options.profiler = ndi.fun.doc.lightsheet.BuildProfile( ...
        options.profileLog, options.profileEverySeconds);

    % Assign each unique path a 0-based level index in the ORDER it
    % first appears (finest first, since listPyramids is finest-first).
    levelDocs = cell(numel(pathOrder), 1);
    docByPath = containers.Map();
    sharedLevel0 = false;
    doneChunks = 0;
    % How many later levels are reduced from each level. A streamed
    % level is kept locally only while that count is above zero.
    readers = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for idx = 1:numel(pathOrder)
        from = reducedFrom(options.levelSources, pathOrder{idx});
        if ~isempty(from)
            if ~isKey(readers, from), readers(from) = 0; end
            readers(from) = readers(from) + 1;
        end
    end
    % Levels built already, as another level's twin (see findTwin).
    built = false(1, numel(pathOrder));
    for idx = 1:numel(pathOrder)
        if built(idx), continue; end
        p = pathOrder{idx};
        [entry, level, reductionFn] = levelMeta(p);
        if numel(pathReductions(p)) > 1 && idx == 1
            sharedLevel0 = true;
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
        source = [];
        if options.materializeChunks
            source = resolveLevelSource(session, p, entry, level, ...
                options, docByPath);
        end
        stream = [];
        if streaming
            stream = struct('session', session, ...
                'retain', isKey(readers, p) && readers(p) > 0, ...
                'existing', []);
            if resuming
                stream.existing = resumedLevel(options.resume, idx - 1, reductionFn);
            end
        end
        % FOLDED levels: built during this level, from its reads (level 0
        % from the slices, with level 1 of each ladder).
        fold = [];
        qs = [];
        if streaming && options.foldLevel1 && ~isempty(source) && strcmp(source.kind, 'smartspim')
            qs = foldCandidates(built);
        end
        for fq = qs
            [fEntry, fLevel, fReduction] = levelMeta(pathOrder{fq});
            fStream = struct('session', session, ...
                'retain', isKey(readers, pathOrder{fq}) && readers(pathOrder{fq}) > 0, ...
                'existing', []);
            if resuming
                fStream.existing = resumedLevel(options.resume, fq - 1, fReduction);
            end
            fSource = resolveLevelSource(session, pathOrder{fq}, fEntry, fLevel, options, docByPath);
            fSource.folded = true;
            one = struct('entry', fEntry, 'level', fLevel, 'levelIndex', fq - 1, ...
                'reductionFn', fReduction, 'source', fSource, 'stream', fStream, ...
                'chunks', levelChunks{fq}, 'grid', levelGrids{fq}, ...
                'shape', double(fLevel.shape(:).'), 'q', fq);
            if isempty(fold), fold = one; else, fold(end+1) = one; end %#ok<AGROW> a level or two
            fprintf(['[makePyramid] Level %d/%d (%s, %s) is built during this ' ...
                'level, from the same reads of the slices.\n'], fq, numel(pathOrder), ...
                char(fEntry.name), fReduction);
        end

        % A TWIN (when not folded): a later level reduced from the same
        % slices with the same chunk grid, by another reduction (the max
        % ladder's level 1 beside the mean ladder's). Built with this one,
        % it costs no read of the slices of its own.
        twin = [];
        q = 0;
        if streaming && ~isempty(source) && strcmp(source.kind, 'reduceSmartspim')
            q = findTwin(idx);
        end
        if q > 0
            [tEntry, tLevel, tReduction] = levelMeta(pathOrder{q});
            tStream = struct('session', session, ...
                'retain', isKey(readers, pathOrder{q}) && readers(pathOrder{q}) > 0, ...
                'existing', []);
            if resuming
                tStream.existing = resumedLevel(options.resume, q - 1, tReduction);
            end
            twin = struct('entry', tEntry, 'level', tLevel, 'levelIndex', q - 1, ...
                'reductionFn', tReduction, ...
                'source', resolveLevelSource(session, pathOrder{q}, tEntry, tLevel, ...
                    options, docByPath), ...
                'stream', tStream);
            fprintf(['[makePyramid] Level %d/%d (%s, %s) is built with it, ' ...
                'from the same reads of the slices.\n'], q, numel(pathOrder), ...
                char(tEntry.name), tReduction);
        end
        [levelDocs{idx}, doneChunks, twinDoc, foldDocs] = makeOneLevel(session, pyramidDoc, ...
            entry, level, idx - 1, reductionFn, options, ...
            levelChunks{idx}, levelGrids{idx}, ...
            doneChunks, totalChunks, source, stream, twin, fold);
        docByPath(p) = levelDocs{idx};
        for fk = 1:numel(foldDocs)
            if ~isempty(foldDocs{fk})
                fq = fold(fk).q;
                levelDocs{fq} = foldDocs{fk};
                docByPath(pathOrder{fq}) = foldDocs{fk};
                built(fq) = true;
            end
        end
        if ~isempty(twinDoc)
            levelDocs{q} = twinDoc;
            docByPath(pathOrder{q}) = twinDoc;
            built(q) = true;
        end
        % The level this one was reduced from may now be finished with.
        from = reducedFrom(options.levelSources, p);
        if streaming && ~isempty(from)
            readers(from) = readers(from) - 1;
            if readers(from) == 0
                session.releaseMembers(docByPath(from));
            end
        end
    end
    if streaming
        % The label without "(uploading)", in place once every chunk is in.
        pyramidDoc = pyramidDoc.setproperties('lightsheetZarrPyramid.label', label);
        session.replaceOnCommit(pyramidDoc);
    end
    options.profiler.finish();
    reportProgress(options.progressFcn, max(doneChunks, totalChunks), ...
        max(totalChunks, 1), 'Done.');

    function [entry, level, reductionFn] = levelMeta(path)
    % The pyramid entry, level and reduction name of level PATH.
        lmRep = representative(path);
        entry = pyramids(lmRep.entryIdx);
        level = entry.levels(lmRep.levelIdx);
        lmReds = pathReductions(path);
        if numel(lmReds) > 1
            reductionFn = 'none';
        else
            reductionFn = lmReds{1};
        end
    end

    function qs = foldCandidates(done)
    % The levels that can be built during level 0 (pathOrder{1}, read from
    % the slices): later, not DONE, block-reduced straight from the same
    % slices of level 0's shape, all with one factor and one chunk shape,
    % and with a read region (planFoldCells) of at most 8 GB.
        qs = [];
        if ~isa(options.levelSources, 'containers.Map') || ...
                ~isKey(options.levelSources, pathOrder{1}), return; end
        fcZero = options.levelSources(pathOrder{1});
        if ~strcmp(fcZero.kind, 'smartspim'), return; end
        fcRep = representative(pathOrder{1});
        fcShape = double(pyramids(fcRep.entryIdx).levels(fcRep.levelIdx).shape(:).');
        fcFactor = [];
        fcChunks = [];
        for fcK = 2:numel(pathOrder)
            if done(fcK) || ~isKey(options.levelSources, pathOrder{fcK}), continue; end
            fcSrc = options.levelSources(pathOrder{fcK});
            if ~strcmp(fcSrc.kind, 'reduceSmartspim') || ...
                    ~isequal(fcSrc.slicePaths, fcZero.slicePaths) || ...
                    ~isequal(double(fcSrc.fromShape(:).'), fcShape)
                continue
            end
            fcF = double(fcSrc.factor(:).');
            if isempty(fcFactor)
                fcFactor = fcF;
                fcChunks = levelChunks{fcK};
                fcL = arrayfun(@(a) lcm(levelChunks{1}(a), fcChunks(a) * fcF(a)), 1:numel(fcF));
                if prod(min(fcL, fcShape)) * elementSizeBytes(char(fcZero.dtype)) > 8 * 2^30
                    return      % too big a region to hold: build them afterwards
                end
            elseif ~isequal(fcF, fcFactor) || ~isequal(levelChunks{fcK}, fcChunks)
                continue
            end
            qs(end+1) = fcK; %#ok<AGROW>
        end
    end

    function q = findTwin(i)
    % The first later, unbuilt level that reads the same slices as level
    % I, with the same factor and chunk grid, by another reduction; 0 if
    % none.
        q = 0;
        if ~isa(options.levelSources, 'containers.Map'), return; end
        ftMine = options.levelSources(pathOrder{i});
        for ftK = i+1:numel(pathOrder)
            if built(ftK) || ~isKey(options.levelSources, pathOrder{ftK}), continue; end
            ftOther = options.levelSources(pathOrder{ftK});
            if strcmp(ftOther.kind, 'reduceSmartspim') && ~strcmp(ftOther.reduction, ftMine.reduction) && ...
                    isequal(double(ftOther.factor(:).'), double(ftMine.factor(:).')) && ...
                    isequal(double(ftOther.fromShape(:).'), double(ftMine.fromShape(:).')) && ...
                    isequal(ftOther.slicePaths, ftMine.slicePaths) && ...
                    isequal(levelChunks{ftK}, levelChunks{i}) && ...
                    isequal(levelGrids{ftK}, levelGrids{i})
                q = ftK;
                return
            end
        end
    end
end

function d = resumedLevel(resume, levelIndex, reductionFn)
% The level document an earlier run declared for this level, or [].
    d = [];
    for k = 1:numel(resume.levelDocs)
        lp = resume.levelDocs{k}.document_properties.lightsheetZarrLevel;
        if double(lp.level) == levelIndex && strcmp(char(lp.reduction_function), reductionFn)
            d = resume.levelDocs{k};
            return
        end
    end
end

function from = reducedFrom(levelSources, p)
% The level path P is block-reduced from, or '' when it is read from
% elsewhere (a store, or slices).
    from = '';
    if isKey(levelSources, p)
        src = levelSources(p);
        if strcmp(src.kind, 'reduce')
            from = char(src.fromPath);
        end
    end
end

function [levelDoc, doneChunks, twinDoc, foldDocs] = makeOneLevel(session, pyramidDoc, pyramidEntry, level, levelIndex, reductionFn, options, chunks, chunkGrid, doneChunks, totalChunks, source, stream, twin, fold)
% MAKEONELEVEL - declare (or adopt) one level, and build its chunks
%
%   TWIN, when not empty, is another level built from the SAME reads: a
%   struct with fields entry, level, levelIndex, reductionFn, source and
%   stream, for a level with the same chunk grid reduced from the same
%   slices by another reduction (the max ladder's level 1 beside the
%   mean ladder's). Both are declared, each region of the slices is read
%   once and reduced both ways, and both levels' chunks are sent. TWINDOC
%   is the twin's level document, or [] when the twin was not built here
%   (it had nothing left to send, or this level had nothing left, in
%   which case the caller builds the twin on its own).
    if nargin < 14, twin = []; end
    if nargin < 15, fold = []; end
    twinDoc = [];
    foldDocs = cell(1, numel(fold));
    [levelDoc, stream, doneChunks, complete, tmpRoot] = prepareLevel(session, ...
        pyramidDoc, pyramidEntry, level, levelIndex, reductionFn, options, ...
        chunks, chunkGrid, doneChunks, source, stream);
    if complete
        return      % the folded levels, if any, are built on their own later
    end
    % FOLDED levels (built from this level's reads): declare or adopt
    % each; one with nothing left to send is simply recorded.
    keepFold = true(1, numel(fold));
    foldCleaners = cell(1, numel(fold));
    for k = 1:numel(fold)
        [fDoc, fStream, doneChunks, fComplete, fTmp] = prepareLevel(session, ...
            pyramidDoc, fold(k).entry, fold(k).level, fold(k).levelIndex, ...
            fold(k).reductionFn, options, fold(k).chunks, fold(k).grid, ...
            doneChunks, fold(k).source, fold(k).stream);
        foldDocs{k} = fDoc;
        if fComplete
            keepFold(k) = false;
        else
            fold(k).stream = fStream;
            foldCleaners{k} = onCleanup(@() cleanupTmp(fTmp));
        end
    end
    fold = fold(keepFold);
    foldAt = find(keepFold);
    if ~isempty(fold)
        twin = [];      % the folded levels include any twin
    end
    if ~isempty(twin)
        [tDoc, tStream, doneChunks, tComplete, tTmp] = prepareLevel(session, ...
            pyramidDoc, twin.entry, twin.level, twin.levelIndex, twin.reductionFn, ...
            options, chunks, chunkGrid, doneChunks, twin.source, twin.stream);
        if tComplete
            twinDoc = tDoc;     % already all in the cloud: nothing to co-build
            twin = [];
        else
            twin.stream = tStream;
            twin.levelDoc = tDoc;
            twinCleaner = onCleanup(@() cleanupTmp(tTmp));
        end
    end
    tmpCleaner = onCleanup(@() cleanupTmp(tmpRoot));
    if options.materializeChunks
        levelLabel = sprintf('Level %d (%s)', levelIndex, reductionFn);
        if ~isempty(twin)
            levelLabel = sprintf('Level %d (%s+%s)', levelIndex, reductionFn, twin.reductionFn);
        end
        if ~isempty(fold)
            levelLabel = sprintf('Level %d (%s) + level %d (%s)', levelIndex, reductionFn, ...
                fold(1).levelIndex, strjoin({fold.reductionFn}, ', '));
        end
        [levelDoc, tmpRoot, doneChunks] = attachChunkFiles(levelDoc, ...
            source, level, chunks, chunkGrid, ...
            options.codec, options.clevel, ...
            options.progressFcn, doneChunks, totalChunks, levelLabel, ...
            options.numWorkers, options.prefetchBytes, options.asyncPrefetch, ...
            options.debugLog, stream, options.profiler, twin, options.readWorkers, ...
            options.splitReadsWithoutPool, fold);
        for k = 1:numel(fold)
            foldDocs{foldAt(k)} = fold(k).stream.levelDoc;
        end
        if isempty(stream)
            tmpCleaner = onCleanup(@() cleanupTmp(tmpRoot));
        end
        if ~isempty(twin)
            twinDoc = twin.levelDoc;
        end
    end

    if isempty(stream)
        session.database_add(levelDoc);
    end
end

function [levelDoc, stream, doneChunks, complete, tmpRoot] = prepareLevel(session, pyramidDoc, pyramidEntry, level, levelIndex, reductionFn, options, chunks, chunkGrid, doneChunks, source, stream)
% PREPARELEVEL - the level's document, declared to a streaming target
% (or, resuming, adopted from it with the chunks it still lacks in
% stream.only). COMPLETE is true when a resumed level has every chunk.
    complete = false;
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
        'dtype', ndi.fun.doc.lightsheet.dtypeName(level.dtype, 'zarr'), ...
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
    if ~isempty(stream)
        tmpRoot = tempname;
        mkdir(tmpRoot);
        nChunks = prod(chunkGrid);
        if ~isempty(stream.existing)
            % Resuming: the level is already in the cloud with every
            % chunk's uid. Build only the chunks it does not have yet.
            levelDoc = stream.existing;
            session.adopt(levelDoc);
            stream.only = session.missingMembers(levelDoc, 'chunk.bin');
            if isempty(stream.only)
                doneChunks = doneChunks + nChunks * chunkWeight(source);
                cleanupTmp(tmpRoot);
                complete = true;
                return
            end
            fprintf('[makePyramid] Resuming: %d of %d chunks still to send.\n', ...
                numel(stream.only), nChunks);
            doneChunks = doneChunks + (nChunks - numel(stream.only)) * chunkWeight(source);
        else
            % Declare the level before building it: every chunk gets its
            % uid now, in the manifest, from the path it will be written
            % to (the names padEncodeAndWrite uses). The target uploads the
            % level document and manifest, then takes each chunk as it is
            % written.
            planned = arrayfun(@(i) fullfile(tmpRoot, sprintf('chunk_%d.bin', i)), ...
                1:nChunks, 'UniformOutput', false);
            levelDoc = levelDoc.addFileSeries('chunk.bin', planned, 'indices', 1:nChunks);
            session.declare(levelDoc);
            stream.only = [];
        end
        stream.levelDoc = levelDoc;
        stream.tmpRoot = tmpRoot;
    end
end

function [levelDoc, tmpRoot, doneChunks] = attachChunkFiles(levelDoc, source, level, chunks, chunkGrid, codec, clevel, progressFcn, doneChunks, totalChunks, levelLabel, numWorkers, prefetchBytes, asyncPrefetch, debugLog, stream, profiler, twin, readWorkers, splitWithoutPool, fold)
% Read the source zarr level as a whole array, then re-tile into the
% level document's chunk shape and attach each chunk as chunk.bin_<idx>
% (1-based, C-order over chunkGrid). Files are ingested into DID, which
% deletes the temp original as it copies -- so we build each chunk in a
% new tempname and hand it to add_file. SOURCE (see resolveLevelSource)
% says where the level's bytes are read from.

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

    % 1-based linear index goes into the chunk.bin_# filename. A
    % streamed level was declared with paths in a folder made for it.
    if isempty(stream)
        tmpRoot = tempname;
        mkdir(tmpRoot);
    else
        tmpRoot = stream.tmpRoot;
    end
    % No onCleanup here: tmpRoot is returned so the CALLER can register
    % the cleanup AFTER session.database_add has ingested the files. If
    % we cleaned up on return, database_add would find the paths already
    % deleted.
    linearOrder = allChunkIndices(chunkGrid);   % rows are (c1, c2, c3, ...) 1-based
    nChunks = size(linearOrder, 1);
    typesize = elementSizeBytes(char(level.dtype));

    % Locations for the whole level. Filled in as each super-block
    % completes; handed to did.document.addFileSeries ONCE at the end
    % of the level. Per-chunk add_file returned a fresh levelDoc every
    % call, and 40k value-semantics reassignments of a growing struct
    % churned through many GB of allocations even though the final
    % series entry is small -- the bulk method installs all locations
    % in one struct-array assignment, and the observed memory blow-up
    % goes away.
    seriesLocations = cell(1, nChunks);

    % BATCHED SERIAL-READ / PARALLEL-COMPRESS. On a slow spinning drive
    % we cannot afford concurrent seeks, so reads stay strictly serial;
    % but Zstd at clevel=9 is single-core CPU-bound and easy to fan out
    % across a parallel pool. A batch of `poolSize` chunks is read from
    % the source, then handed to the workers to compress and write, in
    % parallel; each chunk's tempfile path is parked in seriesLocations
    % and installed into the level document via a SINGLE
    % did.document.addFileSeries call after the super-block loop exits.
    % poolSize == 1 is the original serial path with no toolbox
    % dependency.
    %
    % READERS OF THEIR OWN. The next region's slices are read on pool
    % workers while this one compresses (ASYNC PIPELINE below), and a read
    % over the network holds its worker for most of a batch while using
    % little CPU. In a pool of numWorkers, those readers left the
    % compression a few workers (CPU 70% idle, workers busy 60% of the
    % compress time), so a pool reading slices in parallel gets
    % readWorkers more workers, and the compression is held to numWorkers
    % of them (encodeBlock's parfor).
    wanted = numWorkers;
    if numWorkers > 1 && asyncPrefetch && readWorkers > 1 && ...
            any(strcmp(source.kind, {'smartspim', 'reduceSmartspim'}))
        wanted = numWorkers + readWorkers;
    end
    poolSize = resolveParallelPool(wanted);
    if wanted > numWorkers && poolSize > 1
        poolSize = min(poolSize, numWorkers);
        fprintf(['[makePyramid] Pool of %d workers: %d compress, %d read the ' ...
            'next region''s slices meanwhile.\n'], wanted, poolSize, readWorkers);
    end

    % How many target chunks fit inside the prefetch budget, sized
    % by uncompressed chunk bytes. Never smaller than the parfor
    % pool (a super-block below poolSize would leave workers idle);
    % never larger than the level itself.
    chunkBytes = prod(chunks) * typesize;
    % A reduced level reads prod(factor) source voxels per output voxel
    % (and holds them as single while reducing, 2x a uint16), so its
    % read buffer is that much bigger than the output region. Shrink
    % the budget to match, so peak memory stays near prefetchBytes.
    amplification = readAmplification(source, typesize);
    prefetchBytes = double(prefetchBytes) / amplification;
    prefetchChunkCount = max(poolSize, ...
        floor(double(prefetchBytes) / max(chunkBytes, 1)));
    prefetchChunkCount = min(prefetchChunkCount, nChunks);

    % Plan every super-block up front (chunk indices + per-chunk lo/hi
    % + union bbox) so the async pipeline can dispatch the next read
    % while the current one is still compressing.
    %
    % ROWS, NOT RUNS. A super-block is made of whole rows of chunks along
    % the fastest axis (x), never part of one: a SmartSPIM slice is read
    % in strips that span its whole width, so a super-block holding half
    % a row would read those strips, and the next super-block would read
    % them again; one that wrapped from the end of one row to the start
    % of the next had a bounding box of two whole rows. Rows are stacked
    % (within one plane, so the box stays tight) up to the budget; a row
    % bigger than twice the budget is split into equal parts. See
    % planSuperBlocks.
    if nargin >= 21 && ~isempty(fold)
        % Level 0 with the levels folded into it: regions planned for all
        % of them (see buildFolded). Up to 4x the usual read budget, since
        % one read now serves several levels.
        doneChunks = buildFolded(source, shape, chunks, chunkGrid, typesize, ...
            stream, fold, codec, clevel, poolSize, readWorkers, asyncPrefetch, ...
            4 * prefetchBytes, progressFcn, doneChunks, totalChunks, levelLabel, ...
            profiler, debugLog, splitWithoutPool, tmpRoot);
        profiler.endLevel(levelLabel);
        return
    end
    superBlocks = planSuperBlocks(linearOrder, chunks, chunkGrid, shape, ...
        prefetchChunkCount);
    nSuperBlocks = numel(superBlocks);
    % Resuming a streamed level: keep only the chunks still to send, in
    % the same super-blocks (same reads), and drop blocks left empty.
    % With a TWIN (a level built from the same reads; see makeOneLevel)
    % a chunk is kept when either level still needs it; sb.mine and
    % sb.theirs say which of the kept chunks each level takes.
    hasTwin = ~isempty(twin);
    onlyMine = [];
    onlyTwin = [];
    if ~isempty(stream), onlyMine = stream.only; end
    if hasTwin, onlyTwin = twin.stream.only; end
    keepBlock = false(1, nSuperBlocks);
    for b = 1:nSuperBlocks
        sb = superBlocks{b};
        mine = true(size(sb.idxs));
        if ~isempty(onlyMine), mine = ismember(sb.idxs, onlyMine); end
        theirs = false(size(sb.idxs));
        if hasTwin
            theirs = true(size(sb.idxs));
            if ~isempty(onlyTwin), theirs = ismember(sb.idxs, onlyTwin); end
        end
        keep = mine | theirs;
        if ~any(keep), continue; end
        sb.idxs = sb.idxs(keep);
        sb.loRows = sb.loRows(keep, :);
        sb.hiRows = sb.hiRows(keep, :);
        sb.loBBox = min(sb.loRows, [], 1);
        sb.hiBBox = max(sb.hiRows, [], 1);
        sb.mine = mine(keep);
        sb.theirs = theirs(keep);
        superBlocks{b} = sb;
        keepBlock(b) = true;
    end
    superBlocks = superBlocks(keepBlock);
    nSuperBlocks = numel(superBlocks);

    % WHAT IS READ. One region of the source per super-block; with a twin,
    % one region of the slices, reduced both ways (readSmartSpimPairRegion).
    readSource = source;
    if hasTwin
        readSource = struct('kind', 'reduceSmartspimPair', ...
            'slicePaths', {source.slicePaths}, 'sourceDtype', source.sourceDtype, ...
            'fromShape', source.fromShape, 'factor', source.factor, ...
            'reductions', {{source.reduction, twin.source.reduction}}, ...
            'dtypes', {{source.dtype, twin.source.dtype}});
    end
    % PARALLEL READS. Slices are read one file at a time, and over a
    % network each file costs a round trip, so a super-block of slices
    % is read as nReaders slabs along z, each on its own pool worker
    % (see startRead). Other sources are read in one piece.
    nReaders = 1;
    if any(strcmp(source.kind, {'smartspim', 'reduceSmartspim'}))
        nReaders = max(1, min(poolSize, readWorkers));
    end

    % ASYNC PIPELINE. If a parpool is available and asyncPrefetch is
    % on, the next super-block's read runs concurrently on pool
    % workers while the parfor is compressing the current one. Total
    % time approaches max(read_time, compress_time) instead of their
    % sum. Peak RAM ~ 2 * prefetchBytes (two blocks in flight).
    useAsync = asyncPrefetch && poolSize > 1 && nSuperBlocks > 1;
    if useAsync
        pool = gcp();
        nextRead = startRead(pool, readSource, superBlocks{1}.loBBox, ...
            superBlocks{1}.hiBBox, nReaders);
    end

    for s = 1:nSuperBlocks
        sb = superBlocks{s};
        tBlock = tic;

        % ---- READ current super-block, DISPATCH the next -----------
        tStep = tic;
        if useAsync
            tiles = finishRead(nextRead);
            if s < nSuperBlocks
                nb = superBlocks{s + 1};
                nextRead = startRead(pool, readSource, nb.loBBox, nb.hiBBox, nReaders);
            end
        elseif splitWithoutPool && any(strcmp(source.kind, {'smartspim', 'reduceSmartspim'}))
            tiles = finishRead(startRead([], readSource, sb.loBBox, sb.hiBBox, readWorkers));
        else
            tiles = readTiles(readSource, sb.loBBox, sb.hiBBox);
        end
        tReadWait = toc(tStep);

        % ---- ASSEMBLE AND COMPRESS (this level, and the twin) -------
        [mPaths, mIdxs, tm] = encodeBlock(tiles{1}, sb, sb.mine, chunks, shape, ...
            codec, clevel, typesize, tmpRoot, poolSize);
        tPaths = {};
        tIdxs = [];
        if hasTwin
            [tPaths, tIdxs, tt] = encodeBlock(tiles{2}, sb, sb.theirs, chunks, shape, ...
                codec, clevel, typesize, twin.stream.tmpRoot, poolSize);
            tm.assemble = tm.assemble + tt.assemble;
            tm.compress = tm.compress + tt.compress;
            tm.workerBusy = tm.workerBusy + tt.workerBusy;
            tm.mbOut = tm.mbOut + tt.mbOut;
        end
        clear tiles;

        % ---- ACCUMULATE, DO NOT MUTATE levelDoc PER SUPER-BLOCK ---
        % Each chunk's tempfile path is parked in seriesLocations and
        % installed in ONE addFileSeries call after the loop (a local
        % target); a streaming target takes the files now.
        preAddDocSize = levelDocPropertyBytes(levelDoc);
        for j = 1:numel(mIdxs)
            seriesLocations{mIdxs(j)} = mPaths{j};
        end
        tStep = tic;
        before = sessionTiming(stream);
        if ~isempty(stream) && ~isempty(mIdxs)
            % Off this disk as soon as the target has them.
            stream.session.streamMembers(stream.levelDoc, 'chunk.bin', ...
                mIdxs, mPaths, stream.retain);
        end
        if hasTwin && ~isempty(tIdxs)
            twin.stream.session.streamMembers(twin.stream.levelDoc, 'chunk.bin', ...
                tIdxs, tPaths, twin.stream.retain);
        end
        tUpload = toc(tStep);
        after = sessionTiming(stream);
        postAddDocSize = preAddDocSize;
        nDone = numel(mIdxs) + numel(tIdxs);
        doneChunks = doneChunks + nDone * chunkWeight(source);
        tStep = tic;
        reportProgress(progressFcn, doneChunks, totalChunks, ...
            sprintf('%s: super-block %d/%d, chunk %d/%d', ...
                levelLabel, s, nSuperBlocks, sb.idxs(end), nChunks));
        tProgress = toc(tStep);
        bboxMB = prod(double(sb.hiBBox - sb.loBBox + 1)) * typesize / 2^20;
        profiler.add(struct('level', levelLabel, 'superblock', s, ...
            'nSuperBlocks', nSuperBlocks, 'chunks', nDone, ...
            'workers', max(1, min(poolSize, max(numel(mIdxs), numel(tIdxs)))), ...
            'mbRead', bboxMB * amplification, ...
            'mbChunks', nDone * prod(chunks) * typesize / 2^20, 'mbOut', tm.mbOut, ...
            'readWait', tReadWait, 'assemble', tm.assemble, 'compress', tm.compress, ...
            'workerBusy', tm.workerBusy, 'upload', tUpload, ...
            'urls', after.urls - before.urls, 'stage', after.stage - before.stage, ...
            'send', after.send - before.send, 'verify', after.verify - before.verify, ...
            'progress', tProgress, 'total', toc(tBlock)));
        appendDebugLog(debugLog, levelLabel, s, nSuperBlocks, doneChunks, ...
            totalChunks, preAddDocSize, postAddDocSize, bboxMB);
    end

    % ---- ONE BULK addFileSeries CALL FOR THE WHOLE LEVEL ---------
    % did.document.addFileSeries installs the whole cellstr of source
    % paths in a single struct-array assignment. The level document's
    % file-series manifest names the series `chunk.bin_#`; `indices`
    % supplies the 1..N chunk numbering that DID substitutes for `#`
    % in each stored location. No per-chunk copy-on-write.
    % DID convention: the series MANIFEST name is bare ("chunk.bin"), not
    % the "_#" pattern. Members are named chunk.bin_1 ... chunk.bin_N
    % automatically. See did.document.seriesNames docstring for the
    % contract. The schema declares "chunk.bin" in both file_list and
    % file_series.
    if isempty(stream)
        levelDoc = levelDoc.addFileSeries('chunk.bin', seriesLocations, ...
            'indices', 1:nChunks);
    end
    profiler.endLevel(levelLabel);
end

function [tempPaths, chunkIdxs, t] = encodeBlock(bigTile, sb, sel, chunks, shape, codec, clevel, typesize, tmpRoot, poolSize)
% ENCODEBLOCK - cut a super-block's region into its chunks (those SEL
% picks) and compress each to a file in TMPROOT, in parallel
%
%   Returns the files, their chunk indices, and timings (assemble,
%   compress, workerBusy, mbOut).
%
%   The chunks go into a plain typed array, one column per chunk, so the
%   parfor slices it and each worker receives only its column (handing
%   the parfor a cell of sub-arrays made it broadcast the whole region
%   to every worker, which ran 64 GB machines out of memory). Assigning
%   each chunk's occupied part into a zeroed slab pads edge chunks.
    t = struct('assemble', 0, 'compress', 0, 'workerBusy', 0, 'mbOut', 0);
    rows = find(sel);
    bs = numel(rows);
    tempPaths = cell(1, bs);
    chunkIdxs = zeros(1, bs);
    if bs == 0, return; end
    t0 = tic;
    srcClass  = class(bigTile);
    bigChunks = zeros([chunks(:).' bs], srcClass);
    for j = 1:bs
        r = rows(j);
        chunkIdxs(j) = sb.idxs(r);
        srcSubs = cell(1, numel(shape));
        dstSubs = cell(1, numel(chunks));
        for a = 1:numel(shape)
            srcSubs{a} = (sb.loRows(r, a) - sb.loBBox(a) + 1) : ...
                         (sb.hiRows(r, a) - sb.loBBox(a) + 1);
            dstSubs{a} = 1:numel(srcSubs{a});
        end
        slabAssign = [dstSubs, {j}];
        bigChunks(slabAssign{:}) = bigTile(srcSubs{:});
    end
    bigChunksFlat = reshape(bigChunks, prod(chunks), bs);
    clear bigChunks;
    chunkShape1 = chunks(:).';
    chunkSecs = zeros(1, bs);
    t.assemble = toc(t0);
    t0 = tic;
    if poolSize > 1 && bs > 1
        % At most POOLSIZE workers, so the pool's readers stay free to read.
        parfor (j = 1:bs, poolSize)
            c0 = tic;
            col = bigChunksFlat(:, j);
            tile = reshape(col, chunkShape1);
            tempPaths{j} = padEncodeAndWrite(tile, chunks, ...
                codec, clevel, typesize, tmpRoot, chunkIdxs(j));
            chunkSecs(j) = toc(c0);
        end
    else
        for j = 1:bs
            c0 = tic;
            col = bigChunksFlat(:, j);
            tile = reshape(col, chunkShape1);
            tempPaths{j} = padEncodeAndWrite(tile, chunks, ...
                codec, clevel, typesize, tmpRoot, chunkIdxs(j));
            chunkSecs(j) = toc(c0);
        end
    end
    t.compress = toc(t0);
    t.workerBusy = sum(chunkSecs);
    for j = 1:bs
        d = dir(tempPaths{j});
        if ~isempty(d), t.mbOut = t.mbOut + d.bytes / 2^20; end
    end
end

function rd = startRead(pool, src, lo, hi, nParts, align)
% STARTREAD - read region [lo, hi] as up to NPARTS slabs along z (axis 3:
% t,c,z,y,x), each on its own pool worker; FINISHREAD puts them together.
% With POOL empty the slabs are read here, one after another (a test of
% the split and join where no pool can be had).
    if nargin < 6, align = 1; end
    [plo, phi] = splitAlongZ(lo, hi, nParts, align);
    rd = cell(1, numel(plo));
    for k = 1:numel(plo)
        if isempty(pool)
            rd{k} = struct('value', {readTiles(src, plo{k}, phi{k})});
        else
            rd{k} = parfeval(pool, @readTiles, 1, src, plo{k}, phi{k});
        end
    end
end

function tiles = finishRead(rd)
% FINISHREAD - wait for STARTREAD's slabs and join them along z
    parts = cell(1, numel(rd));
    for k = 1:numel(rd)
        if isstruct(rd{k})
            parts{k} = rd{k}.value;
        else
            parts{k} = fetchOutputs(rd{k});
        end
    end
    tiles = cell(1, numel(parts{1}));
    for i = 1:numel(tiles)
        pieces = cell(1, numel(parts));
        for k = 1:numel(parts)
            pieces{k} = parts{k}{i};
        end
        tiles{i} = cat(3, pieces{:});
    end
end

function [plo, phi] = splitAlongZ(lo, hi, nParts, align)
% Region [lo, hi] as up to nParts contiguous, nonempty slabs along axis 3,
% each starting ALIGN voxels apart from lo (a reduction's block size, so a
% slab can be reduced on its own and give the same voxels).
    if nargin < 4, align = 1; end
    if numel(lo) < 3 || nParts <= 1
        plo = {lo};
        phi = {hi};
        return
    end
    len = hi(3) - lo(3) + 1;
    nBlocks = ceil(len / align);
    n = min(nParts, nBlocks);
    edges = lo(3) - 1 + min(round(linspace(0, nBlocks, n + 1)) * align, len);
    plo = cell(1, n);
    phi = cell(1, n);
    for k = 1:n
        plo{k} = lo;
        phi{k} = hi;
        plo{k}(3) = edges(k) + 1;
        phi{k}(3) = edges(k + 1);
    end
end

function tiles = readTiles(src, lo, hi)
% READTILES - the region(s) a super-block needs, as a cell: one tile, or,
% for a pair of levels reduced from the same slices, one per level.
    if strcmp(src.kind, 'reduceSmartspimPair')
        tiles = readSmartSpimPairRegion(src, lo, hi);
    elseif strcmp(src.kind, 'smartspimFold')
        tiles = readSmartSpimFoldRegion(src, lo, hi);
    else
        tiles = {readSuperBlockRegion(src, lo, hi)};
    end
end

function out = readSmartSpimPairRegion(source, lo, hi)
% READSMARTSPIMPAIRREGION - region [lo, hi] of two levels block-reduced
% from the same SmartSPIM slices by different reductions (mean, max):
% the slices are read once and reduced both ways, exactly as
% readSmartSpimReducedRegion reduces each.
    f = source.factor;
    srcLo = (lo - 1) .* f + 1;
    srcHi = min(hi .* f, source.fromShape);
    src = readSmartSpimRegion(struct('slicePaths', {source.slicePaths}, ...
        'dtype', source.sourceDtype), srcLo, srcHi);
    out = cell(1, numel(source.reductions));
    for k = 1:numel(source.reductions)
        out{k} = ndi.fun.doc.lightsheet.reduceBlocks(src, f, ...
            source.reductions{k}, source.dtypes{k});
    end
end

function doneChunks = buildFolded(source, shape, chunks, ~, typesize, stream, fold, codec, clevel, poolSize, readWorkers, asyncPrefetch, budgetBytes, progressFcn, doneChunks, totalChunks, levelLabel, profiler, debugLog, splitWithoutPool, tmpRoot)
% BUILDFOLDED - level 0 and the levels FOLD lists, from ONE read of the slices
%
%   FOLD is a struct array of levels block-reduced straight from the same
%   SmartSPIM slices (level 1 of the mean and max ladders): fields
%   source (reduceSmartspim), chunks, grid, shape and stream. Each read
%   is a region of level 0 that holds whole level-0 chunks AND whole
%   chunks of every folded level (see planFoldCells); its level-0 chunks
%   are cut from it as usual, and it is block-reduced to each folded
%   level exactly as readSmartSpimReducedRegion would reduce the same
%   voxels (ndi.fun.doc.lightsheet.reduceBlocks), so every byte is what a
%   separate pass would make. On resume a region is read if any level
%   still lacks a chunk in it, and each level is sent only what it lacks.
    nFold = numel(fold);
    f = double(fold(1).source.factor(:).');
    cells = planFoldCells(shape, chunks, fold(1).chunks, fold(1).shape, f, ...
        budgetBytes, typesize);

    % Which chunks of each cell each level still needs.
    keep = false(1, numel(cells));
    for b = 1:numel(cells)
        c = cells{b};
        c.mine = true(size(c.idxs));
        if ~isempty(stream.only), c.mine = ismember(c.idxs, stream.only); end
        c.sel = cell(1, nFold);
        any1 = false;
        for k = 1:nFold
            c.sel{k} = true(size(c.L1.idxs));
            if ~isempty(fold(k).stream.only)
                c.sel{k} = ismember(c.L1.idxs, fold(k).stream.only);
            end
            any1 = any1 || any(c.sel{k});
        end
        keep(b) = any(c.mine) || any1;
        cells{b} = c;
    end
    cells = cells(keep);
    nCells = numel(cells);
    fprintf(['[makePyramid] %d read(s) of the slices, each giving level 0 and ' ...
        '%d reduced level(s).\n'], nCells, nFold);

    readSource = struct('kind', 'smartspimFold', ...
        'slicePaths', {source.slicePaths}, 'dtype', source.dtype, 'factor', f, ...
        'reductions', {arrayfun(@(x) x.source.reduction, fold, 'UniformOutput', false)}, ...
        'dtypes', {arrayfun(@(x) x.source.dtype, fold, 'UniformOutput', false)});
    nReaders = max(1, min(poolSize, readWorkers));
    useAsync = asyncPrefetch && poolSize > 1 && nCells > 1;
    if useAsync
        pool = gcp();
        nextRead = startRead(pool, readSource, cells{1}.loBBox, cells{1}.hiBBox, ...
            nReaders, f(3));
    end
    for s = 1:nCells
        cb = cells{s};
        tBlock = tic;
        tStep = tic;
        if useAsync
            tiles = finishRead(nextRead);
            if s < nCells
                nextRead = startRead(pool, readSource, cells{s+1}.loBBox, ...
                    cells{s+1}.hiBBox, nReaders, f(3));
            end
        elseif splitWithoutPool
            tiles = finishRead(startRead([], readSource, cb.loBBox, cb.hiBBox, readWorkers, f(3)));
        else
            tiles = readTiles(readSource, cb.loBBox, cb.hiBBox);
        end
        tReadWait = toc(tStep);

        [p0, i0, tm] = encodeBlock(tiles{1}, cb, cb.mine, chunks, shape, ...
            codec, clevel, typesize, tmpRoot, poolSize);
        pk = cell(1, nFold);
        ik = cell(1, nFold);
        sb1 = struct('idxs', cb.L1.idxs, 'loRows', cb.L1.loRows, ...
            'hiRows', cb.L1.hiRows, 'loBBox', cb.L1.loBBox, 'hiBBox', cb.L1.hiBBox);
        for k = 1:nFold
            [pk{k}, ik{k}, tk] = encodeBlock(tiles{1 + k}, sb1, cb.sel{k}, ...
                fold(k).chunks, fold(k).shape, codec, clevel, ...
                elementSizeBytes(fold(k).source.dtype), fold(k).stream.tmpRoot, poolSize);
            tm.assemble = tm.assemble + tk.assemble;
            tm.compress = tm.compress + tk.compress;
            tm.workerBusy = tm.workerBusy + tk.workerBusy;
            tm.mbOut = tm.mbOut + tk.mbOut;
        end
        clear tiles;

        tStep = tic;
        before = sessionTiming(stream);
        if ~isempty(i0)
            stream.session.streamMembers(stream.levelDoc, 'chunk.bin', i0, p0, stream.retain);
        end
        for k = 1:nFold
            if ~isempty(ik{k})
                fold(k).stream.session.streamMembers(fold(k).stream.levelDoc, ...
                    'chunk.bin', ik{k}, pk{k}, fold(k).stream.retain);
            end
        end
        tUpload = toc(tStep);
        after = sessionTiming(stream);
        nDone = numel(i0) + sum(cellfun(@numel, ik));
        doneChunks = doneChunks + nDone;    % folded chunks cost no read of their own
        tStep = tic;
        reportProgress(progressFcn, doneChunks, totalChunks, ...
            sprintf('%s: read %d/%d of the slices', levelLabel, s, nCells));
        tProgress = toc(tStep);
        bboxMB = prod(double(cb.hiBBox - cb.loBBox + 1)) * typesize / 2^20;
        profiler.add(struct('level', levelLabel, 'superblock', s, ...
            'nSuperBlocks', nCells, 'chunks', nDone, ...
            'workers', max(1, min(poolSize, numel(i0))), ...
            'mbRead', bboxMB, ...
            'mbChunks', numel(i0) * prod(chunks) * typesize / 2^20, 'mbOut', tm.mbOut, ...
            'readWait', tReadWait, 'assemble', tm.assemble, 'compress', tm.compress, ...
            'workerBusy', tm.workerBusy, 'upload', tUpload, ...
            'urls', after.urls - before.urls, 'stage', after.stage - before.stage, ...
            'send', after.send - before.send, 'verify', after.verify - before.verify, ...
            'progress', tProgress, 'total', toc(tBlock)));
        appendDebugLog(debugLog, levelLabel, s, nCells, doneChunks, totalChunks, ...
            NaN, NaN, bboxMB);
    end
end

function cells = planFoldCells(shape0, c0, c1, shape1, f, budgetBytes, typesize)
% PLANFOLDCELLS - regions of level 0 that hold whole chunks of level 0
% (chunk shape C0) and of a level reduced from it by F (chunk shape C1)
%
%   Along each axis a cell is L = lcm(C0, C1.*F) voxels of level 0, so it
%   starts on a level-0 chunk boundary and on a reduced-level chunk
%   boundary; whole cells are grouped along x (the last axis) up to
%   BUDGETBYTES (at least one), since a slice is read in full-width
%   strips. Each cell lists its level-0 chunks (idxs, loRows, hiRows,
%   loBBox, hiBBox, linear C-order ids as allChunkIndices numbers them)
%   and, in L1, the reduced level's chunks in that level's coordinates.
%   Cells are in C order (x groups fastest).
    nd = numel(shape0);
    shape0 = double(shape0(:).'); shape1 = double(shape1(:).');
    c0 = double(c0(:).'); c1 = double(c1(:).'); f = double(f(:).');
    L = arrayfun(@(a) lcm(c0(a), c1(a) * f(a)), 1:nd);
    nCell = ceil(shape0 ./ L);
    cellBytes = prod(min(L, shape0)) * typesize;
    gx = max(1, min(nCell(nd), floor(budgetBytes / max(cellBytes, 1))));
    nCell(nd) = ceil(nCell(nd) / gx);
    span = ones(1, nd);
    span(nd) = gx;
    grid0 = ceil(shape0 ./ c0);
    grid1 = ceil(shape1 ./ c1);
    total = prod(nCell);
    cells = cell(1, total);
    sub = cell(1, nd);
    for t = 1:total
        % C order: last axis fastest.
        [sub{nd:-1:1}] = ind2sub(fliplr(nCell), t);
        cc = [sub{:}];
        lo0 = (cc - 1) .* L .* span + 1;
        hi0 = min(lo0 + L .* span - 1, shape0);
        L0 = chunksIn(lo0, hi0, c0, grid0, shape0);
        lo1 = (lo0 - 1) ./ f + 1;
        hi1 = min(ceil(hi0 ./ f), shape1);
        L1 = chunksIn(lo1, hi1, c1, grid1, shape1);
        cells{t} = struct('idxs', L0.idxs, 'loRows', L0.loRows, 'hiRows', L0.hiRows, ...
            'loBBox', lo0, 'hiBBox', hi0, 'L1', L1);
    end
end

function S = chunksIn(lo, hi, c, grid, shape)
% The chunks (shape C, grid GRID) of region [LO, HI], which starts on a
% chunk boundary: linear C-order ids, ascending, and each one's extent.
    nd = numel(lo);
    cLo = (lo - 1) ./ c + 1;
    cHi = ceil(hi ./ c);
    ranges = arrayfun(@(a) cLo(a):cHi(a), 1:nd, 'UniformOutput', false);
    g = cell(1, nd);
    [g{:}] = ndgrid(ranges{:});
    coords = cell2mat(cellfun(@(x) x(:), g, 'UniformOutput', false));
    strides = ones(1, nd);
    for a = nd-1:-1:1
        strides(a) = strides(a + 1) * grid(a + 1);
    end
    ids = (coords - 1) * strides(:) + 1;
    [ids, order] = sort(ids(:).');
    coords = coords(order, :);
    loRows = (coords - 1) .* c + 1;
    hiRows = min(loRows + c - 1, shape);
    S = struct('idxs', ids, 'loRows', loRows, 'hiRows', hiRows, ...
        'loBBox', lo, 'hiBBox', hi);
end

function out = readSmartSpimFoldRegion(source, lo, hi)
% READSMARTSPIMFOLDREGION - region [lo, hi] of level 0 from the slices,
% and the same voxels block-reduced by each of source.reductions: {raw,
% reduced 1, reduced 2, ...}. [lo, hi] starts on a block boundary.
    raw = readSmartSpimRegion(struct('slicePaths', {source.slicePaths}, ...
        'dtype', source.dtype), lo, hi);
    out = cell(1, 1 + numel(source.reductions));
    out{1} = raw;
    for k = 1:numel(source.reductions)
        out{1 + k} = ndi.fun.doc.lightsheet.reduceBlocks(raw, source.factor, ...
            source.reductions{k}, source.dtypes{k});
    end
end

function t = sessionTiming(stream)
% The cloud writer's running time totals (ndi.cloud.upload.SessionWriter
% timing), or zeros for a target that keeps none.
    t = struct('urls', 0, 'stage', 0, 'send', 0, 'verify', 0);
    if ~isempty(stream) && isprop(stream.session, 'timing')
        t = stream.session.timing;
    end
end

function bytes = levelDocPropertyBytes(levelDoc)
% Approximate size in bytes of levelDoc.document_properties. Uses `whos`
% on a local copy of the struct so the levelDoc object itself is not
% traversed (which would add its own overhead). Returns NaN on any
% error so instrumentation cannot break the ingest.
    bytes = NaN;
    try
        props = levelDoc.document_properties; %#ok<NASGU>
        w = whos('props');
        bytes = w.bytes;
    catch
    end
end

function appendDebugLog(path, levelLabel, s, nSuperBlocks, doneChunks, totalChunks, preBytes, postBytes, bboxMB)
% Append one line of memory diagnostics to `path`. Failures are
% swallowed; instrumentation must never take down an ingest.
    if isempty(path), return; end
    if nargin < 9, bboxMB = NaN; end
    try
        rss = matlabRSSMB();
        futCount = poolFutureCount();
        line = sprintf(['%s | %s | sb=%d/%d | chunks=%d/%d | ' ...
                        'rss_MB=%.0f | bbox_MB=%.0f | ' ...
                        'doc_pre_MB=%.2f | doc_post_MB=%.2f | ' ...
                        'doc_delta_MB=%.2f | live_futures=%d'], ...
            char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
            levelLabel, s, nSuperBlocks, ...
            doneChunks, totalChunks, rss, bboxMB, ...
            preBytes/2^20, postBytes/2^20, ...
            (postBytes - preBytes)/2^20, futCount);
        fid = fopen(path, 'a');
        if fid < 0, return; end
        cleanup = onCleanup(@() fclose(fid));
        fprintf(fid, '%s\n', line);
    catch
    end
end

function mb = matlabRSSMB()
% MATLAB's own process RSS in MB. `memory` is Windows-only; on macOS /
% Linux we shell out to `ps -o rss= -p <pid>` which prints kilobytes.
%
% PID lookup goes through Java's ManagementFactory (available in every
% MATLAB that has bundled Java): getRuntimeMXBean().getName() returns
% "PID@HOSTNAME" on every JVM implementation we care about. This
% sidesteps both matlabProcessID (R2023a+ only) and feature('getpid')
% (Code Analyzer flags as unsupported).
    mb = NaN;
    try
        rt = java.lang.management.ManagementFactory.getRuntimeMXBean();
        pidText = char(rt.getName());
        pid = str2double(strtok(pidText, '@'));
        if isnan(pid), return; end
        [rc, out] = system(sprintf('ps -o rss= -p %d', pid));
        if rc == 0
            v = sscanf(strtrim(out), '%f');
            if ~isempty(v), mb = v / 1024; end
        end
    catch
    end
end

function n = poolFutureCount()
% Number of parfeval / parfor futures the pool currently holds. This
% surfaces leaks in the async-prefetch pipeline where a future's output
% never gets released, which retains its bigTile buffer inside the pool.
    n = NaN;
    try
        p = gcp('nocreate');
        if isempty(p), n = 0; return; end
        n = numel(p.FevalQueue.QueuedFutures) + numel(p.FevalQueue.RunningFutures);
    catch
    end
end

function blocks = planSuperBlocks(linearOrder, chunks, chunkGrid, shape, budgetChunks)
% PLANSUPERBLOCKS - group a level's chunks into super-blocks of whole rows
%
%   LINEARORDER is allChunkIndices(chunkGrid): C-order, last axis (x)
%   fastest, so each run of chunkGrid(end) entries is one row along x,
%   and each run of chunkGrid(end-1) rows is one plane. A super-block is
%   up to floor(budgetChunks / rowLength) whole consecutive rows of one
%   plane (at least one row) -- its bounding box is then exactly its
%   chunks -- or, when a row is longer than twice budgetChunks, an equal
%   part of a row. Every chunk is in exactly one super-block, in linear
%   order.
    nChunks = size(linearOrder, 1);
    nd = numel(chunkGrid);
    nx = chunkGrid(nd);
    if nd >= 2
        ny = chunkGrid(nd - 1);
    else
        ny = 1;
    end
    groups = {};
    if nx <= 2 * budgetChunks
        rowsPerBlock = max(1, floor(budgetChunks / nx));
        nRows = nChunks / nx;
        r = 1;
        while r <= nRows
            planeEnd = ceil(r / ny) * ny;           % last row of r's plane
            last = min([r + rowsPerBlock - 1, planeEnd, nRows]);
            groups{end+1} = ((r - 1) * nx + 1):(last * nx); %#ok<AGROW>
            r = last + 1;
        end
    else
        k = ceil(nx / budgetChunks);
        edges = round(linspace(0, nx, k + 1));
        for r = 1:(nChunks / nx)
            for seg = 1:k
                groups{end+1} = (r - 1) * nx + ((edges(seg) + 1):edges(seg + 1)); %#ok<AGROW>
            end
        end
    end
    blocks = cell(1, numel(groups));
    for g = 1:numel(groups)
        idxs = groups{g};
        lo = zeros(numel(idxs), numel(shape));
        hi = zeros(numel(idxs), numel(shape));
        for j = 1:numel(idxs)
            c = linearOrder(idxs(j), :);
            for a = 1:nd
                lo(j, a) = (c(a) - 1) * chunks(a) + 1;
                hi(j, a) = min(lo(j, a) + chunks(a) - 1, shape(a));
            end
        end
        blocks{g} = struct('idxs', idxs, 'loRows', lo, 'hiRows', hi, ...
            'loBBox', min(lo, [], 1), 'hiBBox', max(hi, [], 1));
    end
end

function bigTile = readSuperBlockRegion(source, loBBox, hiBBox)
% READSUPERBLOCKREGION - fetch one super-block region [loBBox, hiBBox]
%
%   Dispatches on SOURCE.kind (see resolveLevelSource). Kept as a plain
%   subfunction (not nested), and every source carries file paths
%   rather than a session, so parfeval can run it on a pool worker
%   without pulling the caller's workspace or a database handle.
    switch source.kind
        case 'omezarr'
            bigTile = ndr.format.omezarr.readArray(source.zarrPath, ...
                source.pyramidName, source.kInEntry, ...
                'Region', [loBBox; hiBBox]);
        case 'smartspim'
            bigTile = readSmartSpimRegion(source, loBBox, hiBBox);
        case 'reduce'
            bigTile = readReducedRegion(source, loBBox, hiBBox);
        case 'reduceSmartspim'
            bigTile = readSmartSpimReducedRegion(source, loBBox, hiBBox);
        otherwise
            error('NDI:lightsheet:makePyramid:unknownSourceKind', ...
                'Unknown level source kind ''%s''.', source.kind);
    end
end

function source = resolveLevelSource(session, p, entry, level, options, docByPath)
% RESOLVELEVELSOURCE - the self-contained read recipe for level path P
%
%   Everything a pool worker needs to read any region of the level,
%   with no session: an OME-Zarr store + array, SmartSPIM slice paths,
%   or (for a reduced level) the on-disk chunk files of the level it
%   is reduced from, which was written earlier in this same call.
    if isKey(options.levelSources, p)
        source = options.levelSources(p);
    else
        source = struct('kind', 'omezarr');
    end
    switch source.kind
        case 'omezarr'
            if isempty(options.sourceZarrPath)
                error('NDI:lightsheet:makePyramid:noSource', ...
                    'Level %s has no levelSources entry and no sourceZarrPath.', p);
            end
            % Which position in this pyramid's datasets holds this
            % level? Its 1-based index is what readArray takes.
            kInEntry = find(arrayfun(@(L) strcmp(char(L.path), p), ...
                entry.levels), 1);
            if isempty(kInEntry)
                error('NDI:lightsheet:makePyramid:missingLevelInEntry', ...
                    'level path %s not found in pyramid %s.', p, char(entry.name));
            end
            source = struct('kind', 'omezarr', ...
                'zarrPath', char(options.sourceZarrPath), ...
                'pyramidName', char(entry.name), 'kInEntry', kInEntry);
        case 'smartspim'
            % Self-contained already (slice paths + dtype).
            source.dtype  = ndi.fun.doc.lightsheet.dtypeName(source.dtype, 'matlab');
        case 'reduceSmartspim'
            % Block-reduced straight from the SmartSPIM slices rather than
            % from a stored level: self-contained, like 'smartspim'.
            source.dtype  = ndi.fun.doc.lightsheet.dtypeName(level.dtype, 'matlab');
            source.sourceDtype = ndi.fun.doc.lightsheet.dtypeName(source.sourceDtype, 'matlab');
            source.factor = double(source.factor(:).');
            source.fromShape = double(source.fromShape(:).');
        case 'reduce'
            if ~isKey(docByPath, source.fromPath)
                error('NDI:lightsheet:makePyramid:reduceOrder', ...
                    ['Level %s reduces level %s, which has not been ' ...
                     'written yet. List finer levels first.'], p, source.fromPath);
            end
            from = docByPath(source.fromPath);
            fp = from.document_properties.lightsheetZarrLevel;
            nFrom = prod(double(fp.chunk_grid));
            paths = cell(1, nFrom);
            % Resolve each stored chunk to its file ONCE, here on the
            % main thread; workers then read plain files.
            for i = 1:nFrom
                f = session.database_openbinarydoc(from, sprintf('chunk.bin_%d', i));
                paths{i} = f.fullpathfilename;
                session.database_closebinarydoc(f);
            end
            source.fromShape  = double(fp.shape(:).');
            source.fromChunks = double(fp.chunks(:).');
            source.fromGrid   = double(fp.chunk_grid(:).');
            source.fromCodec  = char(fp.codec);
            source.fromDtype  = ndi.fun.doc.lightsheet.dtypeName(fp.dtype, 'matlab');
            source.chunkPaths = paths;
            source.dtype      = ndi.fun.doc.lightsheet.dtypeName(level.dtype, 'matlab');
            source.factor     = double(source.factor(:).');
        otherwise
            error('NDI:lightsheet:makePyramid:unknownSourceKind', ...
                'Unknown level source kind ''%s'' for level %s.', source.kind, p);
    end
end

function w = chunkWeight(source)
% How much work one output chunk of a level read from SOURCE is, in
% level-0 chunks. A chunk reduced straight from the SmartSPIM slices
% reads prod(factor) chunks' worth of slices, so it is that many. Any
% other chunk is one: a level-0 chunk reads itself, and a chunk reduced
% from the level before reads that level's local copy, which is quick.
    w = 1;
    if isstruct(source) && isfield(source, 'kind') && strcmp(source.kind, 'reduceSmartspim') ...
            && ~(isfield(source, 'folded') && source.folded)
        w = prod(double(source.factor));
    end
end

function a = readAmplification(source, typesize)
% How many bytes the reader holds per output byte (see attachChunkFiles).
    a = 1;
    if any(strcmp(source.kind, {'reduce', 'reduceSmartspim'}))
        a = prod(source.factor);
        if strcmp(source.reduction, 'mean')
            a = a * max(1, 4 / typesize);   % reduced in single precision
        end
    end
end

function out = readSmartSpimRegion(source, lo, hi)
% READSMARTSPIMREGION - region [lo, hi] (axes t,c,z,y,x) from 2-D slices
%
%   source.slicePaths{c}{z} is the TIFF of channel c at z. Each slice
%   spans the whole stitched canvas, so only the (y, x) window is read
%   (imread PixelRegion decodes just the strips that cover it).
    out = zeros(double(hi - lo + 1), source.dtype);
    rows = [lo(4) hi(4)];
    cols = [lo(5) hi(5)];
    for c = lo(2):hi(2)
        for z = lo(3):hi(3)
            tile = readSliceRetrying(source.slicePaths{c}{z}, rows, cols);
            if ~isa(tile, source.dtype)
                tile = cast(tile, source.dtype);
            end
            out(1, c - lo(2) + 1, z - lo(3) + 1, :, :) = ...
                reshape(tile, [1 1 1 size(tile, 1) size(tile, 2)]);
        end
    end
end

function tile = readSliceRetrying(path, rows, cols)
% IMREAD of one slice window, retried for up to 30 minutes with waits
% growing from 2 s to 60 s: slices often live on a file server, and one
% that drops out for a few minutes should cost minutes, not the run.
    t0 = tic;
    wait = 2;
    while true
        try
            tile = imread(path, 'PixelRegion', {rows, cols});
            return
        catch ME
            % Its folder is reachable but the file is not there: that is
            % a missing slice, not an outage, and waiting will not help.
            gone = isfolder(fileparts(path)) && ~isfile(path);
            if gone || toc(t0) + wait > 1800
                rethrow(ME);
            end
            fprintf('[makePyramid] Could not read %s (%s); trying again in %d s.\n', ...
                path, ME.message, wait);
            pause(wait);
            wait = min(60, 2 * wait);
        end
    end
end

function out = readSmartSpimReducedRegion(source, lo, hi)
% READSMARTSPIMREDUCEDREGION - region [lo, hi] of a level block-reduced
% directly from the SmartSPIM slices (see readReducedRegion for the
% block arithmetic). Used when the level it would otherwise be reduced
% from is not kept on this disk.
    f = source.factor;
    srcLo = (lo - 1) .* f + 1;
    srcHi = min(hi .* f, source.fromShape);
    src = readSmartSpimRegion(struct('slicePaths', {source.slicePaths}, ...
        'dtype', source.sourceDtype), srcLo, srcHi);
    out = ndi.fun.doc.lightsheet.reduceBlocks(src, f, source.reduction, source.dtype);
end

function out = readReducedRegion(source, lo, hi)
% READREDUCEDREGION - region [lo, hi] of a level made by block-reducing
% the level below it.
%
%   Output voxel i covers source voxels (i-1)*f+1 .. i*f along each axis
%   (the last block may be partial), so the region needs source voxels
%   (lo-1).*f+1 .. min(hi.*f, fromShape).
    f = source.factor;
    srcLo = (lo - 1) .* f + 1;
    srcHi = min(hi .* f, source.fromShape);
    src = readStoredLevelRegion(source, srcLo, srcHi);
    out = ndi.fun.doc.lightsheet.reduceBlocks(src, f, source.reduction, source.dtype);
end

function out = readStoredLevelRegion(source, lo, hi)
% READSTOREDLEVELREGION - region [lo, hi] of a level from its chunk files
%
%   Chunks are C-order (last axis fastest), 1-based, each a full
%   (zero-padded) `chunks`-shaped tile in C byte order, raw or Blosc.
    nd = numel(source.fromShape);
    chunks = source.fromChunks;
    grid = source.fromGrid;
    out = zeros(double(hi - lo + 1), source.fromDtype);
    cLo = floor((lo - 1) ./ chunks) + 1;
    cHi = floor((hi - 1) ./ chunks) + 1;
    strides = ones(1, nd);
    for a = nd-1:-1:1
        strides(a) = strides(a + 1) * grid(a + 1);
    end
    ranges = arrayfun(@(a) cLo(a):cHi(a), 1:nd, 'UniformOutput', false);
    combos = cell(1, nd);
    [combos{:}] = ndgrid(ranges{:});
    nTiles = numel(combos{1});
    for t = 1:nTiles
        c = cellfun(@(g) g(t), combos);
        linear = sum((c - 1) .* strides) + 1;
        tile = readStoredChunk(source.chunkPaths{linear}, chunks, ...
            source.fromCodec, source.fromDtype);
        tileLo = (c - 1) .* chunks + 1;
        oLo = max(tileLo, lo);
        oHi = min(tileLo + chunks - 1, hi);
        dst = arrayfun(@(a) (oLo(a) - lo(a) + 1):(oHi(a) - lo(a) + 1), ...
            1:nd, 'UniformOutput', false);
        srcSub = arrayfun(@(a) (oLo(a) - tileLo(a) + 1):(oHi(a) - tileLo(a) + 1), ...
            1:nd, 'UniformOutput', false);
        out(dst{:}) = tile(srcSub{:});
    end
end

function tile = readStoredChunk(path, chunks, codec, dtype)
% READSTOREDCHUNK - one stored chunk file -> a `chunks`-shaped array
%
%   Inverse of padEncodeAndWrite: bytes are C-order, so reshape to the
%   reversed shape and permute back.
    fid = fopen(path, 'r');
    if fid < 0
        error('NDI:lightsheet:makePyramid:readChunk', ...
            'Could not open stored chunk %s.', path);
    end
    raw = fread(fid, Inf, '*uint8');
    fclose(fid);
    if strcmp(codec, 'blosc-zstd')
        raw = ndr.format.blosc.decode(raw);
    end
    vals = typecast(raw(:), dtype);
    nd = numel(chunks);
    tile = permute(reshape(vals, fliplr(chunks)), nd:-1:1);
end

function tmp = padEncodeAndWrite(srcTile, chunks, codec, clevel, typesize, tmpRoot, chunkIdx)
% PADENCODEANDWRITE - one chunk, end to end, on the worker
%
%   Pure per-chunk work: whatever runs in a parfor iteration lives
%   here so the parallel worker has no dependency on outer-function
%   state beyond the arguments it receives.
%
%   For codec='blosc-zstd', the fast path is a single blosc.encodeChunk
%   MEX call from blosc-matlab v0.2.0: pad + permute (Fortran -> Zarr
%   C-order) + typecast + Blosc encode happen inside the C code with
%   no MATLAB-side intermediate allocations. On a lightsheet ingest
%   that removes ~3 full memcpys per chunk (each ~ chunkBytes), which
%   at 40k chunks x 5 pyramid levels is hundreds of GB of avoided
%   main-thread memory traffic per worker.
%
%   Fallback (v0.1.0 MEX, or codec='raw'): do the pad + permute +
%   typecast in MATLAB, then either return the raw bytes or hand them
%   to ndr.format.blosc.encode. Byte-identical output.
    switch codec
        case 'raw'
            payload = padPermuteBytes(srcTile, chunks);
        case 'blosc-zstd'
            if canUseEncodeChunk()
                payload = blosc.encodeChunk(srcTile, chunks(:).', ...
                    'cname',   'zstd', ...
                    'clevel',  clevel, ...
                    'shuffle', 1);
            else
                raw = padPermuteBytes(srcTile, chunks);
                payload = ndr.format.blosc.encode(raw, ...
                    'typesize', typesize, ...
                    'cname',    'zstd', ...
                    'clevel',   clevel, ...
                    'shuffle',  1);
            end
        otherwise
            error('NDI:lightsheet:makePyramid:unknownCodec', ...
                'Unknown codec %s.', codec);
    end
    tmp = fullfile(tmpRoot, sprintf('chunk_%d.bin', chunkIdx));
    fid = fopen(tmp, 'w');
    fwrite(fid, payload);
    fclose(fid);
end

function tf = canUseEncodeChunk()
% CANUSEENCODECHUNK - does this worker have blosc.encodeChunk on its path?
%
%   Runs on the parfor worker (padEncodeAndWrite is called inside the
%   parfor). Each worker is a separate MATLAB process with its own
%   `persistent` scope, so the first call in a worker triggers
%   ensureMex (which downloads blosc-matlab v0.2.0 to prefdir() on
%   first use in that worker's session) and every subsequent call in
%   the same worker is a memoized flag read.
%
%   Falls back to false on any error so a caller without NDR-matlab
%   or without a working install still gets the pad-permute-typecast
%   MATLAB path via ndr.format.blosc.encode.
    persistent flag
    if ~isempty(flag), tf = flag; return; end
    flag = false;
    try
        info = ndr.util.blosc.ensureMex();
        flag = info.available && exist('blosc.encodeChunk', 'file') == 2;
    catch
    end
    tf = flag;
end

function bytes = padPermuteBytes(srcTile, chunks)
% PADPERMUTEBYTES - Fortran ND-array -> zero-padded C-order uint8 bytes.
%
%   The MATLAB fallback for the Blosc fast path: pad the tile up to
%   the target chunk shape with zeros, permute axes into reversed
%   order so the row-major byte layout matches what Zarr writes, then
%   typecast to bytes. Only used when the v0.2.0 blosc-matlab MEX is
%   not available.
    if isequal(size(srcTile), chunks)
        permuted = permute(srcTile, numel(chunks):-1:1);
    else
        padded = zeros(chunks, class(srcTile));
        localSubs = arrayfun(@(k) 1:size(srcTile, k), ...
            1:numel(chunks), 'UniformOutput', false);
        padded(localSubs{:}) = srcTile;
        permuted = permute(padded, numel(chunks):-1:1);
    end
    bytes = typecast(permuted(:), 'uint8');
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
    if isempty(p) || p.NumWorkers < numWorkers
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
        % A pool at least as big is kept (a level that reads slices opens a
        % bigger one; see READERS OF THEIR OWN), so levels do not restart it.
        if isempty(p) || p.NumWorkers < numWorkers
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

function b = elementSizeBytes(dtype)
    try
        className = ndi.fun.doc.lightsheet.dtypeName(dtype, 'matlab');
    catch
        className = '';
    end
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
%   still gets its label refreshed. Any exception is swallowed -- a bar
%   that stopped drawing must not stop an ingest -- except
%   'NDI:job:paused', which is how a job (ndi.job.Job) asks the build to
%   stop at the end of a super-block so it can be resumed.
    if isempty(fcn), return; end
    frac = 0;
    if total > 0
        frac = max(0, min(1, double(done) / double(total)));
    end
    try
        fcn(frac, char(text));
    catch ME
        if strcmp(ME.identifier, 'NDI:job:paused')
            rethrow(ME);
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

