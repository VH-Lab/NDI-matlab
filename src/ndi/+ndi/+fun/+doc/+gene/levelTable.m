function T = levelTable(session, pyrDoc)
% LEVELTABLE - the pyramid's level ladder as one table
%
%   T = ndi.fun.doc.gene.LEVELTABLE(SESSION, PYRDOC)
%
%   Returns one row per stored level of the pyramid, finest first, joining
%   what the pyramid document knows (the ladder, the grid, the base pixel
%   size, the origin) with what each level's tile document knows (that
%   level's pixel dimensions, its tile size, how many tiles it stores).
%
%   The two halves live in different documents -- the ladder in
%   spatialGeneExpressionPyramid, the per-level geometry in one
%   spatialGeneExpressionTiles document per level -- and until now only a
%   private helper inside READVIEWPORT reached across them. Every caller
%   that wanted to set up a viewer, size a figure, or choose a level had to
%   re-derive the join. This is that join, once.
%
%   Inputs:
%   SESSION - an ndi.session or ndi.dataset holding the documents
%   PYRDOC  - a spatialGeneExpressionPyramid document
%
%   Outputs:
%   T - a table with one row per level, sorted by ascending binSize, with
%       variables:
%         binSize      - the level's bin size, in base pixels per bin
%         levelHeight  - the level's height, in bins
%         levelWidth   - the level's width, in bins
%         tileHeight   - tile height, in bins
%         tileWidth    - tile width, in bins
%         tileRows     - grid rows (constant across levels)
%         tileColumns  - grid columns (constant across levels)
%         nTilesStored - tiles actually written at this level
%         nTilesGrid   - tileRows*tileColumns, the tiles a full grid holds
%         pixelSizeX   - width of one bin, in pixelSizeUnits
%         pixelSizeY   - height of one bin, in pixelSizeUnits
%         tileDocId    - the id of that level's tile document
%
%       T.Properties.UserData carries the frame shared by every level:
%       originX, originY, extentX, extentY, basePixelSizeX, basePixelSizeY,
%       pixelSizeUnits, indexOrder, originCorner. A viewer needs those to
%       place the pyramid in world coordinates and would otherwise reach
%       back into the document for them.
%
%   Levels are returned finest first because that is the order napari and
%   the other multiscale viewers expect a ladder in, and because level 1 of
%   the table then means the finest level rather than an arbitrary one.
%
%   Example:
%       T = ndi.fun.doc.gene.levelTable(S, pyrDoc);
%       disp(T);
%       finest = T.binSize(1);
%
%   See also: ndi.fun.doc.gene.readViewport, ndi.fun.doc.gene.readViewportBase,
%     ndi.fun.doc.gene.makePyramid
%
arguments
    session (1,1)
    pyrDoc (1,1) ndi.document
end

p = pyrDoc.document_properties.spatialGeneExpressionPyramid;

q = ndi.query('','depends_on','spatialGeneExpressionPyramid_id',pyrDoc.id()) & ...
    ndi.query('','isa','spatialGeneExpressionTiles');
docs = session.database_search(q);

if isempty(docs)
    error('NDI:gene:levelTable:noLevels', ...
        'Pyramid %s has no spatialGeneExpressionTiles documents.', pyrDoc.id());
end

n = numel(docs);
binSize = zeros(n,1); levelHeight = zeros(n,1); levelWidth = zeros(n,1);
tileHeight = zeros(n,1); tileWidth = zeros(n,1);
nTilesStored = zeros(n,1);
pixelSizeX = zeros(n,1); pixelSizeY = zeros(n,1);
tileDocId = strings(n,1);

for i = 1:n
    lv = docs{i}.document_properties.spatialGeneExpressionTiles;
    binSize(i) = lv.bin_size;
    % dimension_size is [height width nGenes] in the document's YXG order;
    % only the first two are geometry.
    levelHeight(i) = lv.dimension_size(1);
    levelWidth(i)  = lv.dimension_size(2);
    tileHeight(i)  = lv.tile_size_y_bins;
    tileWidth(i)   = lv.tile_size_x_bins;
    nTilesStored(i) = lv.n_tiles_stored;
    pixelSizeX(i)  = lv.pixel_size_x;
    pixelSizeY(i)  = lv.pixel_size_y;
    tileDocId(i)   = string(docs{i}.id());
end

tileRows = repmat(p.tile_rows, n, 1);
tileColumns = repmat(p.tile_columns, n, 1);
nTilesGrid = tileRows .* tileColumns;

T = table(binSize, levelHeight, levelWidth, tileHeight, tileWidth, ...
    tileRows, tileColumns, nTilesStored, nTilesGrid, ...
    pixelSizeX, pixelSizeY, tileDocId);

T = sortrows(T, 'binSize');           % finest first

T.Properties.UserData = struct( ...
    'originX', p.origin_x, 'originY', p.origin_y, ...
    'extentX', p.extent_x, 'extentY', p.extent_y, ...
    'basePixelSizeX', p.base_pixel_size_x, ...
    'basePixelSizeY', p.base_pixel_size_y, ...
    'pixelSizeUnits', p.pixel_size_units, ...
    'indexOrder', p.index_order, ...
    'originCorner', p.origin_corner);

end % levelTable
