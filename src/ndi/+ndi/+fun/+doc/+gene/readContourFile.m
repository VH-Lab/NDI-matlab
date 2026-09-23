function [polys, info] = readContourFile(filename, options)
% READCONTOURFILE - read cell boundary polygons from contours.bin
%
%   [POLYS, INFO] = ndi.fun.doc.gene.READCONTOURFILE(FILENAME)
%   [...] = ndi.fun.doc.gene.READCONTOURFILE(..., 'nVerticesPerCell', K)
%
%   Reads the contour_format_version 1 layout of
%   spatialGeneExpressionCells and returns one N-by-2 [x y] array per
%   cell. The polygon closes implicitly; the first vertex is not
%   repeated.
%
%   BOTH FORMS ARE ACCEPTED. The ragged form carries an offset array;
%   the fixed-width form, which the document signals through a positive
%   n_vertices_per_cell, carries none and packs vertex j of cell i at
%   i*K+j. WRITECONTOURFILE only emits the ragged form, but a file may
%   come from another writer, so both read.
%
%   Optional Name-Value Arguments:
%   nVerticesPerCell (0) - pass the document's field. 0 means ragged,
%                          which is the default and the form this
%                          package writes.
%   vertexType ('int16') / offsetType ('uint32') - pass the document's
%                          data_type_vertex and data_type_offset. They
%                          are FIELDS rather than constants so a level
%                          can widen without a format version change.
%
%   Outputs:
%   POLYS - 1-by-nCells cell array of N-by-2 vertex arrays
%   INFO  - struct with nCells, nVerticesTotal, and the types used
%
%   See also: ndi.fun.doc.gene.writeContourFile, ndi.fun.doc.gene.readCells
%
arguments
    filename (1,:) char
    options.nVerticesPerCell (1,1) {mustBeNonnegative, mustBeInteger} = 0
    options.vertexType (1,:) char = 'int16'
    options.offsetType (1,:) char = 'uint32'
end

fid = fopen(filename, 'r', 'l');
if fid < 0
    error('NDI:gene:readContourFile:open', 'Could not open %s.', filename);
end
cleaner = onCleanup(@() fclose(fid));

n     = double(fread(fid, 1, ['*' options.offsetType]));
total = double(fread(fid, 1, ['*' options.offsetType]));

if options.nVerticesPerCell > 0
    offsets = (0:n)' * options.nVerticesPerCell;
    if offsets(end) ~= total
        error('NDI:gene:readContourFile:fixedMismatch', ...
            ['n_vertices_per_cell is %d and there are %d cells, implying ' ...
             '%d vertices, but the file says %d.'], ...
            options.nVerticesPerCell, n, offsets(end), total);
    end
else
    offsets = double(fread(fid, n+1, ['*' options.offsetType]));
end

vx = double(fread(fid, total, ['*' options.vertexType]));
vy = double(fread(fid, total, ['*' options.vertexType]));
clear cleaner;

if numel(vx) ~= total || numel(vy) ~= total
    error('NDI:gene:readContourFile:truncated', ...
        'File claims %d vertices but holds %d x and %d y.', ...
        total, numel(vx), numel(vy));
end

polys = cell(1, n);
for i = 1:n
    a = offsets(i)+1; b = offsets(i+1);
    if b < a
        polys{i} = zeros(0,2);
    else
        polys{i} = [vx(a:b) vy(a:b)];
    end
end

info = struct('nCells', n, 'nVerticesTotal', total, ...
    'vertexType', options.vertexType, 'offsetType', options.offsetType, ...
    'nVerticesPerCell', options.nVerticesPerCell);

end % readContourFile
