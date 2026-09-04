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

        function s = summarizeGef(meta, geneID)
        % SUMMARIZEGEF - what a .gef contains, from a probe alone
            s = sprintf(['%d genes, %s records\nextent %d x %d (origin %d,%d)\n' ...
                'chip %s, resolution %g nm\nlayout %s, extent from %s'], ...
                numel(geneID), ndi.gui.app.GeneIngest.comma(meta.nRecords), ...
                meta.box(3)-meta.box(1)+1, meta.box(4)-meta.box(2)+1, ...
                meta.box(1), meta.box(2), ...
                ndi.gui.app.GeneIngest.orNone(meta.chipSerial), ...
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
            obj.setStatus('Probing...');
            drawnow;
            try
                % probeOnly: this must not read 10^8 records to show a summary.
                [~,~,~,~,geneID,~,meta] = ndr.format.stereoseq.readGEF( ...
                    gefPath, 'probeOnly', true);
            catch ME
                uialert(obj.fig, ME.message, 'Could not read that GEF');
                obj.setStatus('');
                return;
            end
            uialert(obj.fig, ndi.gui.app.GeneIngest.summarizeGef(meta, geneID), ...
                'GEF contents', 'Icon','info');
            obj.setStatus('Probed. Ingestion from the GUI is not wired up yet.');
        end
    end
end
