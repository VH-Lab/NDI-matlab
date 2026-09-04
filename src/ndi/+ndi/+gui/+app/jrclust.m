classdef jrclust < ndi.gui.app.sessionApp
% NDI.GUI.APP.JRCLUST - run JRCLUST spike sorting on NDI probes
%
%   OBJ = ndi.gui.app.jrclust(SESSION)
%
%   Opens a window that walks an n-trode probe of the ndi.session SESSION through the
%   whole JRCLUST pipeline, without leaving NDI. This app is grouped under the
%   "Spike Sorters" category in the navigator's per-session Apps menu, alongside the
%   other NDI spike sorters (e.g. ndi.gui.app.kiasort).
%
%   The window lists the session's n-trode probes, each with its pipeline state in
%   parentheses ("parameters", "detected", "sorted", "curated", "annotated",
%   "imported"), and has
%   one button per step, in order:
%
%     Check JRCLUST   - report the JRCLUST installation NDI can see: where it is,
%                       its version, its git branch (the VH Lab fork's 'ndi_import'
%                       branch is the one that can read NDI data), and whether its
%                       NDI support is present.
%     Parameters      - write the JRCLUST parameter file for the selected probe,
%                       filling in the probe's geometry from NDI. No data is copied:
%                       JRCLUST reads the probe's samples directly out of NDI.
%     Edit Parameters - open that parameter file in the MATLAB editor, which is where
%                       useGPU, maxSecLoad, siteLoc, siteMap, ignoreChans,
%                       evtGroupRad and the rest are set.
%     Traces          - open JRCLUST's trace viewer, to check the channels and the
%                       site map before sorting.
%     Detect          - run JRCLUST spike detection ('jrc detect').
%     Sort            - run JRCLUST clustering ('jrc sort').
%     Curate          - open JRCLUST's curation GUI ('jrc manual'), where units are
%                       merged, split and annotated ('single', 'multi', 'noise', ...).
%     Import into NDI - import the annotated units as ndi.neuron elements with
%                       neuron_extracellular documents.
%
%   The app is a thin shell: the state comes from
%   ndi.fun.probe.import.jrclust.status and every button calls the matching
%   ndi.fun.probe function, so the same pipeline can be scripted.
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.kiasort,
%             ndi.fun.probe.export.jrclust, ndi.fun.probe.import.jrclust.status,
%             ndi.fun.probe.import.jrclust.probe

    % NOTE: this class is named 'jrclust' inside the package ndi.gui.app, so an
    % unqualified reference to JRCLUST's own 'jrclust' package would resolve to this
    % class. Nothing here calls JRCLUST directly - every action goes through the
    % ndi.fun.probe.* functions - and it should stay that way.

    properties (Constant)
        Name     = "JRCLUST"          % ndi.gui.app.sessionApp menu label
        Category = "Spike Sorters"    % grouped under this Apps submenu
    end

    properties (Access = private)
        session                 % the ndi.session
        fig                     % the uifigure
        ProbeList               % single-select uilistbox of n-trode probes
        CheckButton             % Check JRCLUST installation
        ParamsButton            % write the .prm file
        EditButton              % open the .prm file in the editor
        TracesButton            % jrc traces
        DetectButton            % jrc detect
        SortButton              % jrc sort
        CurateButton            % jrc manual
        ImportButton            % import the units into NDI
        RefreshButton           % re-read the pipeline state
        GPUCheck                % useGPU checkbox
        ForceCheck              % force re-import checkbox
        MaxSecField             % maxSecLoad
        GroupRadField           % evtGroupRad
        StatusLabel             % status text
        probes = {}             % cell array of the session's n-trode probes
    end

    methods
        function obj = jrclust(session)
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

            obj.fig = uifigure('Name', ['JRCLUST: ' obj.session.reference], ...
                'Position', [100 100 640 520], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.jrclust');

            root = uigridlayout(obj.fig, [7 1], ...
                'RowHeight', {30, 18, '1x', 30, 34, 34, 30}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [10 10 10 10], ...
                'BackgroundColor', c.darkBlue);

            title = uilabel(root, 'Text', 'Spike Sort with JRCLUST', ...
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

            % Options that are passed to the parameter-file writer and the importer.
            % Everything else is edited in the parameter file itself.
            opts = uigridlayout(root, [1 7], ...
                'ColumnWidth', {90, 110, 70, 130, 70, '1x', 150}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 6, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            opts.Layout.Row = 4; opts.Layout.Column = 1;

            obj.GPUCheck = uicheckbox(opts, 'Text', 'Use GPU', 'Value', false, ...
                'FontColor', c.white, ...
                'Tooltip', ['Let JRCLUST use the GPU. Leave off unless you have a ' ...
                'compatible GPU. Written into the parameter file.']);
            obj.GPUCheck.Layout.Column = 1;

            lbl1 = uilabel(opts, 'Text', 'Max sec load:', 'FontColor', c.white, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'center');
            lbl1.Layout.Column = 2;
            obj.MaxSecField = uieditfield(opts, 'numeric', 'Value', 100, ...
                'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'Tooltip', ['Seconds of data JRCLUST loads at a time (maxSecLoad). ' ...
                'Lower it if memory is tight, raise it if you have plenty.']);
            obj.MaxSecField.Layout.Column = 3;

            lbl2 = uilabel(opts, 'Text', 'Group radius (um):', 'FontColor', c.white, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'center');
            lbl2.Layout.Column = 4;
            obj.GroupRadField = uieditfield(opts, 'numeric', 'Value', 75, ...
                'Limits', [1 Inf], 'LowerLimitInclusive', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'Tooltip', ['Maximum distance (microns) over which sites are grouped ' ...
                'for spike extraction (evtGroupRad). Use a large value (e.g. 800) to ' ...
                'group every site of a tetrode-like probe.']);
            obj.GroupRadField.Layout.Column = 5;

            obj.CheckButton = uibutton(opts, 'push', 'Text', 'Check JRCLUST', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', ['Report the JRCLUST installation NDI can see: location, ' ...
                'version, git branch and whether its NDI support is present.'], ...
                'ButtonPushedFcn', @(~,~) obj.checkInstall());
            obj.CheckButton.Layout.Column = 7;

            % The pipeline, in order, across two rows of buttons.
            top = uigridlayout(root, [1 4], ...
                'ColumnWidth', {'1x','1x','1x','1x'}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            top.Layout.Row = 5; top.Layout.Column = 1;

            obj.ParamsButton = obj.makeButton(top, 1, '1. Parameters', ...
                ['Write the JRCLUST parameter file for the selected probe, with its ' ...
                'geometry filled in from NDI.'], @() obj.writeParameters());
            obj.EditButton = obj.makeButton(top, 2, '2. Edit Params', ...
                'Open the parameter file in the MATLAB editor.', @() obj.editParameters());
            obj.TracesButton = obj.makeButton(top, 3, '3. Traces', ...
                ['Open JRCLUST''s trace viewer to check the channels and site map ' ...
                'before sorting.'], @() obj.viewTraces());
            obj.DetectButton = obj.makeButton(top, 4, '4. Detect', ...
                'Run JRCLUST spike detection on the selected probe.', @() obj.detectSpikes());

            bottom = uigridlayout(root, [1 4], ...
                'ColumnWidth', {'1x','1x','1x','1x'}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            bottom.Layout.Row = 6; bottom.Layout.Column = 1;

            obj.SortButton = obj.makeButton(bottom, 1, '5. Sort', ...
                'Run JRCLUST clustering on the detected spikes.', @() obj.sortSpikes());
            obj.CurateButton = obj.makeButton(bottom, 2, '6. Curate', ...
                ['Open JRCLUST''s curation GUI. Annotate each unit (single, multi, ' ...
                'noise, ...) and save before importing.'], @() obj.curate());
            obj.ImportButton = obj.makeButton(bottom, 3, '7. Import into NDI', ...
                ['Import the annotated units as ndi.neuron elements with ' ...
                'neuron_extracellular documents.'], @() obj.importResults());
            obj.ForceCheck = uicheckbox(bottom, 'Text', 'Force re-import', 'Value', false, ...
                'FontColor', c.white, ...
                'Tooltip', ['Re-import even when the sort has not changed since the ' ...
                'last import (replaces the neurons that were imported before).']);
            obj.ForceCheck.Layout.Column = 4;

            % Bottom line: [ status <spacer> Refresh ]
            foot = uigridlayout(root, [1 2], ...
                'ColumnWidth', {'1x', 100}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            foot.Layout.Row = 7; foot.Layout.Column = 1;

            obj.StatusLabel = uilabel(foot, 'Text', '', ...
                'FontColor', c.white, 'VerticalAlignment', 'center');
            obj.StatusLabel.Layout.Row = 1; obj.StatusLabel.Layout.Column = 1;

            obj.RefreshButton = uibutton(foot, 'push', 'Text', 'Refresh', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Re-read the pipeline state of every probe', ...
                'ButtonPushedFcn', @(~,~) obj.refreshProbeList());
            obj.RefreshButton.Layout.Row = 1; obj.RefreshButton.Layout.Column = 2;

            obj.loadProbes();
            obj.refreshProbeList();
        end

        function b = makeButton(obj, parent, column, text, tooltip, fcn)
            c = ndi.gui.cloudColors();
            b = uibutton(parent, 'push', 'Text', text, ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Tooltip', tooltip, 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) fcn());
            b.Layout.Row = 1; b.Layout.Column = column;
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
            st = ndi.fun.probe.import.jrclust.status(obj.session, probe);
        end

        function refreshProbeList(obj)
            n = numel(obj.probes);
            items = cell(1, n);
            for i = 1:n
                p = obj.probes{i};
                st = obj.probeStatus(p);
                words = {};
                if st.bootstrapped, words{end+1} = 'parameters'; end %#ok<AGROW>
                if st.detected,     words{end+1} = 'detected';   end %#ok<AGROW>
                if st.sorted,       words{end+1} = 'sorted';     end %#ok<AGROW>
                if st.curated,      words{end+1} = 'curated';    end %#ok<AGROW>
                if st.annotated,    words{end+1} = 'annotated'; end %#ok<AGROW>
                if st.imported,     words{end+1} = 'imported';   end %#ok<AGROW>
                if isempty(words)
                    label = [char(p.elementstring()) ' (not started)'];
                else
                    label = [char(p.elementstring()) ' (' strjoin(words, ', ') ')'];
                end
                items{i} = label;
            end

            prev = obj.ProbeList.Value;
            if isempty(items)
                obj.ProbeList.Items = {};
                obj.ProbeList.ItemsData = [];
                obj.StatusLabel.Text = 'No n-trode probes in this session.';
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
            % Each step needs the previous one to have been done.
            canParams = false; canEdit = false; canDetect = false;
            canSort = false; canCurate = false; canImport = false;
            p = obj.selectedProbe();
            if ~isempty(p)
                st = obj.probeStatus(p);
                canParams = true;
                canEdit   = st.bootstrapped;
                canDetect = st.bootstrapped;
                % sorting reads the features detection wrote; without them JRCLUST
                % stops with 'cannot sort without features'
                canSort   = st.detected && st.features;
                canCurate = st.sorted;
                % importing selects units by their curation note, so it needs a sort
                % somebody has actually labelled, not merely a saved one
                canImport = st.annotated;
                if st.bootstrapped
                    obj.ParamsButton.Text = '1. Update Params';
                else
                    obj.ParamsButton.Text = '1. Parameters';
                end
            end
            obj.ParamsButton.Enable = onOff(canParams);
            obj.EditButton.Enable   = onOff(canEdit);
            obj.TracesButton.Enable = onOff(canEdit);
            obj.DetectButton.Enable = onOff(canDetect);
            obj.SortButton.Enable   = onOff(canSort);
            obj.CurateButton.Enable = onOff(canCurate);
            obj.ImportButton.Enable = onOff(canImport);
        end

        function p = selectedProbe(obj)
            p = [];
            pidx = obj.ProbeList.Value;
            if ~isempty(pidx) && isnumeric(pidx) && pidx <= numel(obj.probes)
                p = obj.probes{pidx};
            end
        end

        function checkInstall(obj)
            info = ndi.fun.probe.import.jrclust.install();
            if info.ok
                icon = 'success';
                titleStr = 'JRCLUST is ready';
            else
                icon = 'warning';
                titleStr = 'JRCLUST is not ready';
            end
            if info.ok && info.isGit && ~info.onExpectedBranch
                icon = 'warning';
                titleStr = ['JRCLUST is not on the ' char(info.expectedBranch) ' branch'];
            end
            uialert(obj.fig, info.summary, titleStr, 'Icon', icon);
        end

        function writeParameters(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end

            st = obj.probeStatus(p);
            if st.bootstrapped
                answer = uiconfirm(obj.fig, ...
                    ['A parameter file already exists for this probe. Writing a new one ' ...
                    'discards any edits you made (the old file is kept as ' ...
                    'jrclust.prm.bak). Continue?'], 'Overwrite parameter file?', ...
                    'Options', {'Overwrite','Cancel'}, 'DefaultOption', 2, ...
                    'CancelOption', 2);
                if ~strcmp(answer,'Overwrite'), return; end
            end

            obj.setBusy(true, 'Writing the JRCLUST parameter file...');
            err = '';
            prmFile = '';
            try
                prmFile = ndi.fun.probe.export.jrclust(obj.session, p, ...
                    'useGPU', obj.GPUCheck.Value, ...
                    'maxSecLoad', obj.MaxSecField.Value, ...
                    'evtGroupRad', obj.GroupRadField.Value, ...
                    'overwrite', true, 'verbose', 1);
            catch e
                err = e.message;
            end
            obj.setBusy(false, '');
            obj.refreshProbeList();

            if ~isempty(err)
                uialert(obj.fig, err, 'Could not write the parameter file');
            else
                uialert(obj.fig, ['Wrote ' prmFile '. Edit it to set the sorting ' ...
                    'parameters before running detection.'], 'Parameter file written', ...
                    'Icon', 'success');
            end
        end

        function editParameters(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end
            try
                ndi.fun.probe.import.jrclust.editParameters(obj.session, p);
            catch e
                uialert(obj.fig, e.message, 'Could not open the parameter file');
            end
        end

        function viewTraces(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end
            try
                ndi.fun.probe.import.jrclust.traces(obj.session, p);
            catch e
                uialert(obj.fig, e.message, 'Could not open the trace viewer');
            end
        end

        function detectSpikes(obj)
            obj.runStage('detect', 'Detecting spikes (this can take a while)...', ...
                'Spike detection finished');
        end

        function sortSpikes(obj)
            obj.runStage('sort', 'Sorting spikes (this can take a while)...', ...
                'Sorting finished');
        end

        function runStage(obj, stage, busyMessage, doneTitle)
            p = obj.selectedProbe();
            if isempty(p), return; end

            obj.setBusy(true, busyMessage);
            err = '';
            try
                ndi.fun.probe.import.jrclust.run(obj.session, p, 'stage', stage, 'verbose', 1);
            catch e
                err = e.message;
                % print the full stack to the command window for diagnosis
                disp(getReport(e, 'extended', 'hyperlinks', 'off'));
            end
            obj.setBusy(false, '');
            obj.refreshProbeList();

            if ~isempty(err)
                uialert(obj.fig, err, ['JRCLUST ' stage ' failed']);
            else
                uialert(obj.fig, sprintf('JRCLUST %s finished for %s.', stage, ...
                    char(p.elementstring())), doneTitle, 'Icon', 'success');
            end
        end

        function curate(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end
            try
                ndi.fun.probe.import.jrclust.curate(obj.session, p);
            catch e
                uialert(obj.fig, e.message, 'Curation failed');
            end
            obj.refreshProbeList();
        end

        function importResults(obj)
            p = obj.selectedProbe();
            if isempty(p), return; end

            obj.setBusy(true, 'Importing the JRCLUST units into NDI...');
            err = '';
            try
                ndi.fun.probe.import.jrclust.probe(obj.session, p, ...
                    'force', double(obj.ForceCheck.Value), 'verbose', 1);
            catch e
                err = e.message;
                disp(getReport(e, 'extended', 'hyperlinks', 'off'));
            end
            obj.setBusy(false, '');
            obj.refreshProbeList();

            if ~isempty(err)
                uialert(obj.fig, err, 'Import failed');
            else
                uialert(obj.fig, sprintf(['The JRCLUST units of %s were imported into ' ...
                    'NDI. See the command window for the details.'], ...
                    char(p.elementstring())), 'Import complete', 'Icon', 'success');
            end
        end

        function setBusy(obj, busy, msg)
            obj.StatusLabel.Text = msg;
            en = onOff(~busy);
            obj.ProbeList.Enable = en;
            obj.CheckButton.Enable = en;
            obj.RefreshButton.Enable = en;
            obj.ParamsButton.Enable = en;
            obj.EditButton.Enable = en;
            obj.TracesButton.Enable = en;
            obj.DetectButton.Enable = en;
            obj.SortButton.Enable = en;
            obj.CurateButton.Enable = en;
            obj.ImportButton.Enable = en;
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
