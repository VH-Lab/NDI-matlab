classdef sessionInfo < handle
%NDI.GUI.NAV.SESSIONINFO Vital-statistics window for one ndi.session.
%
%   NDI.GUI.NAV.SESSIONINFO(SESSION) opens a small window summarising an
%   ndi.session: its DAQ systems (each expandable to its epochs), its
%   elements (name and type), and its subjects. It is the target of the
%   navigator's per-session "Session > Info..." menu item.
%
%   Syntax:
%       ndi.gui.nav.sessionInfo(session)
%       obj = ndi.gui.nav.sessionInfo(session)
%
%   Layout (top to bottom):
%       DAQ systems - a uitree; each DAQ system is a top node carrying the
%                     native disclosure triangle. Expanding one lists its
%                     epochs as "#N - <epoch_id>" children.
%       Elements    - a two-column table: element name | element type.
%       Subjects    - a table of the session's subjects (local identifier
%                     and description).
%
%   The window reads the session once, at construction, from the model
%   methods daqsystem_load, getelements and a database search for subject
%   documents. Everything is wrapped defensively so a session that cannot
%   answer one query still shows the rest.
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.navigator, ndi.session

    properties (SetAccess = protected)
        Session      % the ndi.session being summarised
        Figure       % the uifigure
    end

    methods
        function obj = sessionInfo(session)
            arguments
                session (1,1) ndi.session
            end
            obj.Session = session;
            obj.build();
        end
    end

    methods (Access = private)
        function build(obj)
            %BUILD Construct the window and populate every section.
            c = ndi.gui.cloudColors();
            ref = obj.sessionRef();

            obj.Figure = uifigure('Name', ['Session: ' ref], ...
                'Position', [180 160 460 520], ...
                'Color',    c.offWhite, ...
                'Tag',      'ndiNavigatorSessionInfo');

            g = uigridlayout(obj.Figure, [6 1]);
            g.RowHeight     = {'fit', '1x', 'fit', '1.2x', 'fit', '0.8x'};
            g.ColumnWidth   = {'1x'};
            g.RowSpacing    = 6;
            g.Padding       = [10 10 10 10];
            g.BackgroundColor = c.offWhite;

            obj.sectionLabel(g, 1, 'DAQ systems');
            tree = uitree(g);
            tree.Layout.Row = 2;
            obj.populateDaqTree(tree);

            obj.sectionLabel(g, 3, 'Elements');
            elemTable = uitable(g);
            elemTable.Layout.Row      = 4;
            elemTable.ColumnName      = {'Element name', 'Element type'};
            elemTable.ColumnWidth     = {'1x', '1x'};
            elemTable.RowName         = {};
            elemTable.Data            = obj.elementRows();

            obj.sectionLabel(g, 5, 'Subjects');
            subjTable = uitable(g);
            subjTable.Layout.Row      = 6;
            subjTable.ColumnName      = {'Subject', 'Description'};
            subjTable.ColumnWidth     = {'1x', '1x'};
            subjTable.RowName         = {};
            subjTable.Data            = obj.subjectRows();
        end

        function sectionLabel(~, parent, row, text)
            %SECTIONLABEL A small bold heading above a section.
            c = ndi.gui.cloudColors();
            lbl = uilabel(parent, ...
                'Text',       text, ...
                'FontWeight', 'bold', ...
                'FontColor',  c.darkBlue);
            lbl.Layout.Row = row;
        end

        function populateDaqTree(obj, tree)
            %POPULATEDAQTREE One top node per DAQ system, epochs as children.
            daqs = obj.daqSystems();
            if isempty(daqs)
                uitreenode(tree, 'Text', '(no DAQ systems)');
                return;
            end
            for i = 1:numel(daqs)
                d = daqs{i};
                name = obj.daqName(d);
                dn = uitreenode(tree, 'Text', name);
                obj.addEpochChildren(dn, d);
            end
        end

        function addEpochChildren(~, daqNode, d)
            %ADDEPOCHCHILDREN List a DAQ system's epochs as "#N - <id>".
            try
                et = d.epochtable();
            catch
                et = [];
            end
            if isempty(et)
                uitreenode(daqNode, 'Text', '(no epochs)');
                return;
            end
            for k = 1:numel(et)
                if isfield(et, 'epoch_number') && ~isempty(et(k).epoch_number)
                    num = et(k).epoch_number;
                else
                    num = k;
                end
                if isfield(et, 'epoch_id') && ~isempty(et(k).epoch_id)
                    eid = char(et(k).epoch_id);
                else
                    eid = '(no id)';
                end
                uitreenode(daqNode, 'Text', sprintf('#%d - %s', num, eid));
            end
        end

        function rows = elementRows(obj)
            %ELEMENTROWS Nx2 cell of {name, type} for the session elements.
            rows = cell(0, 2);
            try
                elements = obj.Session.getelements();
            catch
                elements = {};
            end
            for i = 1:numel(elements)
                e = elements{i};
                nm = '';
                ty = '';
                try
                    nm = char(e.name);
                    ty = char(e.type);
                catch
                end
                rows(end+1, :) = {nm, ty}; %#ok<AGROW>
            end
            if isempty(rows)
                rows = {'(none)', ''};
            end
        end

        function rows = subjectRows(obj)
            %SUBJECTROWS Nx2 cell of {identifier, description} for subjects.
            rows = cell(0, 2);
            try
                docs = obj.Session.database_search(ndi.query('', 'isa', 'subject'));
            catch
                docs = {};
            end
            for i = 1:numel(docs)
                id = ''; desc = '';
                try
                    s = docs{i}.document_properties.subject;
                    if isfield(s, 'local_identifier'); id = char(s.local_identifier); end
                    if isfield(s, 'description');       desc = char(s.description); end
                catch
                end
                rows(end+1, :) = {id, desc}; %#ok<AGROW>
            end
            if isempty(rows)
                rows = {'(none)', ''};
            end
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

    methods (Access = private, Static)
        function name = daqName(d)
            %DAQNAME Best-effort display name for a DAQ system.
            try
                name = char(d.name);
            catch
                name = class(d);
            end
            if isempty(name)
                name = '(unnamed DAQ system)';
            end
        end
    end
end
