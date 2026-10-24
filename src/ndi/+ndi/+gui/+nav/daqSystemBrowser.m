classdef daqSystemBrowser < handle
%NDI.GUI.NAV.DAQSYSTEMBROWSER Read-only browser of a session's DAQ systems.
%
%   NDI.GUI.NAV.DAQSYSTEMBROWSER(SESSION) opens a window that shows every
%   DAQ system of an ndi.session, so the user can see how each one finds
%   its data files and its epoch probe maps. It is a viewer only; nothing
%   is edited.
%
%   It is the target of the navigator's per-session "Session > DAQ
%   Systems..." menu item (see ndi.gui.nav.datasetsPane).
%
%   Syntax:
%       ndi.gui.nav.daqSystemBrowser(session)
%       obj = ndi.gui.nav.daqSystemBrowser(session, 'Visible', 'off')
%
%   Layout (master-detail):
%       Left  - a list of the session's DAQ systems by name.
%       Right - a scrollable panel describing the selected DAQ system, in
%               sections:
%                 Acquisition         - DAQ system class, DAQ reader and
%                                       metadata readers.
%                 Files in each epoch - the file navigator and its
%                                       fileparameters filematch patterns,
%                                       one per line.
%                 Epoch probe map     - the epochprobemap_class and the
%                                       epochprobemap_fileparameters
%                                       patterns (or the default location
%                                       when none are set).
%                 Example epoch       - on request ("Load epochs"), a
%                                       chooser of the DAQ system's epochs;
%                                       for the chosen epoch, a table of
%                                       the actual files on disk, the
%                                       pattern each one matches, and which
%                                       file is the epoch probe map. This
%                                       reads the disk, so it runs only
%                                       when asked.
%   Class names are shown by their last component (e.g. "intan" for
%   ndi.daq.reader.mfdaq.intan); hovering shows the full name.
%
%   The window reads the session's DAQ systems once, at construction, with
%   daqsystem_load. Each field is read defensively so a DAQ system missing
%   one part still shows the rest.
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.nav.sessionInfo,
%             ndi.daq.system, ndi.file.navigator

    properties (SetAccess = protected)
        Session      % the ndi.session being browsed
        Figure       % the uifigure
        List         % uilistbox of DAQ system names
        DetailPanel  % uipanel holding the selected DAQ system's details
        DetailGrid   % uigridlayout inside DetailPanel (rebuilt per selection)
        Daqs = {}    % cell array of the session's DAQ system objects
        Info         % struct array of DAQ system descriptions (see describe)
        Epochs = {}  % per DAQ system: [] until loaded, else a struct with
                     %   fields number and id (see loadEpochs)
    end

    properties (Access = private)
        EpochDropdown   % uidropdown of the selected DAQ system's epochs
        EpochButton     % "Load epochs" uibutton
        EpochTable      % uitable of the chosen epoch's files
    end

    properties (Constant)
        EpochColumnNames = {'File', 'Matches pattern', 'Role'}
    end

    methods
        function obj = daqSystemBrowser(session, options)
            arguments
                session (1,1) ndi.session
                options.Visible (1,:) char = 'on'
            end
            obj.Session = session;
            obj.Daqs = obj.daqSystems();
            obj.Info = ndi.gui.nav.daqSystemBrowser.describeAll(obj.Daqs);
            obj.Epochs = cell(1, numel(obj.Daqs));
            obj.build(options.Visible);
        end

        function select(obj, k)
            %SELECT Show the details of DAQ system number K.
            if k < 1 || k > numel(obj.Info)
                return;
            end
            obj.List.Value = k;
            obj.showDetails(k);
        end
    end

    methods (Access = private)
        function build(obj, visible)
            %BUILD Construct the window: DAQ system list and detail panel.
            c = ndi.gui.cloudColors();

            obj.Figure = uifigure('Name', ['DAQ systems: ' obj.sessionRef()], ...
                'Position', [160 120 900 620], ...
                'Color',    c.darkBlue, ...
                'Visible',  visible, ...
                'Tag',      'ndiNavigatorDaqSystemBrowser');

            g = uigridlayout(obj.Figure, [1 2]);
            g.ColumnWidth     = {200, '1x'};
            g.RowHeight       = {'1x'};
            g.ColumnSpacing   = 10;
            g.Padding         = [10 10 10 10];
            g.BackgroundColor = c.darkBlue;

            left = uigridlayout(g, [2 1]);
            left.RowHeight       = {'fit', '1x'};
            left.Padding         = [0 0 0 0];
            left.BackgroundColor = c.darkBlue;
            uilabel(left, 'Text', 'DAQ systems', 'FontWeight', 'bold', ...
                'FontColor', c.white);

            names = {obj.Info.name};
            obj.List = uilistbox(left, ...
                'BackgroundColor', c.white, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             'ndiDaqSystemList');
            if isempty(names)
                obj.List.Items  = {'(no DAQ systems)'};
                obj.List.Enable = 'off';
            else
                obj.List.Items     = names;
                obj.List.ItemsData = 1:numel(names);
                obj.List.ValueChangedFcn = @(src, ~) obj.showDetails(src.Value);
            end

            obj.DetailPanel = uipanel(g, ...
                'BackgroundColor', c.white, ...
                'BorderType',      'none');

            if isempty(names)
                obj.DetailGrid = uigridlayout(obj.DetailPanel, [1 1], ...
                    'BackgroundColor', c.white);
                uilabel(obj.DetailGrid, 'FontColor', c.darkBlue, ...
                    'Text', 'This session has no DAQ systems.');
            else
                obj.select(1);
            end
        end

        function showDetails(obj, k)
            %SHOWDETAILS Rebuild the detail panel for DAQ system K.
            c = ndi.gui.cloudColors();
            s = obj.Info(k);
            short = @ndi.gui.nav.daqSystemBrowser.shortClassName;
            none  = '(none)';

            % Each entry is {kind, label, value, tooltip}; the grid is sized
            % from this list and then filled in order.
            items = {{'title', s.name, '', ''}};
            items{end+1} = {'section', 'Acquisition', '', ''};
            items{end+1} = {'field', 'DAQ system class', short(s.daqClass), s.daqClass};
            items{end+1} = {'field', 'DAQ reader', short(s.readerClass), s.readerClass};
            items = obj.listItems(items, 'Metadata readers', s.metadataReaders, none);

            items{end+1} = {'section', 'Files in each epoch', '', ''};
            items{end+1} = {'field', 'File navigator', short(s.navigatorClass), s.navigatorClass};
            items = obj.listItems(items, 'File patterns', s.fileParameters, none);

            items{end+1} = {'section', 'Epoch probe map', '', ''};
            items{end+1} = {'field', 'Class', short(s.epochProbeMapClass), s.epochProbeMapClass};
            items = obj.listItems(items, 'File patterns', s.epochProbeMapFileParameters, ...
                ndi.gui.nav.daqSystemBrowser.defaultEpochProbeMapText());

            items{end+1} = {'section', 'Example epoch', '', ''};
            items{end+1} = {'epochControls', 'Epoch', '', ''};
            items{end+1} = {'epochTable', '', '', ''};

            if ~isempty(obj.DetailGrid) && isvalid(obj.DetailGrid)
                delete(obj.DetailGrid);
            end
            n = numel(items);
            grid = uigridlayout(obj.DetailPanel, [n 2]);
            grid.ColumnWidth     = {150, '1x'};
            grid.RowHeight       = repmat({'fit'}, 1, n);
            grid.RowHeight{end}  = 200;
            grid.RowSpacing      = 4;
            grid.Padding         = [14 12 14 12];
            grid.BackgroundColor = c.white;
            grid.Scrollable      = 'on';
            obj.DetailGrid = grid;

            for r = 1:n
                it = items{r};
                switch it{1}
                    case 'title'
                        obj.addLabel(grid, r, [1 2], it{2}, 'FontSize', 18, ...
                            'FontWeight', 'bold');
                    case 'section'
                        obj.addLabel(grid, r, [1 2], it{2}, 'FontSize', 14, ...
                            'FontWeight', 'bold', 'FontColor', c.lightBlue, ...
                            'VerticalAlignment', 'bottom');
                    case 'field'
                        if ~isempty(it{2})
                            obj.addLabel(grid, r, 1, [it{2} ':']);
                        end
                        if isempty(it{3})
                            obj.addLabel(grid, r, 2, none, 'FontAngle', 'italic');
                        else
                            obj.addLabel(grid, r, 2, it{3}, 'Tooltip', it{4});
                        end
                    case 'pattern'
                        if ~isempty(it{2})
                            obj.addLabel(grid, r, 1, [it{2} ':']);
                        end
                        obj.addLabel(grid, r, 2, it{3}, 'FontName', 'Monospaced');
                    case 'note'
                        if ~isempty(it{2})
                            obj.addLabel(grid, r, 1, [it{2} ':']);
                        end
                        obj.addLabel(grid, r, 2, it{3}, 'FontAngle', 'italic');
                    case 'epochControls'
                        obj.addLabel(grid, r, 1, [it{2} ':']);
                        obj.buildEpochControls(grid, r, k);
                    case 'epochTable'
                        obj.EpochTable = uitable(grid, ...
                            'ColumnName',      obj.EpochColumnNames, ...
                            'ColumnWidth',     {'1x', '1x', 'fit'}, ...
                            'RowName',         {}, ...
                            'Data',            {'(choose "Load epochs" to see the files of an epoch)', '', ''}, ...
                            'BackgroundColor', c.white, ...
                            'ForegroundColor', c.darkBlue, ...
                            'Tag',             'ndiDaqSystemEpochFiles');
                        obj.EpochTable.Layout.Row    = r;
                        obj.EpochTable.Layout.Column = [1 2];
                end
            end

            % Epochs already loaded for this DAQ system are shown at once.
            if ~isempty(obj.Epochs{k})
                obj.fillEpochDropdown(k);
            end
        end

        function buildEpochControls(obj, grid, row, k)
            %BUILDEPOCHCONTROLS The epoch chooser and "Load epochs" button.
            c = ndi.gui.cloudColors();
            sub = uigridlayout(grid, [1 2]);
            sub.Layout.Row      = row;
            sub.Layout.Column   = 2;
            sub.ColumnWidth     = {'1x', 'fit'};
            sub.RowHeight       = {'fit'};
            sub.Padding         = [0 0 0 0];
            sub.BackgroundColor = c.white;
            obj.EpochDropdown = uidropdown(sub, ...
                'Items',  {'(not loaded)'}, ...
                'Enable', 'off', ...
                'Tag',    'ndiDaqSystemEpochChooser', ...
                'ValueChangedFcn', @(src, ~) obj.showEpochFiles(k, src.Value));
            obj.EpochButton = uibutton(sub, ...
                'Text',            'Load epochs', ...
                'Tooltip',         'Read this DAQ system''s epochs from disk', ...
                'BackgroundColor', c.lightBlue, ...
                'FontColor',       c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.loadEpochs(k));
        end

        function loadEpochs(obj, k)
            %LOADEPOCHS Read DAQ system K's epochs (on request) and list them.
            nav = ndi.gui.nav.daqSystemBrowser.getProp(obj.Daqs{k}, 'filenavigator');
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Load epochs', ...
                'Message', 'Reading epochs...', 'Indeterminate', 'on');
            try
                et = nav.epochtable();
            catch ME
                delete(dlg);
                uialert(obj.Figure, ME.message, 'Load epochs');
                return;
            end
            delete(dlg);
            ep = struct('number', {}, 'id', {});
            for i = 1:numel(et)
                ep(i).number = i;
                ep(i).id = '';
                if isfield(et, 'epoch_id')
                    ep(i).id = char(et(i).epoch_id);
                end
            end
            obj.Epochs{k} = ep;
            obj.fillEpochDropdown(k);
        end

        function fillEpochDropdown(obj, k)
            %FILLEPOCHDROPDOWN Populate the epoch chooser from obj.Epochs{K}
            %   and show the files of the first epoch.
            ep = obj.Epochs{k};
            obj.EpochButton.Enable = 'off';
            if isempty(ep)
                obj.EpochDropdown.Items = {'(no epochs)'};
                obj.EpochTable.Data = {'(this DAQ system has no epochs)', '', ''};
                return;
            end
            obj.EpochDropdown.Items = ndi.gui.nav.daqSystemBrowser.epochLabels([ep.number], {ep.id});
            obj.EpochDropdown.ItemsData = [ep.number];
            obj.EpochDropdown.Enable = 'on';
            obj.EpochDropdown.Value = ep(1).number;
            obj.showEpochFiles(k, ep(1).number);
        end

        function showEpochFiles(obj, k, n)
            %SHOWEPOCHFILES Table of epoch N's files for DAQ system K.
            nav = ndi.gui.nav.daqSystemBrowser.getProp(obj.Daqs{k}, 'filenavigator');
            try
                files = nav.getepochfiles_number(n);
            catch ME
                obj.EpochTable.Data = {['(could not read the epoch files: ' ME.message ')'], '', ''};
                return;
            end
            if ndi.file.navigator.isingested(files)
                obj.EpochTable.Data = {['(this epoch is ingested; its raw files ' ...
                    'are stored in the database)'], '', ''};
                return;
            end
            probeMapFile = '';
            try
                probeMapFile = nav.epochprobemapfilename(n);
            catch
            end
            obj.EpochTable.Data = ndi.gui.nav.daqSystemBrowser.epochFileRows( ...
                files, obj.Info(k).fileParameters, probeMapFile);
        end

        function lbl = addLabel(~, parent, row, col, text, varargin)
            %ADDLABEL A dark-blue label placed at ROW, COL of the grid.
            c = ndi.gui.cloudColors();
            lbl = uilabel(parent, 'Text', text, 'FontColor', c.darkBlue, ...
                'WordWrap', 'on', varargin{:});
            lbl.Layout.Row    = row;
            lbl.Layout.Column = col;
        end

        function daqs = daqSystems(obj)
            %DAQSYSTEMS Cell array of the session's DAQ system objects.
            try
                % No name filter: a 'name' regexp makes the database search
                % much slower on large databases, and every DAQ system is
                % wanted anyway.
                daqs = obj.Session.daqsystem_load();
            catch
                daqs = {};
            end
            if isempty(daqs)
                daqs = {};
            elseif ~iscell(daqs)
                daqs = {daqs};
            end
        end

        function ref = sessionRef(obj)
            %SESSIONREF Best-effort human-readable session reference.
            try
                ref = char(obj.Session.reference);
            catch
                ref = '';
            end
            if isempty(ref)
                ref = '(unnamed session)';
            end
        end
    end

    methods (Static)
        function info = describeAll(daqs)
            %DESCRIBEALL Struct array of describe() for each DAQ system in DAQS.
            info = ndi.gui.nav.daqSystemBrowser.describe([]);
            info = info([]);
            for i = 1:numel(daqs)
                info(end+1) = ndi.gui.nav.daqSystemBrowser.describe(daqs{i}); %#ok<AGROW>
            end
        end

        function s = describe(d)
            %DESCRIBE Display description of one DAQ system D.
            %   S is a struct with char fields name, daqClass, readerClass,
            %   navigatorClass and epochProbeMapClass, and cellstr fields
            %   fileParameters, epochProbeMapFileParameters and
            %   metadataReaders. D may be an ndi.daq.system or anything with
            %   the same properties (name, filenavigator, daqreader,
            %   daqmetadatareader); a part that cannot be read is left empty.
            %   DESCRIBE([]) returns the empty template.
            s = struct('name', '', 'daqClass', '', 'readerClass', '', ...
                'navigatorClass', '', 'fileParameters', {{}}, ...
                'epochProbeMapClass', '', 'epochProbeMapFileParameters', {{}}, ...
                'metadataReaders', {{}});
            if isempty(d)
                return;
            end
            s.daqClass = class(d);
            s.name = ndi.gui.nav.daqSystemBrowser.getText(d, 'name');

            reader = ndi.gui.nav.daqSystemBrowser.getProp(d, 'daqreader');
            if ~isempty(reader)
                s.readerClass = class(reader);
            end

            nav = ndi.gui.nav.daqSystemBrowser.getProp(d, 'filenavigator');
            if ~isempty(nav)
                s.navigatorClass = class(nav);
                s.fileParameters = ndi.gui.nav.daqSystemBrowser.filematchList( ...
                    ndi.gui.nav.daqSystemBrowser.getProp(nav, 'fileparameters'));
                s.epochProbeMapClass = ndi.gui.nav.daqSystemBrowser.getText(nav, 'epochprobemap_class');
                s.epochProbeMapFileParameters = ndi.gui.nav.daqSystemBrowser.filematchList( ...
                    ndi.gui.nav.daqSystemBrowser.getProp(nav, 'epochprobemap_fileparameters'));
            end

            mdr = ndi.gui.nav.daqSystemBrowser.getProp(d, 'daqmetadatareader');
            if ~isempty(mdr) && ~iscell(mdr)
                mdr = {mdr};
            end
            for i = 1:numel(mdr)
                m = mdr{i};
                entry = class(m);
                tsv = ndi.gui.nav.daqSystemBrowser.getText(m, 'tab_separated_file_parameter');
                if ~isempty(tsv)
                    entry = [entry ' (' tsv ')'];
                end
                s.metadataReaders{end+1} = entry;
            end
        end

        function list = filematchList(fp)
            %FILEMATCHLIST Cellstr of filematch patterns from file parameters FP.
            %   FP may be empty, a char/string pattern, a cell of patterns, or
            %   a struct with a 'filematch' field holding any of those (the
            %   form ndi.file.navigator stores).
            list = {};
            if isempty(fp)
                return;
            end
            if isstruct(fp)
                if ~isfield(fp, 'filematch')
                    return;
                end
                fp = fp(1).filematch;
            end
            if ischar(fp) || isstring(fp)
                list = reshape(cellstr(fp), 1, []);
            elseif iscell(fp)
                list = cellfun(@char, fp(:)', 'UniformOutput', false);
            end
        end

        function name = shortClassName(fullName)
            %SHORTCLASSNAME Last component of a package-qualified class name.
            %   'ndi.daq.reader.mfdaq.intan' -> 'intan'. Empty stays empty.
            name = char(fullName);
            dots = strfind(name, '.');
            if ~isempty(dots)
                name = name(dots(end)+1:end);
            end
        end

        function labels = epochLabels(numbers, ids)
            %EPOCHLABELS Epoch chooser text, e.g. 'Epoch 1  (t00001)'.
            labels = cell(1, numel(numbers));
            for i = 1:numel(numbers)
                labels{i} = sprintf('Epoch %d', numbers(i));
                if i <= numel(ids) && ~isempty(ids{i})
                    labels{i} = [labels{i} '  (' char(ids{i}) ')'];
                end
            end
        end

        function rows = epochFileRows(files, patterns, probeMapFile)
            %EPOCHFILEROWS Nx3 cell {file name, matching pattern, role}.
            %   FILES are the full paths of one epoch's files, PATTERNS the
            %   navigator's filematch patterns and PROBEMAPFILE the epoch's
            %   epoch probe map file (full path, or ''). Each file is listed
            %   by name with the first pattern it matches; the epoch probe
            %   map file is marked in the Role column. When the probe map
            %   lives outside the epoch files (the default hidden location),
            %   it gets its own row.
            rows = cell(0, 3);
            for i = 1:numel(files)
                [~, nm, ext] = fileparts(files{i});
                name = [nm ext];
                role = '';
                if ~isempty(probeMapFile) && strcmp(files{i}, probeMapFile)
                    role = 'epoch probe map';
                end
                rows(end+1, :) = {name, ...
                    ndi.gui.nav.daqSystemBrowser.matchingPattern(patterns, name), role}; %#ok<AGROW>
            end
            if ~isempty(probeMapFile) && ~any(strcmp(files, probeMapFile))
                [~, nm, ext] = fileparts(probeMapFile);
                role = 'epoch probe map (default location)';
                if ~isfile(probeMapFile)
                    role = [role ', not found'];
                end
                rows(end+1, :) = {[nm ext], '', role};
            end
            if isempty(rows)
                rows = {'(this epoch has no files)', '', ''};
            end
        end

        function p = matchingPattern(patterns, name)
            %MATCHINGPATTERN First of PATTERNS that file NAME matches, or ''.
            %   Matching follows ndi.file.navigator (vlt.string.
            %   strcmp_substitution, where '#' stands for a shared unknown
            %   string); each pattern is tried on its own.
            p = '';
            for i = 1:numel(patterns)
                try
                    tf = vlt.string.strcmp_substitution(patterns{i}, {name});
                catch
                    tf = false;
                end
                if any(tf)
                    p = patterns{i};
                    return;
                end
            end
        end

        function t = defaultEpochProbeMapText()
            %DEFAULTEPOCHPROBEMAPTEXT What is shown when no epoch probe map
            %   file parameters are set (see
            %   ndi.file.navigator/defaultepochprobemapfilename).
            t = '(none set; default: hidden .<first epoch file>.epochprobemap.ndi file)';
        end
    end

    methods (Static, Access = private)
        function items = listItems(items, label, list, emptyText)
            %LISTITEMS Append one 'pattern' row per entry of LIST to ITEMS,
            %   labelling only the first; or one 'note' row of EMPTYTEXT.
            if isempty(list)
                items{end+1} = {'note', label, emptyText, ''};
                return;
            end
            for i = 1:numel(list)
                if i == 1
                    items{end+1} = {'pattern', label, list{i}, ''}; %#ok<AGROW>
                else
                    items{end+1} = {'pattern', '', list{i}, ''}; %#ok<AGROW>
                end
            end
        end

        function v = getProp(o, name)
            %GETPROP O.(NAME), or [] if it cannot be read.
            try
                v = o.(name);
            catch
                v = [];
            end
        end

        function t = getText(o, name)
            %GETTEXT O.(NAME) as char, or '' if it cannot be read.
            v = ndi.gui.nav.daqSystemBrowser.getProp(o, name);
            try
                t = char(v);
            catch
                t = '';
            end
            if size(t, 1) > 1
                t = strjoin(cellstr(t), ', ');
            end
        end
    end
end
