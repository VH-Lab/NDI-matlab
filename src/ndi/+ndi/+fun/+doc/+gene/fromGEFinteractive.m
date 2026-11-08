function [pyrDocs, tileDocsCell, geneListDoc, sourceDoc, info] = ...
    fromGEFinteractive(session, gefPath, options)
% FROMGEFINTERACTIVE - draw ROIs on a GEF preview and import N pyramids
%
%   [PYRDOCS, TILEDOCSCELL, GENELISTDOC, SOURCEDOC, INFO] = ...
%       ndi.fun.doc.gene.FROMGEFINTERACTIVE(SESSION, GEFPATH)
%   [...] = ndi.fun.doc.gene.FROMGEFINTERACTIVE(..., 'nSubjects', 3, ...)
%
%   Imports a Stereo-seq .gef as a set of per-subject pyramids with the
%   polygons picked on a quick preview rendered from the file's own
%   records. One readGEF covers both the preview and the subsequent
%   pyramids: the records loaded for drawing on are the records sliced by
%   each polygon.
%
%   WORKFLOW. The function reads the .gef, bins the records to a low-res
%   density image (summed counts across all genes), opens a figure, and
%   asks for one polygon per animal with drawpolygon. After the last
%   polygon the user picks a subject for each polygon: an existing one
%   from the session's subject list, or a new one typed into an inputdlg
%   -- the new subject is created in the session on the fly, so a
%   session that starts empty does not have to be set up ahead of time.
%   The N pyramids are then built in one pass sharing a geneList and a
%   sourceFile.
%
%   HOW LONG THE PICKING SITS. The read is the slow phase (minutes on a
%   ferret hemisphere) and happens BEFORE any UI appears, so a scientist
%   who clicks Import and leaves the room returns to a figure already
%   waiting for the first polygon. For a scripted run with polygons known
%   ahead of time, use ndi.fun.doc.gene.fromGEFbyROI; both call the same
%   internal path.
%
%   Inputs:
%   SESSION - an ndi.session or ndi.dataset
%   GEFPATH - path to the .gef
%
%   Optional Name-Value Arguments:
%   nSubjects (0)         - number of polygons expected. 0 asks the user
%                           via an inputdlg at the top of the picking
%                           step. Ignored when 'subjects' is supplied.
%   subjects  ({})        - subject ids assigned ahead of time, one per
%                           polygon. When supplied, N is numel(subjects)
%                           and the per-polygon subject prompt is
%                           skipped; useful when the caller knows the
%                           subjects and only needs the user to draw.
%   previewBin (50)       - bin size in GEF base pixels for the preview
%                           density image. 50 keeps a hemisphere preview
%                           under a few megapixels and is coarse enough
%                           to render instantly while still showing where
%                           tissue is.
%   logStretch (true)     - log-stretch the preview for visibility. Spot
%                           counts span several decades; a linear stretch
%                           hides small sections next to a dense one.
%       (plus every option fromGEFbyROI accepts, passed through to
%        makePyramid for each ROI)
%
%   Outputs: same as fromGEFbyROI. INFO.roiDocs holds one
%   spatialGeneExpressionROI provenance document per drawn polygon.
%
%   See also: ndi.fun.doc.gene.fromGEF,
%             ndi.fun.doc.gene.fromGEFbyROI,
%             ndi.fun.doc.gene.makePyramid

arguments
    session (1,1)
    gefPath (1,:) char {mustBeFile}
    options.nSubjects (1,1) {mustBeInteger, mustBeNonnegative} = 0
    options.subjects (1,:) cell = {}
    options.previewBin (1,1) {mustBePositive, mustBeInteger} = 50
    options.logStretch (1,1) logical = true
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

% -- read, once -----------------------------------------------------------
localTick(options.progressFcn, 0, 'Reading the GEF...');
[x, y, geneIndex, count, geneID, geneName, meta] = ...
    ndr.format.stereoseq.readGEF(gefPath, 'maxGenes', options.maxGenes, ...
    'verbose', options.verbose);

% -- build a quick preview density image ---------------------------------
localTick(options.progressFcn, 0.50, 'Rendering preview...');
[img, xRange, yRange] = localBinDensity(x, y, count, options.previewBin);
imgDisp = img;
if options.logStretch
    imgDisp = log1p(double(imgDisp));
end

% -- determine N and (optionally) pre-assign subjects --------------------
subjectsGiven = ~isempty(options.subjects);
if subjectsGiven
    n = numel(options.subjects);
    subjects = options.subjects;
else
    n = options.nSubjects;
    if n == 0
        answer = inputdlg('Number of subjects (one polygon each):', ...
            'Split GEF by ROI', 1, {'3'});
        if isempty(answer)
            error('NDI:gene:fromGEFinteractive:cancelled', ...
                'User cancelled at the subject-count prompt.');
        end
        n = str2double(answer{1});
        if ~isfinite(n) || n < 1 || n ~= floor(n)
            error('NDI:gene:fromGEFinteractive:badCount', ...
                'Need a positive integer subject count; got "%s".', ...
                answer{1});
        end
    end
    subjects = cell(1, n);
end

% -- draw N polygons -----------------------------------------------------
f = figure('Name', 'Split GEF by ROI', 'NumberTitle', 'off');
cleanup = onCleanup(@() localCloseIfOpen(f));
ax = axes(f);
imagesc(ax, xRange, yRange, imgDisp);
axis(ax, 'image');
colormap(ax, turbo);
colorbar(ax);
xlabel(ax, 'x (GEF pixels)');
ylabel(ax, 'y (GEF pixels)');

polygons = cell(1, n);
drawn = gobjects(1, n);
for k = 1:n
    title(ax, sprintf(['Polygon %d of %d: click vertices, double-click ' ...
        'to finish (Esc cancels)'], k, n));
    h = drawpolygon(ax);
    if ~isvalid(h) || isempty(h.Position) || size(h.Position, 1) < 3
        error('NDI:gene:fromGEFinteractive:polygonAborted', ...
            'Polygon %d was not completed; aborting.', k);
    end
    polygons{k} = h.Position;
    % Lock the drawn ROI so a later polygon's click cannot drag its
    % vertices by accident, and label it on the image for clarity.
    h.InteractionsAllowed = 'none';
    h.Label = sprintf('%d', k);
    drawn(k) = h;
end
title(ax, sprintf('%d polygon(s) drawn; picking subjects...', n));
drawnow;

% -- pick subjects per polygon -------------------------------------------
if ~subjectsGiven
    subjects = localPickSubjects(session, n);
end
if any(cellfun(@isempty, subjects))
    error('NDI:gene:fromGEFinteractive:subjectMissing', ...
        'A subject was not picked for every polygon.');
end

close(f);

% -- compute: hand off to the shared core --------------------------------
[pyrDocs, tileDocsCell, geneListDoc, sourceDoc, info] = buildROIpyramids( ...
    session, x, y, geneIndex, count, geneID, geneName, meta, gefPath, ...
    subjects, polygons, options);

end % fromGEFinteractive

% ------------------------------------------------------------------------

function [img, xRange, yRange] = localBinDensity(x, y, count, binPx)
% LOCALBINDENSITY - sum counts into a (nyBin x nxBin) grid for preview
%
%   The preview exists to show where tissue is, not to show gene
%   expression; summing counts across all genes puts every record in and
%   avoids a per-gene decision at a step the user does not need to see
%   per-gene.
xMin = double(min(x)); xMax = double(max(x));
yMin = double(min(y)); yMax = double(max(y));
xBin = floor((double(x) - xMin) / binPx) + 1;
yBin = floor((double(y) - yMin) / binPx) + 1;
nxBin = max(xBin);
nyBin = max(yBin);
% Rows are y, columns are x. imagesc paints row 1 at the top, so y=yMin
% is at the top of the figure, matching how an image is normally shown.
img = accumarray([yBin xBin], double(count), [nyBin nxBin], @sum, 0);
xRange = [xMin xMax];
yRange = [yMin yMax];
end

% ------------------------------------------------------------------------

function subjects = localPickSubjects(session, n)
% LOCALPICKSUBJECTS - prompt once per polygon, letting the user pick an
% existing subject or create a new one on the fly
%
%   Each polygon gets its own picker. The list shows every subject already
%   in the session plus a "+ Create new subject..." entry at the top; that
%   entry opens an inputdlg for a local_identifier and creates the subject
%   in the session before using its id. A session with no subjects is not
%   an error -- creation is the first option in the list.
subjectDocs = session.database_search(ndi.query('', 'isa', 'subject'));
labels = cell(size(subjectDocs));
for i = 1:numel(subjectDocs)
    labels{i} = subjectDocs{i}.document_properties.subject.local_identifier;
end
createOption = '+ Create new subject...';
subjects = cell(1, n);
k = 1;
while k <= n
    listItems = [{createOption}; labels(:)];
    [idx, ok] = listdlg('ListString', listItems, ...
        'SelectionMode', 'single', ...
        'Name', 'Pick subject', ...
        'PromptString', sprintf('Subject for polygon %d of %d:', k, n), ...
        'OKString', 'Pick', 'CancelString', 'Cancel');
    if ~ok
        error('NDI:gene:fromGEFinteractive:cancelled', ...
            'User cancelled at the subject picker for polygon %d.', k);
    end
    if idx == 1
        % Create-new path. Cancelling the inputdlg sends the user back
        % to the picker for this polygon (same k), so a wrong click on
        % the first entry does not abandon the whole ingest.
        nameAnswer = inputdlg( ...
            {'Local identifier for the new subject:'}, ...
            sprintf('New subject (polygon %d of %d)', k, n), ...
            1, {''});
        if isempty(nameAnswer) || isempty(strtrim(nameAnswer{1}))
            continue;
        end
        localID = strtrim(nameAnswer{1});
        % A typo of an existing identifier reuses it rather than
        % duplicating the subject.
        existingIdx = find(strcmp(labels, localID), 1);
        if ~isempty(existingIdx)
            subjects{k} = subjectDocs{existingIdx}.id();
        else
            newSub = ndi.document('subject', ...
                'subject.local_identifier', localID, ...
                'base.session_id', session.id());
            session.database_add(newSub);
            subjectDocs{end+1} = newSub; %#ok<AGROW>
            labels{end+1} = localID; %#ok<AGROW>
            subjects{k} = newSub.id();
        end
    else
        % Offset by one because index 1 is the create-new entry.
        subjects{k} = subjectDocs{idx - 1}.id();
    end
    k = k + 1;
end
end

% ------------------------------------------------------------------------

function localCloseIfOpen(f)
if isvalid(f)
    close(f);
end
end

% ------------------------------------------------------------------------

function localTick(fcn, frac, txt)
if isempty(fcn), return; end
fcn(frac, txt);
end
