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
%   below it, two lists: on the left the available electrode geometries, on
%   the right the session's n-trode probes with their currently-assigned
%   geometry shown in parentheses (blank if none). A button between the two,
%   with a left-to-right arrow, is enabled when both a geometry and a probe
%   are selected; clicking it assigns the selected geometry to the selected
%   probe and saves the probe_geometry document to the database.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from
%   the ndi.gui.navigator "Apps" menu.
%
%   See also: ndi.gui.app.sessionApp, ndi.fun.probe.geometry.fromLibrary,
%             ndi.fun.probe.geometry.listLibrary, ndi.fun.probe.geometry.get

    properties (Constant)
        Name = "Electrode Map"   % ndi.gui.app.sessionApp menu label
    end

    properties (Access = private)
        session                 % the ndi.session being edited
        fig                     % the uifigure
        GeometryList            % uilistbox of electrode geometries (left)
        ProbeList               % uilistbox of n-trode probes (right)
        AssignButton            % the assign (->) button
        probes = {}             % cell array of the session's n-trode probes
        geometryNames = {}      % cell array of library geometry names
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
                'Position', [100 100 640 460], ...
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

            % Body: [geometries] [ -> ] [probes]
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

            obj.GeometryList = uilistbox(body, 'Items', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.GeometryList.Layout.Row = 2; obj.GeometryList.Layout.Column = 1;

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
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.ProbeList.Layout.Row = 2; obj.ProbeList.Layout.Column = 3;

            % Populate
            obj.loadGeometries();
            obj.loadProbes();
            obj.refreshProbeList();
            obj.updateButtonState();
        end

        function loadGeometries(obj)
            % Fill the left list from the electrode-layout library.
            try
                names = ndi.fun.probe.geometry.listLibrary();
            catch
                names = {};
            end
            obj.geometryNames = names;
            obj.GeometryList.Items = names;
            if isempty(names)
                obj.GeometryList.Items = {};
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
            % Rebuild the right list, showing each probe's assigned geometry in
            % parentheses (blank if none). ItemsData is the probe index so the
            % selection maps back to obj.probes.
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                label = char(p.elementstring());
                suffix = obj.assignedGeometryLabel(p);
                if ~isempty(suffix)
                    label = [label ' (' suffix ')']; %#ok<AGROW>
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

        function suffix = assignedGeometryLabel(obj, probe)
            % The model name of the geometry currently assigned to PROBE, or '' if
            % none. Uses probe_model when set, otherwise a generic 'assigned' tag.
            suffix = '';
            try
                G = ndi.fun.probe.geometry.get(obj.session, probe);
                if G.found
                    if isfield(G.pg, 'probe_model') && ~isempty(G.pg.probe_model)
                        suffix = char(G.pg.probe_model);
                    else
                        suffix = 'assigned';
                    end
                end
            catch
                suffix = '';
            end
        end

        function updateButtonState(obj)
            % Enable the assign button only when both a geometry and a probe are
            % selected (i.e. both lists are non-empty and have a current value).
            hasGeom = ~isempty(obj.GeometryList.Items) && ~isempty(obj.GeometryList.Value);
            hasProbe = ~isempty(obj.ProbeList.Items) && ~isempty(obj.ProbeList.Value);
            if hasGeom && hasProbe
                obj.AssignButton.Enable = 'on';
            else
                obj.AssignButton.Enable = 'off';
            end
        end

        function assignSelected(obj)
            % Assign the selected geometry to the selected probe and save it.
            gname = obj.GeometryList.Value;   % geometry name (char)
            pidx  = obj.ProbeList.Value;       % probe index (from ItemsData)
            if isempty(gname) || isempty(pidx) || pidx > numel(obj.probes)
                return;
            end
            probe = obj.probes{pidx};

            try
                % replace: re-assigning overwrites the probe's geometry rather than
                % stacking a second probe_geometry document.
                ndi.fun.probe.geometry.fromLibrary(obj.session, probe, gname, ...
                    'replace', true);
            catch e
                uialert(obj.fig, e.message, 'Assignment failed');
                return;
            end

            obj.refreshProbeList();
        end
    end
end
