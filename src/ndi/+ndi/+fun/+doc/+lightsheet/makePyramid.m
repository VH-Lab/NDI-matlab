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
            'axes_units', {axesUnits}, ...
            'channel_names', {{}}, ...
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
    chunkGrid = ceil(level.shape ./ level.chunks);

    props = struct( ...
        'label', sprintf('%s level %d (%s)', pyramidEntry.name, levelIndex, reductionFn), ...
        'level', levelIndex, ...
        'reduction_function', reductionFn, ...
        'axes_order', joinAxisNames(pyramidEntry.axes), ...
        'shape', level.shape, ...
        'chunks', level.chunks, ...
        'chunk_grid', chunkGrid, ...
        'n_chunks_stored', 0, ...
        'chunk_index_origin', 1, ...
        'chunk_order', 'C', ...
        'dtype', char(level.dtype), ...
        'fill_value', 0, ...
        'byte_order', 'little', ...
        'codec', 'raw', ...
        'codec_params', '{}', ...
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

    session.database_add(levelDoc);
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
