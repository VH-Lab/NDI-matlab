function [T, info] = readCells(session, cellsDoc)
% READCELLS - read the cell table of a spatialGeneExpressionCells document
%
%   [T, INFO] = ndi.fun.doc.gene.READCELLS(SESSION, CELLSDOC)
%
%   Reads cells.tsv and returns one row per segmented cell. Columns are
%   taken BY HEADER NAME, not by position: the specification names them
%   cell_index, cell_id, x, y, area, dnb_count, total_counts, n_genes,
%   but only the first four are required and writers in the wild differ on
%   the rest. The extraction spike that produced the first opossum cells
%   wrote 'dnbCount' and 'n_genes_by_counts' where the spec says
%   'dnb_count' and 'n_genes', so reading by position would have silently
%   mapped one measurement onto another's name.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset holding the document
%   CELLSDOC - a spatialGeneExpressionCells document
%
%   Outputs:
%   T    - a table with one row per cell. cellIndex, cellID, x and y are
%          always present; any further columns carry the header names the
%          file used. x and y are the centroid, in SOURCE coordinates --
%          the same frame the pyramid's origin and extent are in, and the
%          frame a viewer must transform before drawing.
%   INFO - struct with nCells, coordinateUnits, contoursPresent,
%          contourReference and segmentationMethod, read from the
%          document rather than assumed.
%
%   CONTOURS ARE NOT READ HERE. contours.bin holds the boundary polygons
%   and needs its own reader; this returns centroids, which is what a
%   viewer needs to place cells and what every caller so far has wanted.
%   INFO.contoursPresent says whether there is more to read.
%
%   Note on what a "cell" is: Stereo-seq CellBin segments NUCLEI from the
%   stain image and dilates outward, so a row here is a nucleus plus a
%   margin rather than a measured cell body. INFO.segmentationMethod
%   records which method produced it.
%
%   Example:
%       [T, info] = ndi.fun.doc.gene.readCells(S, cellsDoc);
%       fprintf('%d cells in %s\n', info.nCells, info.coordinateUnits);
%
%   See also: ndi.fun.doc.gene.readViewportBase, ndi.fun.doc.gene.levelTable
%
arguments
    session (1,1)
    cellsDoc (1,1) ndi.document
end

c = cellsDoc.document_properties.spatialGeneExpressionCells;

bd = session.database_openbinarydoc(cellsDoc, 'cells.tsv');
cleaner = onCleanup(@() session.database_closebinarydoc(bd));
txt = fileread(bd.fullpathfilename);
clear cleaner;

lines = strsplit(strtrim(txt), newline);
if numel(lines) < 1 || isempty(strtrim(lines{1}))
    error('NDI:gene:readCells:noHeader', ...
        'cells.tsv in document %s has no header row.', cellsDoc.id());
end

header = strsplit(strtrim(lines{1}), sprintf('\t'));
required = {'cell_index','cell_id','x','y'};
missing = required(~ismember(required, header));
if ~isempty(missing)
    error('NDI:gene:readCells:missingColumns', ...
        'cells.tsv is missing required column(s): %s. It has: %s.', ...
        strjoin(missing, ', '), strjoin(header, ', '));
end

n = numel(lines) - 1;
data = cell(n, numel(header));
for i = 1:n
    f = strsplit(lines{i+1}, sprintf('\t'), 'CollapseDelimiters', false);
    if numel(f) < numel(header)
        f(end+1:numel(header)) = {''};    %#ok<AGROW>
    end
    data(i,:) = f(1:numel(header));
end

T = table();
for j = 1:numel(header)
    name = header{j};
    col = data(:,j);
    switch name
        case 'cell_index', T.cellIndex = localNumeric(col);
        case 'cell_id',    T.cellID    = string(col);
        case 'x',          T.x         = localNumeric(col);
        case 'y',          T.y         = localNumeric(col);
        otherwise
            % Keep the file's own header name. Renaming a column a writer
            % chose is how one measurement quietly becomes another.
            num = localNumeric(col);
            if all(isnan(num)) && ~all(cellfun(@isempty, col))
                T.(matlab.lang.makeValidName(name)) = string(col);
            else
                T.(matlab.lang.makeValidName(name)) = num;
            end
    end
end

info = struct( ...
    'nCells', c.n_cells, ...
    'coordinateUnits', c.coordinate_units, ...
    'contoursPresent', logical(c.contours_present), ...
    'contourReference', c.contour_reference, ...
    'segmentationMethod', c.segmentation_method);

if height(T) ~= c.n_cells
    warning('NDI:gene:readCells:countMismatch', ...
        ['cells.tsv holds %d rows but the document says n_cells is %d. ' ...
         'The file is what was read.'], height(T), c.n_cells);
end

end % readCells

% ------------------------------------------------------------------------

function v = localNumeric(col)
v = str2double(col);
end % localNumeric
