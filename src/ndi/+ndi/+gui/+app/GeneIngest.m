classdef GeneIngest < ndi.gui.app.sessionApp
% NDI.GUI.APP.GENEINGEST - list, add and delete spatial transcriptomics datasets
%
%   ndi.gui.app.GeneIngest(SESSION)
%
%   Lists the spatial gene expression pyramids in a session, and adds or
%   removes one. Reached from the navigator's per-session Apps menu.
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
%   DELETING IS A CASCADE. Levels depend on the pyramid, cells depend on
%   the pyramid, and labels depend on cells, so removing a pyramid orphans
%   everything beneath it. deletionPlan enumerates that first and the
%   confirmation names the counts, because "delete 1 document" and "delete
%   493 documents" should not look the same.
%
%   Example:
%       S = ndi.session.dir('mysession','/path/to/session');
%       ndi.gui.app.GeneIngest(S);
%
%   See also: ndi.fun.doc.gene.makePyramid, ndi.fun.doc.gene.makeCells,
%             ndi.fun.doc.gene.makeCellTypeLabels,
%             ndr.format.stereoseq.readGEF, ndr.format.stereoseq.readCellBin

    properties (Constant)
        Name = "Gene Ingest"
        Category = "Spatial transcriptomics"
    end

    properties (Access = private)
        session
        fig
        table
        statusLabel
        rows = struct([])
    end

    methods
        function obj = GeneIngest(sessionObj, options)
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
            obj.rows = ndi.gui.app.GeneIngest.pyramidRows(obj.session);
            if ~isempty(obj.fig) && isvalid(obj.fig)
                obj.table.Data = ndi.gui.app.GeneIngest.rowsToCell(obj.rows);
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
            docs = session.database_search( ...
                ndi.query('','isa','spatialGeneExpressionPyramid'));
            rows = struct('id',{},'label',{},'subject',{},'assay',{}, ...
                'chipSerial',{},'nGenes',{},'nLevels',{},'extent',{}, ...
                'nCells',{},'nLabelSets',{},'doc',{});
            for i = 1:numel(docs)
                d = docs{i};
                p = d.document_properties.spatialGeneExpressionPyramid;
                k = numel(rows) + 1;
                rows(k).id = d.id();
                rows(k).doc = d;
                rows(k).label = ndi.gui.app.GeneIngest.field(p,'label','');
                rows(k).assay = ndi.gui.app.GeneIngest.field(p,'assay','');
                rows(k).chipSerial = ndi.gui.app.GeneIngest.field(p,'chip_serial','');
                rows(k).subject = ndi.gui.app.GeneIngest.dependency(d,'subject_id');
                rows(k).nGenes = ndi.gui.app.GeneIngest.field(p,'n_genes',NaN);
                rows(k).extent = [ndi.gui.app.GeneIngest.field(p,'extent_x',NaN), ...
                                  ndi.gui.app.GeneIngest.field(p,'extent_y',NaN)];
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
            choices.chipSerial = ndi.gui.app.GeneIngest.field(gefMeta,'chipSerial','');
            choices.binSizes = [1 2 4 8 16 32];
            choices.grid = 9;
            % The GEF's resolution attribute is in NANOMETRES and
            % basePixelSize is in micrometres, so this is the one unit
            % conversion in the ingest path. SAW's usual 500 nm becomes
            % 0.5, which is also makePyramid's default -- so a mistake here
            % looks exactly like the default and would not stand out.
            res = ndi.gui.app.GeneIngest.field(gefMeta,'resolutionNm',500);
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
        %   PLAN = ndi.gui.app.GeneIngest.INGESTPLAN(GEFMETA, GENEID, ...
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
            bs = ndi.gui.app.GeneIngest.field(choices,'binSizes',[]);
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

            wantCells = ndi.gui.app.GeneIngest.field(choices,'importCells',false);
            haveCellbin = ~isempty(cellbinMeta);
            sel = ndi.gui.app.GeneIngest.field(choices,'labelSelections', ...
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
                if ~ndi.gui.app.GeneIngest.field(cellbinMeta,'contoursPresent',false)
                    W{end+1} = ['This cellbin file has no obsm/cell_border, ' ...
                        'so cells get centroids and no outlines.'];
                end
            end

            % -- what will happen anyway but should be seen -------------
            nInFile = ndi.gui.app.GeneIngest.field(gefMeta,'nGenesInFile',numel(geneID));
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
            src = ndi.gui.app.GeneIngest.field(gefMeta,'boxSource','');
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
            if isempty(ndi.gui.app.GeneIngest.field(choices,'genomeAssembly',''))
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
            plan.steps = ndi.gui.app.GeneIngest.addStep(plan.steps, ...
                'geneList', sprintf('gene list of %d genes', numel(geneID)), ...
                struct('genomeAssembly', choices.genomeAssembly, ...
                       'annotationSource', choices.annotationSource, ...
                       'label', choices.label));
            plan.steps = ndi.gui.app.GeneIngest.addStep(plan.steps, ...
                'pyramid', sprintf('pyramid, %d level(s), %dx%d tiles', ...
                    numel(bs), choices.grid, choices.grid), ...
                struct('binSizes', bs, 'grid', choices.grid, ...
                       'subjectID', choices.subjectID, ...
                       'basePixelSize', choices.basePixelSize, ...
                       'label', choices.label, 'assay', choices.assay, ...
                       'chipSerial', choices.chipSerial));
            if wantCells
                n = ndi.gui.app.GeneIngest.field(cellbinMeta,'nCells',NaN);
                plan.steps = ndi.gui.app.GeneIngest.addStep(plan.steps, ...
                    'cells', sprintf('cells, %s of them', ...
                        ndi.gui.app.GeneIngest.comma(n)), ...
                    struct('contourReference', choices.contourReference, ...
                           'segmentationMethod', choices.segmentationMethod, ...
                           'obsColumns', {choices.obsColumns}, ...
                           'subjectID', choices.subjectID, ...
                           'label', choices.label));
                for i = 1:numel(sel)
                    plan.steps = ndi.gui.app.GeneIngest.addStep(plan.steps, ...
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
                    ndi.gui.app.GeneIngest.bullets(plan.errors));
                return;
            end
            lines = cell(numel(plan.steps),1);
            for i = 1:numel(plan.steps)
                lines{i} = plan.steps(i).description;
            end
            msg = sprintf('This creates:\n\n%s', ...
                ndi.gui.app.GeneIngest.bullets(lines));
            if ~isempty(plan.warnings)
                msg = sprintf('%s\n\nWorth knowing:\n\n%s', msg, ...
                    ndi.gui.app.GeneIngest.bullets(plan.warnings));
            end
            msg = sprintf(['%s\n\nReading the records takes minutes on a ' ...
                'real section.'], msg);
        end

        function result = runIngest(session, gefPath, cellbinPath, plan, progressFcn)
        % RUNINGEST - execute a plan, in dependency order
        %
        %   RESULT = ndi.gui.app.GeneIngest.RUNINGEST(SESSION, GEFPATH, ...
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
                error('NDI:GeneIngest:planHasErrors', ...
                    'This plan cannot run:\n%s', ...
                    ndi.gui.app.GeneIngest.bullets(plan.errors));
            end

            result = struct('geneListDoc',[],'pyrDoc',[],'tileDocs',{{}}, ...
                'cellsDoc',[],'labelDocs',{{}},'notes',{{}});
            n = numel(plan.steps);

            % -- the GEF, read once -------------------------------------
            % Every step below is fed from this one read. The gene list and
            % the pyramid both need it and it is the expensive thing, so it
            % happens here rather than inside either maker.
            ndi.gui.app.GeneIngest.tick(progressFcn, 0, n, 'Reading the GEF...');
            maxGenes = ndi.gui.app.GeneIngest.field(plan.choices,'maxGenes',0);
            [x, y, geneIndex, count, geneID, geneName, gefMeta] = ...
                ndr.format.stereoseq.readGEF(gefPath, 'maxGenes', maxGenes);
            result.notes = ndi.gui.app.GeneIngest.readNotes(gefMeta, geneID);

            for i = 1:n
                step = plan.steps(i);
                ndi.gui.app.GeneIngest.tick(progressFcn, i-1, n, step.description);
                switch step.kind
                    case 'geneList'
                        nv = ndi.gui.app.GeneIngest.nameValue(step.args, ...
                            {'genomeAssembly','annotationSource','label'});
                        result.geneListDoc = ndi.fun.doc.gene.makeGeneList( ...
                            session, geneID, geneName, nv{:});
                    case 'pyramid'
                        nv = ndi.gui.app.GeneIngest.nameValue(step.args, ...
                            {'binSizes','grid','subjectID','basePixelSize', ...
                             'label','assay','chipSerial'});
                        [result.pyrDoc, result.tileDocs] = ...
                            ndi.fun.doc.gene.makePyramid(session, ...
                                double(x(:)), double(y(:)), ...
                                double(geneIndex(:)), double(count(:)), ...
                                result.geneListDoc, nv{:});
                    case 'cells'
                        result = ndi.gui.app.GeneIngest.runCellsStep( ...
                            session, cellbinPath, step, plan, result);
                    case 'labels'
                        % The values were read with the cells, in the same
                        % pass, because reading the file twice risks the two
                        % reads disagreeing about row order -- and a label
                        % array that is off by one row is still a valid set
                        % of labels.
                        fn = matlab.lang.makeValidName(step.args.labelName);
                        labels = result.labelValues.(fn);
                        d = ndi.fun.doc.gene.makeCellTypeLabels(session, ...
                            labels, result.cellsDoc, ...
                            'isUnsupervised', step.args.isUnsupervised, ...
                            'labelName', step.args.labelName);
                        result.labelDocs{end+1} = d;
                end
            end
            ndi.gui.app.GeneIngest.tick(progressFcn, n, n, 'Done.');
            if isfield(result,'labelValues')
                result = rmfield(result, 'labelValues');
            end
        end

        function notes = readNotes(gefMeta, geneID)
        % READNOTES - what the full read found that a probe could not
        %
        %   These are checks that need every record, so they cannot be part
        %   of the confirmation screen and are reported afterwards instead.
        %   They are reported rather than raised: none of them makes the
        %   pyramid wrong, and all of them change what it means.
            notes = {};
            nClamped = ndi.gui.app.GeneIngest.field(gefMeta,'nCountsClamped',0);
            if nClamped > 0
                notes{end+1} = sprintf(['%s count(s) were clamped at the ' ...
                    'ceiling. Those pixels read low.'], ...
                    ndi.gui.app.GeneIngest.comma(nClamped));
            end
            src = ndi.gui.app.GeneIngest.field(gefMeta,'boxSource','');
            if ~isempty(src)
                notes{end+1} = sprintf('Extent taken from %s.', src);
            end
            % SAW computes its own per-gene MID totals. Agreeing with the
            % instrument vendor's count is a stronger check than the two
            % ports agreeing with each other, which only shows they made
            % the same choices.
            if isfield(gefMeta,'statTotals') && ~isempty(gefMeta.statTotals)
                note = ndi.gui.app.GeneIngest.field(gefMeta,'statTotalsNote','');
                if ~isempty(note)
                    notes{end+1} = sprintf('SAW /stat/gene: %s', note);
                end
            end
            if isempty(geneID)
                notes{end+1} = 'The read returned no genes.';
            end
            notes = notes(:);
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
                numel(geneID), ndi.gui.app.GeneIngest.comma(meta.nRecords), ...
                ext, ndi.gui.app.GeneIngest.orNone(meta.chipSerial), ...
                meta.resolutionNm, meta.root, meta.boxSource);
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
        % One read of the cellbin file serves the cells AND every labeling.
        %
        % Reading it once per document would be simpler to write and is the
        % wrong shape: readCellBin returns cells in file order and labels in
        % file order, and the only thing tying a label array to a cell table
        % is that they came from the same pass. Two passes that disagreed
        % about row order -- a column added, a filter applied, anything --
        % would produce a label array that is still entirely valid and
        % entirely wrong.
            sel = ndi.gui.app.GeneIngest.field(plan.choices,'labelSelections', ...
                struct('name',{},'isUnsupervised',{}));
            wanted = ndi.gui.app.GeneIngest.field(step.args,'obsColumns',{});
            for i = 1:numel(sel)
                if ~ismember(sel(i).name, wanted)
                    wanted{end+1} = sel(i).name; %#ok<AGROW>
                end
            end
            [cellID, cx, cy, contours, obs, cbMeta] = ...
                ndr.format.stereoseq.readCellBin(cellbinPath, ...
                    'contourReference', step.args.contourReference, ...
                    'obsColumns', wanted);

            nv = ndi.gui.app.GeneIngest.nameValue(step.args, ...
                {'segmentationMethod','subjectID','label'});
            % The NUMERIC columns become extra columns of cells.tsv; the
            % label columns do not, because a labeling gets its own
            % document. Both were requested in the one read above.
            numericWanted = setdiff(wanted, {sel.name}, 'stable');
            extra = table();
            for i = 1:numel(numericWanted)
                fn = matlab.lang.makeValidName(numericWanted{i});
                extra.(fn) = obs.(fn)(:);
            end
            % contourReference on the DOCUMENT must be what the reader
            % actually concluded, not what the user asked for: 'auto' is a
            % request, and cbMeta.contourReference is the answer.
            result.cellsDoc = ndi.fun.doc.gene.makeCells(session, ...
                cellID, cx, cy, result.pyrDoc, nv{:}, ...
                'contours', contours, 'extra', extra, ...
                'contourReference', cbMeta.contourReference);

            result.notes{end+1} = sprintf( ...
                'Contours read as %s (%s).', cbMeta.contourReference, ...
                cbMeta.contourReferenceSource);
            % Keep the label values from THIS pass for the label steps.
            result.labelValues = struct();
            for i = 1:numel(sel)
                fn = matlab.lang.makeValidName(sel(i).name);
                result.labelValues.(fn) = obs.(fn);
                nUnlabeled = sum(strcmp(obs.(fn), ''));
                if nUnlabeled > 0
                    result.notes{end+1} = sprintf(['%s leaves %d cell(s) ' ...
                        'unlabeled.'], sel(i).name, nUnlabeled); %#ok<AGROW>
                end
            end
        end

        function subj = subjectChoices(session)
        % The session's subjects, as id plus something a human recognises.
        % Presented by local_identifier rather than by document id: a
        % subject is chosen by a person who knows the animal, not the hash.
            docs = session.database_search(ndi.query('','isa','subject'));
            subj = struct('id',{},'label',{});
            for i = 1:numel(docs)
                k = numel(subj) + 1;
                subj(k).id = docs{i}.id();
                lbl = '';
                try
                    lbl = char(docs{i}.document_properties.subject.local_identifier);
                catch
                    lbl = '';
                end
                if isempty(lbl), lbl = subj(k).id; end
                subj(k).label = lbl;
            end
        end

        function driveDialog(d, frac, txt)
            if isempty(d) || ~isvalid(d), return; end
            d.Value = frac;
            d.Message = txt;
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

        function nv = nameValue(args, keep)
        % Turn a step's args struct into a name-value list, dropping the
        % fields the maker does not take. The plan carries a few fields for
        % the confirmation text that are not arguments to anything.
            nv = {};
            f = fieldnames(args);
            for i = 1:numel(f)
                if ~ismember(f{i}, keep), continue; end
                nv{end+1} = f{i};        %#ok<AGROW>
                nv{end+1} = args.(f{i}); %#ok<AGROW>
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
            obj.fig = uifigure('Name','Gene Ingest','Position',[100 100 900 420]);
            g = uigridlayout(obj.fig,[3 4]);
            g.RowHeight = {'1x', 30, 22};
            g.ColumnWidth = {'1x', 90, 90, 90};

            obj.table = uitable(g, 'ColumnName', ...
                {'Label','Subject','Assay','Chip','Genes','Levels','Cells','Label sets'});
            obj.table.Layout.Row = 1; obj.table.Layout.Column = [1 4];

            b = uibutton(g,'Text','Reload','ButtonPushedFcn',@(~,~) obj.reload());
            b.Layout.Row = 2; b.Layout.Column = 2;
            b = uibutton(g,'Text','Add...','ButtonPushedFcn',@(~,~) obj.onAdd());
            b.Layout.Row = 2; b.Layout.Column = 3;
            b = uibutton(g,'Text','Delete','ButtonPushedFcn',@(~,~) obj.onDelete());
            b.Layout.Row = 2; b.Layout.Column = 4;

            obj.statusLabel = uilabel(g,'Text','');
            obj.statusLabel.Layout.Row = 3; obj.statusLabel.Layout.Column = [1 4];
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

        function onDelete(obj)
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            plan = ndi.gui.app.GeneIngest.deletionPlan(obj.session, r.doc);
            choice = uiconfirm(obj.fig, ...
                ndi.gui.app.GeneIngest.deletionMessage(plan), 'Confirm delete', ...
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

            plan = ndi.gui.app.GeneIngest.ingestPlan(gefMeta, geneID, cbMeta, choices);
            msg = ndi.gui.app.GeneIngest.ingestMessage(plan);
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
                result = ndi.gui.app.GeneIngest.runIngest(obj.session, ...
                    gefPath, cellbinPath, plan, ...
                    @(frac,txt) ndi.gui.app.GeneIngest.driveDialog(d, frac, txt));
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
                    ndi.gui.app.GeneIngest.bullets(result.notes)), 'Done', ...
                    'Icon','success');
            end
            obj.reload();
        end

        function choices = askChoices(obj, gefMeta, geneID, cbMeta)
        % The confirmation screen. Shows what was READ, what was INFERRED
        % and the evidence behind each inference, and asks for the one
        % thing the files cannot supply: the subject.
            choices = [];
            defaults = ndi.gui.app.GeneIngest.ingestChoices(gefMeta, cbMeta);

            text = sprintf('%s\n\n', ...
                ndi.gui.app.GeneIngest.summarizeGef(gefMeta, geneID));
            if ~isempty(cbMeta)
                items = ndi.gui.app.GeneIngest.contourFindings(cbMeta);
                text = sprintf('%sCells: %d\n', text, cbMeta.nCells);
                for i = 1:numel(items)
                    text = sprintf('%s  %s: %s  [%s]\n', text, ...
                        items(i).name, items(i).value, items(i).evidence);
                end
            end
            uialert(obj.fig, text, 'What these files contain', 'Icon','info');

            subj = ndi.gui.app.GeneIngest.subjectChoices(obj.session);
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
                lf = ndi.gui.app.GeneIngest.labelFindings(cbMeta);
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
