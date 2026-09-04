function cellsDoc = makeCells(session, cellID, x, y, pyrDoc, options)
% MAKECELLS - create a spatialGeneExpressionCells document
%
%   CELLSDOC = ndi.fun.doc.gene.MAKECELLS(SESSION, CELLID, X, Y, PYRDOC)
%   CELLSDOC = ndi.fun.doc.gene.MAKECELLS(..., 'contours', POLYS)
%
%   Writes cells.tsv, optionally contours.bin, and enters the document in
%   the database. One row per segmented cell, in the same coordinate
%   frame as the pyramid it depends on.
%
%   Inputs:
%   CELLID - identifier from the source file, one per cell. Kept as TEXT:
%            these are commonly 14-digit numbers that lose precision as
%            doubles and then no longer match the file they came from.
%   X, Y   - centroids, in the coordinate frame named by
%            'coordinateUnits'. Same length as CELLID.
%   PYRDOC - the spatialGeneExpressionPyramid these cells belong to. A
%            cell table is meaningless without the frame it is in, so the
%            dependency is required rather than optional.
%
%   Optional Name-Value Arguments:
%   label ('')                  - human-readable description
%   segmentationMethod ('')     - how cells were segmented, with version.
%                                 Worth stating plainly: Stereo-seq
%                                 CellBin segments NUCLEI and dilates
%                                 outward, so a "cell" is a nucleus plus
%                                 a margin, not a measured cell body.
%   segmentationDilation (0)    - the dilation applied, in bins
%   coordinateUnits ('source')  - frame of X and Y
%   subjectID ('')              - the subject these cells were measured
%                                 from. Optional here because the pyramid
%                                 already carries one, unlike makePyramid
%                                 where it is required.
%   extra (table())             - further per-cell columns, written after
%                                 the required four with their own names.
%                                 The specification names area, dnb_count,
%                                 total_counts and n_genes, but writers
%                                 differ and READCELLS matches by header,
%                                 so a caller's own names survive.
%   contours ({})               - cell array of N-by-2 [x y] vertex arrays,
%                                 one per cell. Empty writes no
%                                 contours.bin and leaves contours_present
%                                 at 0.
%   contourReference ('centroid') - whether contour vertices are relative
%                                 to their cell's centroid or absolute.
%                                 This decides whether they fit in int16;
%                                 WRITECONTOURFILE checks and refuses
%                                 rather than wrapping.
%
%   Outputs:
%   CELLSDOC - the stored spatialGeneExpressionCells document
%
%   Example:
%       d = ndi.fun.doc.gene.makeCells(S, ids, x, y, pyr, ...
%             'segmentationMethod','CellBin 1.0','label','opossum V1');
%
%   See also: ndi.fun.doc.gene.readCells, ndi.fun.doc.gene.makePyramid,
%     ndi.fun.doc.gene.writeContourFile
%
arguments
    session (1,1)
    cellID
    x (:,1) double
    y (:,1) double
    pyrDoc (1,1) ndi.document
    options.label (1,:) char = ''
    options.segmentationMethod (1,:) char = ''
    options.segmentationDilation (1,1) double = 0
    options.coordinateUnits (1,:) char = 'source'
    options.subjectID (1,:) char = ''
    options.extra table = table()
    options.contours cell = {}
    options.contourReference (1,:) char = 'centroid'
end

cellID = string(cellID);
cellID = cellID(:);
n = numel(cellID);
if numel(x) ~= n || numel(y) ~= n
    error('NDI:gene:makeCells:length', ...
        'CELLID, X and Y must be the same length; got %d, %d and %d.', ...
        n, numel(x), numel(y));
end
if ~isempty(options.extra) && height(options.extra) ~= n
    error('NDI:gene:makeCells:extraLength', ...
        'extra has %d rows but there are %d cells.', height(options.extra), n);
end
if ~isempty(options.contours) && numel(options.contours) ~= n
    error('NDI:gene:makeCells:contourLength', ...
        'contours has %d entries but there are %d cells.', ...
        numel(options.contours), n);
end

% ---- cells.tsv ----------------------------------------------------------
% cell_index is the 0-BASED row number, and is the key contours.bin and
% every cellTypeLabels document reference. It is written explicitly rather
% than left implicit so a reader never has to infer it from row order.
tsvPath = [tempname '.tsv'];
fid = fopen(tsvPath, 'w');
if fid < 0
    error('NDI:gene:makeCells:write', 'Could not open %s.', tsvPath);
end
cleaner = onCleanup(@() fclose(fid));

extraNames = string(options.extra.Properties.VariableNames);
fprintf(fid, 'cell_index\tcell_id\tx\ty');
for j = 1:numel(extraNames)
    fprintf(fid, '\t%s', extraNames(j));
end
fprintf(fid, '\n');

for i = 1:n
    fprintf(fid, '%d\t%s\t%g\t%g', i-1, cellID(i), x(i), y(i));
    for j = 1:numel(extraNames)
        v = options.extra{i, j};
        if isnumeric(v) || islogical(v)
            fprintf(fid, '\t%g', v);
        else
            fprintf(fid, '\t%s', string(v));
        end
    end
    fprintf(fid, '\n');
end
clear cleaner;

fileNames = {'cells.tsv'};
filePaths = {tsvPath};

% ---- contours.bin -------------------------------------------------------
contoursPresent = 0;
nVerticesPerCell = 0;
vertexType = 'int16';
offsetType = 'uint32';
if ~isempty(options.contours)
    cbPath = [tempname '.bin'];
    ndi.fun.doc.gene.writeContourFile(cbPath, options.contours, ...
        'vertexType', vertexType, 'offsetType', offsetType);
    fileNames{end+1} = 'contours.bin';
    filePaths{end+1} = cbPath;
    contoursPresent = 1;
end

% ---- the document -------------------------------------------------------
c = struct( ...
    'label', options.label, ...
    'n_cells', n, ...
    'segmentation_method', options.segmentationMethod, ...
    'segmentation_dilation', options.segmentationDilation, ...
    'coordinate_units', options.coordinateUnits, ...
    'contours_present', contoursPresent, ...
    'contour_reference', options.contourReference, ...
    'n_vertices_per_cell', nVerticesPerCell, ...
    'data_type_vertex', vertexType, ...
    'data_type_offset', offsetType, ...
    'contour_format_version', 1);

cellsDoc = ndi.document('spatialGeneExpressionCells', ...
    'spatialGeneExpressionCells', c, ...
    'base.session_id', session.id());
cellsDoc = cellsDoc.set_dependency_value( ...
    'spatialGeneExpressionPyramid_id', pyrDoc.id());
if ~isempty(options.subjectID)
    cellsDoc = cellsDoc.set_dependency_value('subject_id', options.subjectID);
end

cellsDoc = storeDoc(session, cellsDoc, fileNames, filePaths);

end % makeCells
