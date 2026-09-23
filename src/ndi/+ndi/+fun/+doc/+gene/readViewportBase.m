function [img, info] = readViewportBase(session, pyrDoc, binSize, rectSource, geneRows, options)
% READVIEWPORTBASE - render a rectangle given in SOURCE coordinates
%
%   [IMG, INFO] = ndi.fun.doc.gene.READVIEWPORTBASE(SESSION, PYRDOC, ...
%       BINSIZE, RECTSOURCE, GENEROWS)
%   [...] = ndi.fun.doc.gene.READVIEWPORTBASE(..., 'density', false)
%
%   READVIEWPORT takes its rectangle in the pixels OF ONE LEVEL, zero-based
%   and relative to that level's upper-left. That is the right frame for
%   the tile arithmetic and the wrong frame for a caller, who has a
%   rectangle in the source coordinates the data was acquired in -- the
%   GEF's own x/y, the frame cell centroids and contours also live in.
%   Converting between the two means subtracting the pyramid origin and
%   dividing by the bin size with the rounding going the right way, which
%   is a short calculation that is easy to get subtly wrong and that every
%   viewer would otherwise write for itself.
%
%   The returned image always COVERS the requested rectangle: the low edge
%   rounds down and the high edge rounds up, so the caller never gets less
%   than it asked for. Because a level's bins do not generally align with
%   the requested edges, what comes back usually covers slightly MORE.
%   INFO.rectSourceCovered reports exactly what, so a caller can place the
%   image without re-deriving the rounding.
%
%   Inputs:
%   PYRDOC     - a spatialGeneExpressionPyramid document
%   BINSIZE    - which level to read; must appear in the pyramid's bin_sizes
%   RECTSOURCE - [x0 y0 width height] in SOURCE coordinates. Pass [] for
%                the pyramid's whole extent.
%   GENEROWS   - ZERO-BASED gene list rows to include, or [] for every gene
%
%   Optional Name-Value Arguments:
%   density (true) - divide by binSize^2, giving counts per base pixel, so
%                    one contrast range serves the whole ladder. See
%                    ndi.fun.doc.gene.readViewport.
%
%   Outputs:
%   IMG  - the rendered rectangle, in bins of BINSIZE
%   INFO - the struct from READVIEWPORT, plus:
%            rectLevel         - [x0 y0 w h] actually read, in level bins
%            rectSourceCovered - [x0 y0 w h] in source coordinates that IMG
%                                actually spans
%            originX, originY  - the pyramid origin that was subtracted
%
%   Example:
%       T = ndi.fun.doc.gene.levelTable(S, pyrDoc);
%       b = ndi.fun.doc.gene.chooseLevel(T, rect, 1024);
%       [img, info] = ndi.fun.doc.gene.readViewportBase(S, pyrDoc, b, rect, []);
%
%   See also: ndi.fun.doc.gene.readViewport, ndi.fun.doc.gene.levelTable,
%     ndi.fun.doc.gene.chooseLevel
%
arguments
    session (1,1)
    pyrDoc (1,1) ndi.document
    binSize (1,1) {mustBePositive, mustBeInteger}
    rectSource
    geneRows
    options.density (1,1) logical = true
end

p = pyrDoc.document_properties.spatialGeneExpressionPyramid;

if isempty(rectSource)
    rectSource = [p.origin_x p.origin_y p.extent_x p.extent_y];
end
if numel(rectSource) ~= 4
    error('NDI:gene:readViewportBase:badRect', ...
        'RECTSOURCE must be [x0 y0 width height] or []; got %d elements.', ...
        numel(rectSource));
end
if rectSource(3) <= 0 || rectSource(4) <= 0
    error('NDI:gene:readViewportBase:emptyRect', ...
        'RECTSOURCE must have positive width and height; got %g by %g.', ...
        rectSource(3), rectSource(4));
end

% source -> pyramid base pixels -> level bins. The low edge floors and the
% high edge ceils so the result covers the request rather than clipping it.
bx0 = rectSource(1) - p.origin_x;
by0 = rectSource(2) - p.origin_y;
lx0 = floor(bx0 / binSize);
ly0 = floor(by0 / binSize);
lx1 = ceil((bx0 + rectSource(3)) / binSize);   % exclusive
ly1 = ceil((by0 + rectSource(4)) / binSize);

% A request wholly outside the pyramid is a legitimate viewport, not an
% error -- a viewer pans off the edge routinely -- but it must not become a
% negative or zero-sized read, so clamp to the level and report what came
% back through rectSourceCovered.
lv = localLevelSize(session, pyrDoc, binSize);
lx0 = max(lx0, 0); ly0 = max(ly0, 0);
lx1 = min(lx1, lv(2)); ly1 = min(ly1, lv(1));
wLevel = max(lx1 - lx0, 0); hLevel = max(ly1 - ly0, 0);

rectLevel = [lx0 ly0 wLevel hLevel];

if wLevel == 0 || hLevel == 0
    img = zeros(max(hLevel,0), max(wLevel,0));
    info = struct('tilesRead',0,'tilesEmpty',0,'binSize',binSize, ...
        'levelSize',lv);
else
    [img, info] = ndi.fun.doc.gene.readViewport(session, pyrDoc, binSize, ...
        rectLevel, geneRows, 'density', options.density);
end

info.rectLevel = rectLevel;
info.rectSourceCovered = [ ...
    lx0 * binSize + p.origin_x, ...
    ly0 * binSize + p.origin_y, ...
    wLevel * binSize, ...
    hLevel * binSize];
info.originX = p.origin_x;
info.originY = p.origin_y;

end % readViewportBase

% ------------------------------------------------------------------------

function sz = localLevelSize(session, pyrDoc, binSize)
T = ndi.fun.doc.gene.levelTable(session, pyrDoc);
i = find(T.binSize == binSize, 1);
if isempty(i)
    error('NDI:gene:readViewportBase:noSuchLevel', ...
        'This pyramid has no level with bin_size %d. It has: %s.', ...
        binSize, mat2str(T.binSize(:)'));
end
sz = [T.levelHeight(i) T.levelWidth(i)];
end % localLevelSize
