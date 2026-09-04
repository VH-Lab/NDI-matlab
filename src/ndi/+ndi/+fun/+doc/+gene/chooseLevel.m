function [binSize, info] = chooseLevel(T, rectSource, targetPixels)
% CHOOSELEVEL - the coarsest pyramid level that still resolves a rectangle
%
%   [BINSIZE, INFO] = ndi.fun.doc.gene.CHOOSELEVEL(T, RECTSOURCE, TARGETPIXELS)
%
%   Given the level table T and a rectangle in SOURCE coordinates, returns
%   the largest bin size whose rendering of that rectangle is still at
%   least TARGETPIXELS across its longer side. Reading a finer level than
%   the display can show costs bin-size-squared more tiles for pixels that
%   are then thrown away; reading a coarser one loses detail the display
%   could have shown.
%
%   NOT NEEDED FOR NAPARI. napari's multiscale interface takes the whole
%   ladder and picks a level itself from the shape ratios, so a napari
%   viewer should hand it every level rather than choose one. This is for
%   the callers that render a single image: a MATLAB figure, a thumbnail,
%   an export, a tile server.
%
%   Inputs:
%   T            - the table from ndi.fun.doc.gene.levelTable
%   RECTSOURCE   - [x0 y0 width height] in source coordinates (the GEF's
%                  own x/y frame, the same frame cell centroids use)
%   TARGETPIXELS - how many pixels the longer side should span, at least
%
%   Outputs:
%   BINSIZE - the chosen bin size, always one present in T
%   INFO    - struct with fields:
%               renderedWidth, renderedHeight - the rectangle's size in
%                   bins at BINSIZE
%               longSide      - max(renderedWidth, renderedHeight)
%               metTarget     - false when even the finest level cannot
%                   reach TARGETPIXELS, in which case the finest is
%                   returned. Asking for more detail than the data holds is
%                   a legitimate request with a definite answer; it is not
%                   an error, but a caller that scales its display off the
%                   result should know it happened.
%
%   Example:
%       T = ndi.fun.doc.gene.levelTable(S, pyrDoc);
%       b = ndi.fun.doc.gene.chooseLevel(T, [3000 2000 4000 4000], 1024);
%
%   See also: ndi.fun.doc.gene.levelTable, ndi.fun.doc.gene.readViewportBase
%
arguments
    T table
    rectSource (1,4) double {mustBeFinite}
    targetPixels (1,1) double {mustBePositive}
end

w = rectSource(3); h = rectSource(4);
if w <= 0 || h <= 0
    error('NDI:gene:chooseLevel:emptyRect', ...
        'RECTSOURCE must have positive width and height; got %g by %g.', w, h);
end

% T is sorted finest first. Walk coarsest -> finest and take the first that
% still meets the target, so the answer is the COARSEST acceptable level.
longSide = max(w, h) ./ T.binSize;
ok = find(longSide >= targetPixels, 1, 'last');

if isempty(ok)
    ok = 1;                      % finest level; cannot do better
    metTarget = false;
else
    metTarget = true;
end

binSize = T.binSize(ok);
info = struct( ...
    'renderedWidth',  w / binSize, ...
    'renderedHeight', h / binSize, ...
    'longSide',       longSide(ok), ...
    'metTarget',      metTarget);

end % chooseLevel
