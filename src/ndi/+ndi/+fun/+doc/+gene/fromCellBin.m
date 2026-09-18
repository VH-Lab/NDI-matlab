function [cellsDoc, labelDocs, info] = fromCellBin(session, h5adPath, pyrDoc, options)
% FROMCELLBIN - build cell and label documents from a SAW cellbin .h5ad
%
%   [CELLSDOC, LABELDOCS, INFO] = ...
%       ndi.fun.doc.gene.FROMCELLBIN(SESSION, H5ADPATH, PYRDOC)
%   [...] = ndi.fun.doc.gene.FROMCELLBIN(..., 'labelings', SEL)
%
%   Reads a SAW cell segmentation .h5ad with ndr.format.stereoseq.readCellBin
%   and turns it into a spatialGeneExpressionCells document positioned
%   against PYRDOC, plus one cellTypeLabels document per labeling the
%   caller asked for.
%
%   IT READS THE FILE ONCE, AND THAT IS THE POINT. readCellBin returns
%   cells in file order and labels in file order, and the ONLY thing tying
%   a label array to a cell table is that they came from the same pass.
%   Two passes that disagreed about row order -- a column added, a filter
%   applied, a different obsColumns request -- would produce a label array
%   that is still entirely valid and entirely wrong, on cells that are all
%   real. So the cells and every labeling come out of one call here.
%
%   LABELINGS ARE ASKED FOR, NEVER ASSUMED. A cellbin routinely carries a
%   transferred atlas call and one or more unsupervised clusterings side
%   by side; the file does not say which is which, and reading a cluster
%   index as a cell type is a scientific error rather than a display bug.
%   Pass nothing and you get cells with no labels. INFO.labelColumns lists
%   what was available, with readCellBin's name-based guess at each, so a
%   caller can offer the choice rather than make it.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset
%   H5ADPATH - path to the cellbin .h5ad
%   PYRDOC   - the spatialGeneExpressionPyramid these cells are positioned
%              against. Required: a cell table is meaningless without the
%              frame it is in.
%
%   Optional Name-Value Arguments:
%   labelings ([])       - which labelings to ingest, as a struct array
%       with fields 'name' and 'isUnsupervised'. isUnsupervised is the
%       caller's call, not the file's: cellTypeLabels carries the field
%       precisely so a human settles it. Pass [] for none.
%   obsColumns ({})      - numeric /obs columns to carry into cells.tsv as
%       extra measurements, e.g. {'area','total_counts'}
%   contourReference ('auto') - 'auto', 'centroid' or 'absolute'. The file
%       does not record which its vertices are; 'auto' infers it and
%       INFO.meta carries the evidence. Getting it wrong puts every
%       outline a chip-width from its cell WITHOUT raising anything.
%   segmentationMethod ('SAW CellBin') - recorded on the document. Worth
%       stating plainly: CellBin segments NUCLEI and dilates outward, so a
%       "cell" is a nucleus plus a margin.
%   segmentationDilation (0) - the dilation applied, in bins
%   subjectID ('')       - subject these cells were measured from
%   label ('')           - human-readable label
%   recordSource (true)  - create a fileReference document describing the
%       .h5ad and point the cells document at it through source_file_id
%   checksum (true)      - compute that file's MD5
%
%   Outputs:
%   CELLSDOC  - the spatialGeneExpressionCells document
%   LABELDOCS - cell array of cellTypeLabels, one per requested labeling
%   INFO      - struct with the reader's meta, labelColumns (what was
%               available), sourceDoc, and notes: cells a labeling left
%               unassigned, and what the contour reference was inferred
%               to be and from what evidence.
%
%   Example:
%       [~, ~, info] = ndi.fun.doc.gene.fromCellBin(S, f, pyr);  % look
%       sel = struct('name','subclass_nn_column','isUnsupervised',false);
%       [cells, labels] = ndi.fun.doc.gene.fromCellBin(S, f, pyr, ...
%           'labelings', sel, 'obsColumns', {'area'});
%
%   See also: ndr.format.stereoseq.readCellBin, ndi.fun.doc.gene.fromGEF,
%             ndi.fun.doc.gene.makeCells, ndi.fun.doc.gene.makeCellTypeLabels

arguments
    session (1,1)
    h5adPath (1,:) char {mustBeFile}
    pyrDoc (1,1) ndi.document
    options.labelings = []
    options.obsColumns cell = {}
    options.contourReference (1,:) char = 'auto'
    options.segmentationMethod (1,:) char = 'SAW CellBin'
    options.segmentationDilation (1,1) double = 0
    options.subjectID (1,:) char = ''
    options.label (1,:) char = ''
    options.recordSource (1,1) logical = true
    options.checksum (1,1) logical = true
end

sel = options.labelings;
if isempty(sel)
    sel = struct('name', {}, 'isUnsupervised', {});
end

% Everything the one read must produce: the numeric columns the caller
% wants on cells.tsv, plus every labeling's own column.
wanted = options.obsColumns;
for i = 1:numel(sel)
    if ~ismember(sel(i).name, wanted)
        wanted{end+1} = sel(i).name; %#ok<AGROW>
    end
end

% -- the one read --------------------------------------------------------
[cellID, cx, cy, contours, obs, meta] = ndr.format.stereoseq.readCellBin( ...
    h5adPath, 'contourReference', options.contourReference, ...
    'obsColumns', wanted);

% The numeric columns become extra columns of cells.tsv; the label columns
% do not, because a labeling gets its own document.
labelNames = {};
if ~isempty(sel), labelNames = {sel.name}; end
numericWanted = setdiff(options.obsColumns, labelNames, 'stable');
extra = table();
for i = 1:numel(numericWanted)
    fn = matlab.lang.makeValidName(numericWanted{i});
    extra.(fn) = obs.(fn)(:);
end

sourceDoc = [];
if options.recordSource
    sourceDoc = ndi.fun.doc.gene.makeSourceFile(session, h5adPath, ...
        'checksum', options.checksum);
    session.database_add(sourceDoc);
end

% contourReference on the DOCUMENT must be what the reader CONCLUDED, not
% what the caller asked for: 'auto' is a request, meta.contourReference is
% the answer.
cellsDoc = ndi.fun.doc.gene.makeCells(session, cellID, cx, cy, pyrDoc, ...
    'contours', contours, 'extra', extra, ...
    'contourReference', meta.contourReference, ...
    'segmentationMethod', options.segmentationMethod, ...
    'segmentationDilation', options.segmentationDilation, ...
    'subjectID', options.subjectID, 'label', options.label, ...
    'sourceFileID', localDocID(sourceDoc));

% -- labelings, from the SAME pass ---------------------------------------
labelDocs = {};
notes = {};
if meta.contoursPresent
    notes{end+1} = sprintf('Contours read as %s (%s).', ...
        meta.contourReference, meta.contourReferenceSource);
else
    notes{end+1} = 'No obsm/cell_border: cells have centroids and no outlines.';
end

for i = 1:numel(sel)
    fn = matlab.lang.makeValidName(sel(i).name);
    labels = obs.(fn);
    labelDocs{end+1} = ndi.fun.doc.gene.makeCellTypeLabels(session, ...
        labels, cellsDoc, 'isUnsupervised', sel(i).isUnsupervised, ...
        'labelName', sel(i).name); %#ok<AGROW>
    nUnlabeled = sum(strcmp(labels, ''));
    if nUnlabeled > 0
        notes{end+1} = sprintf('%s leaves %d cell(s) unlabeled.', ...
            sel(i).name, nUnlabeled); %#ok<AGROW>
    end
end

labelColumns = struct('name', {}, 'nCategories', {}, 'isUnsupervisedGuess', {});
if isfield(meta, 'labelColumns')
    labelColumns = meta.labelColumns;
end

% Built field by field rather than with struct(): struct() distributes
% over cell values and labelColumns is a struct array, so the one-call
% form is ambiguous for exactly the two fields that matter here.
info = struct();
info.meta = meta;
info.labelColumns = labelColumns;
info.sourceDoc = sourceDoc;
info.notes = notes(:);

end % fromCellBin

% ------------------------------------------------------------------------

function id = localDocID(doc)
if isempty(doc)
    id = '';
else
    id = doc.id();
end
end
