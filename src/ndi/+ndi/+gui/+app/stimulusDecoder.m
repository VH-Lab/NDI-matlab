classdef stimulusDecoder < ndi.gui.app.sessionApp
% NDI.GUI.APP.STIMULUSDECODER - GUI to run the stimulus decoder on a probe's epochs
%
%   OBJ = ndi.gui.app.stimulusDecoder(SESSION)
%
%   Opens a window (in the NDI Cloud colour scheme) that drives
%   ndi.app.stimulus.decoder for the ndi.session SESSION. It lets you:
%
%     * Choose a stimulator probe from a dropdown of the session's
%       'stimulator'-type probes.
%     * See that probe's stimulus epochs in a multi-select listbox. An epoch
%       that already has an associated 'stimulus_presentation' document (i.e.
%       it has been decoded) is marked with a leading "*".
%     * Select one or more epochs and click "Run decoder" to parse their
%       stimuli (ndi.app.stimulus.decoder.parse_stimuli), writing the
%       stimulus_presentation documents that downstream tools - such as
%       ndi.fun.export.blech_clust and ndi.gui.app.katzExporter - require.
%
%   By default an already-decoded epoch is left untouched (its "*" stays). Tick
%   "Re-decode selected (overwrite)" to remove and rebuild the selected epochs'
%   documents.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from the
%   ndi.gui.navigator "Apps" menu.
%
%   Example:
%       S = ndi.session.dir('/path/to/session');
%       ndi.gui.app.stimulusDecoder(S);
%
%   See also: ndi.gui.app.sessionApp, ndi.app.stimulus.decoder,
%             ndi.fun.export.blech_clust, ndi.gui.app.katzExporter

    properties (Constant)
        Name = "Stimulus Decoder"    % ndi.gui.app.sessionApp menu label
        Category = "Stimulus"        % groups the app under a "Stimulus" submenu
    end

    properties (Access = private)
        session                 % the ndi.session being operated on
        fig                     % the uifigure

        % widgets
        probeDropdown           % popup of the session's stimulator probes
        epochList               % multi-select listbox of stimulus epochs
        overwriteCheckbox       % "Re-decode selected (overwrite)"
        runButton               % the "Run decoder" button

        % state
        stimulators = {}        % cell array of the session's stimulator probes
        epochIds = {}           % epoch ids of the selected probe, in list order
        decodedEpochs = {}      % epoch ids that already have a stimulus_presentation
        waitDlg = []            % active "please wait" dialog (if any)
    end

    methods
        function obj = stimulusDecoder(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
            % the initial database reads (probes, epochs, documents) can take a
            % moment, so show a "please wait" indicator over them
            obj.withWait('Loading stimulator probes...', @() obj.reloadProbes());
        end % stimulusDecoder
    end

    methods (Access = private)

        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Stimulus Decoder: ' char(obj.session.reference)], ...
                'Position', [100 100 560 520], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.stimulusDecoder');

            root = uigridlayout(obj.fig, [6 1], ...
                'RowHeight', {30, 20, 32, 22, '1x', 44}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [12 12 12 12], ...
                'BackgroundColor', c.darkBlue);

            % Row 1: title
            title = uilabel(root, 'Text', 'Run Stimulus Decoder', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            % Row 2: session reference / path
            sub = uilabel(root, 'Text', ['Session: ' char(obj.session.reference) ...
                '    Path: ' obj.sessionPath()], ...
                'FontColor', c.white, 'HorizontalAlignment', 'center');
            sub.Layout.Row = 2; sub.Layout.Column = 1;

            % Row 3: stimulator selector + reload
            prow = uigridlayout(root, [1 3], ...
                'ColumnWidth', {90, '1x', 90}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            prow.Layout.Row = 3; prow.Layout.Column = 1;
            plbl = uilabel(prow, 'Text', 'Stimulator:', 'FontWeight', 'bold', ...
                'FontColor', c.white, 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'center');
            plbl.Layout.Column = 1;
            obj.probeDropdown = uidropdown(prow, 'Items', {'(none)'}, 'ItemsData', {}, ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ValueChangedFcn', @(~,~) obj.onProbeChanged());
            obj.probeDropdown.Layout.Column = 2;
            rb = uibutton(prow, 'Text', 'Reload', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.withWait('Loading stimulator probes...', ...
                    @() obj.reloadProbes()));
            rb.Layout.Column = 3;

            % Row 4: list header
            header = uilabel(root, ...
                'Text', 'Stimulus epochs (* = has stimulus_presentation):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            header.Layout.Row = 4; header.Layout.Column = 1;

            % Row 5: multi-select epoch list
            obj.epochList = uilistbox(root, 'Items', {}, 'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'FontName', get(groot, 'FixedWidthFontName'), ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.epochList.Layout.Row = 5; obj.epochList.Layout.Column = 1;

            % Row 6: overwrite checkbox + run button
            brow = uigridlayout(root, [1 3], ...
                'ColumnWidth', {'1x', 'fit', 150}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 12, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            brow.Layout.Row = 6; brow.Layout.Column = 1;
            obj.overwriteCheckbox = uicheckbox(brow, ...
                'Text', 'Re-decode selected (overwrite)', 'FontColor', c.white, ...
                'Value', false, ...
                'Tooltip', ['Remove and rebuild the stimulus_presentation documents ' ...
                    'of the selected epochs, even if they already exist']);
            obj.overwriteCheckbox.Layout.Column = 2;
            obj.runButton = uibutton(brow, 'push', 'Text', 'Run decoder', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, ...
                'FontColor', c.darkBlue, 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.runDecoder());
            obj.runButton.Layout.Column = 3;
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

        function reloadProbes(obj)
            try
                obj.stimulators = obj.session.getprobes('type', 'stimulator');
            catch
                obj.stimulators = {};
            end
            if ~iscell(obj.stimulators), obj.stimulators = {}; end
            if isempty(obj.stimulators)
                obj.probeDropdown.Items = {'(no stimulator probes)'};
                obj.probeDropdown.ItemsData = {};
                obj.clearEpochList();
                return;
            end
            labels = cell(1, numel(obj.stimulators));
            for i = 1:numel(obj.stimulators)
                labels{i} = char(obj.stimulators{i}.elementstring());
            end
            obj.probeDropdown.Items = labels;
            obj.probeDropdown.ItemsData = 1:numel(obj.stimulators);
            obj.probeDropdown.Value = 1;
            obj.onProbeChanged();
        end % reloadProbes

        function p = selectedProbe(obj)
            p = [];
            idx = obj.probeDropdown.Value;
            if isempty(idx) || ~isnumeric(idx), return; end
            if idx >= 1 && idx <= numel(obj.stimulators)
                p = obj.stimulators{idx};
            end
        end % selectedProbe

        function onProbeChanged(obj)
            obj.withWait('Loading epochs...', @() obj.reloadEpochs());
        end % onProbeChanged

        function reloadEpochs(obj)
            % list the selected probe's stimulus epochs, marking decoded ones
            % with a leading "*". Preserves the current selection by epoch id.
            prevSel = obj.selectedEpochIds();   % normalized cell of epoch ids
            p = obj.selectedProbe();
            if isempty(p)
                obj.clearEpochList();
                return;
            end
            try
                et = p.epochtable();
                obj.epochIds = {et.epoch_id};
            catch ME
                obj.epochIds = {};
                obj.epochList.Items = {['(could not read epochs: ' ME.message ')']};
                obj.epochList.ItemsData = {};
                obj.decodedEpochs = {};
                obj.updateButtonState();
                return;
            end
            obj.decodedEpochs = obj.decodedEpochIds(p);

            items = cell(1, numel(obj.epochIds));
            for i = 1:numel(obj.epochIds)
                mark = '  ';
                if ismember(obj.epochIds{i}, obj.decodedEpochs)
                    mark = '* ';
                end
                items{i} = [mark obj.epochIds{i}];
            end
            if isempty(items)
                obj.epochList.Items = {'(no stimulus epochs)'};
                obj.epochList.ItemsData = {};
            else
                obj.epochList.Items = items;
                obj.epochList.ItemsData = obj.epochIds;
                % restore any still-valid selection
                keep = intersect(prevSel, obj.epochIds, 'stable');
                obj.epochList.Value = keep;
            end
            obj.updateButtonState();
        end % reloadEpochs

        function ids = decodedEpochIds(obj, probe)
            % epoch ids that already have a stimulus_presentation document for
            % PROBE (a single database search, matched by the epochid field)
            ids = {};
            try
                q = ndi.query('','isa','stimulus_presentation','') & ...
                    ndi.query('','depends_on','stimulus_element_id', probe.id());
                docs = obj.session.database_search(q);
            catch
                docs = {};
            end
            for i = 1:numel(docs)
                try
                    ids{end+1} = docs{i}.document_properties.epochid.epochid; %#ok<AGROW>
                catch
                    % a stimulus_presentation without a readable epochid: skip
                end
            end
            ids = unique(ids);
        end % decodedEpochIds

        function clearEpochList(obj)
            obj.epochIds = {};
            obj.decodedEpochs = {};
            obj.epochList.Items = {};
            obj.epochList.ItemsData = {};
            obj.updateButtonState();
        end % clearEpochList

        function sel = selectedEpochIds(obj)
            % the epoch ids currently selected in the listbox ({} when the list
            % only holds a placeholder item, which carries no ItemsData)
            if isempty(obj.epochList.ItemsData)
                sel = {};
                return;
            end
            sel = obj.epochList.Value;
            if isempty(sel)
                sel = {};
            elseif ischar(sel)
                sel = {sel};
            end
        end % selectedEpochIds

        function updateButtonState(obj)
            % Run is enabled when a probe is chosen and at least one epoch is
            % selected
            ok = ~isempty(obj.selectedProbe()) && ~isempty(obj.selectedEpochIds());
            obj.runButton.Enable = onOff(ok);
        end % updateButtonState

        % ---- decoding -------------------------------------------------------

        function runDecoder(obj)
            p = obj.selectedProbe();
            sel = obj.selectedEpochIds();
            if isempty(p) || isempty(sel)
                uialert(obj.fig, 'Choose a stimulator probe and select one or more epochs.', ...
                    'Nothing selected');
                return;
            end
            overwrite = obj.overwriteCheckbox.Value;

            % without overwrite, epochs that are already decoded are a no-op;
            % warn the user rather than appear to do nothing
            already = intersect(sel, obj.decodedEpochs, 'stable');
            if ~overwrite && numel(already) == numel(sel)
                uialert(obj.fig, ['Every selected epoch already has a ' ...
                    'stimulus_presentation document. Tick "Re-decode selected ' ...
                    '(overwrite)" to rebuild them.'], 'Already decoded');
                return;
            end

            obj.runButton.Enable = 'off';
            dlg = uiprogressdlg(obj.fig, 'Title', 'Please wait', ...
                'Message', sprintf('Decoding %d epoch(s)...', numel(sel)), ...
                'Indeterminate', 'on');
            restore = onCleanup(@() obj.finishRun(dlg)); %#ok<NASGU>

            try
                sd = ndi.app.stimulus.decoder(obj.session);
                newdocs = sd.parse_stimuli(p, double(overwrite), sel);
            catch ME
                uialert(obj.fig, ME.message, 'Decoding failed', 'Icon', 'error');
                return;
            end

            obj.reloadEpochs();   % refresh the "*" markers
            uialert(obj.fig, sprintf('Decoded %d epoch(s); wrote %d document(s).', ...
                numel(sel), numel(newdocs)), 'Done', 'Icon', 'success');
        end % runDecoder

        function finishRun(obj, dlg)
            if ~isempty(dlg) && isvalid(dlg), delete(dlg); end
            if isvalid(obj.runButton)
                obj.updateButtonState();
            end
        end % finishRun

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
