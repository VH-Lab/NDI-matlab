classdef ensembleMaker < ndi.gui.app.sessionApp
% NDI.GUI.APP.ENSEMBLEMAKER - GUI to build neuron ensembles for n-trode probes
%
%   OBJ = ndi.gui.app.ensembleMaker(SESSION)
%
%   Opens a window (in the NDI Cloud colour scheme) that builds spiking-neuron
%   ensembles for the n-trode probes of the ndi.session SESSION by calling
%   ndi.fun.ensemble.allElement. It lets you:
%
%     * See the session's n-trode probes in a multi-select listbox. A probe
%       that already has an ensemble built (an ndi.element.ensemble with at
%       least one epoch) is marked with a leading "*".
%     * Select one or more probes and click "Make Ensemble" to build (or extend)
%       their ensembles - one epoch per recorded epoch of each probe.
%
%   By default an epoch that already has an ensemble is left untouched. Tick
%   "Rebuild existing (replace)" to delete and rebuild the selected probes'
%   ensembles from scratch.
%
%   Ensembles produced here are what ndi.gui.app.katzExporter and
%   ndi.fun.export.blech_clust read when exporting.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from the
%   ndi.gui.navigator "Apps" menu.
%
%   Example:
%       S = ndi.session.dir('/path/to/session');
%       ndi.gui.app.ensembleMaker(S);
%
%   See also: ndi.gui.app.sessionApp, ndi.fun.ensemble.allElement,
%             ndi.fun.ensemble.create, ndi.element.ensemble,
%             ndi.gui.app.katzExporter

    properties (Constant)
        Name = "Ensemble Maker"      % ndi.gui.app.sessionApp menu label
        Category = "Ensembles"       % groups the app under an "Ensembles" submenu
    end

    properties (Access = private)
        session                 % the ndi.session being operated on
        fig                     % the uifigure

        % widgets
        probeList               % multi-select listbox of n-trode probes
        rebuildCheckbox         % "Rebuild existing (replace)"
        makeButton              % the "Make Ensemble" button

        % state
        probes = {}             % cell array of the session's n-trode probes
        haveEnsemble = {}       % element ids of probes that already have an ensemble
        waitDlg = []            % active "please wait" dialog (if any)
    end

    methods
        function obj = ensembleMaker(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
            % the initial database reads (probes, ensembles) can take a moment,
            % so show a "please wait" indicator over them
            obj.withWait('Loading n-trode probes...', @() obj.reloadProbes());
        end % ensembleMaker
    end

    methods (Access = private)

        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Ensemble Maker: ' char(obj.session.reference)], ...
                'Position', [100 100 560 500], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.ensembleMaker');

            root = uigridlayout(obj.fig, [5 1], ...
                'RowHeight', {30, 20, 22, '1x', 44}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [12 12 12 12], ...
                'BackgroundColor', c.darkBlue);

            % Row 1: title
            title = uilabel(root, 'Text', 'Make Neuron Ensembles', ...
                'FontSize', 16, 'FontWeight', 'bold', 'FontColor', c.white, ...
                'HorizontalAlignment', 'center');
            title.Layout.Row = 1; title.Layout.Column = 1;

            % Row 2: session reference / path
            sub = uilabel(root, 'Text', ['Session: ' char(obj.session.reference) ...
                '    Path: ' obj.sessionPath()], ...
                'FontColor', c.white, 'HorizontalAlignment', 'center');
            sub.Layout.Row = 2; sub.Layout.Column = 1;

            % Row 3: list header
            header = uilabel(root, 'Text', 'n-trode probes (* = has ensemble):', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            header.Layout.Row = 3; header.Layout.Column = 1;

            % Row 4: multi-select probe list
            obj.probeList = uilistbox(root, 'Items', {}, 'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'FontName', get(groot, 'FixedWidthFontName'), ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.probeList.Layout.Row = 4; obj.probeList.Layout.Column = 1;

            % Row 5: rebuild checkbox + make button + reload
            brow = uigridlayout(root, [1 4], ...
                'ColumnWidth', {'fit', '1x', 90, 150}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 12, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            brow.Layout.Row = 5; brow.Layout.Column = 1;
            obj.rebuildCheckbox = uicheckbox(brow, ...
                'Text', 'Rebuild existing (replace)', 'FontColor', c.white, ...
                'Value', false, ...
                'Tooltip', ['Delete and rebuild the selected probes'' ensembles, ' ...
                    'even for epochs that already have one']);
            obj.rebuildCheckbox.Layout.Column = 1;
            rb = uibutton(brow, 'Text', 'Reload', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.withWait('Loading n-trode probes...', ...
                    @() obj.reloadProbes()));
            rb.Layout.Column = 3;
            obj.makeButton = uibutton(brow, 'push', 'Text', 'Make Ensemble', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, ...
                'FontColor', c.darkBlue, 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.makeEnsembles());
            obj.makeButton.Layout.Column = 4;
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
            % list the session's n-trode probes, marking those that already have
            % an ensemble with a leading "*". Preserves the current selection.
            prevSel = obj.probeList.Value;   % array of probe indices
            try
                obj.probes = obj.session.getprobes('type', 'n-trode');
            catch
                obj.probes = {};
            end
            if ~iscell(obj.probes), obj.probes = {}; end
            obj.haveEnsemble = obj.probesWithEnsemble();

            n = numel(obj.probes);
            if n == 0
                obj.probeList.Items = {'(no n-trode probes)'};
                obj.probeList.ItemsData = [];
                obj.updateButtonState();
                return;
            end
            items = cell(1, n);
            for i = 1:n
                mark = '  ';
                if ismember(obj.probes{i}.id(), obj.haveEnsemble)
                    mark = '* ';
                end
                items{i} = [mark char(obj.probes{i}.elementstring())];
            end
            obj.probeList.Items = items;
            obj.probeList.ItemsData = 1:n;
            if ~isempty(prevSel) && isnumeric(prevSel)
                obj.probeList.Value = prevSel(prevSel >= 1 & prevSel <= n);
            end
            obj.updateButtonState();
        end % reloadProbes

        function ids = probesWithEnsemble(obj)
            % element ids of the probes that already have an ensemble element
            % carrying at least one epoch (a single search over the session's
            % ensemble elements, matched by their underlying element)
            ids = {};
            try
                allEns = obj.session.getelements('element.type', 'ensemble');
            catch
                allEns = {};
            end
            for k = 1:numel(allEns)
                e = allEns{k};
                u = [];
                try
                    u = e.underlying_element;
                catch
                    u = [];
                end
                if isempty(u), continue; end
                % only count probes whose ensemble has at least one epoch built
                try
                    hasEpoch = ~isempty(ndi.fun.ensemble.findExisting(obj.session, e));
                catch
                    hasEpoch = false;
                end
                if hasEpoch
                    ids{end+1} = u.id(); %#ok<AGROW>
                end
            end
            ids = unique(ids);
        end % probesWithEnsemble

        function sel = selectedProbes(obj)
            % the probe objects currently selected in the listbox
            sel = {};
            if isempty(obj.probeList.ItemsData)
                return;
            end
            idx = obj.probeList.Value;
            if isempty(idx) || ~isnumeric(idx), return; end
            idx = idx(idx >= 1 & idx <= numel(obj.probes));
            sel = obj.probes(idx);
        end % selectedProbes

        function updateButtonState(obj)
            obj.makeButton.Enable = onOff(~isempty(obj.selectedProbes()));
        end % updateButtonState

        % ---- ensemble building ----------------------------------------------

        function makeEnsembles(obj)
            sel = obj.selectedProbes();
            if isempty(sel)
                uialert(obj.fig, 'Select one or more n-trode probes.', 'Nothing selected');
                return;
            end
            rebuild = obj.rebuildCheckbox.Value;
            if rebuild
                ifexists = 'replace';
            else
                ifexists = 'skip';
            end

            obj.makeButton.Enable = 'off';
            nSel = numel(sel);
            dlg = uiprogressdlg(obj.fig, 'Title', 'Please wait', ...
                'Message', sprintf('Building ensembles for %d probe(s)...', nSel), ...
                'Value', 0);
            restore = onCleanup(@() obj.finishMake(dlg)); %#ok<NASGU>

            errs = {};
            for k = 1:nSel
                p = sel{k};
                lbl = char(p.elementstring());
                if isvalid(dlg)
                    dlg.Message = sprintf('Building ensemble for %s (%d of %d)...', ...
                        lbl, k, nSel);
                    dlg.Value = (k-1)/nSel;
                end
                try
                    ndi.fun.ensemble.allElement(obj.session, p, ...
                        'IfExists', ifexists, 'Verbose', false);
                catch ME
                    errs{end+1} = sprintf('%s: %s', lbl, ME.message); %#ok<AGROW>
                end
            end
            if isvalid(dlg), dlg.Value = 1; end

            obj.reloadProbes();   % refresh the "*" markers

            if ~isempty(errs)
                uialert(obj.fig, strjoin(errs, newline), 'Some ensembles failed', ...
                    'Icon', 'error');
            else
                uialert(obj.fig, sprintf('Built ensembles for %d probe(s).', nSel), ...
                    'Done', 'Icon', 'success');
            end
        end % makeEnsembles

        function finishMake(obj, dlg)
            if ~isempty(dlg) && isvalid(dlg), delete(dlg); end
            if isvalid(obj.makeButton)
                obj.updateButtonState();
            end
        end % finishMake

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
