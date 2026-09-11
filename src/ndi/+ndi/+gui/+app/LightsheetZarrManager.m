classdef LightsheetZarrManager < ndi.gui.app.sessionApp
% NDI.GUI.APP.LIGHTSHEETZARRMANAGER - list, add, view and delete lightsheet OME-Zarr pyramids
%
%   ndi.gui.app.LightsheetZarrManager(SESSION)
%
%   Lists the lightsheetZarrPyramid documents in a session, grouped by
%   subject and paired with their level counts, and lets the user add,
%   open or remove one. Reached from the navigator's per-session Apps
%   menu.
%
%   WHAT IS LISTED IS PYRAMIDS, NOT ZARR STORES. An OME-Zarr store on
%   disk is the input; what lands in the database is a
%   lightsheetZarrPyramid plus one lightsheetZarrLevel per level, and
%   optionally a fileReference. A single store frequently produces two
%   parents (a mean pyramid and a max pyramid), listed as two rows.
%
%   VIEWING IS SOMEONE ELSE'S JOB. The viewer is napari, which is
%   Python, so View does not draw anything here: it builds a command
%   line via NDI.FUN.DOC.LIGHTSHEET.VIEWCOMMAND and hands it to a
%   launcher, by default /usr/local/bin/napariViewLightsheet. That
%   launcher is a shell wrapper rather than the console script itself
%   because MATLAB exports library paths of its own, and a Python
%   process started from MATLAB picks up MATLAB's copies of libraries
%   it must not use; the wrapper scrubs the environment before exec'ing
%   the real entry point. viewCommand builds the command and is pure,
%   so what will run can be shown in the dialog before it runs and can
%   be copied into a terminal when it does not.
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
        % A wrapper in /usr/local/bin rather than the console script in
        % a virtual environment: MATLAB exports library paths of its
        % own, and a Python process started from MATLAB loads MATLAB's
        % copies of libraries it must not use. The wrapper scrubs those
        % and then execs the real entry point. Overridden by the
        % preference GUI.LightsheetZarrManager.ViewerLauncher, which
        % the View dialog writes.
        DefaultViewerLauncher = "/usr/local/bin/napariViewLightsheet"
    end

    properties (Access = private)
        session
        fig
        table
        statusLabel
        rows = struct([])
    end

    methods
        function obj = LightsheetZarrManager(sessionObj, options)
            arguments
                sessionObj (1,1)
                options.build (1,1) logical = true
            end
            obj.session = sessionObj;
            if options.build
                obj.buildUI();
                obj.refresh();
            end
        end
    end

    methods (Access = private)
        function buildUI(obj)
            obj.fig = uifigure('Name', char(obj.Name), ...
                'Position', [100 100 900 500]);
            g = uigridlayout(obj.fig, [3 1], 'RowHeight', {'fit', '1x', 'fit'});

            % Top bar: Add / View / Delete
            top = uigridlayout(g, [1 5], 'ColumnWidth', {80, 80, 80, '1x', 100});
            uibutton(top, 'Text', 'Add',    'ButtonPushedFcn', @(~,~) obj.onAdd());
            uibutton(top, 'Text', 'View',   'ButtonPushedFcn', @(~,~) obj.onView());
            uibutton(top, 'Text', 'Delete', 'ButtonPushedFcn', @(~,~) obj.onDelete());
            uilabel(top,  'Text', '');
            uibutton(top, 'Text', 'Refresh','ButtonPushedFcn', @(~,~) obj.refresh());

            obj.table = uitable(g, ...
                'ColumnName', {'label','reduction','subject','n_levels','shape_level0','dtype','id'}, ...
                'ColumnEditable', false);

            obj.statusLabel = uilabel(g, 'Text', '');
        end

        function refresh(obj)
            q = ndi.query('', 'isa', 'lightsheetZarrPyramid');
            docs = obj.session.database_search(q);
            n = numel(docs);
            rows = repmat(struct('label','','reduction','','subject','', ...
                'n_levels',0,'shape_level0','','dtype','','id',''), n, 1);
            for k = 1:n
                p = docs{k}.document_properties.lightsheetZarrPyramid;
                rows(k).label = char(p.label);
                rows(k).reduction = char(p.reduction);
                rows(k).subject = subjectLabel(docs{k});
                rows(k).n_levels = p.n_levels;
                rows(k).shape_level0 = mat2str(double(p.shape_level0));
                rows(k).dtype = char(p.dtype);
                rows(k).id = docs{k}.id();
            end
            obj.rows = rows;
            obj.table.Data = struct2table(rows, 'AsArray', true);
            obj.statusLabel.Text = sprintf('%d pyramids', n);
        end

        function onAdd(obj)
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

            subjectID = obj.pickSubject();
            if isempty(subjectID), return; end

            try
                ndi.fun.doc.lightsheet.fromOMEZarr(obj.session, zarrPath, ...
                    'subjectID', subjectID);
                obj.refresh();
            catch ME
                uialert(obj.fig, ME.message, 'Add failed');
            end
        end

        function onView(obj)
            row = obj.selectedRow();
            if isempty(row), return; end
            sessionPath = obj.session.path;
            launcher = ndi.gui.app.LightsheetZarrManager.launcherPath();

            cmd = ndi.fun.doc.lightsheet.viewCommand(launcher, sessionPath, row.id);
            if ~ispc, cmd = [cmd ' &']; else, cmd = ['start "napari" ' cmd]; end
            [status, output] = system(cmd);
            if status ~= 0
                uialert(obj.fig, sprintf('%s\n\n%s', cmd, output), ...
                    'Launch failed');
            end
        end

        function onDelete(obj)
            row = obj.selectedRow();
            if isempty(row), return; end
            plan = ndi.gui.app.LightsheetZarrManager.deletionPlan(obj.session, row.id);
            msg = sprintf('Delete pyramid %s and %d level documents?', ...
                row.label, plan.nLevels);
            answer = uiconfirm(obj.fig, msg, 'Delete', ...
                'Options', {'Delete', 'Cancel'}, 'DefaultOption', 'Cancel');
            if ~strcmp(answer, 'Delete'), return; end
            for k = 1:numel(plan.docsToRemove)
                obj.session.database_rm(plan.docsToRemove{k});
            end
            obj.refresh();
        end

        function row = selectedRow(obj)
            sel = obj.table.Selection;
            if isempty(sel)
                uialert(obj.fig, 'Select a pyramid first.', 'No selection');
                row = [];
                return;
            end
            row = obj.rows(sel(1));
        end

        function id = pickSubject(obj)
            subs = obj.session.database_search(ndi.query('', 'isa', 'subject'));
            if isempty(subs)
                uialert(obj.fig, 'No subject documents in this session.', ...
                    'No subject');
                id = '';
                return;
            end
            labels = cellfun(@(d) char(d.document_properties.subject.local_identifier), ...
                subs, 'UniformOutput', false);
            [idx, ok] = listdlg('PromptString', 'Subject:', ...
                'SelectionMode', 'single', 'ListString', labels);
            if ~ok, id = ''; return; end
            id = subs{idx}.id();
        end
    end

    methods (Static)
        function p = launcherPath()
            p = char(ndi.gui.app.LightsheetZarrManager.DefaultViewerLauncher);
            try
                v = ndi.preferences.get('GUI.LightsheetZarrManager.ViewerLauncher');
                if ~isempty(char(v)), p = char(v); end
            catch
            end
        end

        function plan = deletionPlan(session, pyramidID)
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
    end
end

function s = subjectLabel(pyramidDoc)
    s = '';
    try
        dep = pyramidDoc.dependency_value('subject_id');
        if ~isempty(dep)
            s = char(dep);
        end
    catch
    end
end
