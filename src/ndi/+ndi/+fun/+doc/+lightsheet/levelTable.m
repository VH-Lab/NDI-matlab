function t = levelTable(session, pyramidDoc, options)
% NDI.FUN.DOC.LIGHTSHEET.LEVELTABLE - table of a pyramid's levels, finest-first
%
%   T = NDI.FUN.DOC.LIGHTSHEET.LEVELTABLE(SESSION, PYRAMIDDOC)
%   T = NDI.FUN.DOC.LIGHTSHEET.LEVELTABLE(SESSION, PYRAMIDDOC, ...
%       'reduction', 'mean')
%
%   Queries SESSION for every LIGHTSHEETZARRLEVEL document whose
%   `lightsheetZarrPyramid_id` depends_on matches PYRAMIDDOC.id(), and
%   returns a MATLAB table sorted by `level` ascending (finest-first).
%
%   When the 'reduction' name-value is passed, the returned table only
%   contains levels with reduction_function in {'none', <reduction>} --
%   the shared raw level(s) plus the requested reduction. Omit to get
%   every level (both mean and max in a store that ships both).
%
%   Table columns: level, reduction_function, shape, chunks, chunk_grid,
%   n_chunks_stored, voxel_size, translation, dtype, id.
%
%   UserData holds the parent pyramid's frame:
%     axes_order, voxel_size_level0, translation_level0, dtype,
%     pyramid_name, id (parent id), reductions (cellstr of the
%     reduction_function values present in the full ladder, minus
%     'none').
%
%   PYRAMIDDOC may be an ndi.document or an id char/string; either is
%   accepted so this can be called from a GUI that only has the row's
%   id.
%
%   See also: ndi.fun.doc.lightsheet.chooseLevel

    arguments
        session (1,1)
        pyramidDoc
        options.reduction char = ''
    end

    if isa(pyramidDoc, 'ndi.document')
        parentDoc = pyramidDoc;
        parentID = parentDoc.id();
    else
        parentID = char(pyramidDoc);
        parentDoc = session.database_search(ndi.query('base.id', 'exact_string', parentID));
        if isempty(parentDoc)
            error('NDI:lightsheet:levelTable:noParent', ...
                'No lightsheetZarrPyramid with id %s in session.', parentID);
        end
        parentDoc = parentDoc{1};
    end

    q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
    q2 = ndi.query('depends_on', 'depends_on', 'lightsheetZarrPyramid_id', parentID);
    docs = session.database_search(q1 & q2);
    if isempty(docs)
        t = emptyTable();
        t.Properties.UserData = frame(parentDoc, {});
        return;
    end

    n = numel(docs);
    level = zeros(n, 1);
    reduction_function = cell(n, 1);
    shape = cell(n, 1);
    chunks = cell(n, 1);
    chunk_grid = cell(n, 1);
    n_chunks_stored = zeros(n, 1);
    voxel_size = cell(n, 1);
    translation = cell(n, 1);
    dtype = cell(n, 1);
    id = cell(n, 1);

    for k = 1:n
        p = docs{k}.document_properties.lightsheetZarrLevel;
        level(k) = p.level;
        reduction_function{k} = char(p.reduction_function);
        shape{k} = reshape(double(p.shape), 1, []);
        chunks{k} = reshape(double(p.chunks), 1, []);
        chunk_grid{k} = reshape(double(p.chunk_grid), 1, []);
        n_chunks_stored(k) = p.n_chunks_stored;
        voxel_size{k} = reshape(double(p.voxel_size), 1, []);
        translation{k} = reshape(double(p.translation), 1, []);
        dtype{k} = char(p.dtype);
        id{k} = docs{k}.id();
    end

    reductionsPresent = setdiff(unique(reduction_function), {'none'});

    if ~isempty(options.reduction)
        keep = strcmp(reduction_function, 'none') | strcmp(reduction_function, options.reduction);
        level = level(keep);
        reduction_function = reduction_function(keep);
        shape = shape(keep);
        chunks = chunks(keep);
        chunk_grid = chunk_grid(keep);
        n_chunks_stored = n_chunks_stored(keep);
        voxel_size = voxel_size(keep);
        translation = translation(keep);
        dtype = dtype(keep);
        id = id(keep);
    end

    t = table(level, reduction_function, shape, chunks, chunk_grid, ...
        n_chunks_stored, voxel_size, translation, dtype, id);
    t = sortrows(t, 'level');
    t.Properties.UserData = frame(parentDoc, reductionsPresent);
end

function f = frame(parentDoc, reductionsPresent)
    p = parentDoc.document_properties.lightsheetZarrPyramid;
    f = struct( ...
        'axes_order', char(p.axes_order), ...
        'voxel_size_level0', reshape(double(p.voxel_size_level0), 1, []), ...
        'translation_level0', reshape(double(p.translation_level0), 1, []), ...
        'dtype', char(p.dtype), ...
        'pyramid_name', char(p.pyramid_name), ...
        'id', parentDoc.id(), ...
        'reductions', {reductionsPresent});
end

function t = emptyTable()
    t = table( ...
        zeros(0,1), cell(0,1), cell(0,1), cell(0,1), cell(0,1), ...
        zeros(0,1), cell(0,1), cell(0,1), cell(0,1), cell(0,1), ...
        'VariableNames', {'level','reduction_function','shape','chunks','chunk_grid', ...
                          'n_chunks_stored','voxel_size','translation','dtype','id'});
end
