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
%
%   PASS THESE IN THE TYPE THE READER GAVE THEM. They are held for the
%   whole build, so promoting an int32/uint16 record array to double
%   before calling costs 32 bytes a record where 14 would do -- 14 GB on
%   a 7.7e8-record section, held from the first level to the last. This
%   function converts per level, into temporaries it can release.
%   GENELISTDOC - the geneList ndi.document these indices refer to
%
%   Optional Name-Value Arguments:
%   binSizes ([1 2 4 8 16 32]) - level bin sizes in base pixels, finest
%       first. Dyadic by default. Each level transition compresses the
%       dynamic range of sparse counts by the step's AREA factor while
%       leaving the mean unchanged, so uniform, small ratios give the
%       smoothest zooming: a 2x step costs 4x, a 5x step costs 25x.
%   grid ([])           - tile grid, GRID by GRID at every level. Default
%       [] SIZES IT FROM THE DATA, which is the only way to size it: a
%       fixed 9x9 that gives a mouse section 20 MB tiles gives a ferret
%       hemisphere 257 MB ones, because the grid is a fixed fraction of
%       the extent and the extent is what changes. See tileBudgetBytes.
%       Pass a number to force one.
%   tileBudgetBytes (50 MB) - what the automatic grid aims for in the
%       BIGGEST tile at the finest level, not the average one. Tissue is
%       not spread evenly over its bounding box, so the densest tile of a
%       real section runs a few times the median and budgeting the median
%       misses by that factor. Bigger tiles mean fewer files to store,
%       upload and track; smaller tiles mean less to fetch before the
%       viewer can draw. Only consulted when grid is [].
%   gridRange ([3 64])  - bounds on the automatic grid. The upper bound is
%       a file-count limit rather than a geometric one: GRID^2 files per
%       level times the number of levels all have to be written, stored
%       and uploaded.
%   sourceFileID ('')   - id of a fileReference (or generic_file) document
%                         describing the
%       file this pyramid was built from. The spatialGeneExpressionTiles
%       class has carried a source_file_id dependency since it was
%       written and nothing populated it; ndi.fun.doc.gene.fromGEF now
%       does. Empty leaves it unset, which is what a pyramid built from
%       arrays in memory should say.
%   subjectID           - subject to depend on. REQUIRED: the pyramid
%       document declares subject_id mustbenotempty, because a section
%       is measured from an animal and NDI records that on the
%       measurement. The tiles and cells documents do NOT require it;
%       they depend on the pyramid, which already carries it, and a
%       second copy is a second place to be wrong.
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
%   progressFcn ([])    - a handle called as PROGRESSFCN(FRACTION, TEXT)
%       as the build moves, with FRACTION in [0 1] across THIS call. This
%       is the slow half of an ingest -- a 7.7e8-record section spends
%       minutes per level -- and reporting only at the ends of it makes
%       the whole pyramid look like one silent block, so every level and
%       every tile scan within it reports. Empty is silent, so a caller
%       with no display does not have to supply one.
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
%   WHAT IT COSTS TO RUN. A real section is ~10^8 records and this is the
%   step that decides whether it fits. Three things keep it down, and all
%   three are in localMakeLevel and localMakeBand:
%     - the records are used in the type they arrived in. Promoting them
%       to double costs 32 bytes a record for the whole build where 14
%       does.
%     - the sort key packs the tile, the pixel and the gene together, so
%       they are DECODED back out of it rather than carried alongside it.
%       Two full-length arrays go through the sort where six used to.
%     - a level is built ONE BAND OF TILE ROWS AT A TIME, so the sort's
%       working set is the section divided by the grid.
%   Measured together on a 7.7e8-record ferret hemisphere: about 90 GB of
%   MATLAB before, about 13 GB after.
%
%   TWO WAYS A LARGE SECTION BREAKS THIS, both checked before any tile is
%   written. Neither can be reached by a fixture of a few records, and one
%   of them is silent, so they are checked here rather than left to the
%   caller: this is where the extent, the gene count and the grid are all
%   known at once, and the arithmetic they threaten is the arithmetic
%   below.
%
%   See also: ndi.fun.doc.gene.makeGeneList, ndi.fun.doc.gene.readViewport
%
%
arguments
    session (1,1)
    x (:,1) {mustBeNumeric}
    y (:,1) {mustBeNumeric}
    geneIndex (:,1) {mustBeNumeric, mustBeNonnegative}
    count (:,1) {mustBeNumeric, mustBeNonnegative}
    geneListDoc (1,1) ndi.document
    options.binSizes (1,:) {mustBePositive, mustBeInteger} = [1 2 4 8 16 32]
    options.grid double = []
    options.tileBudgetBytes (1,1) double {mustBePositive} = 50 * 2^20
    options.gridRange (1,2) double {mustBePositive, mustBeInteger} = [3 64]
    options.subjectID (1,:) char = ''
    options.basePixelSize (1,2) double = [0.5 0.5]
    options.pixelSizeUnits (1,:) char = 'micrometer'
    options.label (1,:) char = ''
    options.assay (1,:) char = ''
    options.chipSerial (1,:) char = ''
    options.pipelineVersion (1,:) char = ''
    options.origin double = []
    options.sourceFileID (1,:) char = ''
    options.progressFcn = []
end

n = numel(x);
if ~all([numel(y) numel(geneIndex) numel(count)] == n)
    error('NDI:gene:makePyramid:lengthMismatch', ...
        'X, Y, GENEINDEX and COUNT must be the same length.');
end
if n == 0
    error('NDI:gene:makePyramid:noRecords', 'No records were supplied.');
end
if isempty(options.subjectID)
    % Checked here rather than left to the database. The pyramid schema
    % declares subject_id mustbenotempty, so an empty one fails inside DID
    % validation with a message about the schema; saying it here names the
    % argument the caller actually has to supply.
    error('NDI:gene:makePyramid:subjectRequired', ...
        ['A subject is required: pass ''subjectID'' with the id of a subject ' ...
         'document. The spatialGeneExpressionPyramid schema declares ' ...
         'subject_id mustbenotempty.']);
end

nGenes = geneListDoc.document_properties.geneList.n_genes;
if max(geneIndex) >= nGenes
    error('NDI:gene:makePyramid:geneIndexOutOfRange', ...
        ['Largest gene index is %d but the geneList has %d genes. ' ...
         'Indices are ZERO-BASED.'], max(geneIndex), nGenes);
end

% DOUBLE, deliberately, even when x and y are integers. Everything below
% subtracts these from the coordinates, and in MATLAB an integer minus a
% double is an INTEGER -- so an integer-typed minX would quietly turn the
% level-pixel division into rounded integer division instead of a floor.
if isempty(options.origin)
    minX = double(min(x)); minY = double(min(y));
else
    minX = double(options.origin(1)); minY = double(options.origin(2));
    if double(min(x)) < minX || double(min(y)) < minY
        error('NDI:gene:makePyramid:originExcludesData', ...
            'Supplied origin [%g %g] is larger than the data minimum [%g %g].', ...
            minX, minY, double(min(x)), double(min(y)));
    end
end
extentX = double(max(x)) - minX + 1;
extentY = double(max(y)) - minY + 1;

binSizes = sort(options.binSizes, 'ascend');

if isempty(options.grid)
    localTick(options.progressFcn, 0, 'Choosing the tile grid...');
    [G, estBytes] = localChooseGrid(x, y, minX, minY, extentX, extentY, ...
        binSizes(1), options.tileBudgetBytes, options.gridRange);
    % Said out loud, because the file COUNT is a cost this choice cannot
    % see: G^2 files per level, all of which have to be written, stored
    % and uploaded. A caller who cares more about that than about fetch
    % latency raises tileBudgetBytes or fixes grid outright.
    localTick(options.progressFcn, 0, sprintf( ...
        'Tile grid %dx%d: %s files per level, biggest tile about %s.', ...
        G, G, localComma(G*G), localBytes(estBytes)));
else
    if ~isscalar(options.grid) || options.grid < 1 || ...
            options.grid ~= fix(options.grid)
        error('NDI:gene:makePyramid:badGrid', ...
            '''grid'' must be a positive integer scalar, or [] to size it from the data.');
    end
    G = double(options.grid);
end

localCheckScale(extentX, extentY, binSizes, G, nGenes);

pyr = struct('label', options.label, ...
    'chip_serial', options.chipSerial, ...
    'pipeline_version', options.pipelineVersion, ...
    'bin_sizes', binSizes, ...
    'base_pixel_size_x', options.basePixelSize(1), ...
    'base_pixel_size_y', options.basePixelSize(2), ...
    'pixel_size_units', options.pixelSizeUnits, ...
    'origin_x', minX, 'origin_y', minY, ...
    'extent_x', extentX, 'extent_y', extentY, ...
    'tile_rows', G, 'tile_columns', G, ...
    'index_order', 'row-major', 'origin_corner', 'upper-left', ...
    'byte_order', 'little');
ge = struct('assay', options.assay, 'count_type', 'raw', 'count_units', 'UMI');

pyrDoc = ndi.document('spatialGeneExpressionPyramid', ...
    'spatialGeneExpressionPyramid', pyr, 'geneExpression', ge) + session.newdocument();
pyrDoc = pyrDoc.set_dependency_value('geneList_id', geneListDoc.id());
pyrDoc = pyrDoc.set_dependency_value('subject_id', options.subjectID);

localTick(options.progressFcn, 0, 'Summing per-gene totals...');
totalsPath = localWriteGeneTotals(geneIndex, count, nGenes);
pyrDoc = storeDoc(session, pyrDoc, {'gene_totals.tsv'}, {totalsPath});

nL = numel(binSizes);
tileDocs = cell(1, nL);
for k = 1:nL
    b = binSizes(k);
    % Equal shares. Every level sorts the SAME record array -- coarsening
    % merges pixels but leaves the genes distinct, so the record count
    % barely falls with bin size and bin32 costs about what bin1 costs.
    % Weighting the shares by output size would report a lie.
    lo = 0.05 + 0.95 * (k - 1) / nL;
    hi = 0.05 + 0.95 * k / nL;
    lvlProgress = @(f, t) localTick(options.progressFcn, lo + (hi - lo) * f, ...
        sprintf('Level %d of %d (bin %d): %s', k, nL, b, t));
    tileDocs{k} = localMakeLevel(session, x, y, geneIndex, count, ...
        minX, minY, extentX, extentY, b, G, nGenes, pyrDoc, options, ...
        lvlProgress);
end
localTick(options.progressFcn, 1, 'Pyramid complete.');

end % makePyramid

% ------------------------------------------------------------------------

function tileDoc = localMakeLevel(session, x, y, gi, c, minX, minY, ...
        extentX, extentY, b, G, nGenes, pyrDoc, options, lvlProgress)

lw = ceil(extentX / b);            % level size in this level's pixels
lh = ceil(extentY / b);
tw = ceil(lw / G);                 % tile size in this level's pixels
th = ceil(lh / G);

% ONE BAND OF TILE ROWS AT A TIME, and this is what decides how much
% memory a section needs.
%
% A tile row is the finest slice that keeps whole tiles together: a tile
% spans TH level rows and the full width of its row, so records in
% different tile rows never share a tile and can be sorted, collapsed and
% written entirely apart. Doing the whole level at once means the sort's
% working set scales with the section; doing it a band at a time means it
% scales with the section DIVIDED BY THE GRID -- and because the grid is
% chosen from the data, a section big enough to need the chunking is
% exactly the one that gets a fine grid to chunk with.
%
% The cost is G passes over the coordinates to select the bands, which is
% cheap next to G sorts, and a build that is somewhat slower and fits.
names = {}; paths = {};
for trow = 0:(G - 1)
    lvlProgress(0.05 + 0.85 * trow / G, ...
        sprintf('tile row %d of %d...', trow + 1, G));
    % The band's bounds in SOURCE units. Computing each record's level row
    % to compare against would allocate the full-length array this loop
    % exists not to allocate; the bounds map back into source units
    % exactly, so the comparison happens on the coordinates as they are.
    yLo = minY + trow * th * b;
    yHi = yLo + th * b;
    sel = (y >= yLo) & (y < yHi);
    if ~any(sel), continue; end
    [bNames, bPaths] = localMakeBand(x(sel), y(sel), gi(sel), c(sel), ...
        minX, minY, b, G, tw, th, nGenes);
    names = [names bNames]; %#ok<AGROW>
    paths = [paths bPaths]; %#ok<AGROW>
end
nStored = numel(names);

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
    'tile_compression', 'none', 'tile_format_version', 1, ...
    'tile_index_origin', 1);

tileDoc = ndi.document('spatialGeneExpressionTiles', ...
    'spatialGeneExpressionTiles', s) + session.newdocument();
tileDoc = tileDoc.set_dependency_value('spatialGeneExpressionPyramid_id', pyrDoc.id());
if ~isempty(options.subjectID)
    tileDoc = tileDoc.set_dependency_value('subject_id', options.subjectID);
end
if ~isempty(options.sourceFileID)
    tileDoc = tileDoc.set_dependency_value('source_file_id', options.sourceFileID);
end
lvlProgress(0.92, sprintf('storing %d tiles...', nStored));
tileDoc = storeDoc(session, tileDoc, names, paths);

end % localMakeLevel

% ------------------------------------------------------------------------

function [names, paths] = localMakeBand(x, y, gi, c, minX, minY, b, G, ...
        tw, th, nGenes)
% Collapse and write one band of tile rows.
%
% THE KEY SORTS TILE-MAJOR: tile index, then the pixel within the tile,
% then the gene. Two things follow, and both matter at scale.
%
% MEMORY. The key already encodes all three, so none of them has to
% survive the sort -- they are decoded back out of it afterwards. Two
% full-length arrays go through the sort where six used to.
%
% TIME. The sorted records arrive already grouped by tile, so each tile is
% one contiguous slice. The previous arrangement tested every record
% against every grid cell, one full pass per cell: tolerable at 9x9,
% ruinous once the grid is sized from the data and can reach 64x64.
%
% Neither changes what is written. Within a tile the records still come
% out ordered by row, then column, then gene, because a tile is a
% contiguous rectangle and global row-major order inside it IS local
% row-major order. The decode is exact for exactly as long as
% localCheckScale's 2^53 guard holds, which is the condition the key
% already needed.
%
% double(y) rather than (y - minY) so that an integer-typed coordinate
% array -- which is what ndr.format.stereoseq.readGEF returns -- does not
% drag minY into integer arithmetic and round where this wants a floor.
key = floor((double(y) - minY) / b);   % level row
py  = floor(key / th);                 % tile row
key = key - py * th;                   % pixel row within the tile
py  = py * G;
px  = floor((double(x) - minX) / b);   % level column
tcol = floor(px / tw);                 % tile column
px  = px - tcol * tw;                  % pixel column within the tile
py  = py + tcol;                       % tile index, row-major
clear tcol
key = (py * th + key) * tw + px;
clear py px
key = key * nGenes + double(gi);
[key, ord] = sort(key, 'ascend');
c = double(c(ord));
clear ord

% Collapse duplicate (pixel, gene) pairs created by binning.
starts = find([true; diff(key) ~= 0]);
last = [starts(2:end) - 1; numel(key)];
key = key(starts);
clear starts
% Run sums without a second full-length array: accumulate in place, then
% difference the running total at each run's end.
c = cumsum(c);
c = c(last);
c = [c(1); diff(c)];
clear last
c = min(c, 65535);                 % data_type_count is uint16

% Decode the survivors back out of the key. px and py come out already
% tile-local, which is the form writeTileFile wants.
gi  = mod(key, nGenes);
key = (key - gi) / nGenes;
px  = mod(key, tw);
key = (key - px) / tw;
py  = mod(key, th);
tid = (key - py) / th;
clear key

% One contiguous slice per occupied tile. Tiles with no data are not
% written at all, so the stored series has holes in it and
% ndi.document/current_file_list, not a walk, is what reports which exist.
tstart = find([true; diff(tid) ~= 0]);
tend   = [tstart(2:end) - 1; numel(tid)];
tval   = tid(tstart);
clear tid

names = cell(1, numel(tstart)); paths = cell(1, numel(tstart));
for k = 1:numel(tstart)
    r = tstart(k):tend(k);
    p = [tempname '.bin'];
    ndi.fun.doc.gene.writeTileFile(p, px(r), py(r), gi(r), c(r));
    % ONE-BASED file suffix: a DID file series names its first member
    % NAME_1 (did.document/addFileSeries: "Member indices must be positive
    % integers (one-based)"). The tile index stays zero-based -- it is a
    % grid position, defined by index_order as row*tile_columns + column.
    names{k} = sprintf('tile.bin_%d', tval(k) + 1);
    paths{k} = p;
end

end % localMakeBand

% ------------------------------------------------------------------------

function [G, estBytes] = localChooseGrid(x, y, minX, minY, extentX, ...
        extentY, b1, budget, gRange)
% Size the tile grid from where the data actually is.
%
% The thing being budgeted is the LARGEST tile at the FINEST level, which
% is the one a viewer waits on and the one that has to be uploaded. Two
% facts make the obvious estimate -- total bytes over GRID^2 -- wrong by
% a factor of a few:
%
%   1. Tissue does not fill its bounding box, and where it is present it
%      is not uniform. On a real ferret hemisphere the densest tile ran
%      2.5x the median, so budgeting the mean tile overshoots by 2.5x.
%   2. Coarser levels are cheaper per record but not by much -- binning
%      merges pixels while the genes in them stay distinct -- so bin1
%      binds and the other levels come along.
%
% So this histograms the records over the extent and budgets the heaviest
% cell, rather than assuming they are spread evenly.

H = 256;                       % histogram cells per side

% Subsample. Choosing a grid does not need every record, and a full pass
% would cost two more full-length doubles at exactly the moment this
% function is trying to save them. Records in a .gef are ordered by GENE,
% so a fixed stride is spatially unbiased.
n = numel(x);
step = max(1, ceil(n / 2e7));
cx = min(floor((double(x(1:step:end)) - minX) / extentX * H), H - 1);
cy = min(floor((double(y(1:step:end)) - minY) / extentY * H), H - 1);
h = accumarray(cy * H + cx + 1, 1, [H*H 1]);
clear cx cy
h = reshape(h, H, H);          % rows are cx, columns are cy
frac = h / sum(h(:));          % share of all records, per histogram cell

% Bytes a record costs in tile format version 1: 4 for the gene index, 2
% for the count, plus the per-pixel row header amortised over the genes
% detected in that pixel. Measured at ~10.6 on a full section; 11 is used
% so the estimate errs towards a smaller tile.
bytesPerRecord = 11;

gLo = max(gRange(1), 1);
gHi = max(gRange(2), gLo);
% A tile may not exceed 65536 level-pixels on a side: tile-local
% coordinates are uint16. localCheckScale raises this as an error; here it
% is simply a floor on the search, so the automatic grid never proposes a
% geometry that its own caller would then refuse.
side = max(ceil(extentX / b1), ceil(extentY / b1));
gLo = max(gLo, ceil(side / 65536));
gHi = max(gHi, gLo);

G = gHi; estBytes = Inf;
for g = gLo:gHi
    % Both partitions are uniform over the same extent, so a histogram
    % cell belongs to the tile containing its centre. The map is the same
    % along both axes and separable, so aggregating H x H down to g x g is
    % one indicator matrix applied on each side.
    m = min(floor(((0:H-1)' + 0.5) / H * g), g - 1) + 1;
    A = sparse((1:H)', m, 1, H, g);
    t = full(A' * frac * A);
    estBytes = max(t(:)) * n * bytesPerRecord;
    if estBytes <= budget
        G = g;
        break;
    end
end

end % localChooseGrid

% ------------------------------------------------------------------------

function localTick(fcn, frac, txt)
% Silent when no handle was given, so every phase can report progress
% without each call site testing for a display first.
if isempty(fcn), return; end
fcn(frac, txt);
end % localTick

% ------------------------------------------------------------------------

function s = localBytes(b)
% Progress text, so a rounded human unit rather than a byte count.
u = {'B','KB','MB','GB','TB'};
k = min(max(1, floor(log(max(b,1)) / log(1024)) + 1), numel(u));
s = sprintf('%.1f %s', b / 1024^(k-1), u{k});
end % localBytes

% ------------------------------------------------------------------------

function s = localComma(n)
% Thousands separators. A record count is the one number in this progress
% text that a reader has to judge the SIZE of, and 771217356 does not read.
s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end % localComma

% ------------------------------------------------------------------------

function localCheckScale(extentX, extentY, binSizes, G, nGenes)
% Refuse a pyramid whose arithmetic this function cannot represent.
%
% Both limits are invisible at fixture scale and reachable on a real
% section, so they are checked against the geometry rather than trusted.
% They live here because this is the only place that knows the extent, the
% gene count and the grid together -- a caller working from a file's
% attributes may not know the extent at all, since a GEF that carries none
% has no extent until its records have been read.

lw = ceil(extentX ./ binSizes);
lh = ceil(extentY ./ binSizes);

% (1) THE SORT KEY, and this is the silent one. Duplicate (pixel, gene)
% pairs are collapsed below with a key that packs the tile, the pixel
% within the tile and the gene into ONE DOUBLE. Doubles are exact
% integers only to 2^53. Past that, distinct records collide and their
% counts merge with no error raised anywhere -- a pyramid that builds
% cleanly and is wrong. localMakeLevel also DECODES the pixel and the
% gene back out of the key rather than carrying them alongside it, so
% past 2^53 the coordinates would be wrong too, not just merged.
%
% The key is tile-major, so its range is the level padded up to whole
% tiles: a little above lw*lh, not exactly it.
maxKey = max(G^2 .* ceil(lw / G) .* ceil(lh / G)) * nGenes;
if maxKey >= 2^53
    error('NDI:gene:makePyramid:sortKeyOverflow', ...
        ['This geometry would drive the duplicate-collapsing sort key to ' ...
         '%.4g, past 2^53 where doubles stop being exact integers. Distinct ' ...
         'records would collide and their counts would merge silently.\n' ...
         'Extent %g x %g, %d genes, finest bin %d. Reduce the gene list, ' ...
         'or coarsen the finest bin size.'], ...
        maxKey, extentX, extentY, nGenes, binSizes(1));
elseif 2^53 / maxKey < 10
    warning('NDI:gene:makePyramid:sortKeyTight', ...
        ['The sort key reaches %.4g, only %.1fx below 2^53. This section ' ...
         'is fine, but a larger one or a bigger gene list would overflow ' ...
         'and merge counts silently.'], maxKey, 2^53 / maxKey);
end

% (2) TILE-LOCAL COORDINATES are uint16 in the tile format, so no tile may
% be more than 65536 level-pixels on a side. Caught here rather than as
% coordinates that wrap inside writeTileFile.
maxSide = max([ceil(lw / G) ceil(lh / G)]);
if maxSide > 65536
    error('NDI:gene:makePyramid:tileTooWide', ...
        ['A tile would be %d level-pixels across, but tile-local ' ...
         'coordinates are uint16 (limit 65536). Raise ''grid'' to at ' ...
         'least %d.'], maxSide, ceil(max(max(lw), max(lh)) / 65536));
end

end % localCheckScale

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
