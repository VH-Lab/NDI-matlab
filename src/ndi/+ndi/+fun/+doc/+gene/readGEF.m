function [x, y, geneIndex, count, geneID, geneName, meta] = readGEF(gefPath, options)
% READGEF - read a Stereo-seq GEF into the flat records makePyramid takes
%
%   [X, Y, GENEINDEX, COUNT, GENEID, GENENAME, META] = ...
%       ndi.fun.doc.gene.READGEF(GEFPATH)
%   [...] = ndi.fun.doc.gene.READGEF(..., 'probeOnly', true)
%
%   Reads a BGI/MGI Stereo-seq .gef (an HDF5 file) and returns one record
%   per (pixel, gene) pair, in the shape ndi.fun.doc.gene.makePyramid
%   expects: X and Y in source units, GENEINDEX a ZERO-BASED row of the
%   returned gene list, COUNT saturating at the tile format's ceiling.
%
%   Optional Name-Value Arguments:
%   probeOnly (false)    - read the gene table, extent and metadata but NOT
%                          the expression records. X, Y, GENEINDEX and COUNT
%                          come back empty; META.nRecords is still exact,
%                          because it is the sum of the gene table's own
%                          counts. A real section holds ~10^8 records and
%                          takes minutes, so a caller that only needs to
%                          SHOW what is in a file -- an ingest GUI listing
%                          genes, extent and chip before the user commits --
%                          can ask without paying for the data.
%   maxGenes (0)         - stop after this many genes; 0 reads all. Use a
%                          few thousand for a first pass.
%   countCeiling (65535) - counts saturate here rather than wrapping, and
%                          META.nCountsClamped reports how many did. The
%                          default is what the tile format stores; it is an
%                          argument so a widened level does not need a new
%                          reader.
%   root ('')            - force the HDF5 group, e.g. '/geneExp/bin1'.
%                          Default '' probes the known layouts.
%   verbose (false)      - progress to the command window. Off by default
%                          because a library function called from a GUI must
%                          not print; the batch harnesses pass true.
%
%   Outputs:
%   X, Y      - int32 columns, source coordinates
%   GENEINDEX - int32 column, ZERO-BASED row into GENEID/GENENAME
%   COUNT     - uint16 column
%   GENEID    - cellstr of accessions, one per gene row; feeds makeGeneList
%   GENENAME  - cellstr of symbols, one per gene row (entries may be empty)
%   META      - struct: root, exprDataset, fields, nGenesInFile, nGenes,
%               nRecords, box, boxSource, resolutionNm, chipSerial,
%               nCountsClamped, statTotals, statTotalsNote, readSeconds
%
%   NOTHING ABOUT THE LAYOUT IS ASSUMED. Every path and field name is probed
%   against a candidate list, because real files disagree: records live under
%   /geneExp/bin1 or /wholeExp/bin1, the expression dataset is expression or
%   cellBin, coordinates are x/y or X/Y, and the count field has four
%   spellings. GEF layouts drift between SAW versions.
%
%   THE EXTENT IS TRUSTED ONLY WHEN IT CONTAINS THE DATA. SAW writes
%   minX/maxX/minY/maxY as attributes, but WHERE varies -- the bin group, an
%   ancestor, or the file root -- so all are probed, nearest first. An
%   attribute box that does not enclose the actual coordinates is REJECTED
%   in favour of the data, which cannot be wrong about its own extent.
%   Probing only the root silently yields a 1x1 pyramid on files that put
%   the attributes deeper; that is how this was first found wrong, and a
%   synthetic fixture that writes them at the root agrees with the bug
%   instead of catching it.
%
%   COUNTS ARE CLIPPED IN A WIDE TYPE. SAW writes uint8 counts at bin1, and
%   min() on a uint8 array saturates at 255 rather than clipping at 65535 --
%   the same trap that bit the Python builder under numpy 2.
%
%   Example:
%       [~,~,~,~,id,nm,m] = ndi.fun.doc.gene.readGEF(f,'probeOnly',true);
%       fprintf('%d genes, %d x %d\n', numel(id), ...
%           m.box(3)-m.box(1)+1, m.box(4)-m.box(2)+1);
%
%   See also: ndi.fun.doc.gene.makePyramid, ndi.fun.doc.gene.makeGeneList
%
arguments
    gefPath (1,:) char {mustBeFile}
    options.probeOnly (1,1) logical = false
    options.maxGenes (1,1) {mustBeInteger, mustBeNonnegative} = 0
    options.countCeiling (1,1) {mustBePositive} = 65535
    options.root (1,:) char = ''
    options.verbose (1,1) logical = false
end

t0 = tic;

% -- locate the (gene, expression) pair -----------------------------------
if isempty(options.root)
    roots = {'/geneExp/bin1', '/wholeExp/bin1'};
else
    roots = {options.root};
end
root = ''; exprName = '';
for i = 1:numel(roots)
    if ~localHasDataset(gefPath, [roots{i} '/gene']), continue; end
    for e = {'expression', 'cellBin'}
        if localHasDataset(gefPath, [roots{i} '/' e{1}])
            root = roots{i}; exprName = e{1}; break;
        end
    end
    if ~isempty(root), break; end
end
if isempty(root)
    error('NDI:gene:readGEF:noGeneExpressionPair', ...
        'No (gene, expression) pair under %s in %s.', strjoin(roots, ', '), gefPath);
end
geneDs = [root '/gene'];
exprDs = [root '/' exprName];

% -- gene table (small: tens of thousands of rows) ------------------------
G = h5read(gefPath, geneDs);
gf = fieldnames(G);
nameField = localPick(gf, {'geneName','geneID','name','gene'});
idField   = localPick(gf, {'geneID','gene','geneName','name'});
offField  = localPick(gf, {'offset','offsets'});
cntField  = localPick(gf, {'count','counts'});

geneName = localToCellstr(G.(nameField));
geneID   = localToCellstr(G.(idField));
gOffset  = double(G.(offField)(:));
gCount   = double(G.(cntField)(:));

nGenesAll = numel(gCount);
nGenes = nGenesAll;
if options.maxGenes > 0
    nGenes = min(options.maxGenes, nGenesAll);
end
geneName = geneName(1:nGenes); geneID = geneID(1:nGenes);

if options.verbose
    fprintf('[gef] %s\n', gefPath);
    fprintf('[gef] root=%s expr=%s  genes=%d of %d\n', ...
        root, exprName, nGenes, nGenesAll);
    fprintf('[gef] gene fields: id=%s name=%s offset=%s count=%s\n', ...
        idField, nameField, offField, cntField);
end

% -- expression field names, WITHOUT reading any records ------------------
% h5info exposes the compound members, so probeOnly can report the layout
% it would have used and a real read validates its field choice up front.
ei = h5info(gefPath, exprDs);
ef = {ei.Datatype.Type.Member.Name};
exF = localPick(ef, {'x','X'});
eyF = localPick(ef, {'y','Y'});
ecF = localPick(ef, {'count','MIDCount','mid_count','umi'});
if options.verbose
    fprintf('[gef] expression fields: x=%s y=%s count=%s\n', exF, eyF, ecF);
end

nRecordsAll = sum(gCount);
nRecords = sum(gCount(1:nGenes));

meta = struct('root', root, 'exprDataset', exprDs, ...
    'fields', struct('x', exF, 'y', eyF, 'count', ecF, ...
                     'geneID', idField, 'geneName', nameField), ...
    'nGenesInFile', nGenesAll, 'nGenes', nGenes, ...
    'nRecords', nRecords, 'box', [], 'boxSource', '', ...
    'resolutionNm', localAttr(gefPath, '/', 'resolution', 500), ...
    'chipSerial', localAttrChar(gefPath, '/', 'sn'), ...
    'nCountsClamped', 0, 'readSeconds', 0);

if options.probeOnly
    x = int32([]); y = int32([]); geneIndex = int32([]); count = uint16([]);
    % No records to check an attribute box against, so report it as
    % unvalidated rather than implying the data agreed with it.
    [box, src] = localFindExtent(gefPath, root, [], [], options.verbose);
    meta.box = box; meta.boxSource = src;
    [meta.statTotals, meta.statTotalsNote] = ...
        localStatTotals(gefPath, geneID, options.verbose);
    meta.readSeconds = toc(t0);
    return;
end

% -- expression records ---------------------------------------------------
% Two strategies. GEF lays records out grouped by gene, so when the offsets
% are contiguous and ascending the gene of record r is implied by the counts
% alone and the whole dataset can be read in a few large blocks. That is
% worth checking rather than assuming: one h5read per gene is ~26,000 calls
% on a real file, and the per-call overhead dominates.
expected = [0; cumsum(gCount(1:end-1))];
contiguous = isequal(gOffset, expected);
if options.verbose
    if contiguous
        fprintf('[gef] gene offsets are contiguous and ascending; reading in blocks\n');
    else
        fprintf(['[gef] gene offsets are NOT contiguous; falling back to one ' ...
                 'read per gene (slower)\n']);
    end
    fprintf('[gef] %s records to read (%s in the file)\n', ...
        localComma(nRecords), localComma(nRecordsAll));
end

x = zeros(nRecords, 1, 'int32');
y = zeros(nRecords, 1, 'int32');
geneIndex = zeros(nRecords, 1, 'int32');
count = zeros(nRecords, 1, 'uint16');
nClamped = 0;
ceilingValue = double(options.countCeiling);

if contiguous
    BLOCK = 20e6;                       % records per read
    written = 0; gi = 1; inGene = 0;
    start = 1;
    while written < nRecords
        n = min(BLOCK, nRecords - written);
        E = h5read(gefPath, exprDs, start, n);
        idx = written + (1:n);
        x(idx) = int32(E.(exF));
        y(idx) = int32(E.(eyF));
        raw = double(E.(ecF));          % WIDE type before clipping
        nClamped = nClamped + sum(raw > ceilingValue);
        count(idx) = uint16(min(raw, ceilingValue));
        % gene of each record, from the counts alone
        gvec = zeros(n, 1, 'int32');
        filled = 0;
        while filled < n
            take = min(gCount(gi) - inGene, n - filled);
            gvec(filled + (1:take)) = int32(gi - 1);   % ZERO-BASED
            filled = filled + take; inGene = inGene + take;
            if inGene >= gCount(gi), gi = gi + 1; inGene = 0; end
        end
        geneIndex(idx) = gvec;
        written = written + n; start = start + n;
        if options.verbose
            fprintf('[gef]   %s/%s records  %.0fs\n', ...
                localComma(written), localComma(nRecords), toc(t0));
        end
    end
else
    written = 0;
    for i = 1:nGenes
        n = gCount(i);
        if n == 0, continue; end
        E = h5read(gefPath, exprDs, gOffset(i) + 1, n);   % h5read is 1-based
        idx = written + (1:n);
        x(idx) = int32(E.(exF));
        y(idx) = int32(E.(eyF));
        raw = double(E.(ecF));
        nClamped = nClamped + sum(raw > ceilingValue);
        count(idx) = uint16(min(raw, ceilingValue));
        geneIndex(idx) = int32(i - 1);
        written = written + n;
        if options.verbose && mod(i, 500) == 0
            fprintf('[gef]   gene %d/%d  %.0fs\n', i, nGenes, toc(t0));
        end
    end
end
meta.nCountsClamped = nClamped;

% -- bounding box ---------------------------------------------------------
[box, boxSource] = localFindExtent(gefPath, root, x, y, options.verbose);
meta.box = box; meta.boxSource = boxSource;

% -- SAW's own per-gene totals, if the file carries them ------------------
% /stat/gene holds a MIDcount per gene computed by SAW itself. That makes it
% a THIRD independent source for a number this project derives twice -- here
% and in the Python builder. Two implementations agreeing only shows they
% made the same choices; agreeing with the instrument vendor's own count
% shows the choices were right.
[meta.statTotals, meta.statTotalsNote] = ...
    localStatTotals(gefPath, geneID, options.verbose);

meta.readSeconds = toc(t0);

if options.verbose
    fprintf('[gef] extent %d x %d source units (origin %d,%d) from %s\n', ...
        box(3)-box(1)+1, box(4)-box(2)+1, box(1), box(2), boxSource);
    fprintf('[gef] max count = %d, %d clamped at %d\n', ...
        max(count), nClamped, ceilingValue);
    fprintf('[gef] read in %.0fs\n', toc(t0));
end

end % readGEF

% ------------------------------------------------------------------------

function tf = localHasDataset(f, name)
try
    h5info(f, name); tf = true;
catch
    tf = false;
end
end

function f = localPick(available, candidates)
for i = 1:numel(candidates)
    if any(strcmp(candidates{i}, available))
        f = candidates{i}; return;
    end
end
error('NDI:gene:readGEF:noSuchField', 'None of {%s} among {%s}.', ...
    strjoin(candidates, ', '), strjoin(available, ', '));
end

function c = localToCellstr(v)
if iscell(v)
    c = cellfun(@(s) strtrim(char(s(:)')), v, 'UniformOutput', false);
elseif ischar(v)
    c = cellstr(v');
else
    c = arrayfun(@(k) strtrim(char(v(:,k)')), 1:size(v,2), 'UniformOutput', false);
end
c = c(:);
c = strrep(c, char(0), '');
end

function v = localAttr(f, loc, name, dflt)
try
    v = double(h5readatt(f, loc, name));
catch
    v = dflt;
end
end

function s = localAttrChar(f, loc, name)
try
    a = h5readatt(f, loc, name);
    if iscell(a), a = a{1}; end
    s = strtrim(char(a(:)'));
catch
    s = '';
end
end

function [box, src] = localFindExtent(f, root, x, y, verbose)
need = {'minX','minY','maxX','maxY'};
parts = strsplit(regexprep(root, '^/+|/+$', ''), '/');
places = cell(1, numel(parts) + 1);
for i = numel(parts):-1:1
    places{numel(parts) - i + 1} = ['/' strjoin(parts(1:i), '/')];
end
places{end} = '/';

haveData = ~isempty(x);
if haveData
    dmin = [double(min(x)) double(min(y))];
    dmax = [double(max(x)) double(max(y))];
end

for p = places
    vals = nan(1,4); ok = true;
    for k = 1:4
        try
            vals(k) = double(h5readatt(f, p{1}, need{k}));
        catch
            ok = false; break;
        end
    end
    if ~ok, continue; end
    if vals(3) <= vals(1) || vals(4) <= vals(2), continue; end
    if ~haveData
        % probeOnly: nothing to validate against, so say so rather than
        % letting a caller read this as a box the data agreed with.
        box = vals; src = sprintf('attrs at %s (unvalidated: no records read)', p{1});
        return;
    end
    if vals(1) <= dmin(1) && vals(2) <= dmin(2) && ...
       vals(3) >= dmax(1) && vals(4) >= dmax(2)
        box = vals; src = sprintf('attrs at %s', p{1}); return;
    end
    if verbose
        fprintf(['[gef] WARNING attrs at %s = [%g %g %g %g] do not contain the ' ...
                 'data range [%g %g]..[%g %g]; using the data instead\n'], ...
            p{1}, vals, dmin, dmax);
    end
end
if haveData
    box = [dmin dmax];
    src = 'data';
else
    box = [];
    src = 'unknown (no attributes found and no records read)';
end
end

function [tot, note] = localStatTotals(f, geneID, verbose)
% SAW's per-gene MIDcount from /stat/gene, aligned to OUR gene rows.
tot = []; note = 'absent (/stat/gene not in this file)';
if ~localHasDataset(f, '/stat/gene')
    if verbose, fprintf('[gef] no /stat/gene; skipping the SAW total check\n'); end
    return;
end
St = h5read(f, '/stat/gene');
sf = fieldnames(St);
idF = localPick(sf, {'geneID','gene','geneName'});
cF  = localPick(sf, {'MIDcount','MIDCount','midcount','count'});
sIDs = localToCellstr(St.(idF));
sTot = double(St.(cF)(:));

n = numel(geneID);
if numel(sIDs) >= n && isequal(sIDs(1:n), geneID(:))
    tot = sTot(1:n);
    note = 'row order identical to geneExp';
else
    % Align by accession rather than by position. Assuming the orders match
    % would import our own ordering into the very check that is supposed to
    % be independent of it.
    m = containers.Map(sIDs, num2cell(sTot));
    tot = nan(n, 1); hit = 0;
    for i = 1:n
        if isKey(m, geneID{i}), tot(i) = m(geneID{i}); hit = hit + 1; end
    end
    note = sprintf('matched %d/%d rows by geneID', hit, n);
end
if verbose, fprintf('[gef] /stat/gene MIDcount read: %s\n', note); end
end

function s = localComma(n)
s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
end
