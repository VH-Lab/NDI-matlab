function img = renderTile(tile, gene_rows, h, w, options)
% RENDERTILE - collapse a tile's gene axis into a raster
%
%   IMG = ndi.fun.doc.gene.RENDERTILE(TILE, GENE_ROWS, H, W)
%   IMG = ndi.fun.doc.gene.RENDERTILE(..., 'binSize', B)
%
%   Sums the selected genes of a tile into an H-by-W matrix. This is the
%   only place the gene axis is collapsed; the tile itself always carries
%   every gene, so changing the selection never requires re-reading it.
%
%   Inputs:
%   TILE      - a structure from ndi.fun.doc.gene.readTileFile
%   GENE_ROWS - ZERO-BASED geneList rows to include, or [] for every gene
%   H, W      - the tile's height and width in pixels of this level
%
%   Optional Name-Value Arguments:
%   binSize (1) - the level's bin_size. When greater than 1 the result is
%                 divided by binSize^2, giving counts per base pixel
%                 rather than summed counts.
%
%                 Binning SUMS, so a coarser level is binSize^2 brighter
%                 than a finer one. A viewer that carries a single
%                 contrast range for a whole multiresolution layer cannot
%                 serve every level under summing. Dividing here makes
%                 mean intensity identical across levels. Nothing on disk
%                 changes: tiles remain raw integer counts and the divisor
%                 comes from the document's bin_size. Pass 1 to see
%                 summed counts.
%
%   Outputs:
%   IMG - H-by-W double. Row 1 is the tile's top row, so IMG(y+1, x+1)
%         holds the pixel at zero-based tile-local (x, y).
%
%   Example:
%       t = ndi.fun.doc.gene.readTileFile(f);
%       img = ndi.fun.doc.gene.renderTile(t, [417 2044], 2048, 2048, 'binSize', 4);
%
%   See also: ndi.fun.doc.gene.readTileFile
%
arguments
    tile (1,1) struct
    gene_rows
    h (1,1) {mustBePositive, mustBeInteger}
    w (1,1) {mustBePositive, mustBeInteger}
    options.binSize (1,1) {mustBePositive, mustBeInteger} = 1
end

img = zeros(h, w);
if tile.n_pixels == 0
    return;
end

counts = double(tile.count);
if ~isempty(gene_rows)
    keep = ismember(double(tile.gene_index), double(gene_rows(:)));
    if ~any(keep)
        return;
    end
    counts(~keep) = 0;
end

% Sum each pixel's run of the count vector. offset is zero-based, so
% pixel i spans counts(offset(i)+1 : offset(i+1)); a cumulative sum
% differenced at the boundaries does every pixel at once.
csum = [0; cumsum(counts)];
edges = double(tile.offset) + 1;
perPixel = csum(edges(2:end)) - csum(edges(1:end-1));

if options.binSize > 1
    perPixel = perPixel / double(options.binSize)^2;
end

% x and y are zero-based; MATLAB subscripts are one-based.
img = accumarray([double(tile.y) + 1, double(tile.x) + 1], perPixel, [h w]);

end % renderTile
