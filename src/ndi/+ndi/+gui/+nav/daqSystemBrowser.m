classdef daqSystemBrowser < handle
%NDI.GUI.NAV.DAQSYSTEMBROWSER Read-only browser of a session's DAQ systems.
%
%   NDI.GUI.NAV.DAQSYSTEMBROWSER(SESSION) opens a window that lists every
%   DAQ system of an ndi.session in a table, one row per DAQ system, so the
%   user can see at a glance how each one finds its data and its epoch
%   probe maps. It is a viewer only; nothing is edited.
%
%   It is the target of the navigator's per-session "Session > DAQ
%   Systems..." menu item (see ndi.gui.nav.datasetsPane).
%
%   Syntax:
%       ndi.gui.nav.daqSystemBrowser(session)
%       obj = ndi.gui.nav.daqSystemBrowser(session, 'Visible', 'off')
%
%   Layout (top to bottom):
%       DAQ systems - a table with the columns:
%                       DAQ system          - the DAQ system's name
%                       DAQ system class    - e.g. ndi.daq.system.mfdaq
%                       DAQ reader          - class of its ndi.daq.reader
%                       File navigator      - class of its ndi.file.navigator
%                       File parameters     - the navigator's fileparameters
%                                             filematch patterns (the files
%                                             that make up an epoch)
%                       Epoch probe map class - the navigator's
%                                             epochprobemap_class
%                       Epoch probe map file parameters - the navigator's
%                                             epochprobemap_fileparameters
%                                             filematch patterns, or the
%                                             default location when unset
%                       Metadata readers    - classes (and tab-separated
%                                             file patterns) of its
%                                             ndi.daq.metadatareader objects
%                     Multiple patterns are joined with ", " in the table.
%       Details     - a text area showing the selected DAQ system's full
%                     description, with one pattern per line, so long
%                     pattern lists can be read in full.
%
%   The window reads the session once, at construction, with
%   daqsystem_load. Each field is read defensively so a DAQ system missing
%   one part still shows the rest.
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.nav.sessionInfo,
%             ndi.daq.system, ndi.file.navigator

    properties (SetAccess = protected)
        Session      % the ndi.session being browsed
        Figure       % the uifigure
        Table        % uitable of DAQ systems
        Details      % uitextarea with the selected DAQ system's details
        Info         % struct array of DAQ system descriptions (see describe)
    end

    properties (Constant)
        ColumnNames = {'DAQ system', 'DAQ system class', 'DAQ reader', ...
            'File navigator', 'File parameters', 'Epoch probe map class', ...
            'Epoch probe map file parameters', 'Metadata readers'}
    end

    methods
        function obj = daqSystemBrowser(session, options)
            arguments
                session (1,1) ndi.session
                options.Visible (1,:) char = 'on'
            end
            obj.Session = session;
            obj.Info = ndi.gui.nav.daqSystemBrowser.describeAll(obj.daqSystems());
            obj.build(options.Visible);
        end
    end

    methods (Access = private)
        function build(obj, visible)
            %BUILD Construct the window and populate the table.
            c = ndi.gui.cloudColors();
            ref = obj.sessionRef();

            obj.Figure = uifigure('Name', ['DAQ systems: ' ref], ...
                'Position', [160 140 1100 520], ...
                'Color',    c.darkBlue, ...
                'Visible',  visible, ...
                'Tag',      'ndiNavigatorDaqSystemBrowser');

            g = uigridlayout(obj.Figure, [4 1]);
            g.RowHeight       = {'fit', '2x', 'fit', '1x'};
            g.ColumnWidth     = {'1x'};
            g.RowSpacing      = 6;
            g.Padding         = [10 10 10 10];
            g.BackgroundColor = c.darkBlue;

            obj.sectionLabel(g, 1, 'DAQ systems');
            obj.Table = uitable(g);
            obj.Table.Layout.Row = 2;
            obj.Table.ColumnName = obj.ColumnNames;
            obj.Table.RowName    = {};
            obj.Table.Data       = ndi.gui.nav.daqSystemBrowser.tableRows(obj.Info);
            obj.Table.ColumnEditable = false;
            obj.Table.Tag        = 'ndiDaqSystemTable';
            obj.Table.BackgroundColor = c.white;
            obj.Table.ForegroundColor = c.darkBlue;  % uitable uses ForegroundColor, not FontColor
            obj.Table.CellSelectionCallback = @(~, evt) obj.onSelect(evt);

            obj.sectionLabel(g, 3, 'Details');
            obj.Details = uitextarea(g, ...
                'Editable',        'off', ...
                'FontName',        'Monospaced', ...
                'BackgroundColor', c.white, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             'ndiDaqSystemDetails');
            obj.Details.Layout.Row = 4;
            if isempty(obj.Info)
                obj.Details.Value = {'This session has no DAQ systems.'};
            else
                obj.showDetails(1);
            end
        end

        function onSelect(obj, evt)
            %ONSELECT Show the details of the DAQ system in the selected row.
            if isempty(evt.Indices) || isempty(obj.Info)
                return;
            end
            obj.showDetails(evt.Indices(1, 1));
        end

        function showDetails(obj, k)
            %SHOWDETAILS Fill the details area with DAQ system K's description.
            if k >= 1 && k <= numel(obj.Info)
                obj.Details.Value = ndi.gui.nav.daqSystemBrowser.detailLines(obj.Info(k));
            end
        end

        function sectionLabel(~, parent, row, text)
            %SECTIONLABEL A small bold heading above a section.
            c = ndi.gui.cloudColors();
            lbl = uilabel(parent, ...
                'Text',       text, ...
                'FontWeight', 'bold', ...
                'FontColor',  c.white);
            lbl.Layout.Row = row;
        end

        function daqs = daqSystems(obj)
            %DAQSYSTEMS Cell array of the session's DAQ system objects.
            try
                daqs = obj.Session.daqsystem_load('name', '(.*)');
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

        function rows = tableRows(info)
            %TABLEROWS Nx8 cell of table text, one row per DAQ system in INFO.
            rows = cell(0, 8);
            for i = 1:numel(info)
                s = info(i);
                rows(end+1, :) = { ...
                    s.name, s.daqClass, s.readerClass, s.navigatorClass, ...
                    ndi.gui.nav.daqSystemBrowser.joinList(s.fileParameters, '(none)'), ...
                    s.epochProbeMapClass, ...
                    ndi.gui.nav.daqSystemBrowser.joinList(s.epochProbeMapFileParameters, ...
                        ndi.gui.nav.daqSystemBrowser.defaultEpochProbeMapText()), ...
                    ndi.gui.nav.daqSystemBrowser.joinList(s.metadataReaders, '(none)')}; %#ok<AGROW>
            end
            if isempty(rows)
                rows = {'(no DAQ systems)', '', '', '', '', '', '', ''};
            end
        end

        function lines = detailLines(s)
            %DETAILLINES Cellstr describing DAQ system S, one pattern per line.
            lines = { ...
                ['DAQ system:            ' s.name], ...
                ['DAQ system class:      ' s.daqClass], ...
                ['DAQ reader:            ' s.readerClass], ...
                ['File navigator:        ' s.navigatorClass], ...
                'File parameters:'};
            lines = [lines, ndi.gui.nav.daqSystemBrowser.indentList(s.fileParameters, '(none)')];
            lines = [lines, {['Epoch probe map class: ' s.epochProbeMapClass], ...
                'Epoch probe map file parameters:'}];
            lines = [lines, ndi.gui.nav.daqSystemBrowser.indentList( ...
                s.epochProbeMapFileParameters, ndi.gui.nav.daqSystemBrowser.defaultEpochProbeMapText())];
            lines = [lines, {'Metadata readers:'}];
            lines = [lines, ndi.gui.nav.daqSystemBrowser.indentList(s.metadataReaders, '(none)')];
        end

        function t = defaultEpochProbeMapText()
            %DEFAULTEPOCHPROBEMAPTEXT What is shown when no epoch probe map
            %   file parameters are set (see
            %   ndi.file.navigator/defaultepochprobemapfilename).
            t = '(default: hidden .<first epoch file>.epochprobemap.ndi file)';
        end
    end

    methods (Static, Access = private)
        function t = joinList(list, emptyText)
            %JOINLIST Join a cellstr with ", ", or EMPTYTEXT if it is empty.
            if isempty(list)
                t = emptyText;
            else
                t = strjoin(list, ', ');
            end
        end

        function lines = indentList(list, emptyText)
            %INDENTLIST One indented line per entry, or EMPTYTEXT if empty.
            if isempty(list)
                list = {emptyText};
            end
            lines = cellfun(@(x) ['    ' x], list, 'UniformOutput', false);
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
