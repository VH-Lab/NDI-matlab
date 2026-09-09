function [pyramidDoc, levelDocs] = makePyramid(session, pyramidEntry, options)
% NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID - write one reduction's pyramid documents
%
%   [PYRAMIDDOC, LEVELDOCS] = NDI.FUN.DOC.LIGHTSHEET.MAKEPYRAMID(...
%       SESSION, PYRAMIDENTRY, options)
%
%   Given ONE multiscales entry as returned by
%   NDR.FORMAT.OMEZARR.LISTPYRAMIDS (fields: name, type, axes, levels),
%   creates:
%
%     * one LIGHTSHEETZARRPYRAMID document (the parent)
%     * one LIGHTSHEETZARRLEVEL document per entry in PYRAMIDENTRY.levels
%
%   and adds them to SESSION.
%
%   Required Name-Value:
%     reduction   - 'mean' or 'max' (or other future value); recorded on
%                   the parent AND on every level.
%     subjectID   - char, depended-on subject id.
%
%   Optional Name-Value:
%     elementID       - char, depended-on element id (may be '').
%     sourceFileID    - char, id of the fileReference document naming
%                       the OME-Zarr store; ''=no source_file_id.
%     pipelineVersion - char, tag for the pyramid.
%     materializeChunks - logical, default false. When true, this
%                       function writes each level's chunk bytes into
%                       the level document's `chunk.bin_#` file series
%                       by reading the source array through
%                       NDR.FORMAT.OMEZARR.READARRAY. When false, the
%                       level documents only carry metadata and the
%                       chunks stay in the source store; a downstream
%                       ingest job (see the design note in
%                       README-lightsheet-zarr.md) is responsible for
%                       materialization. Default false so the ingest is
%                       incremental: describe first, materialize later.
%
%   Returns:
%     PYRAMIDDOC - the parent ndi.document
%     LEVELDOCS  - column cell array of ndi.documents, one per level,
%                  ordered finest-first (matching PYRAMIDENTRY.levels).
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.writeChunkFile,
%             ndi.fun.doc.lightsheet.readViewport

    arguments
        session (1,1)
        pyramidEntry (1,1) struct
        options.reduction (1,:) char {mustBeMember(options.reduction, {'mean','max'})}
        options.subjectID (1,:) char
        options.elementID char = ''
        options.sourceFileID char = ''
        options.pipelineVersion char = ''
        options.materializeChunks (1,1) logical = false
    end

    axesOrder = joinAxisNames(pyramidEntry.axes);
    axesUnits = collectAxisUnits(pyramidEntry.axes);

    levels = pyramidEntry.levels;
    if isempty(levels)
        error('NDI:lightsheet:makePyramid:noLevels', ...
            'Pyramid ''%s'' has no levels.', pyramidEntry.name);
    end

    level0 = levels(1);
    dtype = char(level0.dtype);

    pyramidDoc = session.newdocument('lightsheetZarrPyramid', ...
        'lightsheetZarrPyramid', struct( ...
            'label', pyramidEntry.name, ...
            'reduction', options.reduction, ...
            'pyramid_name', char(pyramidEntry.name), ...
            'pyramid_type', char(pyramidEntry.type), ...
            'axes_order', axesOrder, ...
            'axes_units', {axesUnits}, ...
            'channel_names', {{}}, ...
            'n_channels', channelCount(level0.shape, axesOrder), ...
            'n_levels', numel(levels), ...
            'shape_level0', level0.shape, ...
            'voxel_size_level0', ensureRow(level0.scale), ...
            'voxel_size_units', 'micrometer', ...
            'translation_level0', ensureRow(level0.translation), ...
            'dtype', dtype, ...
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

    levelDocs = cell(numel(levels), 1);
    for k = 1:numel(levels)
        levelDocs{k} = makeOneLevel(session, pyramidDoc, pyramidEntry, ...
            levels(k), k - 1, options);
    end
end

function levelDoc = makeOneLevel(session, pyramidDoc, pyramidEntry, level, levelIndex, options)
    chunkGrid = ceil(level.shape ./ level.chunks);
    nChunks = prod(chunkGrid);

    props = struct( ...
        'label', sprintf('%s level %d', pyramidEntry.name, levelIndex), ...
        'level', levelIndex, ...
        'reduction', options.reduction, ...
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

    if options.materializeChunks
        [levelDoc, nWritten] = ndi.fun.doc.lightsheet.writeChunkFile(...
            session, levelDoc, pyramidEntry, level);
        levelDoc = levelDoc.setproperties( ...
            'lightsheetZarrLevel.n_chunks_stored', nWritten);
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
