function [pyrDoc, tileDocs] = makePyramid(session, x, y, geneIndex, count, geneListDoc, options)
% MAKEPYRAMID - build a tiled multiresolution pyramid and its documents
%
%   [PYRDOC, TILEDOCS] = ndi.fun.doc.gene.MAKEPYRAMID(SESSION, X, Y, ...
%       GENEINDEX, COUNT, GENELISTDOC)
%   [...] = ndi.fun.doc.gene.MAKEPYRAMID(..., 'binSizes', [1 2 4 8 16 32], ...)
%
%   Bins flat spatial transcript records into a pyramid, writes one binary
%   file per tile per level, and creates the spatialGeneExpressionPyramid
%   document together with one spatialGeneExpressionTiles document per
%   level. Levels are siblings depending on the shared pyramid rather than
%   a chain, so enumerating them is a single query.
%
%   Inputs:
%   X, Y        - transcript coordinates in source units, one per record
%   GENEINDEX   - ZERO-BASED row of the gene list, one per record
%   COUNT       - counts, one per record
%   GENELISTDOC - the geneList ndi.document these indices refer to
%
%   Optional Name-Value Arguments:
%   binSizes ([1 2 4 8 16 32]) - level bin sizes in base pixels, finest
%       first. Dyadic by default. Each level transition compresses the
%       dynamic range of sparse counts by the step's AREA factor while
%       leaving the mean unchanged, so uniform, small ratios give the
%       smoothest zooming: a 2x step costs 4x, a 5x step costs 25x.
%   grid (9)            - tile grid, GRID by GRID at every level
%   subjectID ('')      - subject to depend on
%   basePixelSize ([0.5 0.5]) - physical size of one base pixel, [x y]
%   pixelSizeUnits ('micrometer')
%   label ('')
%   assay ('')
%   chipSerial ('')
%   pipelineVersion ('')
%   origin ([])         - [minX minY] of the tiled region. Default [] takes
%                         it from the data. Prefer passing the acquisition's
%                         own bounding box when it is known and contains
%                         the data; a data-derived origin shifts if the
%                         gene set changes.
%
%   Outputs:
%   PYRDOC   - the spatialGeneExpressionPyramid document
%   TILEDOCS - cell array of spatialGeneExpressionTiles documents
%
%   The tile grid is identical at every level. Coarsening trades occupied
%   pixels for genes detected per pixel, so nonzeros barely fall with bin
%   size (17% across a 32x downsample, measured) and every level wants
%   comparable tiling. A tile therefore covers the same physical region at
%   every level, and a viewport maps to tile indices once.
%
%   Tiles containing no data are not written; ndi.document/current_file_list
%   reports which exist.
%
%   See also: ndi.fun.doc.gene.makeGeneList, ndi.fun.doc.gene.readViewport
%
arguments
    session (1,1)
    x (:,1) {mustBeNumeric}
    y (:,1) {mustBeNumeric}
    geneIndex (:,1) {mustBeNumeric, mustBeNonnegative}
    count (:,1) {mustBeNumeric, mustBeNonnegative}
    geneListDoc (1,1) ndi.document
    options.binSizes (1,:) {mustBePositive, mustBeInteger} = [1 2 4 8 16 32]
    options.grid (1,1) {mustBePositive, mustBeInteger} = 9
    options.subjectID (1,:) char = ''
    options.basePixelSize (1,2) double = [0.5 0.5]
    options.pixelSizeUnits (1,:) char = 'micrometer'
    options.label (1,:) char = ''
    options.assay (1,:) char = ''
    options.chipSerial (1,:) char = ''
    options.pipelineVersion (1,:) char = ''
    options.origin double = []
end

n = numel(x);
if ~all([numel(y) numel(geneIndex) numel(count)] == n)
    error('NDI:gene:makePyramid:lengthMismatch', ...
        'X, Y, GENEINDEX and COUNT must be the same length.');
end
if n == 0
    error('NDI:gene:makePyramid:noRecords', 'No records were supplied.');
end

nGenes = geneListDoc.document_properties.geneList.n_genes;
if max(geneIndex) >= nGenes
    error('NDI:gene:makePyramid:geneIndexOutOfRange', ...
        ['Largest gene index is %d but the geneList has %d genes. ' ...
         'Indices are ZERO-BASED.'], max(geneIndex), nGenes);
end

if isempty(options.origin)
    minX = min(x); minY = min(y);
else
    minX = options.origin(1); minY = options.origin(2);
    if min(x) < minX || min(y) < minY
        error('NDI:gene:makePyramid:originExcludesData', ...
            'Supplied origin [%g %g] is larger than the data minimum [%g %g].', ...
            minX, minY, min(x), min(y));
    end
end
extentX = double(max(x) - minX + 1);
extentY = double(max(y) - minY + 1);

G = options.grid;
binSizes = sort(options.binSizes, 'ascend');

pyr = struct('label', options.label, ...
    'chip_serial', options.chipSerial, ...
    'pipeline_version', options.pipelineVersion, ...
    'bin_sizes', binSizes, ...
    'base_pixel_size_x', options.basePixelSize(1), ...
    'base_pixel_size_y', options.basePixelSize(2), ...
    'pixel_size_units', options.pixelSizeUnits, ...
    'origin_x', double(minX), 'origin_y', double(minY), ...
    'extent_x', extentX, 'extent_y', extentY, ...
    'tile_rows', G, 'tile_columns', G, ...
    'index_order', 'row-major', 'origin_corner', 'upper-left', ...
    'byte_order', 'little');
ge = struct('assay', options.assay, 'count_type', 'raw', 'count_units', 'UMI');

pyrDoc = ndi.document('spatialGeneExpressionPyramid', ...
    'spatialGeneExpressionPyramid', pyr, 'geneExpression', ge) + session.newdocument();
pyrDoc = pyrDoc.set_dependency_value('geneList_id', geneListDoc.id());
if ~isempty(options.subjectID)
    pyrDoc = pyrDoc.set_dependency_value('subject_id', options.subjectID);
end

totalsPath = localWriteGeneTotals(geneIndex, count, nGenes);
pyrDoc = storeDoc(session, pyrDoc, {'gene_totals.tsv'}, {totalsPath});

tileDocs = cell(1, numel(binSizes));
for k = 1:numel(binSizes)
    b = binSizes(k);
    tileDocs{k} = localMakeLevel(session, x, y, geneIndex, count, ...
        minX, minY, extentX, extentY, b, G, nGenes, pyrDoc, options);
end

end % makePyramid

% ------------------------------------------------------------------------

function tileDoc = localMakeLevel(session, x, y, gi, c, minX, minY, ...
        extentX, extentY, b, G, nGenes, pyrDoc, options)

lw = ceil(extentX / b);            % level size in this level's pixels
lh = ceil(extentY / b);
tw = ceil(lw / G);                 % tile size in this level's pixels
th = ceil(lh / G);

px = floor(double(x - minX) / b);  % level pixel of each record
py = floor(double(y - minY) / b);

% Collapse duplicate (pixel, gene) pairs created by binning.
key = (py * lw + px) * nGenes + double(gi);
[key, ord] = sort(key, 'ascend');
px = px(ord); py = py(ord); c = double(c(ord)); gi = double(gi(ord));
isNew = [true; diff(key) ~= 0];
starts = find(isNew);
csum = [0; cumsum(c)];
c = csum([starts(2:end); numel(key)+1]) - csum(starts);
px = px(starts); py = py(starts); gi = gi(starts);
c = min(c, 65535);                 % data_type_count is uint16

tcol = floor(px / tw); trow = floor(py / th);
tid  = trow * G + tcol;            % index_order is row-major

names = {}; paths = {}; nStored = 0;
for t = 0:(G*G - 1)
    m = (tid == t);
    if ~any(m), continue; end
    p = [tempname '.bin'];
    ndi.fun.doc.gene.writeTileFile(p, mod(px(m), tw), mod(py(m), th), gi(m), c(m));
    nStored = nStored + 1;
    names{end+1} = sprintf('tile.bin_%d', t); %#ok<AGROW>
    paths{end+1} = p;                          %#ok<AGROW>
end

s = struct('label', sprintf('bin%d', b), 'bin_size', b, ...
    'pixel_size_x', options.basePixelSize(1) * b, ...
    'pixel_size_y', options.basePixelSize(2) * b, ...
    'pixel_size_units', options.pixelSizeUnits, ...
    'dimension_order', 'YXG', 'dimension_labels', 'height,width,gene', ...
    'dimension_size', [lh lw nGenes], ...
    'dimension_scale', [options.basePixelSize(2)*b options.basePixelSize(1)*b 1], ...
    'dimension_scale_units', 'micrometer,micrometer,dimensionless', ...
    'tile_size_x_bins', tw, 'tile_size_y_bins', th, ...
    'n_tiles_stored', nStored, ...
    'data_type_gene_index', 'uint32', 'data_type_count', 'uint16', ...
    'data_type_offset', 'uint32', 'data_type_coordinate', 'uint16', ...
    'tile_compression', 'none', 'tile_format_version', 1);

tileDoc = ndi.document('spatialGeneExpressionTiles', ...
    'spatialGeneExpressionTiles', s) + session.newdocument();
tileDoc = tileDoc.set_dependency_value('spatialGeneExpressionPyramid_id', pyrDoc.id());
if ~isempty(options.subjectID)
    tileDoc = tileDoc.set_dependency_value('subject_id', options.subjectID);
end
tileDoc = storeDoc(session, tileDoc, names, paths);

end % localMakeLevel

% ------------------------------------------------------------------------

function p = localWriteGeneTotals(gi, c, nGenes)
% Per-gene totals for THIS dataset. Not a column of genes.tsv: that file
% belongs to the geneList, which several datasets may share and which would
% then disagree about totals.
tot = accumarray(double(gi(:)) + 1, double(c(:)), [nGenes 1]);
npx = accumarray(double(gi(:)) + 1, 1, [nGenes 1]);
p = [tempname '.tsv'];
fid = fopen(p, 'w');
cl = onCleanup(@() fclose(fid));
fprintf(fid, 'gene_index\ttotal_counts\tn_records\n');
fprintf(fid, '%d\t%d\t%d\n', [(0:nGenes-1); tot(:)'; npx(:)']);
end % localWriteGeneTotals
