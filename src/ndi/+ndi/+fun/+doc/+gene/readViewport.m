function [img, info] = readViewport(session, pyrDoc, binSize, rect, geneRows, options)
% READVIEWPORT - render a rectangle of a pyramid level
%
%   [IMG, INFO] = ndi.fun.doc.gene.READVIEWPORT(SESSION, PYRDOC, BINSIZE, ...
%       RECT, GENEROWS)
%   [...] = ndi.fun.doc.gene.READVIEWPORT(..., 'density', false)
%
%   Fetches only the tiles that intersect RECT, renders the selected genes
%   from each, and assembles the result. Tiles that were never written
%   contribute zeros without any read.
%
%   Inputs:
%   PYRDOC   - a spatialGeneExpressionPyramid document
%   BINSIZE  - which level to read; must appear in the pyramid's bin_sizes
%   RECT     - [x0 y0 width height] in pixels OF THAT LEVEL, zero-based,
%              relative to the level's upper-left. Pass [] for the whole
%              level.
%   GENEROWS - ZERO-BASED gene list rows to include, or [] for every gene
%
%   Optional Name-Value Arguments:
%   density (true) - divide by binSize^2, giving counts per base pixel.
%                    Binning sums, so without this a coarse level is
%                    binSize^2 brighter than a fine one and a single
%                    contrast range cannot serve a whole pyramid.
%
%   Outputs:
%   IMG  - height-by-width double over RECT
%   INFO - struct with fields tilesRead, tilesEmpty, binSize, levelSize
%
%   Every tile carries the full gene axis, so changing GENEROWS costs no
%   further reads if the caller caches what it fetched.
%
%   See also: ndi.fun.doc.gene.makePyramid, ndi.fun.doc.gene.renderTile
%
arguments
    session (1,1)
    pyrDoc (1,1) ndi.document
    binSize (1,1) {mustBePositive, mustBeInteger}
    rect
    geneRows
    options.density (1,1) logical = true
end

p = pyrDoc.document_properties.spatialGeneExpressionPyramid;
[tileDoc, lv] = localFindLevel(session, pyrDoc, binSize);

lh = lv.dimension_size(1); lw = lv.dimension_size(2);
th = lv.tile_size_y_bins;   tw = lv.tile_size_x_bins;
G  = p.tile_rows;

if isempty(rect), rect = [0 0 lw lh]; end
x0 = rect(1); y0 = rect(2); wRect = rect(3); hRect = rect(4);
x1 = min(x0 + wRect, lw); y1 = min(y0 + hRect, lh);

img = zeros(hRect, wRect);
info = struct('tilesRead',0,'tilesEmpty',0,'binSize',binSize,'levelSize',[lh lw]);

stored = tileDoc.current_file_list();
cFirst = floor(x0 / tw); cLast = floor(max(x1-1,x0) / tw);
rFirst = floor(y0 / th); rLast = floor(max(y1-1,y0) / th);

for r = rFirst:min(rLast, G-1)
    for c = cFirst:min(cLast, G-1)
        name = sprintf('tile.bin_%d', r * p.tile_columns + c);
        if ~any(strcmp(name, stored))
            info.tilesEmpty = info.tilesEmpty + 1;
            continue;
        end
        % tilePath remembers where a tile landed, so a caller that reads
        % overlapping rectangles -- a sweep, a montage, one region for
        % several gene subsets -- pays an isfile check rather than a
        % document read and a location resolve each time.
        t = ndi.fun.doc.gene.readTileFile( ...
            ndi.fun.doc.gene.tilePath(session, tileDoc, name));
        info.tilesRead = info.tilesRead + 1;

        if options.density
            tImg = ndi.fun.doc.gene.renderTile(t, geneRows, th, tw, 'binSize', binSize);
        else
            tImg = ndi.fun.doc.gene.renderTile(t, geneRows, th, tw);
        end

        % place the overlap of this tile with the requested rectangle
        tx0 = c*tw; ty0 = r*th;
        ax0 = max(x0, tx0); ax1 = min(x1, tx0+tw);
        ay0 = max(y0, ty0); ay1 = min(y1, ty0+th);
        if ax1 <= ax0 || ay1 <= ay0, continue; end
        img(ay0-y0+1 : ay1-y0, ax0-x0+1 : ax1-x0) = ...
            tImg(ay0-ty0+1 : ay1-ty0, ax0-tx0+1 : ax1-tx0);
    end
end

end % readViewport

% ------------------------------------------------------------------------

function [tileDoc, lv] = localFindLevel(session, pyrDoc, binSize)
q = ndi.query('','depends_on','spatialGeneExpressionPyramid_id',pyrDoc.id()) & ...
    ndi.query('','isa','spatialGeneExpressionTiles');
docs = session.database_search(q);
for i = 1:numel(docs)
    lv = docs{i}.document_properties.spatialGeneExpressionTiles;
    if lv.bin_size == binSize
        tileDoc = docs{i};
        return;
    end
end
error('NDI:gene:readViewport:noSuchLevel', ...
    'This pyramid has no level with bin_size %d.', binSize);
end % localFindLevel
