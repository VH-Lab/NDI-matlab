function name = tileFileName(tileProps, index)
%TILEFILENAME Name of the file holding one tile of a tiles document.
%
%   NAME = NDI.FUN.DOC.GENE.TILEFILENAME(TILEPROPS, INDEX) returns the
%   file name, e.g. 'tile.bin_1', for the tile whose ZERO-BASED grid
%   INDEX is given. TILEPROPS is the spatialGeneExpressionTiles property
%   struct of the tiles document.
%
%   THE SUFFIX IS ONE-BASED. A DID file series names its first member
%   NAME_1, not NAME_0: did.document/addFileSeries takes "ONE-BASED
%   member numbers" and rejects anything else ("Member indices must be
%   positive integers (one-based)").
%
%   THE INDEX IS NOT. It is a grid position, and the parent pyramid's
%   index_order defines it as row*tile_columns + column for 'row-major'.
%   So the suffix is the index plus the document's tile_index_origin.
%
%   WHY THE ORIGIN IS READ RATHER THAN GUESSED. Pyramids built before the
%   one-based convention was honoured name their first tile tile.bin_0
%   and record no tile_index_origin, which reads as 0 and keeps them
%   readable. Inferring the origin from the stored names cannot work: a
%   sparse pyramid whose first tile is empty has no _0 under either
%   convention, so a guess would shift every tile one cell along its row
%   on the documents it got wrong -- an image that is quietly wrong,
%   rather than one that is missing.
%
%   Inputs:
%   TILEPROPS - the spatialGeneExpressionTiles property struct
%   INDEX     - zero-based grid index of the tile
%
%   Outputs:
%   NAME - the file's name within the tiles document
%
%   Example:
%       name = ndi.fun.doc.gene.tileFileName(lv, r*p.tile_columns + c);
%
%   See also: ndi.fun.doc.gene.tileIndexFromName,
%             ndi.fun.doc.gene.readViewport, ndi.fun.doc.gene.exportRegion

arguments
    tileProps (1,1) struct
    index (1,1) {mustBeInteger, mustBeNonnegative}
end

name = sprintf('tile.bin_%d', index + ndi.fun.doc.gene.tileIndexOrigin(tileProps));

end
