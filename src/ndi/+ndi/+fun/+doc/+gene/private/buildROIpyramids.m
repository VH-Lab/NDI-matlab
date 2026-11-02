function [pyrDocs, tileDocsCell, geneListDoc, sourceDoc, info] = ...
    buildROIpyramids(session, x, y, geneIndex, count, geneID, geneName, ...
                     meta, gefPath, subjects, polygons, options)
% BUILDROIPYRAMIDS - shared core: records to N per-ROI pyramids
%
%   [PYRDOCS, TILEDOCSCELL, GENELISTDOC, SOURCEDOC, INFO] = ...
%       BUILDROIPYRAMIDS(SESSION, X, Y, GENEINDEX, COUNT, GENEID, GENENAME, ...
%                        META, GEFPATH, SUBJECTS, POLYGONS, OPTIONS)
%
%   Takes already-read GEF records and a list of (subject, polygon) pairs
%   and builds one spatialGeneExpressionPyramid per polygon, each tagged
%   with its subject. The geneList and the sourceFile documents are SHARED
%   across all ROIs: every pyramid built here came from the same .gef and
%   the same gene annotation, so the dependent documents point at a single
%   geneList and (when enabled) a single sourceFile.
%
%   This function exists because ndi.fun.doc.gene.fromGEFbyROI and
%   ndi.fun.doc.gene.fromGEFinteractive would otherwise be two copies of
%   the same loop differing only in where the polygons came from.
%
%   Inputs:
%   SESSION, X, Y, GENEINDEX, COUNT, GENEID, GENENAME, META
%       the output of ndr.format.stereoseq.readGEF, held once by the caller
%   GEFPATH   - path to the .gef, used only to make a sourceFile document
%   SUBJECTS  - 1xN cell array of subject ids
%   POLYGONS  - 1xN cell array of Mx2 polygon vertices IN GEF PIXEL
%               COORDINATES (col 1 is x, col 2 is y, M>=3)
%   OPTIONS   - struct with the same fields fromGEFbyROI exposes
%
%   Outputs:
%   PYRDOCS       - 1xN cell array of pyramid documents; a cell is [] if
%                   its polygon contained no records
%   TILEDOCSCELL  - 1xN cell array of tile-document cell arrays
%   GENELISTDOC   - the single shared geneList document
%   SOURCEDOC     - the single shared sourceFile document, or [] if
%                   OPTIONS.recordSource is false
%   INFO          - struct with META, SOURCEDOC, NOTES (same shape as
%                   fromGEF's INFO) and NKEEPPERROI (1xN count of records
%                   that landed in each polygon)
%
arguments
    session (1,1)
    x (:,1) {mustBeNumeric}
    y (:,1) {mustBeNumeric}
    geneIndex (:,1) {mustBeNumeric}
    count (:,1) {mustBeNumeric}
    geneID cell
    geneName cell
    meta (1,1) struct
    gefPath (1,:) char
    subjects (1,:) cell
    polygons (1,:) cell
    options (1,1) struct
end

n = numel(subjects);
if numel(polygons) ~= n
    error('NDI:gene:buildROIpyramids:lengthMismatch', ...
        'SUBJECTS and POLYGONS must be the same length (%d, %d).', ...
        n, numel(polygons));
end
if n == 0
    error('NDI:gene:buildROIpyramids:noROIs', ...
        'At least one (subject, polygon) pair is required.');
end

% -- resolve the chip and the base pixel size, same as fromGEF ------------
chipSerial = options.chipSerial;
if isempty(chipSerial)
    chipSerial = meta.chipSerial;
end
basePixelSize = options.basePixelSize;
if any(isnan(basePixelSize))
    % resolutionNm is nanometres and basePixelSize is micrometres. SAW's
    % usual 500 nm becomes 0.5, which is also makePyramid's default -- so
    % getting this conversion wrong looks exactly like the default.
    basePixelSize = [meta.resolutionNm meta.resolutionNm] / 1000;
end

% -- the shared documents -------------------------------------------------
localTick(options.progressFcn, 0.55, 'Building the gene list...');
geneListDoc = ndi.fun.doc.gene.makeGeneList(session, geneID, geneName, ...
    'genomeAssembly', options.genomeAssembly, ...
    'annotationSource', options.annotationSource, ...
    'geneIdNamespace', options.geneIdNamespace, ...
    'geneSymbolNamespace', options.geneSymbolNamespace, ...
    'label', options.label);

sourceDoc = [];
if options.recordSource
    localTick(options.progressFcn, 0.60, 'Describing the source file...');
    sourceDoc = ndi.fun.doc.gene.makeSourceFile(session, gefPath, ...
        'checksum', options.checksum);
    session.database_add(sourceDoc);
end

% -- per-ROI pyramids -----------------------------------------------------
% Progress plan: 0.00-0.55 is the caller's readGEF, 0.55-0.65 is the shared
% docs above, 0.65-1.00 is the N pyramids divided evenly.
pyrDocs = cell(1, n);
tileDocsCell = cell(1, n);
nKeepPerROI = zeros(1, n);
pyramidSpan = 1 - 0.65;
pyramidPerROI = pyramidSpan / n;

% Double once, for inpolygon only; the records go to makePyramid in the
% type the reader gave them. Promoting them for the whole build would cost
% 32 bytes a record where 14 does.
xd = double(x);
yd = double(y);

for k = 1:n
    poly = polygons{k};
    if ~isnumeric(poly) || size(poly, 1) < 3 || size(poly, 2) ~= 2
        error('NDI:gene:buildROIpyramids:polygonShape', ...
            ['Polygon %d must be a numeric Mx2 vertex list with M>=3; ' ...
             'got %dx%d.'], k, size(poly, 1), size(poly, 2));
    end
    if ~(ischar(subjects{k}) || (isstring(subjects{k}) && isscalar(subjects{k}))) ...
            || strlength(string(subjects{k})) == 0
        error('NDI:gene:buildROIpyramids:subjectEmpty', ...
            ['Subject %d is empty or not a scalar string; every polygon ' ...
             'needs a nonempty subject id.'], k);
    end
    subjectID = char(subjects{k});

    polyX = double(poly(:,1));
    polyY = double(poly(:,2));

    % bbox prefilter cuts inpolygon's query set by (bbox area / extent
    % area) for free: on a hemisphere split into three pieces that is a
    % 3x speedup. A separate find keeps keepIdx in records-space so the
    % subsequent indexing into x/y/geneIndex/count stays type-preserving.
    bbMask = xd >= min(polyX) & xd <= max(polyX) & ...
             yd >= min(polyY) & yd <= max(polyY);
    bbIdx = find(bbMask);
    inPoly = inpolygon(xd(bbIdx), yd(bbIdx), polyX, polyY);
    keepIdx = bbIdx(inPoly);
    nKeepPerROI(k) = numel(keepIdx);

    localTick(options.progressFcn, ...
        0.65 + (k-1) * pyramidPerROI, ...
        sprintf('Pyramid %d of %d (%d records)...', ...
            k, n, nKeepPerROI(k)));

    if nKeepPerROI(k) == 0
        warning('NDI:gene:buildROIpyramids:emptyROI', ...
            ['Polygon %d (subject %s) contained no records; no pyramid ' ...
             'was built.'], k, subjectID);
        continue;
    end

    sub = localSubProgress(options.progressFcn, ...
        0.65 + (k-1) * pyramidPerROI, ...
        0.65 + k * pyramidPerROI);

    [pyrDocs{k}, tileDocsCell{k}] = ndi.fun.doc.gene.makePyramid( ...
        session, x(keepIdx), y(keepIdx), ...
        geneIndex(keepIdx), count(keepIdx), geneListDoc, ...
        'binSizes', options.binSizes, 'grid', options.grid, ...
        'tileBudgetBytes', options.tileBudgetBytes, ...
        'gridRange', options.gridRange, ...
        'subjectID', subjectID, 'basePixelSize', basePixelSize, ...
        'pixelSizeUnits', options.pixelSizeUnits, 'label', options.label, ...
        'assay', options.assay, 'chipSerial', chipSerial, ...
        'pipelineVersion', options.pipelineVersion, ...
        'origin', options.origin, ...
        'sourceFileID', localDocID(sourceDoc), ...
        'progressFcn', sub);
end

localTick(options.progressFcn, 1, 'Done.');

info = struct();
info.meta = meta;
info.sourceDoc = sourceDoc;
info.notes = ndi.fun.doc.gene.readNotes(meta, geneID);
info.nKeepPerROI = nKeepPerROI;

end % buildROIpyramids

% ------------------------------------------------------------------------

function sub = localSubProgress(fcn, lo, hi)
% Re-scale a caller's [0 1] progress handle onto the [LO HI] slice of it.
if isempty(fcn)
    sub = [];
else
    sub = @(f, t) fcn(lo + (hi - lo) * f, t);
end
end

% ------------------------------------------------------------------------

function localTick(fcn, frac, txt)
if isempty(fcn), return; end
fcn(frac, txt);
end

% ------------------------------------------------------------------------

function id = localDocID(doc)
if isempty(doc)
    id = '';
else
    id = doc.id();
end
end
