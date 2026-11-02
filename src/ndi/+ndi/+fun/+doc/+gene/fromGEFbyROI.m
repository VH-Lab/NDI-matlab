function [pyrDocs, tileDocsCell, geneListDoc, sourceDoc, info] = ...
    fromGEFbyROI(session, gefPath, subjects, polygons, options)
% FROMGEFBYROI - import a .gef into N per-subject pyramids by polygon ROIs
%
%   [PYRDOCS, TILEDOCSCELL, GENELISTDOC, SOURCEDOC, INFO] = ...
%       ndi.fun.doc.gene.FROMGEFBYROI(SESSION, GEFPATH, SUBJECTS, POLYGONS)
%   [...] = ndi.fun.doc.gene.FROMGEFBYROI(..., 'binSizes', [1 2 4 8 16 32], ...)
%
%   Reads a Stereo-seq .gef ONCE and builds one spatial gene expression
%   pyramid per polygon, each attributed to the matching subject. Use this
%   when a single chip's section captured tissue from multiple animals: a
%   polygon per animal cuts the records in physical pixel coordinates and
%   writes a separate pyramid for each.
%
%   For picking polygons interactively on a quick preview of the file, use
%   ndi.fun.doc.gene.fromGEFinteractive instead; both call the same
%   internal path, so a script's three polygons and a scientist's three
%   drawn polygons produce the same result.
%
%   WHAT IS SHARED, WHAT IS NOT. One readGEF, one geneList, one
%   sourceFile. One pyramid and its tiles PER POLYGON, each with its own
%   subject on it. Overlap between polygons is honoured as drawn: a
%   record inside two polygons appears in both pyramids. Record
%   classification is inpolygon on the FULL polygon, not just its
%   bounding box.
%
%   Inputs:
%   SESSION   - an ndi.session or ndi.dataset
%   GEFPATH   - path to the .gef
%   SUBJECTS  - 1xN cell array of subject ids (one per polygon)
%   POLYGONS  - 1xN cell array of Mx2 polygon vertices in GEF pixel
%               coordinates: col 1 is x, col 2 is y, M>=3. These are the
%               same units ndr.format.stereoseq.readGEF returns in X, Y.
%
%   Optional Name-Value Arguments:
%       The same list ndi.fun.doc.gene.fromGEF exposes, minus subjectID
%       (which is replaced by SUBJECTS). All are passed through to
%       makePyramid for every ROI, so one call shares annotation,
%       binSizes, grid, assay, basePixelSize and the rest across the N
%       pyramids. SUBJECTID itself is NOT accepted: SUBJECTS replaces it,
%       and quietly ignoring one when the other is given would hide the
%       intent.
%
%   Outputs:
%   PYRDOCS       - 1xN cell array of pyramid documents (empty for an
%                   empty polygon)
%   TILEDOCSCELL  - 1xN cell array of tile-document cell arrays
%   GENELISTDOC   - the single shared geneList document
%   SOURCEDOC     - the single shared sourceFile document, or [] if
%                   recordSource is false
%   INFO          - struct with meta, sourceDoc, notes, nKeepPerROI, and
%                   roiDocs (a 1xN cell array of spatialGeneExpressionROI
%                   provenance documents, one per polygon, so a future
%                   V2 importer can lift the drawn geometry)
%
%   Example:
%       polyA = [1000 500; 3000 500; 3000 2500; 1000 2500];
%       polyB = [4000 500; 7000 500; 7000 2500; 4000 2500];
%       [pyrs, tiles, gl, src, info] = ndi.fun.doc.gene.fromGEFbyROI(S, ...
%           '/data/section.gef', {subA.id(), subB.id()}, {polyA, polyB}, ...
%           'genomeAssembly', 'monDom5');
%
%   See also: ndi.fun.doc.gene.fromGEF,
%             ndi.fun.doc.gene.fromGEFinteractive,
%             ndi.fun.doc.gene.makePyramid

arguments
    session (1,1)
    gefPath (1,:) char {mustBeFile}
    subjects (1,:) cell
    polygons (1,:) cell
    options.maxGenes (1,1) {mustBeInteger, mustBeNonnegative} = 0
    options.binSizes (1,:) {mustBePositive, mustBeInteger} = [1 2 4 8 16 32]
    options.grid double = []
    options.tileBudgetBytes (1,1) double {mustBePositive} = 50 * 2^20
    options.gridRange (1,2) double {mustBePositive, mustBeInteger} = [3 64]
    options.basePixelSize (1,2) double = [NaN NaN]
    options.pixelSizeUnits (1,:) char = 'micrometer'
    options.label (1,:) char = ''
    options.assay (1,:) char = 'Stereo-seq'
    options.chipSerial (1,:) char = ''
    options.pipelineVersion (1,:) char = ''
    options.origin double = []
    options.genomeAssembly (1,:) char = ''
    options.annotationSource (1,:) char = ''
    options.geneIdNamespace (1,:) char = ''
    options.geneSymbolNamespace (1,:) char = ''
    options.recordSource (1,1) logical = true
    options.checksum (1,1) logical = true
    options.verbose (1,1) logical = false
    options.progressFcn = []
end

% -- read, once ----------------------------------------------------------
localTick(options.progressFcn, 0, 'Reading the GEF...');
[x, y, geneIndex, count, geneID, geneName, meta] = ...
    ndr.format.stereoseq.readGEF(gefPath, 'maxGenes', options.maxGenes, ...
    'verbose', options.verbose);

[pyrDocs, tileDocsCell, geneListDoc, sourceDoc, info] = buildROIpyramids( ...
    session, x, y, geneIndex, count, geneID, geneName, meta, gefPath, ...
    subjects, polygons, options);

end % fromGEFbyROI

% ------------------------------------------------------------------------

function localTick(fcn, frac, txt)
if isempty(fcn), return; end
fcn(frac, txt);
end
