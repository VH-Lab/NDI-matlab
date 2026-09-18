classdef stimulusResponse < ndi.gui.app.sessionApp
% NDI.GUI.APP.STIMULUSRESPONSE - GUI to compute stimulus responses for elements
%
%   OBJ = ndi.gui.app.stimulusResponse(SESSION)
%
%   Opens a window (in the NDI Cloud colour scheme) that drives
%   ndi.app.stimulus.tuning_response.stimulus_responses for the ndi.session
%   SESSION. It lets you:
%
%     * Choose a stimulator probe from a dropdown of the session's
%       'stimulator'-type probes.
%     * Choose one or more element types to compute responses for, from a
%       multi-select listbox (currently just "spikes").
%     * Tick "Replace existing responses" to rebuild responses from scratch.
%
%   When run, for each element of the chosen type(s):
%
%     * If "Replace existing responses" is ticked, a single (OR) database
%       search first finds all stimulus_response documents for the chosen
%       stimulator and the elements of the chosen type(s); those documents
%       (and their scalar-parameter documents) are removed, then responses are
%       recomputed for every element.
%     * If it is not ticked, one search first lists the stimulus_response
%       documents that already exist for the chosen stimulator. Any element
%       that already has a response is left untouched; responses are computed
%       only for elements that do not yet have one.
%
%   Responses require that the stimuli have already been decoded and their
%   control stimuli labeled (see ndi.gui.app.stimulusDecoder); without the
%   'stimulus_presentation' and 'control_stimulus_ids' documents no responses
%   are produced.
%
%   Progress is shown in an NDI progress bar (ndi.gui.component.ProgressBarWindow),
%   which docks into an open navigator's Progress pane when one is present.
%
%   This is a session GUI app (see ndi.gui.app.sessionApp): its constructor
%   takes the ndi.session as its first argument, so it can be launched from the
%   ndi.gui.navigator "Apps" menu.
%
%   Example:
%       S = ndi.session.dir('/path/to/session');
%       ndi.gui.app.stimulusResponse(S);
%
%   See also: ndi.gui.app.sessionApp, ndi.gui.app.stimulusDecoder,
%             ndi.app.stimulus.tuning_response, ndi.gui.component.ProgressBarWindow

    properties (Constant)
        Name = "Stimulus Response"   % ndi.gui.app.sessionApp menu label
        Category = "Stimulus"        % groups the app under a "Stimulus" submenu
    end

    % Element types the user can compute responses on. For now only spiking
    % elements are offered; add types here as they become supported.
    properties (Constant, Access = private)
        ElementTypes = {'spikes'}
    end

    properties (Access = private)
        session                 % the ndi.session being operated on
        fig                     % the uifigure

        % widgets
        probeDropdown           % popup of the session's stimulator probes
        typeList                % multi-select listbox of element types
        replaceCheckbox         % "Replace existing responses"
        runButton               % the "Compute responses" button

        % state
        stimulators = {}        % cell array of the session's stimulator probes
        waitDlg = []            % active "please wait" dialog (if any)
    end

    methods
        function obj = stimulusResponse(session)
            arguments
                session (1,1) ndi.session
            end
            obj.session = session;
            obj.build();
            obj.withWait('Loading stimulator probes...', @() obj.reloadProbes());
        end % stimulusResponse
    end

    methods (Access = private)

        function build(obj)
            c = ndi.gui.cloudColors();

            obj.fig = uifigure('Name', ['Stimulus Response: ' char(obj.session.reference)], ...
                'Position', [100 100 640 460], ...
                'Color', c.darkBlue, ...
                'Tag', 'ndi.gui.app.stimulusResponse');

            root = uigridlayout(obj.fig, [6 1], ...
                'RowHeight', {30, 20, 32, 22, '1x', 44}, ...
                'ColumnWidth', {'1x'}, ...
                'RowSpacing', 8, 'Padding', [12 12 12 12], ...
                'BackgroundColor', c.darkBlue);

            % Row 1: title
            title = uilabel(root, 'Text', 'Compute Stimulus Responses', ...
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
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.probeDropdown.Layout.Column = 2;
            rb = uibutton(prow, 'Text', 'Reload', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.withWait('Loading stimulator probes...', ...
                    @() obj.reloadProbes()));
            rb.Layout.Column = 3;

            % Row 4: element-type header
            lhdr = uilabel(root, 'Text', 'Element types to compute on:', ...
                'FontWeight', 'bold', 'FontColor', c.white);
            lhdr.Layout.Row = 4; lhdr.Layout.Column = 1;

            % Row 5: element-type listbox
            obj.typeList = uilistbox(root, 'Items', obj.ElementTypes, ...
                'Multiselect', 'on', ...
                'BackgroundColor', c.white, 'FontColor', c.darkBlue, ...
                'Value', obj.ElementTypes, ...
                'ValueChangedFcn', @(~,~) obj.updateButtonState());
            obj.typeList.Layout.Row = 5; obj.typeList.Layout.Column = 1;

            % Row 6: replace checkbox + run button
            brow = uigridlayout(root, [1 3], ...
                'ColumnWidth', {'fit', '1x', 170}, 'RowHeight', {'1x'}, ...
                'ColumnSpacing', 12, 'Padding', [0 0 0 0], ...
                'BackgroundColor', c.darkBlue);
            brow.Layout.Row = 6; brow.Layout.Column = 1;
            obj.replaceCheckbox = uicheckbox(brow, ...
                'Text', 'Replace existing responses', 'FontColor', c.white, ...
                'Value', false, ...
                'Tooltip', ['Remove and rebuild every stimulus_response document ' ...
                    'for the chosen stimulator and element type(s); otherwise only ' ...
                    'elements without an existing response are computed']);
            obj.replaceCheckbox.Layout.Column = 1;
            obj.runButton = uibutton(brow, 'push', 'Text', 'Compute responses', ...
                'FontWeight', 'bold', 'BackgroundColor', c.lightBlue, ...
                'FontColor', c.darkBlue, 'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) obj.runResponses());
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
                obj.updateButtonState();
                return;
            end
            labels = cell(1, numel(obj.stimulators));
            for i = 1:numel(obj.stimulators)
                labels{i} = char(obj.stimulators{i}.elementstring());
            end
            obj.probeDropdown.Items = labels;
            obj.probeDropdown.ItemsData = 1:numel(obj.stimulators);
            obj.probeDropdown.Value = 1;
            obj.updateButtonState();
        end % reloadProbes

        function p = selectedProbe(obj)
            p = [];
            idx = obj.probeDropdown.Value;
            if isempty(idx) || ~isnumeric(idx), return; end
            if idx >= 1 && idx <= numel(obj.stimulators)
                p = obj.stimulators{idx};
            end
        end % selectedProbe

        function types = selectedTypes(obj)
            % the element types currently selected in the listbox, as a cell of
            % char
            types = obj.typeList.Value;
            if isempty(types)
                types = {};
            elseif ischar(types)
                types = {types};
            end
        end % selectedTypes

        function updateButtonState(obj)
            % Run is enabled when a probe is chosen and at least one element
            % type is selected
            ok = ~isempty(obj.selectedProbe()) && ~isempty(obj.selectedTypes());
            obj.runButton.Enable = onOff(ok);
        end % updateButtonState

        % ---- computation ----------------------------------------------------

        function runResponses(obj)
            p = obj.selectedProbe();
            types = obj.selectedTypes();
            if isempty(p) || isempty(types)
                uialert(obj.fig, ['Choose a stimulator probe and at least one ' ...
                    'element type.'], 'Nothing selected');
                return;
            end
            replace = obj.replaceCheckbox.Value;

            % gather the elements of the chosen type(s)
            [elems, elemTypes] = obj.withWaitOut('Finding elements...', ...
                @() obj.elementsOfTypes(types));
            if isempty(elems)
                uialert(obj.fig, ['No elements of the selected type(s) were found ' ...
                    'in this session.'], 'No elements');
                return;
            end

            obj.runButton.Enable = 'off';
            restoreBtn = onCleanup(@() obj.finishRun()); %#ok<NASGU>

            rapp = ndi.app.stimulus.tuning_response(obj.session);

            % Decide which elements to compute, and clean up first if replacing.
            if replace
                % one (OR) search over all chosen elements, then remove the
                % matching stimulus_response documents (and their parameters)
                obj.removeExistingResponses(p, elems);
                todo = true(1, numel(elems));
            else
                % one search to list which elements already have a response;
                % skip those, compute the rest
                existingElemIds = obj.existingResponseElementIds(p);
                todo = true(1, numel(elems));
                for k = 1:numel(elems)
                    todo(k) = ~ismember(char(elems{k}.id()), existingElemIds);
                end
            end

            nTodo = nnz(todo);
            if nTodo == 0
                uialert(obj.fig, ['Every element of the selected type(s) already ' ...
                    'has a stimulus response. Tick "Replace existing responses" ' ...
                    'to rebuild them.'], 'Nothing to do');
                return;
            end

            % NDI progress bar (docks into an open navigator's Progress pane)
            pbTag = ['stimresp_' char(p.id())];
            pbw = i_makeBar('Stimulus Response', ...
                sprintf('Computing responses (%d element(s))', nTodo), pbTag);

            computed = 0; skipped = numel(elems) - nTodo; failed = 0;
            done = 0;
            for k = 1:numel(elems)
                if ~todo(k)
                    continue;
                end
                try
                    % reset=0: for replace we already removed the old documents
                    % above; for the skip path the element has none. Either way
                    % this avoids duplicate documents.
                    rapp.stimulus_responses(p, elems{k}, 0);
                    computed = computed + 1;
                catch ME
                    failed = failed + 1;
                    warning('ndi:gui:app:stimulusResponse', ...
                        'Could not compute responses for %s (%s): %s', ...
                        char(elems{k}.elementstring()), elemTypes{k}, ME.message);
                end
                done = done + 1;
                i_updateBar(pbw, pbTag, done / nTodo);
            end
            i_closeBar(pbw, pbTag);

            msg = sprintf('Computed responses for %d element(s); skipped %d already done.', ...
                computed, skipped);
            if failed > 0
                msg = [msg sprintf(' %d element(s) failed - see the command window.', failed)];
                uialert(obj.fig, msg, 'Done with errors', 'Icon', 'warning');
            else
                uialert(obj.fig, msg, 'Done', 'Icon', 'success');
            end
        end % runResponses

        function [elems, elemTypes] = elementsOfTypes(obj, types)
            % all elements whose element.type is one of TYPES, with a parallel
            % cell ELEMTYPES recording each element's type
            elems = {}; elemTypes = {};
            for t = 1:numel(types)
                try
                    e = obj.session.getelements('element.type', types{t});
                catch
                    e = {};
                end
                if ~iscell(e), e = {}; end
                for i = 1:numel(e)
                    elems{end+1} = e{i};           %#ok<AGROW>
                    elemTypes{end+1} = types{t};   %#ok<AGROW>
                end
            end
        end % elementsOfTypes

        function q = responseQuery(~, p, elems)
            % stimulus_response documents for stimulator P and any element in
            % ELEMS - a single query built as a big OR over the elements
            base = ndi.query('','isa','stimulus_response','') & ...
                ndi.query('','depends_on','stimulator_id', p.id());
            elemQ = [];
            for k = 1:numel(elems)
                eq = ndi.query('','depends_on','element_id', elems{k}.id());
                if isempty(elemQ)
                    elemQ = eq;
                else
                    elemQ = elemQ | eq;
                end
            end
            if isempty(elemQ)
                q = base;
            else
                q = base & elemQ;
            end
        end % responseQuery

        function removeExistingResponses(obj, p, elems)
            % remove the stimulus_response documents for stimulator P and the
            % given ELEMS (one OR search), along with their scalar-parameter
            % documents so none are left orphaned
            try
                docs = obj.session.database_search(obj.responseQuery(p, elems));
            catch
                docs = {};
            end
            if isempty(docs), return; end
            pdocs = {};
            for i = 1:numel(docs)
                try
                    pid = docs{i}.dependency_value('stimulus_response_scalar_parameters_id', ...
                        'ErrorIfNotFound', 0);
                catch
                    pid = '';
                end
                if ~isempty(pid)
                    try
                        pdocs = cat(2, pdocs, obj.session.database_search( ...
                            ndi.query('base.id','exact_string', pid, '')));
                    catch
                    end
                end
            end
            obj.session.database_rm(docs);
            if ~isempty(pdocs)
                obj.session.database_rm(pdocs);
            end
        end % removeExistingResponses

        function ids = existingResponseElementIds(obj, p)
            % the ids of the elements that already have at least one
            % stimulus_response document for stimulator P
            ids = {};
            try
                docs = obj.session.database_search( ...
                    ndi.query('','isa','stimulus_response','') & ...
                    ndi.query('','depends_on','stimulator_id', p.id()));
            catch
                docs = {};
            end
            for i = 1:numel(docs)
                try
                    eid = docs{i}.dependency_value('element_id', 'ErrorIfNotFound', 0);
                catch
                    eid = '';
                end
                if ~isempty(eid) && ~ismember(eid, ids)
                    ids{end+1} = eid;   %#ok<AGROW>
                end
            end
        end % existingResponseElementIds

        function finishRun(obj)
            if isvalid(obj.runButton)
                obj.updateButtonState();
            end
        end % finishRun

        % ---- shared "please wait" helpers (nestable) ------------------------

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

        function varargout = withWaitOut(obj, msg, fn)
            % like withWait, but forwards FN's outputs
            nested = ~isempty(obj.waitDlg) && isvalid(obj.waitDlg);
            cleaner = []; %#ok<NASGU>
            if ~nested && ~isempty(obj.fig) && isvalid(obj.fig)
                obj.waitDlg = uiprogressdlg(obj.fig, 'Title', 'Please wait', ...
                    'Message', msg, 'Indeterminate', 'on');
                cleaner = onCleanup(@() obj.clearWait());
            end
            [varargout{1:nargout}] = fn();
        end % withWaitOut

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

function pbw = i_makeBar(titleStr, labelStr, tag)
    % ndi.gui.component.ProgressBarWindow docks into an open navigator's Progress
    % pane, or opens a standalone window if no navigator is open.
    pbw = [];
    try
        pbw = ndi.gui.component.ProgressBarWindow(titleStr);
        pbw.addBar('Label', labelStr, 'Tag', tag, 'Auto', false);
    catch
        pbw = [];
    end
end

function i_updateBar(pbw, tag, frac)
    try
        if ~isempty(pbw) && isvalid(pbw)
            pbw.updateBar(tag, max(0, min(1, frac)));
            drawnow limitrate;
        end
    catch
    end
end

function i_closeBar(pbw, tag)
    try
        if ~isempty(pbw) && isvalid(pbw)
            pbw.removeBar(tag);
        end
    catch
    end
end
