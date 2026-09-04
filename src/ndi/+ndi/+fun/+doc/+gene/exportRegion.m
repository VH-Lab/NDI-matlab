function [M, pixelXY, info] = exportRegion(session, pyrDoc, binSize, rect, options)
% EXPORTREGION - extract a region as a sparse (pixel x gene) matrix
%
%   [M, PIXELXY, INFO] = ndi.fun.doc.gene.EXPORTREGION(SESSION, PYRDOC, ...
%       BINSIZE, RECT)
%
%   Pulls a rectangle out of a pyramid level in the orientation analysis
%   tools expect: one row per occupied pixel, one column per gene, raw
%   integer counts. This is the reusable core of any export; serializing
%   it as .h5ad or .gem is a thin layer on top and is better done where a
%   library for that container exists.
%
%   Extracting a region rather than the whole dataset is deliberately the
%   primary form. It is the request people actually make -- find something
%   in a viewer, then compute on that -- and it costs only the tiles that
%   intersect it. Pass RECT = [] for the entire level.
%
%   Inputs:
%   BINSIZE - which level to read
%   RECT    - [x0 y0 width height] in pixels of that level, zero-based
%
%   Optional Name-Value Arguments:
%   dropEmptyGenes (false) - also return only the genes detected in the
%                            region, with INFO.geneRows naming them
%
%   Outputs:
%   M       - sparse n_pixels-by-n_genes double of raw counts
%   PIXELXY - n_pixels-by-2, the ZERO-BASED level pixel of each row,
%             relative to the level origin, not to RECT
%   INFO    - struct with tilesRead, binSize, geneRows (empty unless
%             dropEmptyGenes), and originBase, the [x y] of the region in
%             BASE pixel units, so the caller can place it in space
%
%   Counts are raw: no density normalization is applied, because that is a
%   display concern and would make the export lossy.
%
%   See also: ndi.fun.doc.gene.readViewport
%
arguments
    session (1,1)
    pyrDoc (1,1) ndi.document
    binSize (1,1) {mustBePositive, mustBeInteger}
    rect
    options.dropEmptyGenes (1,1) logical = false
end

p = pyrDoc.document_properties.spatialGeneExpressionPyramid;
[tileDoc, lv] = localFindLevelE(session, pyrDoc, binSize);
lh = lv.dimension_size(1); lw = lv.dimension_size(2);
th = lv.tile_size_y_bins;   tw = lv.tile_size_x_bins;
nGenes = lv.dimension_size(3);

if isempty(rect), rect = [0 0 lw lh]; end
x0 = rect(1); y0 = rect(2);
x1 = min(x0 + rect(3), lw); y1 = min(y0 + rect(4), lh);

stored = tileDoc.current_file_list();
I = []; J = []; V = []; PX = []; PY = [];
tilesRead = 0;

for r = floor(y0/th) : min(floor(max(y1-1,y0)/th), p.tile_rows-1)
    for c = floor(x0/tw) : min(floor(max(x1-1,x0)/tw), p.tile_columns-1)
        name = sprintf('tile.bin_%d', r * p.tile_columns + c);
        if ~any(strcmp(name, stored)), continue; end
        bd = session.database_openbinarydoc(tileDoc, name);
        cl = onCleanup(@() session.database_closebinarydoc(bd));
        t = ndi.fun.doc.gene.readTileFile(bd.fullpathfilename);
        clear cl;
        tilesRead = tilesRead + 1;
        if t.n_pixels == 0, continue; end

        gx = double(t.x) + c*tw;   % level coordinates
        gy = double(t.y) + r*th;
        keep = gx >= x0 & gx < x1 & gy >= y0 & gy < y1;
        if ~any(keep), continue; end

        reps = double(t.offset(2:end)) - double(t.offset(1:end-1));
        rowOfRecord = repelem((1:t.n_pixels)', reps);
        keepRec = keep(rowOfRecord);

        base = numel(PX);
        newRows = cumsum(keep);                       % local pixel numbering
        I = [I; base + newRows(rowOfRecord(keepRec))]; %#ok<AGROW>
        J = [J; double(t.gene_index(keepRec)) + 1];    %#ok<AGROW>
        V = [V; double(t.count(keepRec))];             %#ok<AGROW>
        PX = [PX; gx(keep)];                           %#ok<AGROW>
        PY = [PY; gy(keep)];                           %#ok<AGROW>
    end
end

nPix = numel(PX);
M = sparse(I, J, V, max(nPix,1), nGenes);
if nPix == 0, M = sparse(0, nGenes); end
pixelXY = [PX PY];

info = struct('tilesRead', tilesRead, 'binSize', binSize, 'geneRows', [], ...
    'originBase', [p.origin_x + x0*binSize, p.origin_y + y0*binSize]);

if options.dropEmptyGenes && nPix > 0
    detected = find(any(M ~= 0, 1));
    M = M(:, detected);
    info.geneRows = detected(:) - 1;   % report ZERO-BASED rows
end

end % exportRegion

% ------------------------------------------------------------------------

function [tileDoc, lv] = localFindLevelE(session, pyrDoc, binSize)
q = ndi.query('','depends_on','spatialGeneExpressionPyramid_id',pyrDoc.id()) & ...
    ndi.query('','isa','spatialGeneExpressionTiles');
docs = session.database_search(q);
for i = 1:numel(docs)
    lv = docs{i}.document_properties.spatialGeneExpressionTiles;
    if lv.bin_size == binSize
        tileDoc = docs{i}; return;
    end
end
error('NDI:gene:exportRegion:noSuchLevel', ...
    'This pyramid has no level with bin_size %d.', binSize);
end
