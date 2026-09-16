function info = writeContourFile(filename, polys, options)
% WRITECONTOURFILE - write cell boundary polygons as contours.bin
%
%   INFO = ndi.fun.doc.gene.WRITECONTOURFILE(FILENAME, POLYS)
%   INFO = ndi.fun.doc.gene.WRITECONTOURFILE(..., 'vertexType','int16')
%
%   Writes the contour_format_version 1 layout of
%   spatialGeneExpressionCells:
%
%     n_cells           offsetType   1
%     n_vertices_total  offsetType   1
%     offset            offsetType   n_cells + 1
%     vx                vertexType   n_vertices_total
%     vy                vertexType   n_vertices_total
%
%   Cell i has vertices offset(i):offset(i+1). The polygon closes
%   implicitly; the first vertex is not repeated, so a caller that closed
%   its ring must not pass the duplicate.
%
%   Always writes the RAGGED form, with an offset array, even when every
%   cell happens to have the same number of vertices. The fixed-width form
%   the specification also allows saves n_cells+1 offsets and cannot
%   represent a later ragged edit; READCONTOURFILE accepts both, so files
%   from other writers still read.
%
%   Inputs:
%   FILENAME - path to write
%   POLYS    - cell array, one entry per cell, each an N-by-2 array of
%              [x y] vertices. An empty entry is a cell with no contour
%              and is written as zero vertices rather than dropped, so
%              row i of cells.tsv stays row i here.
%
%   Optional Name-Value Arguments:
%   vertexType ('int16')  - stored type of the vertex coordinates
%   offsetType ('uint32') - stored type of the counts and offsets
%
%   Outputs:
%   INFO - struct with nCells, nVerticesTotal, vertexType, offsetType and
%          nVerticesPerCell (0 when ragged, which is what this writes).
%
%   RANGE IS CHECKED, not assumed. int16 holds +/-32767, which is ample
%   for centroid-relative vertices and NOT ample for absolute source
%   coordinates on a chip 20,000 bins across. Writing those would wrap
%   silently and put boundaries in the wrong place, so a value that does
%   not fit is an error naming the offending cell.
%
%   See also: ndi.fun.doc.gene.readContourFile, ndi.fun.doc.gene.makeCells
%
arguments
    filename (1,:) char
    polys cell
    options.vertexType (1,:) char = 'int16'
    options.offsetType (1,:) char = 'uint32'
end

n = numel(polys);
counts = zeros(n,1);
for i = 1:n
    p = polys{i};
    if isempty(p)
        counts(i) = 0;
        continue;
    end
    if size(p,2) ~= 2
        error('NDI:gene:writeContourFile:shape', ...
            'Polygon %d must be N-by-2 [x y]; got %d columns.', i, size(p,2));
    end
    counts(i) = size(p,1);
end

lim = double(intmax(options.vertexType));
lo  = double(intmin(options.vertexType));
allV = vertcat(polys{~cellfun(@isempty, polys)});
if ~isempty(allV)
    bad = find(any(allV > lim | allV < lo, 2), 1);
    if ~isempty(bad)
        error('NDI:gene:writeContourFile:range', ...
            ['A vertex (%g, %g) does not fit in %s (%g..%g). Contours ' ...
             'stored relative to their centroid fit easily; ABSOLUTE ' ...
             'source coordinates on a chip this size do not, and would ' ...
             'wrap silently. Check contour_reference.'], ...
            allV(bad,1), allV(bad,2), options.vertexType, lo, lim);
    end
end

offsets = [0; cumsum(counts)];
total = offsets(end);

vx = zeros(total,1); vy = zeros(total,1);
for i = 1:n
    if counts(i) == 0, continue; end
    vx(offsets(i)+1:offsets(i+1)) = polys{i}(:,1);
    vy(offsets(i)+1:offsets(i+1)) = polys{i}(:,2);
end

fid = fopen(filename, 'w', 'l');       % little-endian, the document's byte_order
if fid < 0
    error('NDI:gene:writeContourFile:open', 'Could not open %s for writing.', filename);
end
cleaner = onCleanup(@() fclose(fid));
fwrite(fid, n, options.offsetType);
fwrite(fid, total, options.offsetType);
fwrite(fid, offsets, options.offsetType);
fwrite(fid, vx, options.vertexType);
fwrite(fid, vy, options.vertexType);
clear cleaner;

info = struct('nCells', n, 'nVerticesTotal', total, ...
    'vertexType', options.vertexType, 'offsetType', options.offsetType, ...
    'nVerticesPerCell', 0);

end % writeContourFile
