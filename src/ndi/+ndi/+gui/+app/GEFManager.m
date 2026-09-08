classdef GEFManager < ndi.gui.app.sessionApp
% NDI.GUI.APP.GEFMANAGER - list, add, view and delete spatial transcriptomics datasets
%
%   ndi.gui.app.GEFManager(SESSION)
%
%   Lists the spatial gene expression pyramids in a session, and adds,
%   opens or removes one. Reached from the navigator's per-session Apps
%   menu.
%
%   WHAT IS LISTED IS PYRAMIDS, NOT FILES. A .gef is an input; what lands
%   in the database is a spatialGeneExpressionPyramid plus one
%   spatialGeneExpressionTiles per level, optionally a
%   spatialGeneExpressionCells, and optionally several cellTypeLabels. The
%   list shows what the session HAS, and the "cells" and "labels" columns
%   say what is still missing -- which is the question a user actually
%   arrives with.
%
%   ADDING IS THREE STEPS, and the middle one is the point:
%
%     1. choose the .gef, and optionally a SAW cellbin .h5ad
%     2. CONFIRM WHAT WAS INFERRED FROM THOSE FILES
%     3. run
%
%   Step 2 is a confirmation screen rather than a picker because the
%   things at stake are not preferences. A cellbin file does not record
%   whether its boundary vertices are relative to each cell's centroid or
%   absolute, nor what value pads the unused vertex slots;
%   ndr.format.stereoseq.readCellBin infers both and reports the evidence,
%   and getting the first wrong puts every outline a chip-width from its
%   cell WITHOUT RAISING ANYTHING. Nor does the file record whether a
%   labeling is a transferred cell type call or an unsupervised
%   clustering, and reading a cluster index as a cell type is a scientific
%   error rather than a display bug. So the user is shown the inference
%   and its numbers, and can override it, rather than having a heuristic
%   decide silently on their behalf.
%
%   INGESTION IS A PLAN AND THEN A RUN, and they are separate on purpose.
%   ingestPlan takes the two probes and the user's answers and returns the
%   ordered steps, or the reasons it cannot. It touches no file and no
%   database, so every refusal -- no subject, a labeling selected with no
%   cells to attach it to, a gene list that would be empty -- is reached in
%   milliseconds instead of after the multi-minute read that produced
%   nothing. runIngest then executes that plan and does the reading.
%   Deciding and doing were worth prising apart here because the doing is
%   slow and the deciding is where the mistakes are.
%
%   READING IS CHEAP HERE BY CONSTRUCTION. A real section is ~10^8 records
%   and takes minutes; both readers take 'probeOnly', which returns the
%   gene table, extent, chip serial and available columns without touching
%   the bulk data. Everything shown before the user commits is a probe.
%
%   VIEWING IS SOMEONE ELSE'S JOB. The viewer is napari, which is Python,
%   so View does not draw anything here: it builds a command line and
%   hands it to a launcher, by default /usr/local/bin/napariViewGEF. That
%   launcher is a shell wrapper rather than the console script itself
%   because MATLAB exports library paths of its own, and a Python process
%   started from MATLAB picks up MATLAB's copies of libraries it must not
%   use; the wrapper scrubs the environment before exec'ing the real
%   entry point. viewCommand builds the command and is pure, so what will
%   run can be shown in the dialog before it runs -- and can be copied
%   into a terminal when it does not.
%
%   DELETING IS A CASCADE. Levels depend on the pyramid, cells depend on
%   the pyramid, and labels depend on cells, so removing a pyramid orphans
%   everything beneath it. deletionPlan enumerates that first and the
%   confirmation names the counts, because "delete 1 document" and "delete
%   493 documents" should not look the same.
%
%   Example:
%       S = ndi.session.dir('mysession','/path/to/session');
%       ndi.gui.app.GEFManager(S);
%
%   See also: ndi.fun.doc.gene.makePyramid, ndi.fun.doc.gene.makeCells,
%             ndi.fun.doc.gene.makeCellTypeLabels,
%             ndr.format.stereoseq.readGEF, ndr.format.stereoseq.readCellBin

    properties (Constant)
        Name = "GEF Manager"
        Category = "Spatial transcriptomics"

        % Where the napari launcher lives when nobody has said otherwise.
        % A wrapper in /usr/local/bin rather than the console script in a
        % virtual environment: MATLAB exports library paths of its own,
        % and a Python process started from MATLAB loads MATLAB's copies
        % of libraries it must not use. The wrapper scrubs those and then
        % execs the real entry point. Overridden by the preference
        % GUI.GEFManager.ViewerLauncher, which the View dialog writes.
        DefaultViewerLauncher = "/usr/local/bin/napariViewGEF"
    end

    properties (Access = private)
        session
        fig
        table
        statusLabel
        rows = struct([])
    end

    methods
        function obj = GEFManager(sessionObj, options)
            arguments
                sessionObj (1,1)
                % build=false constructs the model without a figure, so
                % every decision this app makes is checkable with no
                % display. Same arrangement spikeSorterImporter uses.
                options.build (1,1) logical = true
            end
            obj.session = sessionObj;
            if options.build
                obj.buildUI();
                obj.reload();
            end
        end

        function reload(obj)
            obj.rows = ndi.gui.app.GEFManager.pyramidRows(obj.session);
            if ~isempty(obj.fig) && isvalid(obj.fig)
                obj.table.Data = ndi.gui.app.GEFManager.rowsToCell(obj.rows);
                obj.setStatus(sprintf('%d pyramid(s).', numel(obj.rows)));
            end
        end
    end

    % =====================================================================
    % The model. Static and pure: no figure, no state, so it is testable
    % headlessly and a test failure names a decision rather than a widget.
    % =====================================================================
    methods (Static)

        function rows = pyramidRows(session)
        % PYRAMIDROWS - one row per pyramid, with what it does and does not have
        %
        %   The "cells" and "labels" columns exist because the common
        %   question is not "what is here" but "what still needs
        %   ingesting", and a pyramid with no cells looks identical to one
        %   with cells unless the list says so.
        %
        %   THREE OF THESE COLUMNS DO NOT LIVE ON THE PYRAMID, and reading
        %   them from it gave a blank or a NaN in a column that should have
        %   held a number -- which reads as "this pyramid has no genes"
        %   rather than as "this code looked in the wrong place":
        %
        %     assay    is on the geneExpression superclass, so it is under
        %              document_properties.geneExpression, not under the
        %              pyramid's own property list.
        %     n_genes  is on the geneList document the pyramid depends on.
        %              It belongs there: several pyramids of the same chip
        %              share one gene list, and copying the count onto each
        %              would be a second place for it to be wrong.
        %     subject  is a document id in the dependency. An id names the
        %              subject uniquely and tells the reader nothing, so
        %              what is shown is its local_identifier, with the id
        %              kept on the row for anything that needs to be exact.
        %
        %   The two lookups are done ONCE for the whole session rather than
        %   per row: a session with 40 pyramids would otherwise make 40
        %   subject queries to answer one question.
            docs = session.database_search( ...
                ndi.query('','isa','spatialGeneExpressionPyramid'));
            subjectNames = ndi.gui.app.GEFManager.subjectNameMap(session);
            geneCounts = ndi.gui.app.GEFManager.geneListCountMap(session);
            rows = struct('id',{},'label',{},'subject',{},'subjectID',{}, ...
                'assay',{},'chipSerial',{},'nGenes',{},'nLevels',{},'extent',{}, ...
                'nCells',{},'nLabelSets',{},'doc',{});
            for i = 1:numel(docs)
                d = docs{i};
                p = d.document_properties.spatialGeneExpressionPyramid;
                k = numel(rows) + 1;
                rows(k).id = d.id();
                rows(k).doc = d;
                rows(k).label = ndi.gui.app.GEFManager.field(p,'label','');
                ge = struct();
                if isfield(d.document_properties,'geneExpression')
                    ge = d.document_properties.geneExpression;
                end
                rows(k).assay = ndi.gui.app.GEFManager.field(ge,'assay','');
                rows(k).chipSerial = ndi.gui.app.GEFManager.field(p,'chip_serial','');
                rows(k).subjectID = ndi.gui.app.GEFManager.dependency(d,'subject_id');
                rows(k).subject = ndi.gui.app.GEFManager.lookup( ...
                    subjectNames, rows(k).subjectID, rows(k).subjectID);
                rows(k).nGenes = ndi.gui.app.GEFManager.lookup(geneCounts, ...
                    ndi.gui.app.GEFManager.dependency(d,'geneList_id'), NaN);
                rows(k).extent = [ndi.gui.app.GEFManager.field(p,'extent_x',NaN), ...
                                  ndi.gui.app.GEFManager.field(p,'extent_y',NaN)];
                rows(k).nLevels = numel(session.database_search( ...
                    ndi.query('','depends_on','spatialGeneExpressionPyramid_id',d.id()) & ...
                    ndi.query('','isa','spatialGeneExpressionTiles')));
                cellsDocs = session.database_search( ...
                    ndi.query('','depends_on','spatialGeneExpressionPyramid_id',d.id()) & ...
                    ndi.query('','isa','spatialGeneExpressionCells'));
                rows(k).nCells = numel(cellsDocs);
                nLab = 0;
                for j = 1:numel(cellsDocs)
                    nLab = nLab + numel(session.database_search( ...
                        ndi.query('','depends_on','cells_document_id',cellsDocs{j}.id()) & ...
                        ndi.query('','isa','cellTypeLabels')));
                end
                rows(k).nLabelSets = nLab;
            end
        end

        function plan = deletionPlan(session, pyrDoc)
        % DELETIONPLAN - every document that goes with a pyramid
        %
        %   Levels depend on the pyramid, cells depend on the pyramid, and
        %   labels depend on cells. Deleting the pyramid alone would leave
        %   all of them referencing something that is gone, so they are
        %   enumerated and deleted together -- and counted first, so the
        %   confirmation can say how much.
            plan = struct('pyramid',{{pyrDoc}},'tiles',{{}},'cells',{{}}, ...
                'labels',{{}},'total',0);
            plan.tiles = session.database_search( ...
                ndi.query('','depends_on','spatialGeneExpressionPyramid_id',pyrDoc.id()) & ...
                ndi.query('','isa','spatialGeneExpressionTiles'));
            plan.cells = session.database_search( ...
                ndi.query('','depends_on','spatialGeneExpressionPyramid_id',pyrDoc.id()) & ...
                ndi.query('','isa','spatialGeneExpressionCells'));
            labels = {};
            for j = 1:numel(plan.cells)
                more = session.database_search( ...
                    ndi.query('','depends_on','cells_document_id',plan.cells{j}.id()) & ...
                    ndi.query('','isa','cellTypeLabels'));
                labels = [labels(:); more(:)]; %#ok<AGROW>
            end
            plan.labels = labels;
            plan.total = 1 + numel(plan.tiles) + numel(plan.cells) + numel(plan.labels);
        end

        function msg = deletionMessage(plan)
        % DELETIONMESSAGE - what the confirmation says
        %
        %   Names every kind and count. "Delete 1 document" and "delete
        %   493 documents" must not read the same.
            msg = sprintf(['This removes %d document(s):\n\n' ...
                '  1 pyramid\n  %d level(s)\n  %d cell set(s)\n  %d label set(s)\n\n' ...
                'The label sets go because their cells go, and the cells go ' ...
                'because the pyramid they are positioned against goes. ' ...
                'This cannot be undone.'], ...
                plan.total, numel(plan.tiles), numel(plan.cells), numel(plan.labels));
        end

        function items = contourFindings(meta)
        % CONTOURFINDINGS - the inferences a cellbin file forced, for review
        %
        %   Returns one row per thing readCellBin had to INFER rather than
        %   read, with the evidence behind it, so the confirmation screen
        %   shows a decision and its basis instead of a checkbox.
            items = struct('name',{},'value',{},'evidence',{},'overridable',{});
            if ~isfield(meta,'contoursPresent') || ~meta.contoursPresent
                items(1).name = 'Contours';
                items(1).value = 'absent';
                items(1).evidence = 'obsm/cell_border is not in this file';
                items(1).overridable = false;
                return;
            end
            e = meta.relativeEvidence;
            items(1).name = 'Contour reference';
            items(1).value = meta.contourReference;
            items(1).evidence = sprintf( ...
                ['real-vertex |median| %.3g vs centroid scale %.0f = %.5f, ' ...
                 'threshold %.2f (%s)'], ...
                e.realVertexAbsMedian, e.centroidScale, e.ratio, e.threshold, ...
                meta.contourReferenceSource);
            items(1).overridable = true;

            items(2).name = 'Padding sentinel';
            items(2).value = sprintf('%g', meta.padValue);
            items(2).evidence = sprintf('fills %.0f%% of the vertex slots', ...
                100*meta.padFraction);
            items(2).overridable = true;

            items(3).name = 'Vertices per cell';
            v = meta.verticesPerCell;
            items(3).value = sprintf('min %d, median %g, max %d', v(1), v(2), v(3));
            if meta.raggedVertices
                items(3).evidence = 'ragged; empty contours keep their row';
            else
                items(3).evidence = 'fixed width';
            end
            items(3).overridable = false;
        end

        function items = labelFindings(meta)
        % LABELFINDINGS - the candidate labelings, and the one real choice
        %
        %   A cellbin routinely carries a transferred atlas call and one or
        %   more unsupervised clusterings side by side. They are not
        %   interchangeable and the file does not say which is which, so
        %   these are OFFERED rather than inferred, and each carries the
        %   guess readCellBin made from the column name -- marked as a
        %   guess, because that is all the file supports.
            items = struct('name',{},'nCategories',{},'isUnsupervisedGuess',{}, ...
                'warning',{});
            if ~isfield(meta,'labelColumns'), return; end
            for i = 1:numel(meta.labelColumns)
                L = meta.labelColumns(i);
                items(i).name = L.name;
                items(i).nCategories = L.nCategories;
                items(i).isUnsupervisedGuess = L.isUnsupervisedGuess;
                if L.isUnsupervisedGuess
                    items(i).warning = ['Looks like an unsupervised clustering. ' ...
                        'A cluster index is not a cell type and carries no ' ...
                        'biological identity outside the run that produced it.'];
                else
                    items(i).warning = ['Looks like a transferred cell type call. ' ...
                        'It is an inference about each cell, not a measurement.'];
                end
            end
        end

        function choices = ingestChoices(gefMeta, cellbinMeta)
        % INGESTCHOICES - the defaults the confirmation screen starts from
        %
        %   Everything a user can change, pre-filled from the two probes.
        %   Returned as a struct rather than read off widgets so the
        %   defaults themselves are testable, and so a caller with no
        %   display can ingest by adjusting these and calling ingestPlan.
        %
        %   subjectID has NO DEFAULT and never will. It is the one field
        %   the files cannot supply -- a .gef records a chip, not an animal
        %   -- and guessing it would attach a section to the wrong subject
        %   in a way nothing later could detect.
            arguments
                gefMeta (1,1) struct
                cellbinMeta = []
            end
            choices = struct();
            choices.subjectID = '';
            choices.label = '';
            choices.assay = 'Stereo-seq';
            choices.chipSerial = ndi.gui.app.GEFManager.field(gefMeta,'chipSerial','');
            choices.binSizes = [1 2 4 8 16 32];
            choices.grid = 9;
            % The GEF's resolution attribute is in NANOMETRES and
            % basePixelSize is in micrometres, so this is the one unit
            % conversion in the ingest path. SAW's usual 500 nm becomes
            % 0.5, which is also makePyramid's default -- so a mistake here
            % looks exactly like the default and would not stand out.
            res = ndi.gui.app.GEFManager.field(gefMeta,'resolutionNm',500);
            choices.basePixelSize = [res res] / 1000;
            choices.genomeAssembly = '';
            choices.annotationSource = '';
            choices.maxGenes = 0;            % 0 = every gene
            choices.importCells = false;
            choices.contourReference = 'auto';
            choices.segmentationMethod = '';
            choices.obsColumns = {};
            choices.labelSelections = struct('name',{},'isUnsupervised',{});

            if isempty(cellbinMeta), return; end
            choices.importCells = true;
            choices.segmentationMethod = 'SAW CellBin';
            % Nothing is preselected. A cellbin carries several labelings
            % side by side and the file does not say which is a cell type
            % call and which is a clustering; picking one here would be the
            % heuristic this app exists to avoid. The guess is offered --
            % see labelFindings -- and left unchecked.
        end

        function plan = ingestPlan(gefMeta, geneID, cellbinMeta, choices)
        % INGESTPLAN - the ordered steps, or the reasons there are none
        %
        %   PLAN = ndi.gui.app.GEFManager.INGESTPLAN(GEFMETA, GENEID, ...
        %       CELLBINMETA, CHOICES)
        %
        %   Pure: no session, no file, no database. Given what the probes
        %   found and what the user chose, it returns what would be created
        %   and what is wrong with the request. Nothing here reads a
        %   record, so a refusal costs nothing and a user learns their
        %   subject is missing before the wait rather than after it.
        %
        %   PLAN.errors is a cellstr and ALL of them are collected rather
        %   than the first thrown, because a dialog that reports one
        %   problem per attempt turns a two-field mistake into two rounds.
        %   PLAN.warnings is for what will happen anyway but should be seen.
            arguments
                gefMeta (1,1) struct
                geneID cell
                cellbinMeta
                choices (1,1) struct
            end
            plan = struct();
            plan.steps = struct('kind',{},'description',{},'args',{});
            plan.errors = {};
            plan.warnings = {};
            plan.choices = choices;

            E = {}; W = {};

            % -- what cannot proceed ------------------------------------
            if ~isfield(choices,'subjectID') || isempty(choices.subjectID)
                E{end+1} = ['A subject is required. The pyramid document ' ...
                    'declares subject_id mustbenotempty, because a section ' ...
                    'is measured from an animal; the .gef records a chip, ' ...
                    'not a subject, so it cannot be filled in for you.'];
            end
            if isempty(geneID)
                E{end+1} = ['The GEF probe found no genes, so there is no ' ...
                    'gene list to index counts against.'];
            end
            bs = ndi.gui.app.GEFManager.field(choices,'binSizes',[]);
            if isempty(bs) || any(bs < 1) || any(bs ~= round(bs))
                E{end+1} = 'Bin sizes must be positive whole numbers.';
            elseif numel(unique(bs)) ~= numel(bs)
                E{end+1} = 'Bin sizes must not repeat.';
            elseif min(bs) ~= 1
                % Legal, not fatal: basePixelSize describes bin 1 whether or
                % not bin 1 is stored, so the ladder stays interpretable.
                W{end+1} = sprintf(['The finest level is %d, so no ' ...
                    'full-resolution level is stored. Nothing later can ' ...
                    'recover it without re-reading the GEF.'], min(bs));
            end

            wantCells = ndi.gui.app.GEFManager.field(choices,'importCells',false);
            haveCellbin = ~isempty(cellbinMeta);
            sel = ndi.gui.app.GEFManager.field(choices,'labelSelections', ...
                struct('name',{},'isUnsupervised',{}));
            if wantCells && ~haveCellbin
                E{end+1} = 'Cells were selected but no cellbin file was given.';
            end
            if ~isempty(sel) && ~wantCells
                E{end+1} = ['Labelings were selected but cells were not. A ' ...
                    'cellTypeLabels document depends on the cells it labels ' ...
                    'and cannot be created without them.'];
            end
            if haveCellbin && wantCells
                names = {};
                if isfield(cellbinMeta,'labelColumns') && ~isempty(cellbinMeta.labelColumns)
                    names = {cellbinMeta.labelColumns.name};
                end
                for i = 1:numel(sel)
                    if ~ismember(sel(i).name, names)
                        E{end+1} = sprintf(['No labeling %s in that cellbin ' ...
                            'file.'], sel(i).name); %#ok<AGROW>
                    end
                end
                if ~ndi.gui.app.GEFManager.field(cellbinMeta,'contoursPresent',false)
                    W{end+1} = ['This cellbin file has no obsm/cell_border, ' ...
                        'so cells get centroids and no outlines.'];
                end
            end

            % -- what will happen anyway but should be seen -------------
            nInFile = ndi.gui.app.GEFManager.field(gefMeta,'nGenesInFile',numel(geneID));
            if nInFile > numel(geneID)
                W{end+1} = sprintf(['Only %d of the file''s %d genes will be ' ...
                    'read. The pyramid will be missing the rest and nothing ' ...
                    'in it will say so.'], numel(geneID), nInFile);
            end
            % readGEF's own words for where the extent came from: 'attrs
            % at ...', with '(unvalidated: no records read)' appended under
            % probeOnly, or 'unknown (...)' when the file carries no
            % attributes at all. Both are expected at probe time and mean
            % different things, so they are reported separately rather than
            % collapsed into one "unverified" note.
            src = ndi.gui.app.GEFManager.field(gefMeta,'boxSource','');
            if contains(src, 'unvalidated')
                W{end+1} = ['The extent shown came from the file''s ' ...
                    'attributes and no records have been checked against ' ...
                    'it. The real read accepts it only if it contains the ' ...
                    'data, and falls back to the data otherwise.'];
            elseif startsWith(src, 'unknown')
                W{end+1} = ['This file carries no extent attributes, so the ' ...
                    'extent will be derived from the records themselves. ' ...
                    'It cannot be shown before the read.'];
            end
            if isempty(ndi.gui.app.GEFManager.field(choices,'genomeAssembly',''))
                W{end+1} = ['No genome assembly recorded. Counts are not ' ...
                    'reproducible without the annotation they were made ' ...
                    'against, and it cannot be recovered from the .gef.'];
            end
            for i = 1:numel(sel)
                if ~sel(i).isUnsupervised
                    W{end+1} = sprintf(['%s will be stored as a cell type ' ...
                        'call, not a clustering. If it is a cluster index ' ...
                        'this is a scientific error rather than a display ' ...
                        'one.'], sel(i).name); %#ok<AGROW>
                end
            end

            plan.errors = E(:);
            plan.warnings = W(:);
            if ~isempty(E), return; end

            % -- the steps ----------------------------------------------
            % Ordered by dependency, and that order is the whole point:
            % the pyramid indexes the gene list, the cells are positioned
            % against the pyramid, and the labels name the cells.
            plan.steps = ndi.gui.app.GEFManager.addStep(plan.steps, ...
                'geneList', sprintf('gene list of %d genes', numel(geneID)), ...
                struct('genomeAssembly', choices.genomeAssembly, ...
                       'annotationSource', choices.annotationSource, ...
                       'label', choices.label));
            plan.steps = ndi.gui.app.GEFManager.addStep(plan.steps, ...
                'pyramid', sprintf('pyramid, %d level(s), %dx%d tiles', ...
                    numel(bs), choices.grid, choices.grid), ...
                struct('binSizes', bs, 'grid', choices.grid, ...
                       'subjectID', choices.subjectID, ...
                       'basePixelSize', choices.basePixelSize, ...
                       'label', choices.label, 'assay', choices.assay, ...
                       'chipSerial', choices.chipSerial));
            if wantCells
                n = ndi.gui.app.GEFManager.field(cellbinMeta,'nCells',NaN);
                plan.steps = ndi.gui.app.GEFManager.addStep(plan.steps, ...
                    'cells', sprintf('cells, %s of them', ...
                        ndi.gui.app.GEFManager.comma(n)), ...
                    struct('contourReference', choices.contourReference, ...
                           'segmentationMethod', choices.segmentationMethod, ...
                           'obsColumns', {choices.obsColumns}, ...
                           'subjectID', choices.subjectID, ...
                           'label', choices.label));
                for i = 1:numel(sel)
                    plan.steps = ndi.gui.app.GEFManager.addStep(plan.steps, ...
                        'labels', sprintf('labeling %s', sel(i).name), ...
                        struct('labelName', sel(i).name, ...
                               'isUnsupervised', sel(i).isUnsupervised));
                end
            end
        end

        function msg = ingestMessage(plan)
        % INGESTMESSAGE - what the confirmation says before the wait
        %
        %   Names every document that will be created and every warning,
        %   because this is the last screen before a read that can take
        %   minutes and cannot be undone without the delete cascade.
            if ~isempty(plan.errors)
                msg = sprintf('This cannot run yet:\n\n%s', ...
                    ndi.gui.app.GEFManager.bullets(plan.errors));
                return;
            end
            lines = cell(numel(plan.steps),1);
            for i = 1:numel(plan.steps)
                lines{i} = plan.steps(i).description;
            end
            msg = sprintf('This creates:\n\n%s', ...
                ndi.gui.app.GEFManager.bullets(lines));
            if ~isempty(plan.warnings)
                msg = sprintf('%s\n\nWorth knowing:\n\n%s', msg, ...
                    ndi.gui.app.GEFManager.bullets(plan.warnings));
            end
            msg = sprintf(['%s\n\nReading the records takes minutes on a ' ...
                'real section.'], msg);
        end

        function result = runIngest(session, gefPath, cellbinPath, plan, progressFcn)
        % RUNINGEST - execute a plan, in dependency order
        %
        %   RESULT = ndi.gui.app.GEFManager.RUNINGEST(SESSION, GEFPATH, ...
        %       CELLBINPATH, PLAN)
        %   RESULT = ...RUNINGEST(..., PROGRESSFCN)
        %
        %   This is where the reading happens, and it is the only part of
        %   the app that is slow. PLAN has already been validated by
        %   ingestPlan, so a refusal here is a genuine surprise rather than
        %   a rejected request.
        %
        %   PROGRESSFCN, if given, is called as PROGRESSFCN(FRACTION, TEXT)
        %   before each step. It is a plain function handle rather than a
        %   uiprogressdlg so this runs with no display; the app passes one
        %   that drives the dialog.
        %
        %   RESULT has fields geneListDoc, pyrDoc, tileDocs, cellsDoc,
        %   labelDocs and notes. NOTES is a cellstr of what the full read
        %   found that the probe could not -- clamped counts, an extent the
        %   records disagreed with, SAW''s own per-gene totals disagreeing
        %   with ours. Those checks only become possible once every record
        %   has been read, so they are reported after the fact rather than
        %   asked about before it.
            arguments
                session (1,1)
                gefPath (1,:) char
                cellbinPath (1,:) char
                plan (1,1) struct
                progressFcn = []
            end
            if ~isempty(plan.errors)
                error('NDI:GEFManager:planHasErrors', ...
                    'This plan cannot run:\n%s', ...
                    ndi.gui.app.GEFManager.bullets(plan.errors));
            end

            result = struct('geneListDoc',[],'pyrDoc',[],'tileDocs',{{}}, ...
                'cellsDoc',[],'labelDocs',{{}},'notes',{{}});
            n = numel(plan.steps);

            % -- the GEF, read once, into its documents ------------------
            % ndi.fun.doc.gene.fromGEF owns this path: one read, then the
            % gene list and the pyramid built from it. This class used to
            % run that sequence itself, which left two copies of the
            % read-once discipline free to drift apart. The app now differs
            % from a script only in passing a progress callback.
            %
            % recordSource is FALSE, which keeps this a refactor rather
            % than a change of behaviour. fromGEF would otherwise also
            % create a generic_file describing the .gef and checksum it --
            % a second full read of a ~9.4 GB file, and a document that
            % ingestMessage never told the user about. That screen names
            % every document that will be created, so adding one silently
            % would make it wrong. Recording provenance from the GUI is
            % worth doing; it needs a plan step and a line on the
            % confirmation screen, not a quiet default.
            glArgs = ndi.gui.app.GEFManager.stepArgs(plan, 'geneList');
            pyArgs = ndi.gui.app.GEFManager.stepArgs(plan, 'pyramid');
            % Spelled out rather than pulled through a local handle: the
            % obvious short name for one would be 'get', which shadows the
            % graphics built-in inside a class that draws.
            maxGenes   = ndi.gui.app.GEFManager.field(plan.choices, 'maxGenes', 0);
            assembly   = ndi.gui.app.GEFManager.field(glArgs, 'genomeAssembly', '');
            annotation = ndi.gui.app.GEFManager.field(glArgs, 'annotationSource', '');
            lbl        = ndi.gui.app.GEFManager.field(pyArgs, 'label', '');
            binSizes   = ndi.gui.app.GEFManager.field(pyArgs, 'binSizes', [1 2 4 8 16 32]);
            gridN      = ndi.gui.app.GEFManager.field(pyArgs, 'grid', 9);
            subjectID  = ndi.gui.app.GEFManager.field(pyArgs, 'subjectID', '');
            pixelSize  = ndi.gui.app.GEFManager.field(pyArgs, 'basePixelSize', [NaN NaN]);
            assay      = ndi.gui.app.GEFManager.field(pyArgs, 'assay', 'Stereo-seq');
            chipSerial = ndi.gui.app.GEFManager.field(pyArgs, 'chipSerial', '');
            [result.pyrDoc, result.tileDocs, result.geneListDoc, gefInfo] = ...
                ndi.fun.doc.gene.fromGEF(session, gefPath, ...
                    'maxGenes', maxGenes, ...
                    'genomeAssembly', assembly, ...
                    'annotationSource', annotation, ...
                    'label', lbl, 'binSizes', binSizes, 'grid', gridN, ...
                    'subjectID', subjectID, 'basePixelSize', pixelSize, ...
                    'assay', assay, 'chipSerial', chipSerial, ...
                    'recordSource', false, ...
                    'progressFcn', ndi.gui.app.GEFManager.gefProgress( ...
                        progressFcn, n));
            result.notes = gefInfo.notes;

            % Only 'cells' still does work here. The other three kinds are
            % done by the two wrappers, each of which reads its file once
            % and makes every document that read supports: fromGEF the gene
            % list and the pyramid, fromCellBin the cells and every
            % labeling. They stay in plan.steps because the plan is what
            % the confirmation screen describes, and a user should see each
            % document named before committing to a read that takes minutes
            % and cannot be undone without the delete cascade.
            for i = 1:n
                step = plan.steps(i);
                switch step.kind
                    case 'cells'
                        ndi.gui.app.GEFManager.tick( ...
                            progressFcn, i-1, n, step.description);
                        result = ndi.gui.app.GEFManager.runCellsStep( ...
                            session, cellbinPath, step, plan, result);
                    case {'geneList','pyramid','labels'}
                        % Already created; see above. Not ticked either,
                        % because the bar has passed these already and
                        % moving it backwards would read as a stall.
                end
            end
            ndi.gui.app.GEFManager.tick(progressFcn, n, n, 'Done.');

        end

        function notes = readNotes(gefMeta, geneID)
        % READNOTES - what the full read found that a probe could not
        %
        %   Kept as a forwarder so the app and the ingest wrappers cannot
        %   drift on what a read is worth reporting. The logic moved to
        %   ndi.fun.doc.gene.readNotes when the .gef-to-documents path was
        %   lifted out of this class, because a caller with no display
        %   needs those notes just as much.
            notes = ndi.fun.doc.gene.readNotes(gefMeta, geneID);
        end

        function args = stepArgs(plan, kind)
        % STEPARGS - the args of the first step of KIND, or an empty struct
        %
        %   The plan is the contract between the confirmation screen and
        %   the run, so the run reads its arguments back out of the plan
        %   rather than off plan.choices. A user who saw a pyramid of six
        %   levels described gets a pyramid of six levels.
        %
        %   Public and static like the rest of the pure layer, so it can be
        %   tested with no display and no session.
            args = struct();
            for i = 1:numel(plan.steps)
                if strcmp(plan.steps(i).kind, kind)
                    args = plan.steps(i).args;
                    return;
                end
            end
        end

        function f = gefProgress(progressFcn, n)
        % GEFPROGRESS - map fromGEF's own [0 1] onto the whole run's bar
        %
        %   fromGEF reports progress across itself; it does not know how
        %   many steps the plan has. It covers the geneList and pyramid
        %   steps, which are always the first two, so its fraction is
        %   scaled into that share and the bar stays monotonic when the
        %   cells step picks up.
        %
        %   Public and static like the rest of the pure layer, so the
        %   no-overshoot invariant can be tested with no display.
            f = [];
            if isempty(progressFcn) || n <= 0, return; end
            share = min(2, n) / n;
            f = @(frac, txt) progressFcn(max(0, min(1, frac * share)), txt);
        end


        function s = summarizeGef(meta, geneID)
        % SUMMARIZEGEF - what a .gef contains, from a probe alone
        %
        %   THE EXTENT MAY BE UNKNOWN HERE, and that is a legitimate state
        %   rather than a defect: readGEF reports an extent from the file's
        %   attributes when it finds them, and a file that carries none has
        %   no extent until its records have been read. A probe reads no
        %   records, so meta.box comes back empty and there is nothing
        %   truthful to print. It gets derived from the data during the
        %   real read.
            if numel(meta.box) == 4
                ext = sprintf('extent %d x %d (origin %d,%d)', ...
                    meta.box(3)-meta.box(1)+1, meta.box(4)-meta.box(2)+1, ...
                    meta.box(1), meta.box(2));
            else
                ext = 'extent not yet known';
            end
            s = sprintf(['%d genes, %s records\n%s\n' ...
                'chip %s, resolution %g nm\nlayout %s, extent from %s'], ...
                numel(geneID), ndi.gui.app.GEFManager.comma(meta.nRecords), ...
                ext, ndi.gui.app.GEFManager.orNone(meta.chipSerial), ...
                meta.resolutionNm, meta.root, meta.boxSource);
        end
        function p = launcherPath()
        % LAUNCHERPATH - the viewer launcher, from preferences or default
        %
        %   A missing or unreadable preference falls back to the default
        %   rather than raising: the dialog can still open, and the field
        %   it opens with is editable.
            p = char(ndi.gui.app.GEFManager.DefaultViewerLauncher);
            try
                v = ndi.preferences.get('GUI.GEFManager.ViewerLauncher');
                if ~isempty(char(v)), p = char(v); end
            catch
            end
        end

        function setLauncherPath(p)
        % SETLAUNCHERPATH - remember the launcher for next time
        %
        %   Failing to persist must not cost the launch that is about to
        %   happen, so this swallows rather than raises.
            try
                ndi.preferences.set('GUI.GEFManager.ViewerLauncher', string(p));
            catch
            end
        end

        function cmd = viewCommand(launcher, sessionPath, pyramidID, options)
        % VIEWCOMMAND - the command line that opens a pyramid in napari
        %
        %   CMD = NDI.GUI.APP.GEFMANAGER.VIEWCOMMAND(LAUNCHER, SESSIONPATH,
        %   PYRAMIDID) returns the shell command, as a char row vector,
        %   that hands this pyramid to the napari viewer in NDI-python.
        %
        %   PURE, AND THAT IS THE POINT. Nothing here launches anything or
        %   touches the filesystem, so the command can be built, shown to
        %   the user in the dialog, and asserted in a test with no display
        %   and no Python. When the launch then fails, the exact command
        %   is on screen to be copied into a terminal, which is the
        %   difference between a bug report and a shrug.
        %
        %   THE PYRAMID IS ALWAYS NAMED. The viewer will open a session
        %   holding exactly one pyramid without being told which, but a
        %   session holding two lists them and opens nothing. Passing the
        %   id the user selected removes that as a way for View to appear
        %   to do nothing.
        %
        %   Optional Name-Value Arguments:
        %   cells (false)    - overlay cell centroids
        %   outlines (false) - draw cell boundaries. IMPLIES 'cells': the
        %                      viewer reads boundaries out of the cells
        %                      document it resolved, so outlines without
        %                      cells is not a picture with fewer layers,
        %                      it is a refusal.
        %   density (true)   - counts per base pixel rather than per bin
        %   controls (true)  - dock the gene / display / cell type panels
        %   name ('')        - image layer name. '' leaves the viewer to
        %                      use the pyramid's own label.
        %   labels ('')      - cell type labelings to show, comma
        %                      separated; 'none' shows none. '' lets the
        %                      viewer decide.
        %
        %   See also: ndi.gui.app.GEFManager
            arguments
                % char without a (1,:) size: an emptied uieditfield hands
                % back a 0-by-0 char, and a size constraint would answer
                % that with a validation error where this raises a
                % refusal that says what is missing.
                launcher char
                sessionPath char
                pyramidID char
                options.cells (1,1) logical = false
                options.outlines (1,1) logical = false
                options.density (1,1) logical = true
                options.controls (1,1) logical = true
                options.name char = ''
                options.labels char = ''
            end
            if isempty(strtrim(launcher))
                error('NDI:gene:GEFManager:noLauncher', ...
                    ['No viewer launcher is set. It is normally ' ...
                     '/usr/local/bin/napariViewGEF, a shell wrapper that ' ...
                     'scrubs MATLAB''s library paths before starting ' ...
                     'Python.']);
            end
            if isempty(strtrim(sessionPath))
                error('NDI:gene:GEFManager:noSessionPath', ...
                    ['This session has no directory on disk, so there is ' ...
                     'nothing for the viewer to open. The napari viewer ' ...
                     'reads an ndi.session.dir.']);
            end
            parts = { ...
                ndi.gui.app.GEFManager.shellQuote(strtrim(launcher)), ...
                ndi.gui.app.GEFManager.shellQuote(sessionPath), ...
                '--pyramid', ndi.gui.app.GEFManager.shellQuote(pyramidID)};
            if options.cells || options.outlines
                parts{end+1} = '--cells';
            end
            if options.outlines
                parts{end+1} = '--outlines';
            end
            if ~options.density
                parts{end+1} = '--no-density';
            end
            if ~isempty(strtrim(options.name))
                parts{end+1} = '--name';
                parts{end+1} = ndi.gui.app.GEFManager.shellQuote(strtrim(options.name));
            end
            if ~isempty(strtrim(options.labels))
                parts{end+1} = '--labels';
                parts{end+1} = ndi.gui.app.GEFManager.shellQuote(strtrim(options.labels));
            end
            if ~options.controls
                parts{end+1} = '--no-controls';
            end
            cmd = strjoin(parts, ' ');
        end

        function s = shellQuote(str)
        % SHELLQUOTE - one argument, safe to paste into a shell
        %
        %   Session directories and layer names contain spaces, and a
        %   command assembled by concatenation would then hand the viewer
        %   two arguments where one was meant. Single quotes on POSIX
        %   (with the embedded-quote dance, since nothing is special
        %   inside them), double quotes on Windows.
            str = char(str);
            if ispc
                s = ['"' strrep(str, '"', '""') '"'];
            else
                s = ['''' strrep(str, '''', '''\''''') ''''];
            end
        end

        function cmd = detach(cmd)
        % DETACH - the same command, not blocking MATLAB
        %
        %   The viewer runs for as long as the user looks at it. Without
        %   this, MATLAB would sit unresponsive behind it until they close
        %   the window, which reads as the launch having hung.
            if ispc
                cmd = ['start "napari" ' cmd];
            else
                cmd = [cmd ' &'];
            end
        end

        function m = subjectNameMap(session)
        % SUBJECTNAMEMAP - subject document id -> local_identifier
        %
        %   A containers.Map so the lookup is one query for the session
        %   rather than one per pyramid. A subject with no
        %   local_identifier is left out rather than mapped to '': the
        %   caller's default is the id, and an empty cell in the Subject
        %   column would say the pyramid has no subject, which is a
        %   different and worse claim than showing the id.
            m = containers.Map('KeyType','char','ValueType','char');
            docs = session.database_search(ndi.query('','isa','subject'));
            for i = 1:numel(docs)
                p = docs{i}.document_properties;
                if ~isfield(p,'subject'), continue; end
                nm = ndi.gui.app.GEFManager.field(p.subject,'local_identifier','');
                if ~isempty(nm)
                    m(docs{i}.id()) = char(nm);
                end
            end
        end

        function m = geneListCountMap(session)
        % GENELISTCOUNTMAP - geneList document id -> n_genes
        %
        %   Same reason as subjectNameMap: one query, not one per row.
            m = containers.Map('KeyType','char','ValueType','double');
            docs = session.database_search(ndi.query('','isa','geneList'));
            for i = 1:numel(docs)
                p = docs{i}.document_properties;
                if ~isfield(p,'geneList'), continue; end
                m(docs{i}.id()) = double( ...
                    ndi.gui.app.GEFManager.field(p.geneList,'n_genes',NaN));
            end
        end

        function v = lookup(m, key, dflt)
        % LOOKUP - m(key), or DFLT when the key is absent or empty
            v = dflt;
            if isempty(key) || ~isKey(m, char(key)), return; end
            v = m(char(key));
        end

    end

    % =====================================================================
    methods (Static, Access = private)

        function v = field(s, name, dflt)
            if isstruct(s) && isfield(s, name), v = s.(name); else, v = dflt; end
        end

        function v = dependency(d, name)
            try
                v = d.dependency_value(name);
            catch
                v = '';
            end
            if isempty(v), v = ''; end
        end

        function s = orNone(v)
            if isempty(v), s = '(none)'; else, s = v; end
        end

        function s = comma(n)
            s = regexprep(sprintf('%d', round(n)), '(\d)(?=(\d{3})+$)', '$1,');
        end

        function result = runCellsStep(session, cellbinPath, step, plan, result)
        % The cells and every labeling, from ONE read of the cellbin file.
        %
        % This is now a thin adapter over ndi.fun.doc.gene.fromCellBin,
        % which owns the read-once discipline: readCellBin returns cells
        % in file order and labels in file order, and the only thing tying
        % a label array to a cell table is that they came from the same
        % pass. The logic lives in the gene package rather than here so a
        % caller with no display gets the same guarantee -- which was the
        % whole reason for lifting it out.
            sel = ndi.gui.app.GEFManager.field(plan.choices, 'labelSelections', ...
                struct('name',{},'isUnsupervised',{}));
            wanted = ndi.gui.app.GEFManager.field(step.args, 'obsColumns', {});

            [cellsDoc, labelDocs, info] = ndi.fun.doc.gene.fromCellBin( ...
                session, cellbinPath, result.pyrDoc, ...
                'labelings', sel, 'obsColumns', wanted, ...
                'contourReference', step.args.contourReference, ...
                'segmentationMethod', ...
                    ndi.gui.app.GEFManager.field(step.args,'segmentationMethod',''), ...
                'subjectID', ndi.gui.app.GEFManager.field(step.args,'subjectID',''), ...
                'label', ndi.gui.app.GEFManager.field(step.args,'label',''));

            result.cellsDoc = cellsDoc;
            result.labelDocs = labelDocs;
            result.notes = [result.notes(:); info.notes(:)];
        end

        function tick(progressFcn, i, n, txt)
            if isempty(progressFcn), return; end
            frac = 0;
            if n > 0, frac = max(0, min(1, i / n)); end
            progressFcn(frac, txt);
        end

        function steps = addStep(steps, kind, description, args)
            k = numel(steps) + 1;
            steps(k).kind = kind;
            steps(k).description = description;
            steps(k).args = args;
        end

        function t = bullets(lines)
            t = '';
            for i = 1:numel(lines)
                t = sprintf('%s  - %s\n', t, lines{i});
            end
        end

        function c = rowsToCell(rows)
            c = cell(numel(rows), 8);
            for i = 1:numel(rows)
                c{i,1} = rows(i).label;
                c{i,2} = rows(i).subject;
                c{i,3} = rows(i).assay;
                c{i,4} = rows(i).chipSerial;
                c{i,5} = rows(i).nGenes;
                c{i,6} = rows(i).nLevels;
                c{i,7} = rows(i).nCells > 0;
                c{i,8} = rows(i).nLabelSets;
            end
        end
    end

    % =====================================================================
    methods (Access = private)

        function buildUI(obj)
            obj.fig = uifigure('Name','GEF Manager','Position',[100 100 900 420]);
            g = uigridlayout(obj.fig,[3 5]);
            g.RowHeight = {'1x', 30, 22};
            g.ColumnWidth = {'1x', 90, 90, 90, 90};

            obj.table = uitable(g, 'ColumnName', ...
                {'Label','Subject','Assay','Chip','Genes','Levels','Cells','Label sets'});
            obj.table.Layout.Row = 1; obj.table.Layout.Column = [1 5];

            b = uibutton(g,'Text','Reload','ButtonPushedFcn',@(~,~) obj.reload());
            b.Layout.Row = 2; b.Layout.Column = 2;
            b = uibutton(g,'Text','View...','ButtonPushedFcn',@(~,~) obj.onView());
            b.Layout.Row = 2; b.Layout.Column = 3;
            b = uibutton(g,'Text','Add...','ButtonPushedFcn',@(~,~) obj.onAdd());
            b.Layout.Row = 2; b.Layout.Column = 4;
            b = uibutton(g,'Text','Delete','ButtonPushedFcn',@(~,~) obj.onDelete());
            b.Layout.Row = 2; b.Layout.Column = 5;

            obj.statusLabel = uilabel(g,'Text','');
            obj.statusLabel.Layout.Row = 3; obj.statusLabel.Layout.Column = [1 5];
        end

        function setStatus(obj, msg)
            if ~isempty(obj.statusLabel) && isvalid(obj.statusLabel)
                obj.statusLabel.Text = msg;
            end
        end

        function r = selectedRow(obj)
            r = [];
            sel = obj.table.Selection;
            if isempty(sel) || isempty(obj.rows), return; end
            r = obj.rows(sel(1));
        end

        function onView(obj)
        % ONVIEW - the launcher dialog, and then the launch
        %
        %   A dialog rather than a button that just runs, because the
        %   things it asks about cannot be recovered afterwards from the
        %   window that opens: whether the cells are drawn, whether the
        %   outlines are, and what the layer is called. And because the
        %   launcher is a path on the user's machine that NDI cannot know,
        %   only default.
        %
        %   THE COMMAND IS ON SCREEN before it runs, and stays readable
        %   afterwards. Launching another program is the step most likely
        %   to fail for reasons NDI cannot see -- a wrapper not installed,
        %   an environment that is not what it looks like -- and a command
        %   the user can copy into a terminal turns that from a shrug into
        %   something they can act on.
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            sessionPath = '';
            try
                sessionPath = obj.session.getpath();
            catch
            end
            if isempty(sessionPath)
                uialert(obj.fig, ...
                    ['This session has no directory on disk. The napari ' ...
                     'viewer opens an ndi.session.dir, and there is nothing ' ...
                     'here for it to open.'], 'Nothing to view');
                return;
            end

            hasCells = r.nCells > 0;
            launched = false;

            d = uifigure('Name','View in napari','Position',[120 120 660 440]);
            gl = uigridlayout(d,[9 3]);
            gl.RowHeight = {40, 24, 24, 24, 24, 24, 24, 24, 60};
            gl.ColumnWidth = {140, '1x', 100};

            intro = uilabel(gl,'WordWrap','on','Text', ...
                ['Opens this pyramid in napari. The viewer is a separate ' ...
                 'Python program: MATLAB starts it and does not wait for it. ' ...
                 'The command that will run is shown at the bottom.']);
            intro.Layout.Row = 1; intro.Layout.Column = [1 3];

            lab = uilabel(gl,'Text','Launcher');
            lab.Layout.Row = 2; lab.Layout.Column = 1;
            ed = uieditfield(gl,'text','Value',ndi.gui.app.GEFManager.launcherPath());
            ed.Layout.Row = 2; ed.Layout.Column = 2;
            br = uibutton(gl,'Text','Browse...');
            br.Layout.Row = 2; br.Layout.Column = 3;

            lab = uilabel(gl,'Text','Layer name');
            lab.Layout.Row = 3; lab.Layout.Column = 1;
            nameEd = uieditfield(gl,'text','Value','All genes');
            nameEd.Layout.Row = 3; nameEd.Layout.Column = [2 3];

            lab = uilabel(gl,'Text','Cell type labelings');
            lab.Layout.Row = 4; lab.Layout.Column = 1;
            labelEd = uieditfield(gl,'text','Value','', ...
                'Placeholder','blank: let the viewer choose.  none: show no labelings.');
            labelEd.Layout.Row = 4; labelEd.Layout.Column = [2 3];

            cbCells = uicheckbox(gl,'Text','Cell centroids', ...
                'Value',hasCells,'Enable',hasCells);
            cbCells.Layout.Row = 5; cbCells.Layout.Column = [1 3];
            cbOut = uicheckbox(gl,'Text','Cell outlines', ...
                'Value',hasCells,'Enable',hasCells);
            cbOut.Layout.Row = 6; cbOut.Layout.Column = [1 3];
            if ~hasCells
                cbCells.Text = 'Cell centroids (no cells document for this pyramid)';
                cbOut.Text = 'Cell outlines (no cells document for this pyramid)';
            end
            cbCounts = uicheckbox(gl,'Text','Raw counts instead of density','Value',false);
            cbCounts.Layout.Row = 7; cbCounts.Layout.Column = [1 3];
            cbPanels = uicheckbox(gl,'Text','Control panels','Value',true);
            cbPanels.Layout.Row = 8; cbPanels.Layout.Column = [1 3];

            cmdArea = uitextarea(gl,'Editable','off','Value','');
            cmdArea.Layout.Row = 9; cmdArea.Layout.Column = [1 2];
            go = uibutton(gl,'Text','Launch');
            go.Layout.Row = 9; go.Layout.Column = 3;

            br.ButtonPushedFcn = @(~,~) localBrowse();
            go.ButtonPushedFcn = @(~,~) localGo();
            everything = {ed, nameEd, labelEd, cbCells, cbOut, cbCounts, cbPanels};
            for i = 1:numel(everything)
                everything{i}.ValueChangedFcn = @localRefresh;
            end

            localRefresh();
            uiwait(d);
            if ~launched && isvalid(d), delete(d); end

            function c = localCommand()
                % A refusal is shown where the command would be, rather
                % than raised: the dialog is still open and the user is
                % one field away from fixing it.
                try
                    c = ndi.gui.app.GEFManager.viewCommand(ed.Value, sessionPath, ...
                        r.id, 'cells', cbCells.Value, 'outlines', cbOut.Value, ...
                        'density', ~cbCounts.Value, 'controls', cbPanels.Value, ...
                        'name', nameEd.Value, 'labels', labelEd.Value);
                catch ME
                    c = ME.message;
                end
            end

            function localRefresh(~,~)
                % Outlines are read out of the cells document, so the
                % viewer needs cells for them. Ticking the box on the
                % user's behalf is honest; leaving it clear while passing
                % --cells anyway would not be.
                if cbOut.Value, cbCells.Value = true; end
                cmdArea.Value = localCommand();
            end

            function localBrowse()
                [f,pth] = uigetfile('*','Select the napari viewer launcher');
                figure(d);
                if isequal(f,0), return; end
                ed.Value = fullfile(pth,f);
                localRefresh();
            end

            function localGo()
                cmd = localCommand();
                target = strtrim(ed.Value);
                % An absolute path that is not there is the common
                % failure -- the wrapper has not been installed yet --
                % and it is worth naming before the shell answers with
                % "not found". A bare name is left to the shell, which is
                % where PATH lookup belongs.
                if ~isempty(regexp(target,'[/\\]','once')) && ~isfile(target)
                    uialert(d, sprintf(['No launcher at\n  %s\n\nThat path ' ...
                        'is normally a small shell wrapper that scrubs ' ...
                        'MATLAB''s library paths and then runs napariViewGEF ' ...
                        'from your NDI-python environment. Install it there, ' ...
                        'or point this at the console script yourself.'], ...
                        target), 'Launcher not found');
                    return;
                end
                ndi.gui.app.GEFManager.setLauncherPath(target);
                status = system(ndi.gui.app.GEFManager.detach(cmd));
                launched = true;
                delete(d);
                if status == 0
                    obj.setStatus(sprintf('Launched the viewer for %s.', ...
                        ndi.gui.app.GEFManager.orNone(r.label)));
                else
                    obj.setStatus(sprintf(['The launcher exited %d. The ' ...
                        'command was:  %s'], status, cmd));
                end
            end
        end

        function onDelete(obj)
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            plan = ndi.gui.app.GEFManager.deletionPlan(obj.session, r.doc);
            choice = uiconfirm(obj.fig, ...
                ndi.gui.app.GEFManager.deletionMessage(plan), 'Confirm delete', ...
                'Options',{'Delete','Cancel'},'DefaultOption',2,'CancelOption',2);
            if ~strcmp(choice,'Delete'), return; end
            % Deepest first, so nothing is ever left pointing at a document
            % that has already gone.
            for i = 1:numel(plan.labels), obj.session.database_rm(plan.labels{i}); end
            for i = 1:numel(plan.cells),  obj.session.database_rm(plan.cells{i});  end
            for i = 1:numel(plan.tiles),  obj.session.database_rm(plan.tiles{i});  end
            obj.session.database_rm(r.doc);
            obj.setStatus(sprintf('Deleted %d document(s).', plan.total));
            obj.reload();
        end

        function onAdd(obj)
            [f,p] = uigetfile({'*.gef','Stereo-seq GEF (*.gef)'}, 'Select a GEF');
            if isequal(f,0), return; end
            gefPath = fullfile(p,f);

            choice = uiconfirm(obj.fig, ...
                ['Add a SAW cellbin .h5ad? It carries segmented cells, ' ...
                 'their outlines, and any labelings. It can also be added ' ...
                 'later against this same pyramid.'], 'Cell segmentation', ...
                'Options',{'Choose a file','Skip'},'DefaultOption',1);
            cellbinPath = '';
            if strcmp(choice,'Choose a file')
                [f2,p2] = uigetfile({'*.h5ad','SAW cellbin (*.h5ad)'}, ...
                    'Select a cellbin .h5ad');
                if ~isequal(f2,0), cellbinPath = fullfile(p2,f2); end
            end

            % -- probe. Nothing here reads the bulk data. ---------------
            obj.setStatus('Probing...');
            drawnow;
            try
                [~,~,~,~,geneID,~,gefMeta] = ndr.format.stereoseq.readGEF( ...
                    gefPath, 'probeOnly', true);
                cbMeta = [];
                if ~isempty(cellbinPath)
                    [~,~,~,~,~,cbMeta] = ndr.format.stereoseq.readCellBin( ...
                        cellbinPath, 'probeOnly', true);
                end
            catch ME
                uialert(obj.fig, ME.message, 'Could not read that file');
                obj.setStatus('');
                return;
            end

            % -- confirm what was inferred ------------------------------
            choices = obj.askChoices(gefMeta, geneID, cbMeta);
            if isempty(choices)
                obj.setStatus('Cancelled.');
                return;
            end

            plan = ndi.gui.app.GEFManager.ingestPlan(gefMeta, geneID, cbMeta, choices);
            msg = ndi.gui.app.GEFManager.ingestMessage(plan);
            if ~isempty(plan.errors)
                uialert(obj.fig, msg, 'Cannot ingest this yet');
                obj.setStatus('');
                return;
            end
            go = uiconfirm(obj.fig, msg, 'Confirm ingest', ...
                'Options',{'Ingest','Cancel'},'DefaultOption',2,'CancelOption',2);
            if ~strcmp(go,'Ingest'), obj.setStatus('Cancelled.'); return; end

            % -- run ----------------------------------------------------
            d = uiprogressdlg(obj.fig, 'Title','Ingesting', ...
                'Message','Starting...','Indeterminate','off');
            cleanup = onCleanup(@() delete(d));
            try
                result = ndi.gui.app.GEFManager.runIngest(obj.session, ...
                    gefPath, cellbinPath, plan, ...
                    @(frac,txt) ndi.gui.app.GEFManager.driveDialog(d, frac, txt));
            catch ME
                clear cleanup;
                uialert(obj.fig, ME.message, 'Ingest failed');
                obj.setStatus('Ingest failed; see the message.');
                obj.reload();
                return;
            end
            clear cleanup;

            % The notes are shown rather than logged. They are what the
            % full read found and the probe could not -- clamped counts, an
            % extent the records disagreed with -- and every one of them
            % changes what the pyramid means without making it invalid.
            if isempty(result.notes)
                uialert(obj.fig, 'Ingested.', 'Done', 'Icon','success');
            else
                uialert(obj.fig, sprintf('Ingested.\n\nFrom the full read:\n\n%s', ...
                    ndi.gui.app.GEFManager.bullets(result.notes)), 'Done', ...
                    'Icon','success');
            end
            obj.reload();
        end

        function choices = askChoices(obj, gefMeta, geneID, cbMeta)
        % The confirmation screen. Shows what was READ, what was INFERRED
        % and the evidence behind each inference, and asks for the one
        % thing the files cannot supply: the subject.
            choices = [];
            defaults = ndi.gui.app.GEFManager.ingestChoices(gefMeta, cbMeta);

            text = sprintf('%s\n\n', ...
                ndi.gui.app.GEFManager.summarizeGef(gefMeta, geneID));
            if ~isempty(cbMeta)
                items = ndi.gui.app.GEFManager.contourFindings(cbMeta);
                text = sprintf('%sCells: %d\n', text, cbMeta.nCells);
                for i = 1:numel(items)
                    text = sprintf('%s  %s: %s  [%s]\n', text, ...
                        items(i).name, items(i).value, items(i).evidence);
                end
            end
            uialert(obj.fig, text, 'What these files contain', 'Icon','info');

            subj = ndi.gui.app.GEFManager.subjectChoices(obj.session);
            if isempty(subj)
                uialert(obj.fig, ['This session has no subject documents. A ' ...
                    'pyramid must depend on one, because a section is ' ...
                    'measured from an animal.'], 'No subject');
                return;
            end
            answer = listdlg('PromptString','Which subject was this section from?', ...
                'ListString', {subj.label}, 'SelectionMode','single');
            if isempty(answer), return; end
            defaults.subjectID = subj(answer).id;

            % Labelings are offered, never preselected: the file does not
            % say which is a cell type call and which is a clustering.
            if ~isempty(cbMeta)
                lf = ndi.gui.app.GEFManager.labelFindings(cbMeta);
                if ~isempty(lf)
                    strs = cell(numel(lf),1);
                    for i = 1:numel(lf)
                        kind = 'cell type call';
                        if lf(i).isUnsupervisedGuess, kind = 'clustering'; end
                        strs{i} = sprintf('%s (%d categories, looks like a %s)', ...
                            lf(i).name, lf(i).nCategories, kind);
                    end
                    pick = listdlg('PromptString', ...
                        'Which labelings should be ingested? (none is fine)', ...
                        'ListString', strs, 'SelectionMode','multiple', ...
                        'InitialValue', []);
                    sel = struct('name',{},'isUnsupervised',{});
                    for i = 1:numel(pick)
                        k = pick(i);
                        sel(end+1).name = lf(k).name; %#ok<AGROW>
                        sel(end).isUnsupervised = lf(k).isUnsupervisedGuess;
                    end
                    defaults.labelSelections = sel;
                end
            end
            choices = defaults;
        end
    end
end
