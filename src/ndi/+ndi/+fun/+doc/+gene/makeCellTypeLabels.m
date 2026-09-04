function [doc, tsvPath] = makeCellTypeLabels(session, labels, cellsDoc, options)
% MAKECELLTYPELABELS - create a cellTypeLabels document from per-cell labels
%
%   [DOC, TSVPATH] = ndi.fun.doc.gene.MAKECELLTYPELABELS(SESSION, LABELS, CELLSDOC)
%   [...] = ndi.fun.doc.gene.MAKECELLTYPELABELS(..., 'isUnsupervised', true, ...)
%
%   Writes labels.tsv and creates the cellTypeLabels document holding one
%   label per cell. Labels live in their own document rather than as a
%   column of cells.tsv because a single segmentation routinely carries
%   SEVERAL competing labelings -- a transferred atlas call, a clustering
%   at one resolution, the same clustering at another -- and they arrive
%   at different times from different sources. One document each lets them
%   coexist, be added later, and be deleted independently.
%
%   Inputs:
%   LABELS   - one label per cell, in cells.tsv row order. A string array
%              or cellstr; an empty string means UNLABELED, which is a
%              real state and not an error.
%   CELLSDOC - the spatialGeneExpressionCells document these label. The
%              row order must match its cells.tsv, which is why LABELS is
%              positional and why n_cells is checked against it.
%
%   Optional Name-Value Arguments:
%   isUnsupervised (false) - whether this labeling is an unsupervised
%                            clustering. SEE BELOW; it is the one argument
%                            here that is not cosmetic.
%   labelName ('')         - what the labeling is called in its source,
%                            e.g. 'subclass_nn_column' or 'leiden_res1.0'.
%                            Recorded so a labeling can be traced back to
%                            the column it came from.
%   taxonomyLevel ('')     - 'class', 'subclass', 'cluster', ... where the
%                            labeling sits in a cell type hierarchy.
%   assignmentMethod ('')  - how each cell got its label, e.g.
%                            'nearest neighbour from dissociated atlas' or
%                            'leiden, resolution 1.0'.
%   label ('')             - human-readable label for the document itself.
%   referenceDocID ('')    - the atlas or reference this was transferred
%                            from, when there is one in the database.
%
%   Outputs:
%   DOC     - the cellTypeLabels ndi.document, already added to the database
%   TSVPATH - where labels.tsv was written before ingestion
%
%   IS_UNSUPERVISED IS NOT A DETAIL. An unsupervised clustering carries no
%   biological identity: cluster 3 is not a cell type, it is an index, and
%   it means nothing outside the run that produced it. A transferred atlas
%   call is an inference ABOUT each cell that can be right or wrong. A
%   viewer that colours by a clustering and a viewer that colours by a
%   subclass call look identical, so the difference has to be carried in
%   the data or it is lost -- and reading a cluster index as a cell type is
%   a scientific error, not a display bug.
%
%   The source file does not record which kind it is. Callers that infer it
%   from a column name are guessing, and this project has already lost work
%   to that guess: sweeps once anchored silently to 'leiden' and had to be
%   re-run. So this argument is explicit, defaults to the SAFER assumption
%   -- unsupervised, meaning "do not read biology into it" -- and a caller
%   claiming a labeling is a real cell type call has to say so.
%
%   n_cells, n_categories and n_unlabeled are computed here rather than
%   supplied. n_unlabeled matters: a labeling covering a third of the cells
%   and one covering all of them look the same in a legend.
%
%   Example:
%       [d,~] = ndi.fun.doc.gene.makeCellTypeLabels(S, subclass, cellsDoc, ...
%           'labelName','subclass_nn_column', 'taxonomyLevel','subclass', ...
%           'assignmentMethod','nearest neighbour from dissociated atlas');
%
%   See also: ndi.fun.doc.gene.makeCells, ndr.format.stereoseq.readCellBin
%
arguments
    session (1,1)
    labels
    cellsDoc (1,1) ndi.document
    options.isUnsupervised (1,1) logical = true
    options.labelName (1,:) char = ''
    options.taxonomyLevel (1,:) char = ''
    options.assignmentMethod (1,:) char = ''
    options.label (1,:) char = ''
    options.referenceDocID (1,:) char = ''
end

labels = string(labels);
labels = labels(:);
labels(ismissing(labels)) = "";
n = numel(labels);

% The row order is the contract with cells.tsv, so a length mismatch is an
% error rather than something to pad or truncate: a shifted labeling
% assigns every cell its neighbour's type and nothing downstream notices.
% Empty is checked FIRST. Otherwise {} against a populated cells document
% is a length mismatch before it is an empty input, and the caller is told
% their labels are the wrong length rather than that they passed none --
% which is both less useful and, when the two ports order these
% differently, a divergence.
if n == 0
    error('NDI:gene:makeCellTypeLabels:empty', 'LABELS is empty.');
end
nCells = localCellCount(cellsDoc);
if ~isnan(nCells) && nCells ~= n
    error('NDI:gene:makeCellTypeLabels:length', ...
        ['LABELS has %d entries but the cells document has %d cells. ' ...
         'Labels are matched to cells by ROW ORDER, so a mismatch would ' ...
         'silently give cells the wrong type.'], n, nCells);
end

% ---- labels.tsv ---------------------------------------------------------
% cell_index is the 0-BASED row of cells.tsv, written explicitly for the
% same reason it is there: a reader should never infer it from row order.
tsvPath = [tempname '.tsv'];
fid = fopen(tsvPath, 'w');
if fid < 0
    error('NDI:gene:makeCellTypeLabels:write', 'Could not open %s.', tsvPath);
end
cleaner = onCleanup(@() fclose(fid));
fprintf(fid, 'cell_index\tlabel\n');
for i = 1:n
    fprintf(fid, '%d\t%s\n', i-1, labels(i));
end
clear cleaner;

% ---- counts -------------------------------------------------------------
isBlank = strlength(strtrim(labels)) == 0;
nUnlabeled = sum(isBlank);
nCategories = numel(unique(labels(~isBlank)));

c = struct();
c.label = options.label;
c.label_name = options.labelName;
c.taxonomy_level = options.taxonomyLevel;
c.n_cells = n;
c.n_categories = nCategories;
c.n_unlabeled = nUnlabeled;
c.assignment_method = options.assignmentMethod;
c.is_unsupervised = double(options.isUnsupervised);

doc = ndi.document('cellTypeLabels', ...
    'cellTypeLabels', c, ...
    'base.session_id', session.id());
doc = doc.set_dependency_value('cells_document_id', cellsDoc.id());
if ~isempty(options.referenceDocID)
    doc = doc.set_dependency_value('reference_document_id', options.referenceDocID);
end

doc = storeDoc(session, doc, {'labels.tsv'}, {tsvPath});

end % makeCellTypeLabels

% =======================================================================

function n = localCellCount(cellsDoc)
% The cells document's own n_cells, or NaN if it does not carry one.
n = NaN;
try
    p = cellsDoc.document_properties;
    if isfield(p, 'spatialGeneExpressionCells') && ...
            isfield(p.spatialGeneExpressionCells, 'n_cells')
        n = double(p.spatialGeneExpressionCells.n_cells);
    end
catch
    n = NaN;
end
end
