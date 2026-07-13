classdef kiasort < ndi.gui.app.sessionApp
% NDI.GUI.APP.KIASORT - run and curate KIASORT spike sorting within NDI
%
%   OBJ = ndi.gui.app.kiasort(SESSION)
%
%   Opens a window for running KIASORT on the n-trode probes of the ndi.session
%   SESSION and curating the results. This app is grouped under the "Spike Sorters"
%   category in the navigator's per-session Apps menu.
%
%   The window (in the NDI Cloud colour scheme) lists the session's n-trode probes,
%   each showing its status in parentheses: "exported" if the data has been exported
%   for KIASORT, and "run" if KIASORT has already been run for it. Two buttons act on
%   the selected probe:
%       Run    - run KIASORT on the exported binary and import the results into NDI
%                (enabled once the probe has been exported; see
%                ndi.gui.app.ElectrodeDataExport). Requires a MATLAB Python
%                environment with umap-learn (KIASORT uses UMAP).
%       Curate - open KIASORT's interactive curation UI for the sorted results
%                (enabled once KIASORT has been run). Curation is non-destructive and
%                may be repeated; import the curated result afterwards.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor takes
%   the ndi.session as its first argument.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.ElectrodeDataExport,
%             ndi.fun.probe.import.kiasort.run, ndi.fun.probe.import.kiasort.curate

    properties (Constant)
        Name     = "Kiasort"          % ndi.gui.app.sessionApp menu label
        Category = "Spike Sorters"    % grouped under this Apps submenu
    end

    properties (Access = private)
        session                 % the ndi.session
        fig                     % the uifigure
        ProbeList               % single-select uilistbox of n-trode probes
        RunButton               % Run button
        CurateButton            % Curate button
        StatusLabel             % status text
        probes = {}             % cell array of the session's n-trode probes
        kiasort_dir = 'kiasort'
        binaryFileName = 'kiasort.bin'
        subdir = 'kiasort_output'
    end

    methods
        function obj = kiasort(session)
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

            obj.fig = uifigure('Name', ['KIASORT: ' obj.session.reference], ...
                'Position', [100 100 560 440], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.kiasort');

            root = uigridlayout(obj.fig, [4 1], ...
                'RowHeight', {30, 20, '1x', 44}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [10 10 10 10], ...
                'BackgroundColor', c.darkBlue);

            title = uilabel(root, 'Text', 'Run and Curate KIASORT', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            header = uilabel(root, 'Text', 'n-trode Probes (status):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            header.Layout.Row = 2; header.Layout.Column = 1;

            obj.ProbeList = uilistbox(root, 'Items', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.ProbeList.Layout.Row = 3; obj.ProbeList.Layout.Column = 1;

            % Bottom controls: [ status  <spacer>  Run  Curate ]
            bottom = uigridlayout(root, [1 4], ...
                'ColumnWidth', {'1x', 10, 110, 110}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            bottom.Layout.Row = 4; bottom.Layout.Column = 1;

            obj.StatusLabel = uilabel(bottom, 'Text', '', ...
                'FontColor', c.white, 'VerticalAlignment', 'center');
            obj.StatusLabel.Layout.Row = 1; obj.StatusLabel.Layout.Column = 1;

            obj.RunButton = uibutton(bottom, 'push', 'Text', 'Run', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Run KIASORT on the exported probe and import the results', ...
                'Enable', 'off', 'ButtonPushedFcn', @(~,~) obj.runSelected());
            obj.RunButton.Layout.Row = 1; obj.RunButton.Layout.Column = 3;

            obj.CurateButton = uibutton(bottom, 'push', 'Text', 'Curate', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Open KIASORT curation for the selected probe''s results', ...
                'Enable', 'off', 'ButtonPushedFcn', @(~,~) obj.curateSelected());
            obj.CurateButton.Layout.Row = 1; obj.CurateButton.Layout.Column = 4;

            obj.loadProbes();
            obj.refreshProbeList();
            obj.updateButtonState();
        end

        function loadProbes(obj)
            try
                obj.probes = obj.session.getprobes('type', 'n-trode');
            catch
                obj.probes = {};
            end
            if ~iscell(obj.probes)
                obj.probes = {};
            end
        end

        function tf = isExported(obj, probe)
            tf = isfile(fullfile(obj.probeDir(probe), obj.binaryFileName));
        end

        function tf = isRun(obj, probe)
            tf = isfile(fullfile(obj.probeDir(probe), obj.subdir, 'RES_Sorted', 'spike_idx.h5'));
        end

        function d = probeDir(obj, probe)
            elestr = char(probe.elementstring());
            elestr(elestr == ' ') = '_';
            d = fullfile(obj.session.path, obj.kiasort_dir, elestr);
        end

        function refreshProbeList(obj)
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                status = {};
                if obj.isExported(p), status{end+1} = 'exported'; end %#ok<AGROW>
                if obj.isRun(p),      status{end+1} = 'run';      end %#ok<AGROW>
                if isempty(status)
                    label = [char(p.elementstring()) ' (not exported)'];
                else
                    label = [char(p.elementstring()) ' (' strjoin(status, ', ') ')'];
                end
                items{i} = label;
            end

            prev = obj.ProbeList.Value;   % previously selected probe index
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

        function updateButtonState(obj)
            % Run needs an exported probe; Curate needs a probe that has been run.
            pidx = obj.ProbeList.Value;
            canRun = false; canCurate = false;
            if ~isempty(pidx) && isnumeric(pidx) && pidx <= numel(obj.probes)
                p = obj.probes{pidx};
                canRun = obj.isExported(p);
                canCurate = obj.isRun(p);
            end
            obj.RunButton.Enable = onOff(canRun);
            obj.CurateButton.Enable = onOff(canCurate);
        end

        function p = selectedProbe(obj)
            p = [];
            pidx = obj.ProbeList.Value;
            if ~isempty(pidx) && isnumeric(pidx) && pidx <= numel(obj.probes)
                p = obj.probes{pidx};
            end
        end

        function runSelected(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end

            obj.setBusy(true, 'Running KIASORT (this can take a while)...');
            err = '';
            try
                ndi.fun.probe.import.kiasort.run(obj.session, p, 'verbose', 0);
                obj.StatusLabel.Text = 'Importing results...'; drawnow;
                ndi.fun.probe.import.kiasort.probe(obj.session, p, 'verbose', 0);
            catch e
                err = e.message;
            end
            obj.setBusy(false, '');
            obj.refreshProbeList();

            if ~isempty(err)
                uialert(obj.fig, err, 'KIASORT run failed');
            else
                uialert(obj.fig, sprintf('KIASORT finished and results were imported for %s.', ...
                    char(p.elementstring())), 'Run complete', 'Icon', 'success');
            end
        end

        function curateSelected(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end
            try
                ndi.fun.probe.import.kiasort.curate(obj.session, p);
            catch e
                uialert(obj.fig, e.message, 'Curation failed');
            end
        end

        function setBusy(obj, busy, msg)
            obj.StatusLabel.Text = msg;
            en = onOff(~busy);
            obj.RunButton.Enable = en;
            obj.CurateButton.Enable = en;
            obj.ProbeList.Enable = en;
            drawnow;
            if ~busy
                obj.updateButtonState(); % restore correct per-probe enable state
            end
        end
    end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
