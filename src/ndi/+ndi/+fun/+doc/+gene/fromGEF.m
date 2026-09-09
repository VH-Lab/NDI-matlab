function [pyrDoc, tileDocs, geneListDoc, info] = fromGEF(session, gefPath, options)
% FROMGEF - build spatial gene expression documents from a Stereo-seq .gef
%
%   [PYRDOC, TILEDOCS, GENELISTDOC, INFO] = ...
%       ndi.fun.doc.gene.FROMGEF(SESSION, GEFPATH, 'subjectID', ID)
%
%   Reads a BGI/MGI Stereo-seq .gef with ndr.format.stereoseq.readGEF and
%   turns it into the documents that describe it: a geneList, a
%   spatialGeneExpressionPyramid, and one spatialGeneExpressionTiles per
%   level. This is the whole .gef-to-database path in one call.
%
%   THE DIVISION IT OBSERVES: NDR reads the vendor's file and returns
%   arrays; NDI turns arrays into documents. Nothing here parses HDF5, and
%   nothing in NDR knows what a document is. This function is the seam,
%   and it exists because the seam was previously only crossed inside
%   ndi.gui.app.GEFManager -- so a script, a batch import, or the Python
%   port had to either drive a GUI class or write the sequence again.
%
%   IT READS THE FILE ONCE. A real section is ~10^8 records and minutes;
%   the gene list and the pyramid both need those records, so they are
%   read once here rather than once per maker.
%
%   Inputs:
%   SESSION - an ndi.session or ndi.dataset
%   GEFPATH - path to the .gef
%
%   Optional Name-Value Arguments:
%   subjectID ('')       - REQUIRED in practice: the pyramid document
%       declares subject_id mustbenotempty, because a section is measured
%       from an animal and a .gef records a chip rather than a subject.
%       Left with a default so the error comes from makePyramid, which
%       explains it, rather than from an arguments block that cannot.
%   maxGenes (0)         - read only the first N genes; 0 is every gene.
%       A trimmed pyramid is missing genes and nothing in it records
%       that, so INFO.notes says so.
%   binSizes / grid / tileBudgetBytes / gridRange / basePixelSize /
%   pixelSizeUnits / label / assay / chipSerial / pipelineVersion / origin
%       - passed through to ndi.fun.doc.gene.makePyramid. NOTE that grid
%         now defaults to [], which sizes the tile grid from the data
%         rather than fixing it at 9x9 for a mouse section and a ferret
%         hemisphere alike.
%   genomeAssembly / annotationSource / geneIdNamespace /
%   geneSymbolNamespace
%       - passed through to ndi.fun.doc.gene.makeGeneList. Counts are not
%         reproducible without the annotation they were made against and
%         it cannot be recovered from the .gef, so it is worth passing.
%   recordSource (true)  - create a fileReference document describing the
%       .gef and point every tiles document at it through source_file_id.
%       See ndi.fun.doc.gene.makeSourceFile: it DESCRIBES the file rather
%       than ingesting a 9.4 GB copy of it.
%   checksum (true)      - compute the source file's MD5. Costs one full
%       read of the .gef on top of the ingest's own.
%   verbose (false)      - progress from the reader
%   progressFcn ([])     - a handle called as PROGRESSFCN(FRACTION, TEXT)
%       before each phase, with FRACTION in [0 1] across THIS call. A
%       plain handle rather than a dialog object so it works with no
%       display; ndi.gui.app.GEFManager passes one that drives its
%       progress bar. The read dominates the time, so the fractions are
%       weighted towards it rather than spread evenly over the phases.
%       makePyramid gets a handle onto the last 30%, so the pyramid
%       reports per level and per tile instead of going quiet for the
%       minutes it takes.
%
%   Outputs:
%   PYRDOC      - the spatialGeneExpressionPyramid, added to the database
%   TILEDOCS    - cell array of spatialGeneExpressionTiles, one per level
%   GENELISTDOC - the geneList the pyramid indexes against
%   INFO        - struct with the reader's meta, the source document (or
%                 [] when recordSource is false), and NOTES: what the full
%                 read found that a probe could not. Clamped counts, where
%                 the extent came from, SAW's own per-gene totals. None of
%                 it makes the pyramid wrong and all of it changes what it
%                 means, so it is reported rather than raised.
%
%   Example:
%       [pyr, tiles, gl, info] = ndi.fun.doc.gene.fromGEF(S, ...
%           '/data/section1.gef', 'subjectID', sub.id(), ...
%           'genomeAssembly', 'monDom5');
%       disp(info.notes);
%
%   See also: ndr.format.stereoseq.readGEF, ndi.fun.doc.gene.fromCellBin,
%             ndi.fun.doc.gene.makePyramid, ndi.fun.doc.gene.makeGeneList,
%             ndi.fun.doc.gene.makeSourceFile

arguments
    session (1,1)
    gefPath (1,:) char {mustBeFile}
    options.subjectID (1,:) char = ''
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

% -- what the file said about itself -------------------------------------
% The chip serial and the pixel size are IN the .gef, so a caller should
% not have to repeat them. An explicit value still wins: a caller who
% knows the file's own attribute is wrong needs a way to say so.
chipSerial = options.chipSerial;
if isempty(chipSerial)
    chipSerial = meta.chipSerial;
end
basePixelSize = options.basePixelSize;
if any(isnan(basePixelSize))
    % resolutionNm is NANOMETRES and basePixelSize is micrometres. SAW's
    % usual 500 nm becomes 0.5, which is also makePyramid's own default --
    % so getting this conversion wrong looks exactly like the default.
    basePixelSize = [meta.resolutionNm meta.resolutionNm] / 1000;
end

% -- documents, in dependency order --------------------------------------
localTick(options.progressFcn, 0.60, 'Building the gene list...');
geneListDoc = ndi.fun.doc.gene.makeGeneList(session, geneID, geneName, ...
    'genomeAssembly', options.genomeAssembly, ...
    'annotationSource', options.annotationSource, ...
    'geneIdNamespace', options.geneIdNamespace, ...
    'geneSymbolNamespace', options.geneSymbolNamespace, ...
    'label', options.label);

sourceDoc = [];
if options.recordSource
    localTick(options.progressFcn, 0.65, 'Describing the source file...');
    sourceDoc = ndi.fun.doc.gene.makeSourceFile(session, gefPath, ...
        'checksum', options.checksum);
    session.database_add(sourceDoc);
end

localTick(options.progressFcn, 0.70, 'Building the pyramid...');
% The records go in AS READ. Promoting them to double here would cost 32
% bytes a record where 14 does, held for the whole build -- 14 GB on a
% 7.7e8-record section -- and makePyramid converts per level anyway, into
% temporaries it can release.
[pyrDoc, tileDocs] = ndi.fun.doc.gene.makePyramid(session, ...
    x(:), y(:), geneIndex(:), count(:), geneListDoc, ...
    'progressFcn', localSubProgress(options.progressFcn, 0.70, 1.00), ...
    'binSizes', options.binSizes, 'grid', options.grid, ...
    'tileBudgetBytes', options.tileBudgetBytes, ...
    'gridRange', options.gridRange, ...
    'subjectID', options.subjectID, 'basePixelSize', basePixelSize, ...
    'pixelSizeUnits', options.pixelSizeUnits, 'label', options.label, ...
    'assay', options.assay, 'chipSerial', chipSerial, ...
    'pipelineVersion', options.pipelineVersion, 'origin', options.origin, ...
    'sourceFileID', localDocID(sourceDoc));

localTick(options.progressFcn, 1, 'Pyramid complete.');

info = struct();
info.meta = meta;
info.sourceDoc = sourceDoc;
info.notes = ndi.fun.doc.gene.readNotes(meta, geneID);

end % fromGEF

% ------------------------------------------------------------------------

function sub = localSubProgress(fcn, lo, hi)
% Re-scale a caller's [0 1] progress handle onto the [LO HI] slice of it,
% so a phase can report its own progress in its own terms without knowing
% where in the whole call it sits. Empty stays empty: makePyramid then
% skips the reporting rather than calling a handle that does nothing.
if isempty(fcn)
    sub = [];
else
    sub = @(f, t) fcn(lo + (hi - lo) * f, t);
end
end

% ------------------------------------------------------------------------

function localTick(fcn, frac, txt)
% Silent when no handle was given, so every phase can report progress
% without each call site testing for a display first.
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
