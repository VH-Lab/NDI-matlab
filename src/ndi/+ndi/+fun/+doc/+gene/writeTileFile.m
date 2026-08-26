function writeTileFile(filename, x, y, gene_index, count)
% WRITETILEFILE - write one spatialGeneExpressionTiles binary tile
%
%   ndi.fun.doc.gene.WRITETILEFILE(FILENAME, X, Y, GENE_INDEX, COUNT)
%
%   Writes tile format version 1 from flat, pixel-repeated records: one
%   entry of each input per (pixel, gene) pair. The records are grouped
%   into compressed-sparse-row form over occupied pixels, so each pixel's
%   coordinate is stored once rather than once per transcript.
%
%   Inputs:
%   FILENAME   - full path to write
%   X, Y       - tile-local pixel coordinates, ZERO-BASED, one per record
%   GENE_INDEX - row of the geneList, ZERO-BASED, one per record
%   COUNT      - count, one per record
%
%   All four inputs must be the same length. Passing zero records writes a
%   valid empty tile, but a tile with no data should normally not be
%   written at all: the document's file_list marks tiles as optional and
%   ndi.document/current_file_list reports which exist.
%
%   IMPORTANT: X, Y and GENE_INDEX are ZERO-BASED, matching the file
%   format and the geneList's genes.tsv. See ndi.fun.doc.gene.readTileFile
%   for why no conversion happens here.
%
%   Example:
%       ndi.fun.doc.gene.writeTileFile(f, [1 1 2], [0 0 3], [10 20 10], [2 1 4]);
%
%   See also: ndi.fun.doc.gene.readTileFile
%
arguments
    filename (1,:) char
    x (:,1) {mustBeNumeric, mustBeNonnegative}
    y (:,1) {mustBeNumeric, mustBeNonnegative}
    gene_index (:,1) {mustBeNumeric, mustBeNonnegative}
    count (:,1) {mustBeNumeric, mustBeNonnegative}
end

n = numel(x);
if numel(y) ~= n || numel(gene_index) ~= n || numel(count) ~= n
    error('NDI:gene:writeTileFile:lengthMismatch', ...
        'X, Y, GENE_INDEX and COUNT must be the same length (%d, %d, %d, %d).', ...
        n, numel(y), numel(gene_index), numel(count));
end

fid = fopen(filename, 'wb', 'ieee-le');
if fid < 0
    error('NDI:gene:writeTileFile:cannotOpen', ...
        'Could not open ''%s'' for writing.', filename);
end
c = onCleanup(@() fclose(fid));

if n == 0
    fwrite(fid, 0, 'uint32');
    fwrite(fid, 0, 'uint32');
    fwrite(fid, 0, 'uint32');   % offset is always n_pixels+1 entries
    return;
end

% Group records by pixel. Sort on the (y, x) key so the pixel order is
% deterministic and identical to the order NDI-python produces; a stable
% sort keeps each pixel's genes in their original order.
key = double(y) * 65536 + double(x);
[key, order] = sort(key, 'ascend');
x = x(order); y = y(order);
gene_index = gene_index(order); count = count(order);

isNew = [true; diff(key) ~= 0];
starts = find(isNew);
n_pixels = numel(starts);
offset = [starts - 1; n];      % zero-based row pointer

fwrite(fid, n_pixels, 'uint32');
fwrite(fid, n,        'uint32');
fwrite(fid, x(starts),   'uint16');
fwrite(fid, y(starts),   'uint16');
fwrite(fid, offset,      'uint32');
fwrite(fid, gene_index,  'uint32');
fwrite(fid, count,       'uint16');

end % writeTileFile
