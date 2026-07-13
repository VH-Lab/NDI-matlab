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
%   for KIASORT, "run" if KIASORT has been run, and "curated" if curated results
%   exist. Below the list are checkboxes for the main KIASORT options, and two
%   buttons that act on the selected probe:
%       Run    - run KIASORT (with the checked options) on the exported binary and
%                import the results into NDI. Requires the probe to be exported (see
%                ndi.gui.app.ElectrodeDataExport) and a MATLAB Python environment
%                with umap-learn.
%       Curate - open KIASORT's curation UI for the sorted results.
%
%   The app is a thin shell: status is read from ndi.fun.probe.import.kiasort.status
%   and the actions call ndi.fun.probe.import.kiasort.run / .probe / .curate.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.ElectrodeDataExport,
%             ndi.fun.probe.import.kiasort.run, ndi.fun.probe.import.kiasort.status

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
        ConfigChecks            % containers.Map: cfg field -> uicheckbox handle
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
                'Position', [100 100 560 500], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.kiasort');

            root = uigridlayout(obj.fig, [6 1], ...
                'RowHeight', {30, 18, '1x', 18, 100, 44}, 'ColumnWidth', {'1x'}, ...
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

            cfgHeader = uilabel(root, 'Text', 'KIASORT options:', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            cfgHeader.Layout.Row = 4; cfgHeader.Layout.Column = 1;

            % Main KIASORT config checkboxes (field, label, default, tooltip). These
            % are the boolean options from kiaSort_main_configs; their values are
            % passed to ndi.fun.probe.import.kiasort.run as cfg_overrides.
            defs = { ...
                'useGPU', 'Use GPU', true, ...
                    'Use GPU acceleration if a compatible GPU is available.'; ...
                'parallelProcessing', 'Parallel processing', false, ...
                    'Use a parallel pool (Parallel Computing Toolbox) to sort across CPU workers.'; ...
                'denoising', 'Whitening', true, ...
                    ['Spatially whiten the data (decorrelate channels) to remove shared / ' ...
                     'common-mode noise before spike detection. Recommended.']; ...
                'extremeNoise', 'Denoising', false, ...
                    ['Extra removal of extreme, correlated noise using the noise percentile / ' ...
                     'correlation thresholds. Off by default; enable for unusually noisy data.']; ...
                'sort_only', 'Sort only', false, ...
                    ['Skip the sample-clustering stage and re-sort the full recording using ' ...
                     'previously sorted samples. Leave OFF for a fresh sort (needs prior samples).']; ...
                'extractWaveform', 'Save waveforms', false, ...
                    ['Also save every spike''s waveform to disk (waveforms.h5). NOT required for ' ...
                     'curation - KIASORT curation reconstructs individual spike waveforms (and ' ...
                     'their variability) from the raw binary - nor for NDI import. Enable only to ' ...
                     'precompute a per-spike waveform file for other analysis.']; ...
                'parallelSort', 'Parallel sort', false, ...
                    ['EXPERIMENTAL. Run the final sorting stage (sortData) with per-channel ' ...
                     'parallelism across CPU workers. Serial (unchecked) is the validated default ' ...
                     'and results should match it (validate with kiaSort_compare_sortings). ' ...
                     'Needs the Parallel Computing Toolbox; falls back to serial if unavailable.']};

            cfgGrid = uigridlayout(root, [3 3], ...
                'RowHeight', {'1x','1x','1x'}, 'ColumnWidth', {'1x','1x','1x'}, ...
                'RowSpacing', 4, 'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            cfgGrid.Layout.Row = 5; cfgGrid.Layout.Column = 1;

            obj.ConfigChecks = containers.Map('KeyType', 'char', 'ValueType', 'any');
            for i = 1:size(defs,1)
                cb = uicheckbox(cfgGrid, 'Text', defs{i,2}, 'Value', defs{i,3}, ...
                    'FontColor', c.white, 'Tooltip', defs{i,4});
                obj.ConfigChecks(defs{i,1}) = cb;
            end

            % Bottom controls: [ status  <spacer>  Run  Curate ]
            bottom = uigridlayout(root, [1 4], ...
                'ColumnWidth', {'1x', 10, 110, 110}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            bottom.Layout.Row = 6; bottom.Layout.Column = 1;

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

        function st = probeStatus(obj, probe)
            % Thin delegate to the ndi.fun status function (keeps the app logic-free).
            st = ndi.fun.probe.import.kiasort.status(obj.session, probe, ...
                'kiasort_dir', obj.kiasort_dir, 'binaryFileName', obj.binaryFileName, ...
                'subdir', obj.subdir);
        end

        function refreshProbeList(obj)
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                st = obj.probeStatus(p);
                words = {};
                if st.exported, words{end+1} = 'exported'; end %#ok<AGROW>
                if st.run,      words{end+1} = 'run';      end %#ok<AGROW>
                if st.curated,  words{end+1} = 'curated';  end %#ok<AGROW>
                if isempty(words)
                    label = [char(p.elementstring()) ' (not exported)'];
                else
                    label = [char(p.elementstring()) ' (' strjoin(words, ', ') ')'];
                end
                items{i} = label;
            end

            prev = obj.ProbeList.Value;
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
            canRun = false; canCurate = false;
            p = obj.selectedProbe();
            if ~isempty(p)
                st = obj.probeStatus(p);
                canRun = st.exported;
                canCurate = st.run;
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

        function cfg = configOverrides(obj)
            % Build the cfg_overrides struct from the checkbox states.
            cfg = struct();
            keys = obj.ConfigChecks.keys;
            for i = 1:numel(keys)
                cfg.(keys{i}) = logical(obj.ConfigChecks(keys{i}).Value);
            end
        end

        function runSelected(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end

            cfg = obj.configOverrides();
            obj.setBusy(true, 'Running KIASORT (this can take a while)...');
            err = '';
            try
                ndi.fun.probe.import.kiasort.run(obj.session, p, ...
                    'cfg_overrides', cfg, 'verbose', 0);
                obj.StatusLabel.Text = 'Importing results...'; drawnow;
                ndi.fun.probe.import.kiasort.probe(obj.session, p, 'verbose', 0);
            catch e
                err = e.message;
                % print the full stack to the command window for diagnosis
                disp(getReport(e, 'extended', 'hyperlinks', 'off'));
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
                obj.updateButtonState();
            end
        end
    end
end

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
