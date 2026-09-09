function o = tileIndexOrigin(tileProps)
%TILEINDEXORIGIN The origin a tiles document used for its file suffixes.
%
%   O = NDI.FUN.DOC.GENE.TILEINDEXORIGIN(TILEPROPS) returns the number
%   added to a tile's zero-based grid index to get its file suffix: 1 for
%   documents written since the one-based DID file-series convention was
%   honoured, and 0 for older ones, which record nothing here.
%
%   A value that is absent, empty or not a scalar number reads as 0. A
%   malformed document should not take down a viewer part way through
%   building a layer, and 0 is the reading that keeps the pyramids that
%   already exist openable.
%
%   Inputs:
%   TILEPROPS - the spatialGeneExpressionTiles property struct
%
%   Outputs:
%   O - 0 or 1
%
%   See also: ndi.fun.doc.gene.tileFileName,
%             ndi.fun.doc.gene.tileIndexFromName

arguments
    tileProps (1,1) struct
end

o = 0;
if isfield(tileProps, 'tile_index_origin')
    v = tileProps.tile_index_origin;
    if isnumeric(v) && isscalar(v) && isfinite(v)
        o = double(v);
    end
end

end
