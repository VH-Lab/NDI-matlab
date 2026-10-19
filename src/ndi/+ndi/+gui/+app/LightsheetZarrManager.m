classdef LightsheetZarrManager < ndi.gui.app.sessionApp
% NDI.GUI.APP.LIGHTSHEETZARRMANAGER - list, add, view and delete lightsheet OME-Zarr pyramids
%
%   ndi.gui.app.LightsheetZarrManager(SESSION)
%
%   Lists the lightsheetZarrPyramid documents in a session, paired with
%   their subject and level counts, and lets the user add, open or
%   remove one. Reached from the navigator's per-session Apps menu.
%
%   WHAT IS LISTED IS PYRAMIDS, NOT ZARR STORES. An OME-Zarr store on
%   disk is the input; what lands in the database is a
%   lightsheetZarrPyramid plus one lightsheetZarrLevel per level. A
%   single store frequently produces two parents (a mean pyramid and a
%   max pyramid), listed as two rows.
%
%   VIEWING IS SOMEONE ELSE'S JOB. The viewer is napari, which is
%   Python, so View does not draw anything here: it builds a command
%   line via NDI.FUN.DOC.LIGHTSHEET.VIEWCOMMAND and hands it to a
%   launcher: NDI-python's napariViewLightsheet console script, found by
%   ndi.python.findCommand (install it with ndi.python.install()). It is
%   started with NDI_FROM_MATLAB=1, which tells the Python side to drop
%   the library paths MATLAB exports before loading anything, so no
%   shell wrapper is needed. viewCommand builds the command and is pure,
%   so what will run can be shown in the dialog before it runs and can
%   be copied into a terminal when it does not.
%
%   ADDING CAN GO STRAIGHT TO THE CLOUD. Add... offers this session or a
%   session of an NDI Cloud dataset. For the cloud, the user picks the
%   dataset, one of its sessions and a subject of that session; the
%   pyramid is built here, its chunks are uploaded and checked
%   (ndi.cloud.upload.SessionWriter), and its documents land in that
%   session. Nothing is added to the local session.
%
%   DELETING IS A CASCADE. Levels depend on the pyramid, so removing a
%   pyramid orphans everything beneath it. deletionPlan enumerates that
%   first and the confirmation names the counts, because "delete 1
%   document" and "delete 32 documents" should not look the same.
%
%   Example:
%       S = ndi.session.dir('mysession','/path/to/session');
%       ndi.gui.app.LightsheetZarrManager(S);
%
%   See also: ndi.fun.doc.lightsheet.fromOMEZarr,
%             ndi.fun.doc.lightsheet.viewCommand,
%             ndi.gui.app.GEFManager (the pattern this app mirrors)

    properties (Constant)
        Name = "Lightsheet Zarr Manager"
        Category = "Lightsheet microscopy"

        % Where the napari launcher lives when nobody has said otherwise.
        % Empty means "find it": ndi.python.findCommand('napariViewLightsheet')
        % looks in ~/.ndi/bin (where ndi.python.install puts it) and the
        % other usual places. Overridden by the preference
        % GUI.LightsheetZarrManager.ViewerLauncher.
        DefaultViewerLauncher = ""
    end

    properties (Access = private)
        session
        fig
        table
        statusLabel
        rows = struct([])
        % The View dialog, kept so a second click RAISES the open one
        % rather than stacking another. Non-modal (see onView), so
        % without this the button would build one dialog per press.
        viewDialog = matlab.ui.Figure.empty
    end

    methods
        function obj = LightsheetZarrManager(sessionObj, options)
            arguments
                sessionObj (1,1)
                % build=false constructs the model without a figure, so
                % every decision this app makes is checkable with no
                % display. Same arrangement GEFManager uses.
                options.build (1,1) logical = true
            end
            obj.session = sessionObj;
            if options.build
                obj.buildUI();
                obj.reload();
            end
        end

        function reload(obj)
            obj.rows = ndi.gui.app.LightsheetZarrManager.pyramidRows(obj.session);
            if ~isempty(obj.fig) && isvalid(obj.fig)
                obj.table.Data = ndi.gui.app.LightsheetZarrManager.rowsToCell(obj.rows);
                obj.setStatus(sprintf('%d pyramid(s).', numel(obj.rows)));
            end
        end

        function refresh(obj)
        % REFRESH - backward-compatible alias for reload
            obj.reload();
        end
    end

    % =====================================================================
    % The model. Static and pure: no figure, no state, so it is testable
    % headlessly and a test failure names a decision rather than a widget.
    % =====================================================================
    methods (Static)

        function rows = pyramidRows(session)
        % PYRAMIDROWS - one row per lightsheetZarrPyramid, with subject names
        %
        %   The subject column shows local_identifier, not the raw id: an
        %   id names the subject uniquely and tells the reader nothing.
        %   The lookup is done ONCE for the whole session rather than
        %   per row -- a session with 20 pyramids would otherwise make
        %   20 subject queries to answer one question.
            docs = session.database_search( ...
                ndi.query('','isa','lightsheetZarrPyramid'));
            subjectNames = ndi.gui.app.LightsheetZarrManager.subjectNameMap(session);
            rows = struct('id',{},'label',{},'reduction',{},'subject',{}, ...
                'subjectID',{},'nLevels',{},'shapeLevel0',{},'dtype',{},'doc',{});
            for i = 1:numel(docs)
                d = docs{i};
                p = d.document_properties.lightsheetZarrPyramid;
                k = numel(rows) + 1;
                rows(k).id = d.id();
                rows(k).doc = d;
                rows(k).label = ndi.gui.app.LightsheetZarrManager.field(p,'label','');
                rows(k).subjectID = ndi.gui.app.LightsheetZarrManager.dependency(d,'subject_id');
                rows(k).subject = ndi.gui.app.LightsheetZarrManager.lookup( ...
                    subjectNames, rows(k).subjectID, rows(k).subjectID);

                % Level count and reduction come from the child level
                % docs, not the parent -- the parent schema has neither
                % an n_levels nor a reduction field. Reductions are per
                % level (reduction_function on lightsheetZarrLevel);
                % the parent's pyramid_type names the source volume, not
                % the reduction. See NDI-matlab#979 review 2026-09-25.
                q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
                q2 = ndi.query('depends_on', 'depends_on', ...
                    'lightsheetZarrPyramid_id', rows(k).id);
                levelDocs = session.database_search(q1 & q2);
                rows(k).nLevels = numel(levelDocs);
                rows(k).reduction = ndi.gui.app.LightsheetZarrManager.joinReductions(levelDocs);

                shp = ndi.gui.app.LightsheetZarrManager.field(p,'shape_level0',[]);
                rows(k).shapeLevel0 = shp;
                rows(k).dtype = ndi.gui.app.LightsheetZarrManager.field(p,'dtype','');
            end
        end

        function s = joinReductions(levelDocs)
        % joinReductions - unique non-'none' reduction_function values
        %   Reads reduction_function from each lightsheetZarrLevel doc
        %   and returns them joined by "/", with 'none' (the raw level 0
        %   marker) filtered out. When only 'none' levels exist, returns
        %   the string 'none' so the column doesn't lie about a missing
        %   ladder.
            seen = strings(1, numel(levelDocs));
            for j = 1:numel(levelDocs)
                lp = levelDocs{j}.document_properties.lightsheetZarrLevel;
                seen(j) = string(ndi.gui.app.LightsheetZarrManager.field( ...
                    lp, 'reduction_function', 'none'));
            end
            reductions = unique(seen);
            reductions = reductions(reductions ~= "none");
            if isempty(reductions)
                s = 'none';
            else
                s = char(strjoin(reductions, '/'));
            end
        end

        function m = subjectNameMap(session)
        % SUBJECTNAMEMAP - subject document id -> local_identifier
        %
        %   containers.Map so the lookup is one query for the session
        %   rather than one per pyramid. A subject with no
        %   local_identifier is left out rather than mapped to '': the
        %   caller's default is the id, and an empty cell in the Subject
        %   column would say the pyramid has no subject, which is a
        %   different and worse claim than showing the id.
            m = containers.Map('KeyType','char','ValueType','char');
            docs = session.database_search(ndi.query('','isa','subject'));
            for i = 1:numel(docs)
                p = docs{i}.document_properties;
                if ~isfield(p,'subject'), continue; end
                nm = ndi.gui.app.LightsheetZarrManager.field(p.subject,'local_identifier','');
                if ~isempty(nm)
                    m(docs{i}.id()) = char(nm);
                end
            end
        end

        function plan = deletionPlan(session, pyramidID)
        % DELETIONPLAN - the pyramid and every level that depends on it
        %
        %   Public and static so a caller without a display can preview
        %   what a delete would remove.
            plan = struct();
            plan.pyramidID = char(pyramidID);
            q1 = ndi.query('', 'isa', 'lightsheetZarrLevel');
            q2 = ndi.query('depends_on', 'depends_on', ...
                'lightsheetZarrPyramid_id', plan.pyramidID);
            levelDocs = session.database_search(q1 & q2);
            parentDoc = session.database_search(ndi.query('base.id', ...
                'exact_string', plan.pyramidID));
            plan.nLevels = numel(levelDocs);
            plan.docsToRemove = [levelDocs(:); parentDoc(:)];
        end

        function msg = deletionMessage(plan, label)
        % DELETIONMESSAGE - the confirmation text for a deletion
        %
        %   Names the pyramid and the level count so "delete 1 document"
        %   and "delete 32 documents" do not read the same.
            if nargin < 2, label = ''; end
            if isempty(label), label = plan.pyramidID; end
            msg = sprintf(['This removes %d document(s):\n\n' ...
                '  1 pyramid (%s)\n  %d level(s)\n\n' ...
                'The levels go because the pyramid they belong to goes. ' ...
                'This cannot be undone.'], ...
                1 + plan.nLevels, label, plan.nLevels);
        end

        function p = launcherPath()
        % LAUNCHERPATH - the viewer launcher, from preferences or found
        %
        %   ndi.python.findCommand('napariViewLightsheet'), which honours
        %   the preference GUI.LightsheetZarrManager.ViewerLauncher when
        %   it names a file that exists. When nothing is found this
        %   returns the preference as written, or '' -- never raises: the
        %   dialog can still open, and the field it opens with is
        %   editable.
            p = ndi.gui.app.LightsheetZarrManager.resolveLauncher('');
            if isempty(p)
                try
                    p = strtrim(char(ndi.preferences.get( ...
                        'GUI.LightsheetZarrManager.ViewerLauncher')));
                catch
                end
            end
        end

        function p = resolveLauncher(p)
        % RESOLVELAUNCHER - the launcher typed, or the one found if none was
        %
        %   An explicit launcher always wins. An empty one means "find
        %   it", and stays empty when NDI-python's napariViewLightsheet
        %   is not installed; viewCommand then says how to install it.
            p = strtrim(char(p));
            if isempty(p)
                try
                    p = ndi.python.findCommand('napariViewLightsheet');
                catch
                    p = '';
                end
            end
        end

        function setLauncherPath(p)
        % SETLAUNCHERPATH - remember the launcher for next time
        %
        %   Failing to persist must not cost the launch about to happen.
            try
                ndi.preferences.set('GUI.LightsheetZarrManager.ViewerLauncher', string(p));
            catch
            end
        end

        function paper(h, c)
        % PAPER - put a control on the cloud palette's white body
        %
        %   The figure and its layouts are on c.offWhite, but the
        %   CONTROLS default to MATLAB's grey chrome, which reads as a
        %   grey app with a tinted border. Defensive: a missing handle
        %   or a control without a BackgroundColor is a no-op.
            if isempty(h) || ~isvalid(h)
                return;
            end
            try %#ok<TRYNC>
                h.BackgroundColor = c.white;
            end
            try %#ok<TRYNC>
                h.FontColor = c.darkBlue;
            end
        end

        function accent(btn, c)
        % ACCENT - style a button in the NDI Cloud accent
        %
        %   Light blue on navy, matching ndi.util.ListDialog and the
        %   cloud .mlapp apps. A missing or deleted handle is a no-op
        %   rather than an error: this is styling, and losing the
        %   window over a colour would be a poor trade.
            if isempty(btn) || ~isvalid(btn)
                return;
            end
            btn.BackgroundColor = c.lightBlue;
            btn.FontColor       = c.darkBlue;
            btn.FontWeight      = 'bold';
        end

        function labels = sessionLabels(sessions)
        % SESSIONLABELS - list entries for cloud sessions: reference, then id
            labels = arrayfun(@(x) sprintf('%s  (%s)', ...
                x.session_reference, x.session_id), sessions, ...
                'UniformOutput', false);
            labels = reshape(labels, 1, []);
        end
    end

    % =====================================================================
    methods (Static, Access = private)

        function v = field(s, name, dflt)
            if isstruct(s) && isfield(s, name), v = s.(name); else, v = dflt; end
        end

        function v = dependency(d, name)
            try
                v = d.dependency_value(name);
            catch
                v = '';
            end
            if isempty(v), v = ''; end
        end

        function v = lookup(m, key, dflt)
            v = dflt;
            if isempty(key) || ~isKey(m, char(key)), return; end
            v = m(char(key));
        end

        function c = rowsToCell(rows)
            c = cell(numel(rows), 6);
            for i = 1:numel(rows)
                c{i,1} = rows(i).label;
                c{i,2} = rows(i).subject;
                c{i,3} = rows(i).reduction;
                c{i,4} = rows(i).nLevels;
                if isempty(rows(i).shapeLevel0)
                    c{i,5} = '';
                else
                    c{i,5} = mat2str(double(rows(i).shapeLevel0));
                end
                c{i,6} = rows(i).dtype;
            end
        end
    end

    % =====================================================================
    methods (Access = private)

        function buildUI(obj)
            c = ndi.gui.cloudColors();
            obj.fig = uifigure('Name','Lightsheet Zarr Manager', ...
                'Position',[100 100 900 460], 'Color', c.offWhite);
            % The View dialog is a separate top-level window; closing
            % the manager has to take it along, or an orphaned dialog
            % would report its result to a status bar that no longer
            % exists.
            obj.fig.CloseRequestFcn = @(~,~) obj.onClose();
            g = uigridlayout(obj.fig,[4 5]);
            g.RowHeight = {28, '1x', 30, 22};
            g.ColumnWidth = {'1x', 90, 90, 90, 90};
            g.BackgroundColor = c.offWhite;

            % Navy header bar with white text, matching the cloud apps
            % and ndi.util.ListDialog.
            hb = uigridlayout(g,[1 1]);
            hb.Layout.Row = 1; hb.Layout.Column = [1 5];
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb,'Text','Lightsheet OME-Zarr pyramids', ...
                'FontColor', c.white, 'FontWeight','bold', 'FontSize',14, ...
                'VerticalAlignment','center');

            obj.table = uitable(g, 'ColumnName', ...
                {'Label','Subject','Reduction','Levels','Shape (level 0)','dtype'});
            obj.table.Layout.Row = 2; obj.table.Layout.Column = [1 5];
            ndi.gui.app.LightsheetZarrManager.paper(obj.table, c);

            b = uibutton(g,'Text','Reload','ButtonPushedFcn',@(~,~) obj.reload());
            b.Layout.Row = 3; b.Layout.Column = 2;
            ndi.gui.app.LightsheetZarrManager.accent(b, c);
            b = uibutton(g,'Text','View...','ButtonPushedFcn',@(~,~) obj.onView());
            b.Layout.Row = 3; b.Layout.Column = 3;
            ndi.gui.app.LightsheetZarrManager.accent(b, c);
            b = uibutton(g,'Text','Add...','ButtonPushedFcn',@(~,~) obj.onAdd());
            b.Layout.Row = 3; b.Layout.Column = 4;
            ndi.gui.app.LightsheetZarrManager.accent(b, c);
            b = uibutton(g,'Text','Delete','ButtonPushedFcn',@(~,~) obj.onDelete());
            b.Layout.Row = 3; b.Layout.Column = 5;
            ndi.gui.app.LightsheetZarrManager.accent(b, c);

            obj.statusLabel = uilabel(g,'Text','','FontColor', c.darkBlue);
            obj.statusLabel.Layout.Row = 4; obj.statusLabel.Layout.Column = [1 5];
        end

        function setStatus(obj, msg)
            if ~isempty(obj.statusLabel) && isvalid(obj.statusLabel)
                obj.statusLabel.Text = msg;
            end
        end

        function r = selectedRow(obj)
            r = [];
            sel = obj.table.Selection;
            if isempty(sel) || isempty(obj.rows), return; end
            r = obj.rows(sel(1));
        end

        function onView(obj)
        % ONVIEW - the launcher dialog, and then the launch
        %
        %   A dialog rather than a button that just runs, because the
        %   things it asks about cannot be recovered afterwards from
        %   the window that opens: which channel, which reduction,
        %   which level, and what the layer is called. And because the
        %   launcher is a path on the user's machine that NDI cannot
        %   know, only default.
        %
        %   THE COMMAND IS ON SCREEN before it runs, and stays readable
        %   afterwards. Launching another program is the step most
        %   likely to fail for reasons NDI cannot see -- a wrapper not
        %   installed, an environment that is not what it looks like --
        %   and a command the user can copy into a terminal turns that
        %   from a shrug into something they can act on.
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            sessionPath = '';
            try
                sessionPath = obj.session.getpath();
            catch
                try
                    sessionPath = obj.session.path;
                catch
                end
            end
            if isempty(sessionPath)
                uialert(obj.fig, ...
                    ['This session has no directory on disk. The napari ' ...
                     'viewer opens an ndi.session.dir, and there is ' ...
                     'nothing here for it to open.'], 'Nothing to view');
                return;
            end

            % One dialog at a time. Non-modal, so nothing stops the
            % button being pressed again; without this each press would
            % build another and the user would be editing whichever
            % landed on top while an older one held a different pyramid.
            if ~isempty(obj.viewDialog) && isvalid(obj.viewDialog)
                figure(obj.viewDialog);
                return;
            end

            c = ndi.gui.cloudColors();
            d = uifigure('Name','View in napari','Position',[120 120 660 430], ...
                'Color', c.offWhite);
            gl = uigridlayout(d,[9 3]);
            gl.RowHeight = {28, 40, 24, 24, 24, 24, 24, 24, 60};
            gl.ColumnWidth = {140, '1x', 100};
            gl.BackgroundColor = c.offWhite;

            hb = uigridlayout(gl,[1 1]);
            hb.Layout.Row = 1; hb.Layout.Column = [1 3];
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb,'Text','View in napari', ...
                'FontColor', c.white, 'FontWeight','bold', 'FontSize',14, ...
                'VerticalAlignment','center');

            intro = uilabel(gl,'WordWrap','on','Text', ...
                ['Opens this pyramid in napari. The viewer is a separate ' ...
                 'Python program: MATLAB starts it and does not wait for ' ...
                 'it. The command that will run is shown at the bottom.']);
            intro.Layout.Row = 2; intro.Layout.Column = [1 3];

            lab = uilabel(gl,'Text','Launcher');
            lab.Layout.Row = 3; lab.Layout.Column = 1;
            % Remembered so Go only writes the preference when the user
            % changed the launcher: a path that was merely found must not
            % be pinned over a later ndi.python.install().
            initialLauncher = ndi.gui.app.LightsheetZarrManager.launcherPath();
            ed = uieditfield(gl,'text','Value', initialLauncher);
            ed.Layout.Row = 3; ed.Layout.Column = 2;
            ndi.gui.app.LightsheetZarrManager.paper(ed, c);
            br = uibutton(gl,'Text','Browse...');
            br.Layout.Row = 3; br.Layout.Column = 3;
            ndi.gui.app.LightsheetZarrManager.accent(br, c);

            lab = uilabel(gl,'Text','Layer name');
            lab.Layout.Row = 4; lab.Layout.Column = 1;
            nameEd = uieditfield(gl,'text','Value', ...
                ndi.gui.app.LightsheetZarrManager.orEmpty(r.label));
            nameEd.Layout.Row = 4; nameEd.Layout.Column = [2 3];
            ndi.gui.app.LightsheetZarrManager.paper(nameEd, c);

            lab = uilabel(gl,'Text','Reduction');
            lab.Layout.Row = 5; lab.Layout.Column = 1;
            redDd = uidropdown(gl, 'Items', {'(as selected)','mean','max'}, ...
                'Value','(as selected)');
            redDd.Layout.Row = 5; redDd.Layout.Column = [2 3];
            ndi.gui.app.LightsheetZarrManager.paper(redDd, c);

            lab = uilabel(gl,'Text','Channel');
            lab.Layout.Row = 6; lab.Layout.Column = 1;
            chSpin = uispinner(gl,'Limits',[-1 32],'Value',-1,'Step',1);
            chSpin.Layout.Row = 6; chSpin.Layout.Column = [2 3];
            chSpin.Tooltip = '-1 opens all channels as separate napari layers';
            ndi.gui.app.LightsheetZarrManager.paper(chSpin, c);

            lab = uilabel(gl,'Text','Initial level');
            lab.Layout.Row = 7; lab.Layout.Column = 1;
            lvSpin = uispinner(gl,'Limits',[-1 32],'Value',-1,'Step',1);
            lvSpin.Layout.Row = 7; lvSpin.Layout.Column = [2 3];
            lvSpin.Tooltip = '-1 lets the viewer choose based on window size';
            ndi.gui.app.LightsheetZarrManager.paper(lvSpin, c);

            cbPanels = uicheckbox(gl,'Text','Control panels','Value',true);
            cbPanels.Layout.Row = 8; cbPanels.Layout.Column = [1 3];

            cmdArea = uitextarea(gl,'Editable','off','Value','');
            cmdArea.Layout.Row = 9; cmdArea.Layout.Column = [1 2];
            ndi.gui.app.LightsheetZarrManager.paper(cmdArea, c);
            go = uibutton(gl,'Text','Launch');
            ndi.gui.app.LightsheetZarrManager.accent(go, c);
            go.Layout.Row = 9; go.Layout.Column = 3;

            br.ButtonPushedFcn = @(~,~) localBrowse();
            go.ButtonPushedFcn = @(~,~) localGo();
            everything = {ed, nameEd, redDd, chSpin, lvSpin, cbPanels};
            for i = 1:numel(everything)
                everything{i}.ValueChangedFcn = @localRefresh;
            end

            % One log per launch, named now so the command shown is the
            % exact line that will run (and can be pasted in a terminal).
            logFile = ndi.fun.doc.lightsheet.viewerLogFile();

            localRefresh();
            obj.viewDialog = d;

            function [cmd, ok] = localCommand()
                ok = true;
                try
                    red = '';
                    if ~strcmp(redDd.Value, '(as selected)')
                        red = redDd.Value;
                    end
                    cmd = ndi.fun.doc.lightsheet.viewCommand( ...
                        ndi.gui.app.LightsheetZarrManager.resolveLauncher(ed.Value), ...
                        sessionPath, r.id, ...
                        'reduction', red, ...
                        'channel', chSpin.Value, ...
                        'level', lvSpin.Value, ...
                        'controls', cbPanels.Value, ...
                        'name', nameEd.Value);
                catch ME
                    cmd = ME.message;
                    ok = false;
                end
            end

            function localRefresh(~,~)
                % Show the full shell line: debugging on and output
                % appended to the log, as launchViewer will run it.
                [cmd, ok] = localCommand();
                if ok
                    cmd = ndi.fun.doc.lightsheet.viewerShellCommand( ...
                        cmd, logFile, false, true, ispc);
                end
                cmdArea.Value = cmd;
            end

            function localBrowse()
                [f,pth] = uigetfile('*','Select the napari viewer launcher');
                figure(d);
                if isequal(f,0), return; end
                ed.Value = fullfile(pth,f);
                localRefresh();
            end

            function localGo()
                cmd = localCommand();
                target = ndi.gui.app.LightsheetZarrManager.resolveLauncher(ed.Value);
                if isempty(target)
                    uialert(d, ['NDI-python''s napariViewLightsheet was ' ...
                        'not found. Run ndi.python.install() in MATLAB ' ...
                        'to install it, or point Launcher at it yourself.'], ...
                        'Launcher not found');
                    return;
                end
                if ~isempty(regexp(target,'[/\\]','once')) && ~isfile(target)
                    uialert(d, sprintf(['No launcher at\n  %s\n\nRun ' ...
                        'ndi.python.install() in MATLAB to install ' ...
                        'NDI-python''s napariViewLightsheet, or point ' ...
                        'this at the console script yourself.'], target), ...
                        'Launcher not found');
                    return;
                end
                % Only a launcher the user chose is remembered; clearing
                % the field goes back to finding it automatically.
                if ~strcmp(strtrim(ed.Value), initialLauncher)
                    ndi.gui.app.LightsheetZarrManager.setLauncherPath(strtrim(ed.Value));
                end
                % Debugging lines on, and the viewer's output kept in a
                % log in NDI's temporary folder: launched from here it
                % has no terminal, so the log is the only record of what
                % it fetched and what failed.
                status = ndi.fun.doc.lightsheet.launchViewer(cmd, 'logFile', logFile);
                delete(d);
                if status == 0
                    obj.setStatus(sprintf(['Launched the viewer for %s. ' ...
                        'Its log: %s'], obj.rowLabel(r), logFile));
                else
                    obj.setStatus(sprintf(['The launcher exited %d. ' ...
                        'The command was:  %s  (log: %s)'], status, cmd, logFile));
                end
            end
        end

        function onClose(obj)
        % ONCLOSE - shut the manager, and anything it opened
        %
        %   Only the View dialog is closed. The napari process is
        %   deliberately NOT touched: it was detached on purpose, it is
        %   somebody's picture, and closing the window that launched it
        %   is not a request to close it.
            if ~isempty(obj.viewDialog) && isvalid(obj.viewDialog)
                delete(obj.viewDialog);
            end
            delete(obj.fig);
        end

        function onDelete(obj)
            r = obj.selectedRow();
            if isempty(r)
                uialert(obj.fig,'Select a pyramid first.','Nothing selected');
                return;
            end
            plan = ndi.gui.app.LightsheetZarrManager.deletionPlan( ...
                obj.session, r.id);
            msg = ndi.gui.app.LightsheetZarrManager.deletionMessage( ...
                plan, obj.rowLabel(r));
            choice = uiconfirm(obj.fig, msg, 'Confirm delete', ...
                'Options',{'Delete','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            if ~strcmp(choice,'Delete'), return; end
            for k = 1:numel(plan.docsToRemove)
                obj.session.database_rm(plan.docsToRemove{k});
            end
            obj.setStatus(sprintf('Deleted %d document(s).', ...
                1 + plan.nLevels));
            obj.reload();
        end

        function onAdd(obj)
        % ONADD - ingest an OME-Zarr store, here or into a cloud session
        %
        %   The pyramid goes either to the session this manager shows or
        %   straight to a session of an NDI Cloud dataset (see
        %   onAddToCloud). Nothing in between is local in the second case.
            where = uiconfirm(obj.fig, ...
                ['Add the pyramid to this session, or straight to a ' ...
                 'session of an NDI Cloud dataset?'], 'Add pyramid', ...
                'Options', {'This session', 'NDI Cloud session...', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            switch where
                case 'This session'
                    obj.onAddLocal();
                case 'NDI Cloud session...'
                    obj.onAddToCloud();
            end
        end

        function zarrPath = pickZarr(~)
            zarrPath = '';
            [f, p] = uigetfile({'.zattrs', 'OME-Zarr .zattrs'; ...
                                '*',        'All Files (*)'}, ...
                'Select the OME-Zarr store .zattrs (or its containing folder)');
            if isequal(f, 0), return; end
            if strcmp(f, '.zattrs')
                zarrPath = p;
            else
                zarrPath = fullfile(p, f);
            end
            zarrPath = strip(zarrPath, 'right', filesep);
        end

        function onAddLocal(obj)
            zarrPath = obj.pickZarr();
            if isempty(zarrPath), return; end

            subjectID = obj.pickSubject();
            if isempty(subjectID), return; end

            obj.setStatus('Ingesting...');
            drawnow;
            try
                ndi.fun.doc.lightsheet.fromOMEZarr(obj.session, zarrPath, ...
                    'subjectID', subjectID);
                obj.setStatus('Ingest complete.');
                obj.reload();
            catch ME
                obj.setStatus('Ingest failed; see the message.');
                uialert(obj.fig, ME.message, 'Add failed');
            end
        end

        function onAddToCloud(obj)
        % ONADDTOCLOUD - build the pyramid and add it to a session of a cloud dataset
        %
        %   Dataset, then one of its sessions, then a subject of that
        %   session: a pyramid belongs to a session, and depends on a
        %   subject in it. The chunks are materialized and uploaded by
        %   ndi.cloud.upload.SessionWriter, which checks each file against
        %   NDI Cloud's CRC-32 before any document is added. The result
        %   is not listed here: this table shows the local session.
            zarrPath = obj.pickZarr();
            if isempty(zarrPath), return; end

            try
                datasetId = ndi.cloud.ui.dialog.selectCloudDataset("private");
            catch ME
                if ~strcmp(ME.identifier, 'NDI:CloudDialog:UserCanceled')
                    uialert(obj.fig, ME.message, 'Could not list datasets');
                end
                return;
            end
            datasetId = char(datasetId);

            obj.setStatus('Reading the dataset''s sessions...');
            drawnow;
            try
                sessions = ndi.cloud.upload.SessionWriter.listSessions(datasetId);
            catch ME
                obj.setStatus('');
                uialert(obj.fig, ME.message, 'Could not read the dataset');
                return;
            end
            obj.setStatus('');
            if isempty(sessions)
                uialert(obj.fig, ['This dataset has no sessions. A pyramid ' ...
                    'is added to a session of a dataset, not to the ' ...
                    'dataset itself.'], 'No sessions');
                return;
            end
            [idx, ok] = listdlg('PromptString', 'Session:', ...
                'SelectionMode', 'single', 'ListSize', [400 250], ...
                'ListString', ndi.gui.app.LightsheetZarrManager.sessionLabels(sessions));
            if ~ok, return; end
            session = sessions(idx);

            try
                subjects = ndi.cloud.upload.SessionWriter.listSubjects( ...
                    datasetId, session.session_id);
            catch ME
                uialert(obj.fig, ME.message, 'Could not read the session');
                return;
            end
            if isempty(subjects)
                uialert(obj.fig, sprintf(['Session %s has no subjects. Add ' ...
                    'the subject to that session first.'], ...
                    session.session_reference), 'No subject');
                return;
            end
            [idx, ok] = listdlg('PromptString', 'Subject:', ...
                'SelectionMode', 'single', 'ListSize', [400 250], ...
                'ListString', {subjects.local_identifier});
            if ~ok, return; end
            subjectID = subjects(idx).id;

            go = uiconfirm(obj.fig, sprintf(['Build the pyramid from\n%s\n' ...
                'and add it to session %s of the cloud dataset?\n\n' ...
                'Every chunk is built here and uploaded; for a large ' ...
                'volume this takes a long time and needs free disk for ' ...
                'the chunks until the upload ends. Progress is in the ' ...
                'Command Window.'], zarrPath, session.session_reference), ...
                'Add to NDI Cloud', 'Options', {'Add', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 2);
            if ~strcmp(go, 'Add'), return; end

            obj.setStatus('Building and uploading; see the Command Window...');
            drawnow;
            try
                writer = ndi.cloud.upload.SessionWriter(datasetId, session.session_id);
                [~, ~, info] = ndi.fun.doc.lightsheet.fromOMEZarr(writer, zarrPath, ...
                    'subjectID', subjectID, 'codec', 'blosc-zstd');
                obj.setStatus(sprintf(['Added %d document(s) and %d file(s) ' ...
                    '(%.1f MB) to cloud session %s.'], info.cloud.documents, ...
                    info.cloud.files, info.cloud.bytes / 1e6, ...
                    session.session_reference));
            catch ME
                obj.setStatus('Upload failed; see the message.');
                uialert(obj.fig, ME.message, 'Add to NDI Cloud failed');
            end
        end

        function id = pickSubject(obj)
            subs = obj.session.database_search(ndi.query('', 'isa', 'subject'));
            if isempty(subs)
                uialert(obj.fig, 'No subject documents in this session.', ...
                    'No subject');
                id = '';
                return;
            end
            labels = cellfun(@(x) char( ...
                x.document_properties.subject.local_identifier), ...
                subs, 'UniformOutput', false);
            [idx, ok] = listdlg('PromptString', 'Subject:', ...
                'SelectionMode', 'single', 'ListString', labels);
            if ~ok, id = ''; return; end
            id = subs{idx}.id();
        end

        function s = rowLabel(~, r)
            s = r.label;
            if isempty(s), s = r.id; end
        end
    end

    methods (Static, Access = private)
        function s = orEmpty(v)
            if isempty(v), s = ''; else, s = char(v); end
        end
    end
end
