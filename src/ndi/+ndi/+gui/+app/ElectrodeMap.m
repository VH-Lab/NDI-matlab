classdef ElectrodeMap < ndi.gui.app.sessionApp
% NDI.GUI.APP.ELECTRODEMAP - assign electrode geometries to probes
%
%   OBJ = ndi.gui.app.ElectrodeMap(SESSION)
%
%   Opens a window for assigning electrode geometries (from the NDI library,
%   ndi.fun.probe.geometry.listLibrary) to the n-trode probes of the
%   ndi.session SESSION.
%
%   The window (in the NDI Cloud colour scheme) has a title at the top and,
%   below it, two lists. On the left are the available electrode geometries,
%   each with its site count in parentheses, and a "Plot geometry" button
%   that opens a plot of the selected geometry. On the right are the
%   session's n-trode probes, each with its channel count in parentheses and
%   its currently-assigned geometry in *asterisks* (blank if none). A button
%   between the two, with a left-to-right arrow, is enabled when both a
%   geometry and a probe are selected; clicking it assigns the geometry to
%   the probe and saves the probe_geometry document.
%
%   Selecting a probe that already has a geometry highlights the matching
%   geometry in the left list.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from
%   the ndi.gui.navigator "Apps" menu.
%
%   See also: ndi.gui.app.sessionApp, ndi.fun.probe.geometry.fromLibrary,
%             ndi.fun.probe.geometry.listLibrary, ndi.fun.probe.geometry.plot

    properties (Constant)
        Name = "Electrode Map"   % ndi.gui.app.sessionApp menu label
    end

    properties (Access = private)
        session                 % the ndi.session being edited
        fig                     % the uifigure
        GeometryList            % uilistbox of electrode geometries (left)
        ProbeList               % uilistbox of n-trode probes (right)
        AssignButton            % the assign (->) button
        PlotButton              % the "Plot geometry" button
        probes = {}             % cell array of the session's n-trode probes
        geometryNames = {}      % library geometry names (ItemsData of GeometryList)
        geometryModels = {}     % parallel probe_model of each library geometry
    end

    methods
        function obj = ElectrodeMap(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
        end
    end

    methods (Access = private)
        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Electrode Map: ' obj.session.reference], ...
                'Position', [100 100 680 480], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.ElectrodeMap');

            root = uigridlayout(obj.fig, [2 1], ...
                'RowHeight', {36, '1x'}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [10 10 10 10], ...
                'BackgroundColor', c.darkBlue);

            % Title (static text)
            title = uilabel(root, 'Text', 'Assign Electrode Geometries to Probes', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            % Body: [geometries + plot] [ -> ] [probes]
            body = uigridlayout(root, [2 3], ...
                'RowHeight', {22, '1x'}, 'ColumnWidth', {'1x', 90, '1x'}, ...
                'RowSpacing', 6, 'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            body.Layout.Row = 2; body.Layout.Column = 1;

            leftHeader = uilabel(body, 'Text', 'Electrode Geometries', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            leftHeader.Layout.Row = 1; leftHeader.Layout.Column = 1;

            rightHeader = uilabel(body, 'Text', 'n-trode Probes', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            rightHeader.Layout.Row = 1; rightHeader.Layout.Column = 3;

            % Left column: geometry list on top, "Plot geometry" button below
            leftG = uigridlayout(body, [2 1], ...
                'RowHeight', {'1x', 30}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 6, 'Padding', [0 0 0 0], 'BackgroundColor', c.darkBlue);
            leftG.Layout.Row = 2; leftG.Layout.Column = 1;

            obj.GeometryList = uilistbox(leftG, 'Items', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.GeometryList.Layout.Row = 1; obj.GeometryList.Layout.Column = 1;

            obj.PlotButton = uibutton(leftG, 'push', 'Text', 'Plot geometry', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Plot the selected electrode geometry', ...
                'ButtonPushedFcn', @(~,~) obj.plotSelectedGeometry());
            obj.PlotButton.Layout.Row = 2; obj.PlotButton.Layout.Column = 1;

            % Center column: arrow button, vertically centered
            centerG = uigridlayout(body, [3 1], ...
                'RowHeight', {'1x', 44, '1x'}, 'ColumnWidth', {'1x'}, ...
                'Padding', [0 0 0 0], 'BackgroundColor', c.darkBlue);
            centerG.Layout.Row = 2; centerG.Layout.Column = 2;

            obj.AssignButton = uibutton(centerG, 'push', 'Text', char(8594), ...
                'FontSize', 22, 'FontWeight', 'bold', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Assign the selected geometry to the selected probe', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.assignSelected());
            obj.AssignButton.Layout.Row = 2; obj.AssignButton.Layout.Column = 1;

            obj.ProbeList = uilistbox(body, 'Items', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onProbeSelected());
            obj.ProbeList.Layout.Row = 2; obj.ProbeList.Layout.Column = 3;

            % Populate
            obj.loadGeometries();
            obj.loadProbes();
            obj.refreshProbeList();
            obj.updateButtonState();
        end

        function loadGeometries(obj)
            % Fill the left list from the electrode-layout library, showing each
            % geometry's site count in parentheses. ItemsData is the raw library
            % name (used for assignment/plotting); a parallel probe_model list is
            % cached so a probe's assigned geometry can be matched back to the list.
            try
                names = ndi.fun.probe.geometry.listLibrary();
            catch
                names = {};
            end
            if ~iscell(names), names = {}; end

            items  = cell(1, numel(names));
            models = cell(1, numel(names));
            for i = 1:numel(names)
                label = names{i};
                models{i} = '';
                try
                    g = ndi.fun.probe.geometry.readLibrary(names{i});
                    if isfield(g, 'site_locations_leftright')
                        label = sprintf('%s (%d)', names{i}, numel(g.site_locations_leftright));
                    end
                    if isfield(g, 'probe_model') && ~isempty(g.probe_model)
                        models{i} = char(g.probe_model);
                    end
                catch
                end
                items{i} = label;
            end

            obj.geometryNames  = names;
            obj.geometryModels = models;
            if isempty(names)
                obj.GeometryList.Items = {};
                obj.GeometryList.ItemsData = {};
            else
                obj.GeometryList.Items = items;
                obj.GeometryList.ItemsData = names;
            end
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
            % Rebuild the right list: "<probe> (<channels>) *<assigned geometry>*",
            % with the geometry part blank if none. ItemsData is the probe index so
            % the selection maps back to obj.probes.
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                label = char(p.elementstring());
                nch = ndi.fun.probe.channelCount(p);
                if ~isempty(nch)
                    label = [label ' (' int2str(nch) ')']; %#ok<AGROW>
                end
                model = obj.assignedGeometryLabel(p);
                if ~isempty(model)
                    label = [label ' *' model '*']; %#ok<AGROW>
                end
                items{i} = label;
            end

            prev = obj.ProbeList.Value;   % previously selected probe index (or [])
            if isempty(items)
                obj.ProbeList.Items = {};
                obj.ProbeList.ItemsData = [];
            else
                obj.ProbeList.Items = items;
                obj.ProbeList.ItemsData = 1:n;
                if ~isempty(prev) && isnumeric(prev) && prev >= 1 && prev <= n
                    obj.ProbeList.Value = prev;
                end
            end
            obj.updateButtonState();
        end

        function model = assignedGeometryLabel(obj, probe)
            % The probe_model of the geometry currently assigned to PROBE, or '' if
            % none. Falls back to 'assigned' when a geometry exists without a model.
            model = '';
            try
                G = ndi.fun.probe.geometry.get(obj.session, probe);
                if G.found
                    if isfield(G.pg, 'probe_model') && ~isempty(G.pg.probe_model)
                        model = char(G.pg.probe_model);
                    else
                        model = 'assigned';
                    end
                end
            catch
                model = '';
            end
        end

        function onProbeSelected(obj)
            % When a probe with an assigned geometry is selected, highlight the
            % matching geometry in the left list (matched by probe_model).
            pidx = obj.ProbeList.Value;
            if ~isempty(pidx) && isnumeric(pidx) && pidx <= numel(obj.probes)
                model = obj.assignedGeometryLabel(obj.probes{pidx});
                if ~isempty(model) && ~isempty(obj.geometryModels)
                    idx = find(strcmp(obj.geometryModels, model), 1);
                    if ~isempty(idx) && ~isempty(obj.geometryNames)
                        obj.GeometryList.Value = obj.geometryNames{idx};
                    end
                end
            end
            obj.updateButtonState();
        end

        function updateButtonState(obj)
            % Assign enabled only when both a geometry and a probe are selected;
            % Plot enabled when a geometry is selected.
            hasGeom = ~isempty(obj.GeometryList.Items) && ~isempty(obj.GeometryList.Value);
            hasProbe = ~isempty(obj.ProbeList.Items) && ~isempty(obj.ProbeList.Value);
            obj.AssignButton.Enable = onOff(hasGeom && hasProbe);
            obj.PlotButton.Enable = onOff(hasGeom);
        end

        function plotSelectedGeometry(obj)
            % Open a plot of the selected electrode geometry in a new window.
            gname = obj.GeometryList.Value;
            if isempty(gname)
                return;
            end
            try
                ndi.fun.probe.geometry.plot(gname);
            catch e
                uialert(obj.fig, e.message, 'Plot failed');
            end
        end

        function assignSelected(obj)
            % Assign the selected geometry to the selected probe and save it.
            gname = obj.GeometryList.Value;   % library name (ItemsData)
            pidx  = obj.ProbeList.Value;       % probe index (ItemsData)
            if isempty(gname) || isempty(pidx) || pidx > numel(obj.probes)
                return;
            end
            probe = obj.probes{pidx};

            try
                % replace: re-assigning overwrites the probe's geometry rather than
                % stacking a second probe_geometry document.
                [~, ~, info] = ndi.fun.probe.geometry.fromLibrary(obj.session, probe, ...
                    gname, 'replace', true);
            catch e
                uialert(obj.fig, e.message, 'Assignment failed');
                return;
            end

            obj.refreshProbeList();

            % Surface a channel-count mismatch in the GUI (it is also printed as a
            % warning). The assignment still succeeds; this is advisory.
            if isstruct(info) && isfield(info, 'channel_mismatch') && info.channel_mismatch
                uialert(obj.fig, info.message, 'Channel count mismatch', 'Icon', 'warning');
            end
        end
    end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
