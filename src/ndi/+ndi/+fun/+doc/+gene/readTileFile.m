function tile = readTileFile(filename)
% READTILEFILE - read one spatialGeneExpressionTiles binary tile
%
%   TILE = ndi.fun.doc.gene.READTILEFILE(FILENAME)
%
%   Reads a tile of a spatialGeneExpressionTiles document (tile format
%   version 1) and returns its compressed-sparse-row arrays.
%
%   Inputs:
%   FILENAME - full path to a tile file (a 'tile.bin_N' of the document)
%
%   Outputs:
%   TILE - a structure with fields:
%       n_pixels   - number of occupied pixels in this tile
%       n_nonzero  - number of (pixel, gene) pairs
%       x, y       - (n_pixels x 1) tile-local pixel coordinates, ZERO-BASED
%       offset     - (n_pixels+1 x 1) row pointer, ZERO-BASED
%       gene_index - (n_nonzero x 1) row of the geneList, ZERO-BASED
%       count      - (n_nonzero x 1) counts
%
%   IMPORTANT: every index in the returned structure is ZERO-BASED, because
%   that is what the file holds and what the geneList's genes.tsv
%   gene_index column holds. They are deliberately NOT converted to
%   MATLAB's 1-based convention here: the same file is read by NDI-python,
%   and silently shifting indices on one side only is the most likely way
%   for the two implementations to disagree. Convert at the point of use;
%   ndi.fun.doc.gene.renderTile does so internally.
%
%   Pixel i (zero-based) holds the genes gene_index(offset(i)+1 :
%   offset(i+1)) in MATLAB indexing, with the matching entries of count.
%
%   All values are little-endian, per the pyramid's byte_order field.
%
%   Example:
%       t = ndi.fun.doc.gene.readTileFile('/path/to/tile.bin_12');
%
%   See also: ndi.fun.doc.gene.writeTileFile, ndi.fun.doc.gene.renderTile
%
arguments
    filename (1,:) char {mustBeFile}
end

fid = fopen(filename, 'rb', 'ieee-le');
if fid < 0
    error('NDI:gene:readTileFile:cannotOpen', ...
        'Could not open tile file ''%s''.', filename);
end
c = onCleanup(@() fclose(fid));

tile = struct();
tile.n_pixels  = double(fread(fid, 1, '*uint32'));
tile.n_nonzero = double(fread(fid, 1, '*uint32'));

if isempty(tile.n_pixels) || isempty(tile.n_nonzero)
    error('NDI:gene:readTileFile:truncated', ...
        'Tile file ''%s'' is shorter than its header.', filename);
end

tile.x          = fread(fid, tile.n_pixels,     '*uint16');
tile.y          = fread(fid, tile.n_pixels,     '*uint16');
tile.offset     = fread(fid, tile.n_pixels + 1, '*uint32');
tile.gene_index = fread(fid, tile.n_nonzero,    '*uint32');
tile.count      = fread(fid, tile.n_nonzero,    '*uint16');

if numel(tile.count) ~= tile.n_nonzero
    error('NDI:gene:readTileFile:truncated', ...
        ['Tile file ''%s'' ended early: expected %d counts, read %d. ' ...
         'The data_type_* fields of the document may not match the file.'], ...
        filename, tile.n_nonzero, numel(tile.count));
end

if tile.n_pixels > 0 && double(tile.offset(end)) ~= tile.n_nonzero
    error('NDI:gene:readTileFile:inconsistent', ...
        ['Tile file ''%s'' has a final offset of %d but %d nonzeros; ' ...
         'the row pointer does not span the data.'], ...
        filename, double(tile.offset(end)), tile.n_nonzero);
end

end % readTileFile
