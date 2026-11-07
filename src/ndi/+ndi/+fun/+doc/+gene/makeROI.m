function doc = makeROI(session, pyrDoc, polygon, options)
% MAKEROI - record the polygon that carved a per-subject pyramid
%
%   DOC = ndi.fun.doc.gene.MAKEROI(SESSION, PYRDOC, POLYGON)
%   DOC = ndi.fun.doc.gene.MAKEROI(..., 'sourceFileID', ID, ...)
%
%   Creates a spatialGeneExpressionROI document: a provenance sidecar that
%   stores the drawn polygon alongside the pyramid built from the records
%   inside it. The pyramid remains a freestanding one-subject document;
%   this doc exists next to it.
%
%   Written by ndi.fun.doc.gene.fromGEFbyROI (and the interactive wrapper)
%   so a V2 importer can lift the geometry rather than ask the scientist
%   to redraw. No current tool reads it.
%
%   Inputs:
%   SESSION  - an ndi.session or ndi.dataset
%   PYRDOC   - the spatialGeneExpressionPyramid document this ROI
%              produced, or '' / [] to leave the dependency unset. An
%              empty value is accepted for the empty-polygon case: when
%              no records fell inside, there is no pyramid to depend on
%              but the geometry is still worth recording.
%   POLYGON  - Mx2 matrix of polygon vertices in GEF pixel coordinates
%              (col 1 is x, col 2 is y, M>=3)
%
%   Optional Name-Value Arguments:
%   sourceFileID ('')   - id of the shared source-file document (the .gef
%                         the pyramid was built from). Empty leaves the
%                         dependency unset.
%   label ('')          - a human-readable label
%   coordSpace ('gef_base_pixel')
%   coordUnits ('pixel')
%   nRecordsIn (0)      - number of records that landed inside the
%                         polygon. Reported for provenance; empty is
%                         allowed and simply reads as 0.
%
%   Outputs:
%   DOC - the spatialGeneExpressionROI document, already added to the
%         database
%
%   See also: ndi.fun.doc.gene.fromGEFbyROI,
%             ndi.fun.doc.gene.makePyramid

arguments
    session (1,1)
    pyrDoc
    polygon (:,2) double
    options.sourceFileID (1,:) char = ''
    options.label (1,:) char = ''
    options.coordSpace (1,:) char = 'gef_base_pixel'
    options.coordUnits (1,:) char = 'pixel'
    options.nRecordsIn (1,1) {mustBeInteger, mustBeNonnegative} = 0
end

if size(polygon, 1) < 3
    error('NDI:gene:makeROI:polygonShape', ...
        'POLYGON must have at least 3 vertices; got %d.', size(polygon,1));
end

s = struct('label', options.label, ...
    'n_vertices', size(polygon, 1), ...
    'vertices_x', polygon(:,1), ...
    'vertices_y', polygon(:,2), ...
    'coord_space', options.coordSpace, ...
    'coord_units', options.coordUnits, ...
    'n_records_in', options.nRecordsIn, ...
    'roi_format_version', 1);

doc = ndi.document('spatialGeneExpressionROI', ...
    'spatialGeneExpressionROI', s) + session.newdocument();

pyrID = localDocID(pyrDoc);
if ~isempty(pyrID)
    doc = doc.set_dependency_value( ...
        'spatialGeneExpressionPyramid_id', pyrID);
end
if ~isempty(options.sourceFileID)
    doc = doc.set_dependency_value( ...
        'source_file_id', options.sourceFileID);
end

session.database_add(doc);

end % makeROI

% ------------------------------------------------------------------------

function id = localDocID(doc)
if isempty(doc)
    id = '';
elseif ischar(doc) || isstring(doc)
    id = char(doc);
else
    id = doc.id();
end
end
