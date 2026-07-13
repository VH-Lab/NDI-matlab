classdef spikeSorterImporter < ndi.gui.app.sessionApp
% NDI.GUI.APP.SPIKESORTERIMPORTER - GUI to import spike-sorter output into NDI
%
%   OBJ = NDI.GUI.APP.SPIKESORTERIMPORTER(S)
%
%   Opens a window for importing curated spike-sorter (Kilosort/Phy) output into
%   the ndi.session S and for viewing the extracellular neurons that have already
%   been imported. The window is resizable (initially 600x600) and has three
%   regions for a chosen n-trode probe:
%
%     * Left  ("Session neurons")  - the neuron_extracellular documents already
%                                     in the database for the selected probe
%                                     (via ndi.fun.probe.extracellularInfo),
%                                     listed as: name | quality | pipeline.
%                                     Supports multi-select; Reload re-reads the
%                                     database and Delete removes the selected
%                                     neurons (with a warning). A "Filter by
%                                     pipeline" checkbox restricts the list to
%                                     the pipeline chosen on the right.
%     * Middle ("import")          - a "Tags to import" listbox (the curation
%                                     tags found on the right) and a
%                                     "<- import <-" button that imports the
%                                     whole sort, keeping clusters whose tag is
%                                     selected.
%     * Right ("Pipeline Neurons") - the clusters detected on disk for the
%                                     selected probe and pipeline (via
%                                     ndi.fun.probe.import.kilosort.getInfo),
%                                     listed as: cluster | tag | #spikes. A
%                                     pipeline selector sits above it (currently
%                                     only "Kilosort 2.5").
%
%   Example:
%       S = ndi.session.dir('/path/to/session');
%       ndi.gui.app.spikeSorterImporter(S);
%
%   See also: NDI.FUN.PROBE.EXTRACELLULARINFO,
%   NDI.FUN.PROBE.IMPORT.KILOSORT.GETINFO, NDI.FUN.PROBE.IMPORT.KILOSORT.PROBE

    properties (Constant)
        Name = "spikeSorterImporter"   % ndi.gui.app.sessionApp menu label
    end

    properties
        session            % the ndi.session being browsed
        fig                % the uifigure

        % widgets
        probeDropdown      % popup of n-trode probes
        sessionList        % left listbox (imported neurons)
        pipelineList       % right listbox (detected clusters)
        tagList            % middle listbox (tags to import)
        overwriteCheckbox  % "Overwrite existing" (force re-import)
        pipelineSelector   % right popup (pipeline, e.g. Kilosort 2.5)
        filterCheckbox     % "Filter by pipeline"

        % state
        probes = {};       % cell array of n-trode probe objects
        sessionEntries = []; % current (possibly filtered) extracellularInfo result
        pipelineInfo = [];   % current getInfo result
        waitDlg = [];        % active "please wait" dialog (if any)
    end

    methods
        function obj = spikeSorterImporter(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.buildUI();
            % loading the session's neurons can take a moment, so show a
            % "please wait" indicator over the initial load
            obj.withWait('Loading session neurons...', @() obj.reloadProbes());
        end % constructor
    end

    methods (Access = private)

        function buildUI(obj)
            fixedFont = get(groot,'FixedWidthFontName');

            obj.fig = uifigure('Name','NDI Spike Sorter Importer', ...
                'Position',[100 100 600 600]);

            main = uigridlayout(obj.fig,[4 1]);
            main.RowHeight = {28, 22, 32, '1x'};
            main.ColumnWidth = {'1x'};

            % Row 1: title
            t = uilabel(main,'Text','NDI Spike Sorter Importer', ...
                'FontSize',16,'FontWeight','bold','HorizontalAlignment','center');
            t.Layout.Row = 1; t.Layout.Column = 1;

            % Row 2: session reference and path
            sref = obj.session.reference;
            spath = obj.sessionPath();
            s = uilabel(main,'Text',['Session: ' char(sref) '     Path: ' spath], ...
                'HorizontalAlignment','center');
            s.Layout.Row = 2; s.Layout.Column = 1;

            % Row 3: centered probe popup + reload
            prow = uigridlayout(main,[1 5]);
            prow.Layout.Row = 3; prow.Layout.Column = 1;
            prow.ColumnWidth = {'1x','fit',200,'fit','1x'};
            prow.Padding = [0 0 0 0];
            lbl = uilabel(prow,'Text','n-trode probes:','HorizontalAlignment','right');
            lbl.Layout.Column = 2;
            obj.probeDropdown = uidropdown(prow,'Items',{'(none)'},'ItemsData',{}, ...
                'ValueChangedFcn',@(src,evt) obj.onProbeChanged());
            obj.probeDropdown.Layout.Column = 3;
            rb = uibutton(prow,'Text','reload','ButtonPushedFcn', ...
                @(src,evt) obj.withWait('Loading probes...', @() obj.reloadProbes()));
            rb.Layout.Column = 4;

            % Row 4: the three-column content area
            content = uigridlayout(main,[1 3]);
            content.Layout.Row = 4; content.Layout.Column = 1;
            content.ColumnWidth = {'1x',160,'1x'};
            content.Padding = [0 0 0 0];

            % --- Left column: Session neurons ---
            left = uigridlayout(content,[4 1]);
            left.Layout.Column = 1;
            left.RowHeight = {22,'1x',28,24};
            left.Padding = [0 0 0 0];
            uilabel(left,'Text','Session neurons','FontWeight','bold');
            obj.sessionList = uilistbox(left,'Items',{},'Multiselect','on', ...
                'FontName',fixedFont);
            lbtns = uigridlayout(left,[1 2]);
            lbtns.Padding = [0 0 0 0]; lbtns.ColumnWidth = {'1x','1x'};
            uibutton(lbtns,'Text','Reload','ButtonPushedFcn', ...
                @(s,e) obj.withWait('Loading neurons...', @() obj.reloadSessionNeurons()));
            uibutton(lbtns,'Text','Delete','ButtonPushedFcn',@(s,e) obj.onDelete());
            obj.filterCheckbox = uicheckbox(left,'Text','Filter by pipeline', ...
                'ValueChangedFcn',@(s,e) obj.withWait('Loading neurons...', @() obj.reloadSessionNeurons()));

            % --- Middle column: tags + import ---
            middle = uigridlayout(content,[6 1]);
            middle.Layout.Column = 2;
            middle.RowHeight = {'1x',22,100,30,24,'1x'};
            middle.Padding = [0 0 0 0];
            spacerTop = uilabel(middle,'Text',''); spacerTop.Layout.Row = 1;
            tl = uilabel(middle,'Text','Tags to import'); tl.Layout.Row = 2;
            obj.tagList = uilistbox(middle,'Items',{},'Multiselect','on', ...
                'FontName',fixedFont);
            obj.tagList.Layout.Row = 3;
            ib = uibutton(middle,'Text','<- import <-', ...
                'ButtonPushedFcn',@(s,e) obj.onImport());
            ib.Layout.Row = 4;
            obj.overwriteCheckbox = uicheckbox(middle,'Text','Overwrite existing', ...
                'Tooltip','Re-import from disk, replacing any neurons already imported for this sort');
            obj.overwriteCheckbox.Layout.Row = 5;
            spacerBot = uilabel(middle,'Text',''); spacerBot.Layout.Row = 6;

            % --- Right column: Pipeline Neurons ---
            right = uigridlayout(content,[5 1]);
            right.Layout.Column = 3;
            right.RowHeight = {28,22,18,'1x',30};
            right.Padding = [0 0 0 0];
            right.RowSpacing = 2;
            % pipeline selector row
            psel = uigridlayout(right,[1 2]);
            psel.Layout.Row = 1; psel.Padding = [0 0 0 0];
            psel.ColumnWidth = {'fit','1x'};
            uilabel(psel,'Text','Pipeline:','HorizontalAlignment','right');
            obj.pipelineSelector = uidropdown(psel,'Items',{'Kilosort 2.5'}, ...
                'ValueChangedFcn',@(s,e) obj.reloadPipeline());
            pl = uilabel(right,'Text','Pipeline Neurons','FontWeight','bold');
            pl.Layout.Row = 2;
            % little column header right above the listbox
            ph = uilabel(right,'Text',sprintf('%5s | %-8s | %7s','clust','tag','#spikes'), ...
                'FontName',fixedFont,'FontWeight','bold');
            ph.Layout.Row = 3;
            obj.pipelineList = uilistbox(right,'Items',{},'Multiselect','on', ...
                'FontName',fixedFont);
            obj.pipelineList.Layout.Row = 4;
            % Row 5 deliberately left empty: reserved space for a future button.
        end % buildUI

        function p = sessionPath(obj)
            % best-effort session path for display
            p = '';
            try
                if ismethod(obj.session,'getpath'),
                    p = obj.session.getpath();
                elseif isprop(obj.session,'path'),
                    p = obj.session.path;
                end;
            catch
                p = '';
            end;
        end % sessionPath

        function p = selectedProbe(obj)
            % return the currently selected probe object, or [] if none
            p = [];
            idx = obj.probeDropdown.Value;
            if isempty(idx) || ~isnumeric(idx), return; end;
            if idx>=1 && idx<=numel(obj.probes),
                p = obj.probes{idx};
            end;
        end % selectedProbe

        function reloadProbes(obj)
            obj.probes = obj.session.getprobes('type','n-trode');
            if isempty(obj.probes),
                obj.probeDropdown.Items = {'(no n-trode probes)'};
                obj.probeDropdown.ItemsData = {};
                obj.clearSessionList();
                obj.clearPipelineList();
                return;
            end;
            labels = cell(1,numel(obj.probes));
            for i=1:numel(obj.probes),
                labels{i} = [obj.probes{i}.name ' | ref ' num2str(obj.probes{i}.reference)];
            end;
            obj.probeDropdown.Items = labels;
            obj.probeDropdown.ItemsData = 1:numel(obj.probes);
            obj.probeDropdown.Value = 1;
            obj.onProbeChanged();
        end % reloadProbes

        function onProbeChanged(obj)
            obj.withWait('Loading neurons...', @() obj.reloadProbeData());
        end % onProbeChanged

        function reloadProbeData(obj)
            obj.reloadPipeline();      % refresh tags first so a filter has them
            obj.reloadSessionNeurons();
        end % reloadProbeData

        function withWait(obj, msg, fn)
            % run FN while showing an indeterminate "please wait" dialog. Safe to
            % nest: an inner call reuses the dialog created by the outer call.
            nested = ~isempty(obj.waitDlg) && isvalid(obj.waitDlg);
            cleaner = []; %#ok<NASGU>
            if ~nested && ~isempty(obj.fig) && isvalid(obj.fig),
                obj.waitDlg = uiprogressdlg(obj.fig,'Title','Please wait', ...
                    'Message',msg,'Indeterminate','on');
                cleaner = onCleanup(@() obj.clearWait()); % always remove the dialog
            end;
            fn();
        end % withWait

        function clearWait(obj)
            if ~isempty(obj.waitDlg) && isvalid(obj.waitDlg),
                delete(obj.waitDlg);
            end;
            obj.waitDlg = [];
        end % clearWait

        function reloadSessionNeurons(obj)
            p = obj.selectedProbe();
            if isempty(p),
                obj.clearSessionList();
                return;
            end;
            entries = ndi.fun.probe.extracellularInfo(obj.session, p);
            if obj.filterCheckbox.Value && ~isempty(entries),
                key = obj.pipelineKey();
                keep = arrayfun(@(e) contains(e.pipeline, key), entries);
                entries = entries(keep);
            end;
            obj.sessionEntries = entries;
            items = cell(1,numel(entries));
            for i=1:numel(entries),
                items{i} = sprintf('%-18s | %-8s | %s', entries(i).element_name, ...
                    entries(i).quality_label, entries(i).pipeline);
            end;
            obj.sessionList.Items = items;
            if isempty(items),
                obj.sessionList.ItemsData = {};
            else,
                obj.sessionList.ItemsData = 1:numel(items);
                obj.sessionList.Value = obj.sessionList.ItemsData([]); % clear selection
            end;
        end % reloadSessionNeurons

        function reloadPipeline(obj)
            p = obj.selectedProbe();
            if isempty(p),
                obj.clearPipelineList();
                return;
            end;
            try
                info = ndi.fun.probe.import.kilosort.getInfo(obj.session, p);
            catch ME
                obj.pipelineInfo = [];
                obj.pipelineList.Items = {['(no Kilosort output: ' ME.message ')']};
                obj.pipelineList.ItemsData = {};
                obj.tagList.Items = {};
                obj.tagList.ItemsData = {};
                return;
            end;
            obj.pipelineInfo = info;
            n = info.num_clusters;
            items = cell(1,n);
            for i=1:n,
                items{i} = sprintf('%5d | %-8s | %7d', info.cluster_ids(i), ...
                    char(info.cluster_labels(i)), info.num_spikes(i));
            end;
            obj.pipelineList.Items = items;
            if isempty(items),
                obj.pipelineList.ItemsData = {};
            else,
                obj.pipelineList.ItemsData = info.cluster_ids(:)';
                obj.pipelineList.Value = obj.pipelineList.ItemsData([]);
            end;
            % populate the tags-to-import list
            tags = cellstr(info.unique_tags(:)');
            obj.tagList.Items = tags;
            obj.tagList.ItemsData = tags;
            % default to the importer defaults that are present
            defaults = intersect(lower(tags), {'good','mua'});
            sel = tags(ismember(lower(tags), defaults));
            obj.tagList.Value = sel;
        end % reloadPipeline

        function onImport(obj)
            p = obj.selectedProbe();
            if isempty(p),
                uialert(obj.fig,'Select an n-trode probe first.','No probe');
                return;
            end;
            tags = obj.tagList.Value;
            if ischar(tags), tags = {tags}; end;
            if isempty(tags),
                uialert(obj.fig,'Select at least one tag to import.','No tags selected');
                return;
            end;
            qv = obj.qualityValuesFor(tags);
            overwrite = obj.overwriteCheckbox.Value;
            msg = sprintf(['Import the %s sort for probe "%s", keeping clusters ' ...
                'tagged [%s]?'], obj.pipelineSelector.Value, p.elementstring(), ...
                strjoin(tags,', '));
            if overwrite,
                msg = [msg char(10) char(10) 'Overwrite is on: any neurons already ' ...
                    'imported for this sort will be removed and re-imported from disk.'];
            end;
            choice = uiconfirm(obj.fig, msg, 'Confirm import', ...
                'Options',{'Import','Cancel'},'DefaultOption',2,'CancelOption',2);
            if ~strcmp(choice,'Import'), return; end;
            % clear any orphaned provenance marker (e.g. left by a prior delete)
            % so the importer's checksum guard does not refuse to re-import
            obj.cleanupOrphanClusters(p);
            try
                ndi.fun.probe.import.kilosort.probe(obj.session, p, ...
                    'quality_labels', string(tags), 'quality_values', qv, ...
                    'kilosort_version','2.5','force',double(overwrite), ...
                    'progressbar',true,'verbose',0);
            catch ME
                uialert(obj.fig, ME.message, 'Import failed');
                return;
            end;
            uialert(obj.fig,'Import complete.','Done','Icon','success');
            obj.reloadSessionNeurons();
        end % onImport

        function onDelete(obj)
            sel = obj.sessionList.Value;
            if isempty(sel),
                uialert(obj.fig,'Select one or more neurons to delete.','Nothing selected');
                return;
            end;
            entries = obj.sessionEntries(sel);
            names = {entries.element_name};
            msg = sprintf(['Delete %d neuron(s) from the database? This cannot be ' ...
                'undone.\n\n%s'], numel(entries), strjoin(names, ', '));
            choice = uiconfirm(obj.fig, msg, 'Confirm delete', ...
                'Options',{'Delete','Cancel'},'DefaultOption',2,'CancelOption',2, ...
                'Icon','warning');
            if ~strcmp(choice,'Delete'), return; end;
            % "please wait" indicator (deletion can still take a moment)
            dlg = uiprogressdlg(obj.fig,'Title','Please wait', ...
                'Message',sprintf('Deleting %d neuron(s)...',numel(entries)), ...
                'Indeterminate','on');
            closeDlg = onCleanup(@() delete(dlg)); % always remove the dialog
            % element_id is captured when the list is loaded; deleting the
            % element documents cascades to their dependents (the
            % neuron_extracellular and epoch documents). One database_rm call
            % handles the whole batch (it does a single lookup internally).
            ids = {entries.element_id};
            ids = ids(~cellfun(@isempty,ids));
            if ~isempty(ids),
                obj.session.database_rm(ids);
            end;
            % If a sort no longer has any neurons, remove its now-orphaned
            % kilosort_clusters provenance document; otherwise the importer's
            % checksum guard would consider the sort still imported and refuse
            % to re-import it ("nothing to do").
            obj.cleanupOrphanClusters(obj.selectedProbe());
            obj.reloadSessionNeurons();
        end % onDelete

        function cleanupOrphanClusters(obj, p)
            % remove kilosort_clusters documents for probe P that have no
            % remaining dependent neuron_extracellular documents
            if isempty(p), return; end;
            q = ndi.query('','isa','kilosort_clusters','') & ...
                ndi.query('','depends_on','element_id',p.id());
            kcs = obj.session.database_search(q);
            for i=1:numel(kcs),
                qn = ndi.query('','isa','neuron_extracellular','') & ...
                    ndi.query('','depends_on','spike_clusters_id',kcs{i}.id());
                remaining = obj.session.database_search(qn);
                if isempty(remaining),
                    obj.session.database_rm(kcs{i});
                end;
            end;
        end % cleanupOrphanClusters

        function key = pipelineKey(obj)
            % a substring used to match a stored pipeline string to the selected
            % pipeline (e.g. "Kilosort 2.5" -> "Kilosort2.5", which appears in
            % "Kilosort2.5 to phy to ndi.fun.probe.import.kilosort").
            key = regexprep(obj.pipelineSelector.Value,'\s','');
        end % pipelineKey

        function clearSessionList(obj)
            obj.sessionEntries = [];
            obj.sessionList.Items = {};
            obj.sessionList.ItemsData = {};
        end % clearSessionList

        function clearPipelineList(obj)
            obj.pipelineInfo = [];
            obj.pipelineList.Items = {};
            obj.pipelineList.ItemsData = {};
            obj.tagList.Items = {};
            obj.tagList.ItemsData = {};
        end % clearPipelineList

    end

    methods (Static, Access = private)
        function qv = qualityValuesFor(tags)
            % assign a numeric quality_number to each tag, following the
            % importer convention single/good=1, multi/mua=4, unknown=4.
            qv = zeros(1,numel(tags));
            for i=1:numel(tags),
                switch lower(tags{i}),
                    case {'good','single'}, qv(i) = 1;
                    otherwise,              qv(i) = 4;
                end;
            end;
        end % qualityValuesFor
    end

end % classdef
