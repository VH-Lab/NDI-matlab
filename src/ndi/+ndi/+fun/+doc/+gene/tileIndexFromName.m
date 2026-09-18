function index = tileIndexFromName(tileProps, name)
%TILEINDEXFROMNAME The zero-based grid index of the tile stored under NAME.
%
%   INDEX = NDI.FUN.DOC.GENE.TILEINDEXFROMNAME(TILEPROPS, NAME) is the
%   inverse of ndi.fun.doc.gene.tileFileName: it takes a stored file name
%   such as 'tile.bin_35' and returns the tile's grid index.
%
%   Readers that walk a document's stored names and work backwards to
%   (row, column) need this. With a one-based origin the suffix is one
%   MORE than the grid index, so reading the suffix AS the index puts
%   every tile one cell along its row -- and the last tile of a row into
%   the next row, where it lands on top of a tile that belongs there.
%
%   Inputs:
%   TILEPROPS - the spatialGeneExpressionTiles property struct
%   NAME      - a stored file name, e.g. 'tile.bin_35'
%
%   Outputs:
%   INDEX - zero-based grid index
%
%   See also: ndi.fun.doc.gene.tileFileName,
%             ndi.fun.doc.gene.tileIndexOrigin

arguments
    tileProps (1,1) struct
    name (1,:) char
end

parts = strsplit(name, '_');
index = str2double(parts{end}) - ndi.fun.doc.gene.tileIndexOrigin(tileProps);

end
