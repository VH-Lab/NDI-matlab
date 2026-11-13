classdef sessionTable < handle
%NDI.GUI.NAV.SESSIONTABLE Window showing one summary table of a session.
%
%   NDI.GUI.NAV.SESSIONTABLE(SESSION, KIND) builds one of the session
%   summary tables of ndi.fun.docTable for an ndi.session and shows it in
%   a window. It is the target of the navigator's per-session
%   "Session > Tables" submenu (see ndi.gui.nav.datasetsPane).
%
%   KIND is one of (see ndi.gui.nav.sessionTable.tableKinds):
%       'element'    - ndi.fun.docTable.element    ("Elements...")
%       'epoch'      - ndi.fun.docTable.epoch      ("Epochs...")
%       'probe'      - ndi.fun.docTable.probe      ("Probes...")
%       'subject'    - ndi.fun.docTable.subject    ("Subjects...")
%       'treatment'  - ndi.fun.docTable.treatment  ("Treatments...")
%
%   Syntax:
%       ndi.gui.nav.sessionTable(session, kind)
%       obj = ndi.gui.nav.sessionTable(session, kind, 'Visible', 'off')
%
%   Layout:
%       Header - the table's title and row count, then two buttons:
%                "Assign to workspace..." puts the MATLAB table in a base
%                workspace variable (default name e.g. 'subjectTable');
%                "Export CSV..." writes it to a file with writetable.
%       Body   - a uitable showing the table. Every cell is shown as text
%                (see tableCells), so columns holding vectors, datetimes or
%                cell arrays display uniformly.
%
%   The table is built once, at construction. Building it can take a
%   while on a large session; the navigator shows a progress dialog
%   around the construction.
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.nav.sessionInfo,
%             ndi.fun.docTable.element, ndi.fun.docTable.epoch,
%             ndi.fun.docTable.probe, ndi.fun.docTable.subject,
%             ndi.fun.docTable.treatment

    properties (SetAccess = protected)
        Session      % the ndi.session the table describes
        Kind         % the table kind (see tableKinds)
        Table        % the MATLAB table built by ndi.fun.docTable
        Figure       % the uifigure
        UITable      % the uitable showing Table
    end

    methods
        function obj = sessionTable(session, kind, options)
            arguments
                session (1,1) ndi.session
                kind (1,:) char
                options.Visible (1,:) char {mustBeMember(options.Visible, {'on', 'off'})} = 'on'
            end
            obj.Session = session;
            obj.Kind    = ndi.gui.nav.sessionTable.kindInfo(kind).Kind;
            obj.Table   = ndi.gui.nav.sessionTable.computeTable(session, obj.Kind);
            obj.build(options.Visible);
        end

        function name = assignToWorkspace(obj, name)
            %ASSIGNTOWORKSPACE Put the table in a base workspace variable.
            %   NAME = ASSIGNTOWORKSPACE(OBJ) asks for a variable name
            %   (default e.g. 'subjectTable'); ASSIGNTOWORKSPACE(OBJ, NAME)
            %   uses NAME without asking. Returns the name assigned, or ''
            %   when nothing was (cancelled, invalid name or error).
            info = ndi.gui.nav.sessionTable.kindInfo(obj.Kind);
            title = 'Assign to workspace';
            if nargin < 2
                answer = inputdlg('Workspace variable name:', title, [1 40], ...
                    {info.VariableName});
                if isempty(answer)
                    name = '';
                    return;
                end
                name = answer{1};
            end
            name = strtrim(char(name));
            msg = ndi.gui.nav.datasetsPane.workspaceNameError(name);
            if ~isempty(msg)
                obj.alert(msg, title);
                name = '';
                return;
            end
            try
                assignin('base', name, obj.Table);
            catch ME
                obj.alert(ME.message, title);
                name = '';
            end
        end

        function filename = exportCsv(obj, filename)
            %EXPORTCSV Write the table (as displayed text) to a CSV file.
            %   FILENAME = EXPORTCSV(OBJ) asks for the file;
            %   EXPORTCSV(OBJ, FILENAME) writes FILENAME without asking.
            %   Returns the file written, or '' when nothing was.
            info = ndi.gui.nav.sessionTable.kindInfo(obj.Kind);
            if nargin < 2
                [f, p] = uiputfile('*.csv', 'Export CSV', [info.VariableName '.csv']);
                if isequal(f, 0)
                    filename = '';
                    return;
                end
                filename = fullfile(p, f);
            end
            filename = char(filename);
            try
                [names, data] = ndi.gui.nav.sessionTable.tableCells(obj.Table);
                writetable(cell2table(data, 'VariableNames', ...
                    matlab.lang.makeUniqueStrings(names)), filename);
            catch ME
                obj.alert(ME.message, 'Export CSV');
                filename = '';
            end
        end
    end

    methods (Access = private)
        function alert(obj, msg, title)
            %ALERT Report MSG in the window, or as a warning when hidden.
            if ~isempty(obj.Figure) && isvalid(obj.Figure) ...
                    && strcmp(char(obj.Figure.Visible), 'on')
                uialert(obj.Figure, msg, title);
            else
                warning('ndi:gui:nav:sessionTable:actionFailed', '%s: %s', title, msg);
            end
        end

        function build(obj, visible)
            %BUILD Construct the window and fill the table.
            c = ndi.gui.cloudColors();
            info = ndi.gui.nav.sessionTable.kindInfo(obj.Kind);
            ref = ndi.gui.nav.sessionTable.sessionRef(obj.Session);

            obj.Figure = uifigure('Name', [info.Title ': ' ref], ...
                'Position', [200 140 900 520], ...
                'Color',    c.darkBlue, ...
                'Visible',  visible, ...
                'Tag',      'ndiNavigatorSessionTable');

            g = uigridlayout(obj.Figure, [2 3]);
            g.RowHeight       = {'fit', '1x'};
            g.ColumnWidth     = {'1x', 'fit', 'fit'};
            g.RowSpacing      = 6;
            g.Padding         = [10 10 10 10];
            g.BackgroundColor = c.darkBlue;

            lbl = uilabel(g, ...
                'Text',       ndi.gui.nav.sessionTable.summaryText(info.Title, obj.Table), ...
                'FontWeight', 'bold', ...
                'FontColor',  c.white);
            lbl.Layout.Row = 1; lbl.Layout.Column = 1;

            b1 = uibutton(g, 'Text', 'Assign to workspace...', ...
                'ButtonPushedFcn', @(~,~) obj.assignToWorkspace());
            b1.Layout.Row = 1; b1.Layout.Column = 2;
            b2 = uibutton(g, 'Text', 'Export CSV...', ...
                'ButtonPushedFcn', @(~,~) obj.exportCsv());
            b2.Layout.Row = 1; b2.Layout.Column = 3;

            [names, data] = ndi.gui.nav.sessionTable.tableCells(obj.Table);
            t = uitable(g);
            t.Layout.Row     = 2;
            t.Layout.Column  = [1 3];
            t.ColumnName     = names;
            t.RowName        = {};
            t.Data           = data;
            t.BackgroundColor = c.white;
            t.ForegroundColor = c.darkBlue;
            obj.UITable = t;
        end
    end

    methods (Static)
        function kinds = tableKinds()
            %TABLEKINDS The session tables, in menu (alphabetical) order.
            %   A struct array with fields:
            %       Kind         - the identifier passed to sessionTable
            %       Label        - the "Session > Tables" menu text
            %       Title        - the window / heading title
            %       VariableName - default workspace variable / file name
            %       Function     - the ndi.fun.docTable function name
            kinds = struct( ...
                'Kind',  {'element', 'epoch', 'probe', 'subject', 'treatment'}, ...
                'Label', {'Elements...', 'Epochs...', 'Probes...', ...
                          'Subjects...', 'Treatments...'}, ...
                'Title', {'Element table', 'Epoch table', 'Probe table', ...
                          'Subject table', 'Treatment table'}, ...
                'VariableName', {'elementTable', 'epochTable', 'probeTable', ...
                          'subjectTable', 'treatmentTable'}, ...
                'Function', {'ndi.fun.docTable.element', 'ndi.fun.docTable.epoch', ...
                          'ndi.fun.docTable.probe', 'ndi.fun.docTable.subject', ...
                          'ndi.fun.docTable.treatment'});
        end

        function info = kindInfo(kind)
            %KINDINFO The tableKinds entry for KIND (case-insensitive).
            kinds = ndi.gui.nav.sessionTable.tableKinds();
            i = find(strcmpi(char(kind), {kinds.Kind}), 1);
            if isempty(i)
                error('ndi:gui:nav:sessionTable:unknownKind', ...
                    'Unknown session table kind "%s". Expected one of: %s.', ...
                    char(kind), strjoin({kinds.Kind}, ', '));
            end
            info = kinds(i);
        end

        function T = computeTable(session, kind)
            %COMPUTETABLE Build the KIND table for SESSION.
            %   Calls the ndi.fun.docTable function named by tableKinds and
            %   returns its first output (a MATLAB table).
            info = ndi.gui.nav.sessionTable.kindInfo(kind);
            T = feval(info.Function, session);
            if ~istable(T)
                T = table();
            end
        end

        function str = summaryText(title, T)
            %SUMMARYTEXT Heading text, e.g. 'Subject table (3 rows)'.
            n = 0;
            if istable(T)
                n = height(T);
            end
            if n == 1
                str = sprintf('%s (1 row)', title);
            else
                str = sprintf('%s (%d rows)', title, n);
            end
        end

        function [names, data] = tableCells(T)
            %TABLECELLS Column names and an all-text cell array for uitable.
            %   NAMES is a 1xC cellstr of T's variable names; DATA is an
            %   HxC cell array of char, each cell formatted by cellText. An
            %   empty or non-table T gives NAMES = {} and DATA = cell(0,0).
            names = {};
            data  = cell(0, 0);
            if ~istable(T) || width(T) == 0
                return;
            end
            names = T.Properties.VariableNames;
            h = height(T);
            data = cell(h, numel(names));
            for j = 1:numel(names)
                col = T.(names{j});
                for i = 1:h
                    if iscell(col) && size(col, 2) == 1
                        v = col{i};
                    else
                        v = col(i, :);
                    end
                    data{i, j} = ndi.gui.nav.sessionTable.cellText(v);
                end
            end
        end

        function str = cellText(v)
            %CELLTEXT Format one table value as display text.
            %   char -> itself; string -> joined with ', '; missing / NaN /
            %   NaT / empty -> ''; logical -> 'true'/'false'; numeric
            %   scalar -> num2str; numeric array -> mat2str; datetime /
            %   duration / categorical -> char; cell -> its elements'
            %   texts joined with ', '. Anything else -> its class name in
            %   angle brackets.
            if ischar(v)
                str = reshape(v.', 1, []);
                if size(v, 1) > 1
                    str = strjoin(cellstr(v), ', ');
                end
            elseif isstring(v)
                v = v(~ismissing(v));
                str = char(strjoin(v(:)', ', '));
            elseif iscell(v)
                parts = cellfun(@ndi.gui.nav.sessionTable.cellText, v(:)', ...
                    'UniformOutput', false);
                parts = parts(~cellfun(@isempty, parts));
                str = strjoin(parts, ', ');
            elseif isempty(v)
                str = '';
            elseif islogical(v)
                if isscalar(v)
                    str = char(string(v));
                else
                    str = mat2str(v);
                end
            elseif isnumeric(v)
                if isscalar(v)
                    if isnan(v)
                        str = '';
                    else
                        str = num2str(v);
                    end
                elseif all(isnan(v(:)))
                    str = '';
                else
                    str = mat2str(v);
                end
            elseif isdatetime(v) || isduration(v) || iscategorical(v)
                s = string(v);
                s = s(~ismissing(s));
                str = char(strjoin(s(:)', ', '));
            elseif isstruct(v)
                str = '<struct>';
            else
                str = ['<' class(v) '>'];
            end
            str = char(str);
            if isempty(str)
                str = '';
            end
        end

        function ref = sessionRef(session)
            %SESSIONREF A session's reference for the window title.
            ref = '';
            try
                ref = char(session.reference);
            catch
            end
            if isempty(ref)
                ref = '(unnamed session)';
            end
        end
    end
end
