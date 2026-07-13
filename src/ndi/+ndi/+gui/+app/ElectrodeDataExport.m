classdef ElectrodeDataExport < ndi.gui.app.sessionApp
% NDI.GUI.APP.ELECTRODEDATAEXPORT - export probe data for spike sorters
%
%   OBJ = ndi.gui.app.ElectrodeDataExport(SESSION)
%
%   Opens a window for exporting the n-trode probes of the ndi.session SESSION to
%   the flat int16 format used by spike sorters (Kilosort / KIASORT).
%
%   The window (in the NDI Cloud colour scheme) has a title, a multi-select list of
%   the session's n-trode probes - each showing, in parentheses, the spike sorters
%   it has already been exported for (blank if none) - and, at the bottom, an
%   "Export To:" dropdown of the supported sorters plus an Export button. Selecting
%   one or more probes and a sorter and clicking Export writes each probe's binary
%   and a Kilosort-style channel map (built from the probe's assigned electrode
%   geometry) into the sorter's folder.
%
%   Electrode geometry is not required to export, but if any selected probe has no
%   geometry the app warns first: its channel map would be a default single-column
%   linear layout (usually wrong for real arrays). Assign geometries with
%   ndi.gui.app.ElectrodeMap.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor takes
%   the ndi.session as its first argument, so it can be launched from the
%   ndi.gui.navigator "Apps" menu.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.ElectrodeMap,
%             ndi.fun.probe.export.oneProbe, ndi.fun.probe.export.all_binary

    properties (Constant)
        Name = "Electrode Data Export"   % ndi.gui.app.sessionApp menu label
    end

    properties (Access = private)
        session                 % the ndi.session being exported
        fig                     % the uifigure
        ProbeList               % multi-select uilistbox of n-trode probes
        ExportDropdown          % "Export To:" dropdown of sorter names
        ExportButton            % the Export button
        probes = {}             % cell array of the session's n-trode probes
        exporters               % struct array: name, dir, bin (per supported sorter)
    end

    methods
        function obj = ElectrodeDataExport(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            % Supported export targets. Each writes the same flat int16 binary and a
            % Kilosort-style channel_map.mat, into its own folder, so a probe can be
            % exported independently for each. Add rows here to support more sorters.
            obj.exporters = struct( ...
                'name', {'KIASORT', 'Kilosort'}, ...
                'dir',  {'kiasort', 'kilosort'}, ...
                'bin',  {'kiasort.bin', 'kilosort.bin'});
            obj.build();
        end
    end

    methods (Access = private)
        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Electrode Data Export: ' obj.session.reference], ...
                'Position', [100 100 620 460], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.ElectrodeDataExport');

            root = uigridlayout(obj.fig, [4 1], ...
                'RowHeight', {30, 20, '1x', 44}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [10 10 10 10], ...
                'BackgroundColor', c.darkBlue);

            % Title
            title = uilabel(root, 'Text', 'Export Electrode Data for Spike Sorting', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            % List header
            header = uilabel(root, 'Text', 'n-trode Probes (exported for):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            header.Layout.Row = 2; header.Layout.Column = 1;

            % Multi-select probe list
            obj.ProbeList = uilistbox(root, 'Items', {}, 'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.ProbeList.Layout.Row = 3; obj.ProbeList.Layout.Column = 1;

            % Bottom controls: [ "Export To:"  dropdown  <spacer>  Export ]
            bottom = uigridlayout(root, [1 4], ...
                'ColumnWidth', {75, 180, '1x', 130}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            bottom.Layout.Row = 4; bottom.Layout.Column = 1;

            exportLabel = uilabel(bottom, 'Text', 'Export To:', ...
                'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'center');
            exportLabel.Layout.Row = 1; exportLabel.Layout.Column = 1;

            obj.ExportDropdown = uidropdown(bottom, 'Items', {obj.exporters.name}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.ExportDropdown.Layout.Row = 1; obj.ExportDropdown.Layout.Column = 2;

            obj.ExportButton = uibutton(bottom, 'push', 'Text', 'Export', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Enable', 'off', 'ButtonPushedFcn', @(~,~) obj.doExport());
            obj.ExportButton.Layout.Row = 1; obj.ExportButton.Layout.Column = 4;

            obj.loadProbes();
            obj.refreshProbeList();
            obj.updateButtonState();
        end

        function loadProbes(obj)
            % Collect the session's n-trode probes.
            try
                obj.probes = obj.session.getprobes('type', 'n-trode');
            catch
                obj.probes = {};
            end
            if ~iscell(obj.probes)
                obj.probes = {};
            end
        end

        function refreshProbeList(obj)
            % Rebuild the probe list, showing the sorters each probe is already
            % exported for in parentheses. Preserves the current multi-selection.
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                label = char(p.elementstring());
                done = obj.exportedSorters(p);
                if ~isempty(done)
                    label = [label ' (' strjoin(done, ', ') ')']; %#ok<AGROW>
                end
                items{i} = label;
            end

            prev = obj.ProbeList.Value;   % array of previously selected indices
            if isempty(items)
                obj.ProbeList.Items = {};
                obj.ProbeList.ItemsData = [];
            else
                obj.ProbeList.Items = items;
                obj.ProbeList.ItemsData = 1:n;
                if ~isempty(prev)
                    keep = prev(prev >= 1 & prev <= n);
                    obj.ProbeList.Value = keep;
                end
            end
            obj.updateButtonState();
        end

        function names = exportedSorters(obj, probe)
            % Names of the sorters PROBE has already been exported for (its binary
            % file exists in that sorter's folder).
            elestr = char(probe.elementstring());
            elestr(elestr == ' ') = '_';
            names = {};
            for i = 1:numel(obj.exporters)
                ex = obj.exporters(i);
                if isfile(fullfile(obj.session.path, ex.dir, elestr, ex.bin))
                    names{end+1} = ex.name; %#ok<AGROW>
                end
            end
        end

        function updateButtonState(obj)
            % Export enabled only when at least one probe and a sorter are selected.
            hasProbe = ~isempty(obj.ProbeList.Value);
            hasSorter = ~isempty(obj.ExportDropdown.Items) && ~isempty(obj.ExportDropdown.Value);
            obj.ExportButton.Enable = onOff(hasProbe && hasSorter);
        end

        function ex = exporterByName(obj, name)
            idx = find(strcmp({obj.exporters.name}, name), 1);
            ex = obj.exporters(idx);
        end

        function doExport(obj)
            sel = obj.ProbeList.Value;   % array of probe indices
            if isempty(sel)
                return;
            end
            sel = sel(:).';
            ex = obj.exporterByName(obj.ExportDropdown.Value);

            % Warn about selected probes that have no electrode geometry.
            missing = {};
            for k = 1:numel(sel)
                p = obj.probes{sel(k)};
                G = ndi.fun.probe.geometry.get(obj.session, p);
                if ~G.found
                    missing{end+1} = char(p.elementstring()); %#ok<AGROW>
                end
            end
            if ~isempty(missing)
                msg = sprintf(['%d of the selected probe(s) have no electrode geometry ' ...
                    'assigned:\n    %s\n\nTheir channel map will be a default single-column ' ...
                    'linear layout, which is usually wrong for real arrays. You can assign ' ...
                    'geometries first with the Electrode Map app.\n\nExport anyway?'], ...
                    numel(missing), strjoin(missing, ', '));
                choice = uiconfirm(obj.fig, msg, 'Missing electrode geometry', ...
                    'Options', {'Export anyway', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(choice, 'Export anyway')
                    return;
                end
            end

            % Export each selected probe.
            obj.ExportButton.Enable = 'off';
            drawnow;
            errs = {};
            for k = 1:numel(sel)
                p = obj.probes{sel(k)};
                try
                    ndi.fun.probe.export.oneProbe(obj.session, p, ...
                        'binary_dir', ex.dir, 'binaryFileName', ex.bin, 'verbose', 0);
                catch e
                    errs{end+1} = sprintf('%s: %s', char(p.elementstring()), e.message); %#ok<AGROW>
                end
            end
            obj.ExportButton.Enable = 'on';

            obj.refreshProbeList();

            if ~isempty(errs)
                uialert(obj.fig, strjoin(errs, newline), 'Some exports failed');
            else
                uialert(obj.fig, sprintf('Exported %d probe(s) for %s.', numel(sel), ex.name), ...
                    'Export complete', 'Icon', 'success');
            end
        end
    end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
