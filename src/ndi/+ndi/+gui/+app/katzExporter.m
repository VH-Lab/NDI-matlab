classdef katzExporter < ndi.gui.app.sessionApp
% NDI.GUI.APP.KATZEXPORTER - GUI to export a Katz-lab ensemble to a blech_clust HDF5 file
%
%   OBJ = ndi.gui.app.katzExporter(SESSION)
%
%   Opens a window (in the NDI Cloud colour scheme) that drives
%   ndi.fun.export.blech_clust: it exports a spiking-neuron ensemble plus the
%   tastant stimulus identities/times of one epoch to a blech_clust HMM-ready
%   HDF5 file for the Katz lab (https://github.com/vh-lab/blech_clust).
%
%   The window lets you:
%
%     * Select an ensemble - a dropdown of the session's ndi.element.ensemble
%       elements. The ensemble's underlying probe is exported; the stimulator
%       and epoch dropdowns are the other two coordinates of an export.
%     * Filter by quality - restrict the exported neurons by their
%       neuron_extracellular spike-sorting quality: a minimum quality_number
%       and/or a set of quality_labels, with an option to keep unrated neurons.
%       A live preview lists the neurons of the selected ensemble/epoch and how
%       many pass the current filter, so the effect is visible before export.
%     * Save an HDF5 file - the Export button prompts for a file name
%       (uiputfile) and writes the blech_clust HDF5 file there.
%
%   The pre/post-stimulus window (milliseconds retained around each stimulus
%   delivery) can be adjusted; it defaults to blech_clust's 2000/5000 ms.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from the
%   ndi.gui.navigator "Apps" menu.
%
%   Example:
%       S = ndi.session.dir('/path/to/session');
%       ndi.gui.app.katzExporter(S);
%
%   See also: ndi.gui.app.sessionApp, ndi.fun.export.blech_clust,
%             ndi.fun.ensemble.read, ndi.fun.ensemble.neuronQuality,
%             ndi.element.ensemble

    properties (Constant)
        Name = "Katz Lab Exporter"   % ndi.gui.app.sessionApp menu label
        Category = "Exporters"       % groups the app under an "Exporters" submenu
    end

    properties (Access = private)
        session                 % the ndi.session being exported
        fig                     % the uifigure

        % widgets
        ensembleDropdown        % popup of the session's ensemble elements
        epochDropdown           % popup of the selected ensemble's epochs
        stimulatorDropdown      % popup of the session's stimulator probes
        minQualityCheckbox      % "Minimum quality_number" enable
        minQualitySpinner       % the minimum quality_number value
        qualityLabelList        % multi-select listbox of quality_labels present
        keepUnratedCheckbox     % keep neurons that have no quality document
        preStimSpinner          % ms retained before each stimulus delivery
        postStimSpinner         % ms retained after each stimulus delivery
        neuronList              % preview listbox (neuron | quality# | label)
        summaryLabel            % "N of M neurons pass the quality filter"
        exportButton            % the Export button

        % state
        ensembles = {}          % cell array of ndi.element.ensemble objects
        stimulators = {}        % cell array of the session's stimulator probes
        neuronInfo = struct('name',{},'qnum',{},'qlabel',{},'pass',{})  % preview cache
        waitDlg = []            % active "please wait" dialog (if any)
    end

    methods
        function obj = katzExporter(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
            % the initial database reads (ensembles, stimulators, neurons) can
            % take a moment, so show a "please wait" indicator over them
            obj.withWait('Loading ensembles...', @() obj.reloadAll());
        end % katzExporter
    end

    methods (Access = private)

        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Katz Lab Exporter: ' char(obj.session.reference)], ...
                'Position', [100 100 680 620], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.katzExporter');

            root = uigridlayout(obj.fig, [8 1], ...
                'RowHeight', {30, 20, 32, 32, 'fit', '1x', 22, 44}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [12 12 12 12], ...
                'BackgroundColor', c.darkBlue);

            % Row 1: title
            title = uilabel(root, 'Text', 'Export Ensemble to blech_clust HDF5 (Katz Lab)', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            % Row 2: session reference / path
            sub = uilabel(root, 'Text', ['Session: ' char(obj.session.reference) ...
                '    Path: ' obj.sessionPath()], ...
                'FontColor', c.white, 'HorizontalAlignment', 'center');
            sub.Layout.Row = 2; sub.Layout.Column = 1;

            % Row 3: ensemble selector + reload
            erow = uigridlayout(root, [1 3], ...
                'ColumnWidth', {90, '1x', 90}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            erow.Layout.Row = 3; erow.Layout.Column = 1;
            elbl = uilabel(erow, 'Text', 'Ensemble:', 'FontWeight', 'bold', ...
                'FontColor', c.white, 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            elbl.Layout.Column = 1;
            obj.ensembleDropdown = uidropdown(erow, 'Items', {'(none)'}, 'ItemsData', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onEnsembleChanged());
            obj.ensembleDropdown.Layout.Column = 2;
            rb = uibutton(erow, 'Text', 'Reload', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.withWait('Loading ensembles...', @() obj.reloadAll()));
            rb.Layout.Column = 3;

            % Row 4: epoch + stimulator selectors
            srow = uigridlayout(root, [1 4], ...
                'ColumnWidth', {60, '1x', 80, '1x'}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            srow.Layout.Row = 4; srow.Layout.Column = 1;
            eplbl = uilabel(srow, 'Text', 'Epoch:', 'FontWeight', 'bold', ...
                'FontColor', c.white, 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            eplbl.Layout.Column = 1;
            obj.epochDropdown = uidropdown(srow, 'Items', {'(none)'}, 'ItemsData', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onEpochChanged());
            obj.epochDropdown.Layout.Column = 2;
            stlbl = uilabel(srow, 'Text', 'Stimulator:', 'FontWeight', 'bold', ...
                'FontColor', c.white, 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            stlbl.Layout.Column = 3;
            obj.stimulatorDropdown = uidropdown(srow, 'Items', {'(none)'}, 'ItemsData', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue);
            obj.stimulatorDropdown.Layout.Column = 4;

            % Row 5: quality filter panel
            qpanel = uipanel(root, 'Title', 'Filter by quality', ...
                'BackgroundColor', c.darkBlue, 'ForegroundColor', c.white, ...
                'FontWeight', 'bold');
            qpanel.Layout.Row = 5; qpanel.Layout.Column = 1;
            qgrid = uigridlayout(qpanel, [3 2], ...
                'RowHeight', {28, 70, 24}, 'ColumnWidth', {'1x', '1x'}, ...
                'RowSpacing', 6, 'ColumnSpacing', 12, 'Padding', [10 10 10 10], ...
                'BackgroundColor', c.darkBlue);

            % min quality (checkbox + spinner)
            qrow = uigridlayout(qgrid, [1 2], 'ColumnWidth', {'1x', 90}, ...
                'RowHeight', {'1x'}, 'ColumnSpacing', 6, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            qrow.Layout.Row = 1; qrow.Layout.Column = 1;
            obj.minQualityCheckbox = uicheckbox(qrow, 'Text', 'Minimum quality_number', ...
                'FontColor', c.white, 'Value', false, ...
                'ValueChangedFcn', @(~,~) obj.onFilterChanged());
            obj.minQualityCheckbox.Layout.Column = 1;
            obj.minQualitySpinner = uispinner(qrow, 'Limits', [0 100], ...
                'Value', 2, 'Step', 1, 'Enable', 'off', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onFilterChanged());
            obj.minQualitySpinner.Layout.Column = 2;

            % keep-unrated checkbox (top-right of panel)
            obj.keepUnratedCheckbox = uicheckbox(qgrid, 'Text', 'Keep unrated neurons', ...
                'FontColor', c.white, 'Value', false, ...
                'Tooltip', 'Keep neurons with no neuron_extracellular quality document', ...
                'ValueChangedFcn', @(~,~) obj.onFilterChanged());
            obj.keepUnratedCheckbox.Layout.Row = 1; obj.keepUnratedCheckbox.Layout.Column = 2;

            % quality-label multiselect
            qll = uilabel(qgrid, 'Text', 'quality_label is any of (none = ignore):', ...
                'FontColor', c.white);
            qll.Layout.Row = 2; qll.Layout.Column = 1;
            obj.qualityLabelList = uilistbox(qgrid, 'Items', {}, 'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onFilterChanged());
            obj.qualityLabelList.Layout.Row = 2; obj.qualityLabelList.Layout.Column = 2;

            % pre/post-stim window
            wrow = uigridlayout(qgrid, [1 4], ...
                'ColumnWidth', {70, 80, 80, 80}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 6, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            wrow.Layout.Row = 3; wrow.Layout.Column = [1 2];
            prelbl = uilabel(wrow, 'Text', 'preStim (ms):', 'FontColor', c.white, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'center');
            prelbl.Layout.Column = 1;
            obj.preStimSpinner = uispinner(wrow, 'Limits', [0 Inf], 'Value', 2000, ...
                'Step', 100, 'BackgroundColor', c.white, 'FontColor', c.darkBlue);
            obj.preStimSpinner.Layout.Column = 2;
            postlbl = uilabel(wrow, 'Text', 'postStim:', 'FontColor', c.white, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'center');
            postlbl.Layout.Column = 3;
            obj.postStimSpinner = uispinner(wrow, 'Limits', [1 Inf], 'Value', 5000, ...
                'Step', 100, 'BackgroundColor', c.white, 'FontColor', c.darkBlue);
            obj.postStimSpinner.Layout.Column = 4;

            % Row 6: neuron preview list
            obj.neuronList = uilistbox(root, 'Items', {}, 'Multiselect', 'off', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'FontName', get(groot, 'FixedWidthFontName'));
            obj.neuronList.Layout.Row = 6; obj.neuronList.Layout.Column = 1;

            % Row 7: summary of the filter effect
            obj.summaryLabel = uilabel(root, 'Text', '', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            obj.summaryLabel.Layout.Row = 7; obj.summaryLabel.Layout.Column = 1;

            % Row 8: export button
            brow = uigridlayout(root, [1 3], ...
                'ColumnWidth', {'1x', 200, '1x'}, 'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], 'BackgroundColor', c.darkBlue);
            brow.Layout.Row = 8; brow.Layout.Column = 1;
            obj.exportButton = uibutton(brow, 'push', 'Text', 'Export to HDF5...', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, ...
                'FontColor', c.darkBlue, 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.doExport());
            obj.exportButton.Layout.Column = 2;
        end % build

        function p = sessionPath(obj)
            % best-effort session path for display
            p = '';
            try
                if ismethod(obj.session, 'getpath')
                    p = obj.session.getpath();
                elseif isprop(obj.session, 'path')
                    p = obj.session.path;
                end
            catch
                p = '';
            end
        end % sessionPath

        % ---- data loading ---------------------------------------------------

        function reloadAll(obj)
            % (re)read the ensembles and stimulators from the database, then
            % refresh the dependent widgets
            obj.loadEnsembles();
            obj.loadStimulators();
            obj.onEnsembleChanged();
        end % reloadAll

        function loadEnsembles(obj)
            try
                obj.ensembles = obj.session.getelements('element.type', 'ensemble');
            catch
                obj.ensembles = {};
            end
            if ~iscell(obj.ensembles), obj.ensembles = {}; end
            if isempty(obj.ensembles)
                obj.ensembleDropdown.Items = {'(no ensembles found)'};
                obj.ensembleDropdown.ItemsData = {};
                return;
            end
            labels = cell(1, numel(obj.ensembles));
            for i = 1:numel(obj.ensembles)
                labels{i} = char(obj.ensembles{i}.elementstring());
            end
            obj.ensembleDropdown.Items = labels;
            obj.ensembleDropdown.ItemsData = 1:numel(obj.ensembles);
            obj.ensembleDropdown.Value = 1;
        end % loadEnsembles

        function loadStimulators(obj)
            try
                obj.stimulators = obj.session.getprobes('type', 'stimulator');
            catch
                obj.stimulators = {};
            end
            if ~iscell(obj.stimulators), obj.stimulators = {}; end
            if isempty(obj.stimulators)
                obj.stimulatorDropdown.Items = {'(no stimulators found)'};
                obj.stimulatorDropdown.ItemsData = {};
                return;
            end
            labels = cell(1, numel(obj.stimulators));
            for i = 1:numel(obj.stimulators)
                labels{i} = char(obj.stimulators{i}.elementstring());
            end
            obj.stimulatorDropdown.Items = labels;
            obj.stimulatorDropdown.ItemsData = 1:numel(obj.stimulators);
            obj.stimulatorDropdown.Value = 1;
        end % loadStimulators

        function ens = selectedEnsemble(obj)
            ens = [];
            idx = obj.ensembleDropdown.Value;
            if isempty(idx) || ~isnumeric(idx), return; end
            if idx >= 1 && idx <= numel(obj.ensembles)
                ens = obj.ensembles{idx};
            end
        end % selectedEnsemble

        function stim = selectedStimulator(obj)
            stim = [];
            idx = obj.stimulatorDropdown.Value;
            if isempty(idx) || ~isnumeric(idx), return; end
            if idx >= 1 && idx <= numel(obj.stimulators)
                stim = obj.stimulators{idx};
            end
        end % selectedStimulator

        function onEnsembleChanged(obj)
            % refresh the epoch list for the newly-selected ensemble, then the
            % neuron preview
            ens = obj.selectedEnsemble();
            if isempty(ens)
                obj.epochDropdown.Items = {'(none)'};
                obj.epochDropdown.ItemsData = {};
                obj.refreshNeurons();
                return;
            end
            try
                et = ens.epochtable();
                ids = {et.epoch_id};
            catch
                ids = {};
            end
            if isempty(ids)
                obj.epochDropdown.Items = {'(no epochs)'};
                obj.epochDropdown.ItemsData = {};
            else
                obj.epochDropdown.Items = ids;
                obj.epochDropdown.ItemsData = ids;
                obj.epochDropdown.Value = ids{1};
            end
            obj.onEpochChanged();
        end % onEnsembleChanged

        function onEpochChanged(obj)
            obj.withWait('Reading ensemble neurons...', @() obj.refreshNeurons());
        end % onEpochChanged

        function refreshNeurons(obj)
            % read the neurons of the selected ensemble/epoch and their quality,
            % populate the quality_label choices and the preview list
            obj.neuronInfo = struct('name', {}, 'qnum', {}, 'qlabel', {}, 'pass', {});
            ens = obj.selectedEnsemble();
            epoch = obj.currentEpoch();
            if isempty(ens) || isempty(epoch)
                obj.qualityLabelList.Items = {};
                obj.applyFilterAndShow();
                return;
            end
            try
                ids = ens.neuronIds(epoch);
                names = ens.neuronNames(epoch);
                [qnum, qlabel] = ndi.fun.ensemble.neuronQuality(obj.session, ids);
            catch ME
                obj.neuronList.Items = {['(could not read neurons: ' ME.message ')']};
                obj.neuronList.ItemsData = {};
                obj.qualityLabelList.Items = {};
                obj.summaryLabel.Text = '';
                obj.updateButtonState();
                return;
            end
            n = numel(ids);
            for i = 1:n
                nm = '';
                if i <= numel(names), nm = names{i}; end
                obj.neuronInfo(i) = struct('name', nm, 'qnum', qnum(i), ...
                    'qlabel', qlabel{i}, 'pass', true); %#ok<AGROW>
            end
            % populate the quality_label multiselect from the labels present
            present = unique(qlabel(~cellfun(@isempty, qlabel)));
            keepSel = intersect(obj.qualityLabelList.Value, present);
            obj.qualityLabelList.Items = present;
            obj.qualityLabelList.Value = keepSel;
            obj.applyFilterAndShow();
        end % refreshNeurons

        function epoch = currentEpoch(obj)
            % '' unless a real epoch is chosen (placeholder items such as
            % '(no epochs)' carry no ItemsData, so they are not real epochs)
            epoch = '';
            if isempty(obj.epochDropdown.ItemsData)
                return;
            end
            v = obj.epochDropdown.Value;
            if ischar(v) || (isstring(v) && isscalar(v))
                epoch = char(v);
            end
        end % currentEpoch

        function onFilterChanged(obj)
            % the min-quality spinner is only meaningful when its checkbox is on
            if isvalid(obj.minQualitySpinner)
                obj.minQualitySpinner.Enable = onOff(obj.minQualityCheckbox.Value);
            end
            obj.applyFilterAndShow();
        end % onFilterChanged

        function [minQ, labels, keepUnrated] = filterParameters(obj)
            % gather the current quality-filter settings
            minQ = [];
            if obj.minQualityCheckbox.Value
                minQ = obj.minQualitySpinner.Value;
            end
            labels = obj.qualityLabelList.Value;
            if ischar(labels), labels = {labels}; end
            keepUnrated = obj.keepUnratedCheckbox.Value;
        end % filterParameters

        function applyFilterAndShow(obj)
            % recompute which cached neurons pass the current filter and redraw
            % the preview list + summary (mirrors ndi.fun.ensemble.read's rule:
            % quality is a hard filter; unrated neurons drop unless KeepUnrated)
            [minQ, labels, keepUnrated] = obj.filterParameters();
            n = numel(obj.neuronInfo);
            items = cell(1, n);
            nPass = 0;
            for i = 1:n
                info = obj.neuronInfo(i);
                pass = true;
                unrated = isnan(info.qnum);
                if ~isempty(minQ) && (unrated || info.qnum < minQ)
                    pass = false;
                end
                if ~isempty(labels) && ~ismember(info.qlabel, labels)
                    pass = false;
                end
                if unrated && (~isempty(minQ) || ~isempty(labels))
                    pass = keepUnrated;   % KeepUnrated overrides for unrated neurons
                end
                obj.neuronInfo(i).pass = pass;
                if pass, nPass = nPass + 1; end
                if unrated, qstr = '  -'; else, qstr = sprintf('%3g', info.qnum); end
                mark = '  '; if ~pass, mark = 'x '; end
                lbl = info.qlabel; if isempty(lbl), lbl = '(unrated)'; end
                items{i} = sprintf('%s%-18s | q=%s | %s', mark, info.name, qstr, lbl);
            end
            if isempty(items)
                obj.neuronList.Items = {'(no neurons)'};
                obj.neuronList.ItemsData = {};
                obj.summaryLabel.Text = '';
            else
                obj.neuronList.Items = items;
                obj.neuronList.ItemsData = 1:n;
                obj.summaryLabel.Text = sprintf(...
                    '%d of %d neurons pass the quality filter (x = excluded)', nPass, n);
            end
            obj.updateButtonState();
        end % applyFilterAndShow

        function updateButtonState(obj)
            % Export is enabled only when an ensemble, epoch and stimulator are
            % chosen and at least one neuron passes the filter
            ok = ~isempty(obj.selectedEnsemble()) && ~isempty(obj.currentEpoch()) ...
                && ~isempty(obj.selectedStimulator()) ...
                && any([obj.neuronInfo.pass]);
            obj.exportButton.Enable = onOff(ok);
        end % updateButtonState

        % ---- export ---------------------------------------------------------

        function doExport(obj)
            ens = obj.selectedEnsemble();
            stim = obj.selectedStimulator();
            epoch = obj.currentEpoch();
            if isempty(ens) || isempty(stim) || isempty(epoch)
                uialert(obj.fig, 'Select an ensemble, an epoch and a stimulator first.', ...
                    'Incomplete selection');
                return;
            end
            probe = ens.underlying_element;
            if isempty(probe)
                uialert(obj.fig, ['The selected ensemble has no underlying probe, ' ...
                    'so it cannot be exported.'], 'No underlying probe');
                return;
            end

            % prompt for the output HDF5 file name
            defName = obj.suggestFileName(ens, epoch);
            [fn, pth] = uiputfile({'*.h5', 'HDF5 file (*.h5)'; '*.*', 'All files'}, ...
                'Save blech_clust HDF5 file as', defName);
            if isequal(fn, 0)
                return;   % user cancelled
            end
            outputfile = fullfile(pth, fn);

            [minQ, labels, keepUnrated] = obj.filterParameters();

            obj.exportButton.Enable = 'off';
            dlg = uiprogressdlg(obj.fig, 'Title', 'Please wait', ...
                'Message', ['Exporting to ' fn '...'], 'Indeterminate', 'on');
            restore = onCleanup(@() obj.finishExport(dlg)); %#ok<NASGU>

            try
                ndi.fun.export.blech_clust(stim, probe, epoch, outputfile, ...
                    'ensemble', ens, ...
                    'MinQuality', minQ, ...
                    'QualityLabel', labels, ...
                    'KeepUnrated', keepUnrated, ...
                    'preStim', obj.preStimSpinner.Value, ...
                    'postStim', obj.postStimSpinner.Value, ...
                    'verbose', 0);
            catch ME
                uialert(obj.fig, ME.message, 'Export failed', 'Icon', 'error');
                return;
            end
            uialert(obj.fig, ['Wrote blech_clust HDF5 file:' newline outputfile], ...
                'Export complete', 'Icon', 'success');
        end % doExport

        function finishExport(obj, dlg)
            if ~isempty(dlg) && isvalid(dlg), delete(dlg); end
            if isvalid(obj.exportButton)
                obj.updateButtonState();
            end
        end % finishExport

        function name = suggestFileName(obj, ens, epoch)
            % a sensible default HDF5 name built from the session and epoch
            base = char(obj.session.reference);
            base = regexprep(base, '\s', '_');
            ename = regexprep(ens.name, '\s', '_');
            ep = regexprep(epoch, '\s', '_');
            name = [base '_' ename '_' ep '_blech.h5'];
        end % suggestFileName

        % ---- shared "please wait" helper (nestable) -------------------------

        function withWait(obj, msg, fn)
            nested = ~isempty(obj.waitDlg) && isvalid(obj.waitDlg);
            cleaner = []; %#ok<NASGU>
            if ~nested && ~isempty(obj.fig) && isvalid(obj.fig)
                obj.waitDlg = uiprogressdlg(obj.fig, 'Title', 'Please wait', ...
                    'Message', msg, 'Indeterminate', 'on');
                cleaner = onCleanup(@() obj.clearWait());
            end
            fn();
        end % withWait

        function clearWait(obj)
            if ~isempty(obj.waitDlg) && isvalid(obj.waitDlg)
                delete(obj.waitDlg);
            end
            obj.waitDlg = [];
        end % clearWait

    end % methods (private)

end % classdef

function s = onOff(tf)
    if tf, s = 'on'; else, s = 'off'; end
end
