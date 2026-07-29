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
        variesText              % text area: parameters that vary + their values
        constantTable           % table: parameters held constant + their value
        overwriteCheckbox       % "Re-decode selected (overwrite)"
        runButton               % the "Run decoder" button

        % state
        stimulators = {}        % cell array of the session's stimulator probes
        epochIds = {}           % epoch ids of the selected probe, in list order
        decodedEpochs = {}      % epoch ids that already have a stimulus_presentation
        presDocs = {}           % stimulus_presentation docs (parallel to decodedEpochs)
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
                'Position', [100 100 880 540], ...
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

            % the epoch list (left, ~40%) and the stimulus-parameter panels
            % (right, ~60%) share the same 2-column split so their headers and
            % bodies line up
            splitCols = {'2x', '3x'};    % 40% / 60%

            % Row 4: headers for the two halves
            hrow = uigridlayout(root, [1 2], ...
                'ColumnWidth', splitCols, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            hrow.Layout.Row = 4; hrow.Layout.Column = 1;
            lhdr = uilabel(hrow, ...
                'Text', 'Stimulus epochs (* = has stimulus_presentation):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            lhdr.Layout.Column = 1;
            rhdr = uilabel(hrow, ...
                'Text', 'Stimulus parameters (selected epoch(s)):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            rhdr.Layout.Column = 2;

            % Row 5: split - epoch list on the left, parameter panels on the right
            srow = uigridlayout(root, [1 2], ...
                'ColumnWidth', splitCols, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 8, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            srow.Layout.Row = 5; srow.Layout.Column = 1;

            % left: multi-select epoch list
            obj.epochList = uilistbox(srow, 'Items', {}, 'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'FontName', get(groot, 'FixedWidthFontName'), ...
                'ValueChangedFcn', @(~,~) obj.onEpochSelectionChanged());
            obj.epochList.Layout.Column = 1;

            % right: "What varies" (top) and "What is constant" (bottom)
            pcol = uigridlayout(srow, [4 1], ...
                'RowHeight', {18, '1x', 18, '1x'}, 'ColumnWidth', {'1x'}, ...
                'RowSpacing', 4, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            pcol.Layout.Column = 2;

            vlbl = uilabel(pcol, 'Text', 'What varies', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            vlbl.Layout.Row = 1; vlbl.Layout.Column = 1;
            obj.variesText = uitextarea(pcol, 'Editable', 'off', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'FontName', get(groot, 'FixedWidthFontName'), ...
                'Value', {''});
            obj.variesText.Layout.Row = 2; obj.variesText.Layout.Column = 1;

            clbl = uilabel(pcol, 'Text', 'What is constant', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            clbl.Layout.Row = 3; clbl.Layout.Column = 1;
            obj.constantTable = uitable(pcol, ...
                'ColumnName', {'Parameter', 'Value'}, ...
                'ColumnWidth', {'1x', '1x'}, 'RowName', {}, ...
                'Data', cell(0, 2));
            obj.constantTable.Layout.Row = 4; obj.constantTable.Layout.Column = 1;

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
                obj.presDocs = {};
                obj.updateButtonState();
                obj.updateStimulusInfo();
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
            obj.updateStimulusInfo();
        end % reloadEpochs

        function ids = decodedEpochIds(obj, probe)
            % epoch ids that already have a stimulus_presentation document for
            % PROBE (a single database search, matched by the epochid field).
            % Also caches the documents (obj.presDocs, parallel to the returned
            % ids) so the "what varies / what is constant" panels can be filled
            % without another database read on every selection change.
            ids = {};
            obj.presDocs = {};
            try
                q = ndi.query('','isa','stimulus_presentation','') & ...
                    ndi.query('','depends_on','stimulus_element_id', probe.id());
                docs = obj.session.database_search(q);
            catch
                docs = {};
            end
            for i = 1:numel(docs)
                try
                    thisId = docs{i}.document_properties.epochid.epochid;
                catch
                    % a stimulus_presentation without a readable epochid: skip
                    continue;
                end
                if ~ismember(thisId, ids)
                    ids{end+1} = thisId;          %#ok<AGROW>
                    obj.presDocs{end+1} = docs{i}; %#ok<AGROW>
                end
            end
        end % decodedEpochIds

        function docs = presDocsForEpochs(obj, epochIds)
            % the cached stimulus_presentation documents whose epoch id is in
            % EPOCHIDS (a cell array), as a cell array of ndi.document
            docs = {};
            for i = 1:numel(obj.decodedEpochs)
                if ismember(obj.decodedEpochs{i}, epochIds)
                    docs{end+1} = obj.presDocs{i}; %#ok<AGROW>
                end
            end
        end % presDocsForEpochs

        function clearEpochList(obj)
            obj.epochIds = {};
            obj.decodedEpochs = {};
            obj.presDocs = {};
            obj.epochList.Items = {};
            obj.epochList.ItemsData = {};
            obj.updateButtonState();
            obj.updateStimulusInfo();
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

        function onEpochSelectionChanged(obj)
            obj.updateButtonState();
            obj.updateStimulusInfo();
        end % onEpochSelectionChanged

        % ---- "what varies / what is constant" panels ------------------------

        function updateStimulusInfo(obj)
            % fill the "What varies" text area and the "What is constant" table
            % from the stimulus_presentation documents of the selected epochs
            if isempty(obj.variesText) || ~isvalid(obj.variesText)
                return;   % panels not built yet (called during construction)
            end

            sel = obj.selectedEpochIds();
            docs = obj.presDocsForEpochs(sel);

            if isempty(sel)
                obj.setInfoMessage('(select one or more epochs)');
                return;
            end
            if isempty(docs)
                obj.setInfoMessage(['(no stimulus_presentation for the ' ...
                    'selected epoch(s) - run the decoder first)']);
                return;
            end

            try
                [varies, constant] = ndi.fun.stimulus.whatVaries(docs);
            catch ME
                obj.setInfoMessage(['(could not read stimuli: ' ME.message ')']);
                return;
            end

            % "What varies": one line per parameter, "name = <values>"
            if isempty(varies)
                lines = {'(nothing varies across these stimuli)'};
            else
                lines = cell(1, numel(varies));
                for i = 1:numel(varies)
                    lines{i} = [varies(i).parameter ' = ' ...
                        obj.valueToText(varies(i).values)];
                end
            end
            obj.variesText.Value = lines;

            % "What is constant": a Parameter / Value table
            if isempty(constant)
                obj.constantTable.Data = cell(0, 2);
            else
                data = cell(numel(constant), 2);
                for i = 1:numel(constant)
                    data{i, 1} = constant(i).parameter;
                    data{i, 2} = obj.valueToText(constant(i).value);
                end
                obj.constantTable.Data = data;
            end
        end % updateStimulusInfo

        function setInfoMessage(obj, msg)
            % show a single status line in both panels (nothing to report)
            obj.variesText.Value = {msg};
            obj.constantTable.Data = cell(0, 2);
        end % setInfoMessage

        function s = valueToText(obj, v)
            % a compact one-line text for a parameter value, as produced by
            % ndi.fun.stimulus.whatVaries. Numeric/logical values (including the
            % arrays of varying values) use mat2str; cells and strings are
            % formatted element by element.
            if isnumeric(v) || islogical(v)
                s = mat2str(v);
            elseif ischar(v)
                s = v;
            elseif isstring(v)
                s = char(strjoin(v(:).', ', '));
            elseif iscell(v)
                parts = cell(1, numel(v));
                for i = 1:numel(v)
                    parts{i} = obj.valueToText(v{i});
                end
                s = ['{' strjoin(parts, ', ') '}'];
            else
                s = ['<' class(v) '>'];
            end
        end % valueToText

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
