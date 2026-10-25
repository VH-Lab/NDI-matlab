classdef updateDialog < handle
%NDI.GUI.NAV.UPDATEDIALOG Package table shown by the navigator's Update button.
%
%   D = NDI.GUI.NAV.UPDATEDIALOG(RESULT) opens a modal window listing each
%   package that ndi.update.install looks at (see ndi.update.packageStatus)
%   for RESULT, the output of ndi.update.check. The table shows each
%   package's installed and latest version, its status, whether it will be
%   updated, and an icon for its most serious note:
%       info    - something to know (restart MATLAB, a package skipped)
%       warning - updating touches your work (edits stashed and put back,
%                 local commits merged, toolbox folder overwritten)
%       error   - the update cannot go ahead until you act (an untracked
%                 file in the way, NDI-matlab not on main)
%   Selecting a row shows its notes and the files they are about in the
%   box under the table.
%
%   The Update button is greyed out when there is nothing to update or a
%   package is blocked. When updating touches code you changed it reads
%   "Update anyway" and Cancel is the default.
%
%   D = NDI.GUI.NAV.UPDATEDIALOG(..., 'Parent', FIG) centres the window
%   over the uifigure FIG, and 'Visible', 'off' builds it hidden (for
%   headless tests).
%
%   GO = NDI.GUI.NAV.UPDATEDIALOG.ASK(RESULT, FIG) opens the window, waits
%   for it to close, and returns true if the user pressed Update.
%
%   See also: ndi.gui.nav.ndiPane, ndi.update.packageStatus,
%   ndi.update.check, ndi.update.install

    properties (SetAccess = protected)
        Rows             % structure array from ndi.update.packageStatus
        Summary          % summary structure from ndi.update.packageStatus
        Figure           % the uifigure
        Table            % the package uitable
        DetailsArea      % read-only uitextarea with the selected row's details
        UpdateButton     % "Update" / "Update anyway" uibutton
        CancelButton     % "Cancel" / "Close" uibutton
        Choice (1,1) string = "cancel"  % "update" once Update is pressed
    end

    properties (Constant)
        Columns = {'Package', 'Installed', 'Latest', 'Status', 'Action', 'Notes'}
    end

    methods
        function obj = updateDialog(result, options)
            arguments
                result (1,1) struct
                options.Parent = []
                options.Visible (1,:) char = 'on'
            end
            [obj.Rows, obj.Summary] = ndi.update.packageStatus(result);
            obj.build(options.Parent, options.Visible);
        end

        function showDetails(obj, row)
            %SHOWDETAILS Show the notes and files of table row ROW.
            if row >= 1 && row <= numel(obj.Rows)
                obj.DetailsArea.Value = cellstr(splitlines(obj.Rows(row).Details));
            end
        end

        function choose(obj, choice)
            %CHOOSE Record the user's CHOICE ("update" or "cancel") and close.
            obj.Choice = choice;
            if isvalid(obj.Figure)
                delete(obj.Figure);
            end
        end
    end

    methods (Static)
        function go = ask(result, parent)
            %ASK Open the dialog, wait for it to close, return true for Update.
            d = ndi.gui.nav.updateDialog(result, 'Parent', parent);
            uiwait(d.Figure);
            go = d.Choice == "update";
        end

        function data = tableData(rows)
            %TABLEDATA The uitable Data cell array for ROWS.
            n = numel(rows);
            data = cell(n, numel(ndi.gui.nav.updateDialog.Columns));
            for i = 1:n
                r = rows(i);
                data(i, :) = {char(r.Name), char(r.Installed), char(r.Latest), ...
                    char(r.Status), ndi.gui.nav.updateDialog.actionText(r), ...
                    ndi.gui.nav.updateDialog.noteText(r)};
            end
        end

        function txt = actionText(row)
            %ACTIONTEXT What the update does to ROW: 'Update', 'Install' or ''.
            if ~row.WillUpdate
                txt = '';
            elseif row.Status == "Not installed; will be added"
                txt = 'Install';
            else
                txt = 'Update';
            end
        end

        function txt = noteText(row)
            %NOTETEXT Notes-column text for ROW: its most serious note.
            txt = '';
            if isempty(row.Notes)
                return
            end
            order = ["info", "warning", "error"];
            [~, k] = max(arrayfun(@(l) find(order == l), row.NoteLevels));
            txt = char(row.Notes(k));
            if numel(row.Notes) > 1
                txt = sprintf('%s (+%d more)', txt, numel(row.Notes) - 1);
            end
        end

        function [text, enable] = updateButtonState(summary)
            %UPDATEBUTTONSTATE Text and Enable of the Update button.
            if summary.HasUserChanges
                text = 'Update anyway';
            else
                text = 'Update';
            end
            if summary.CanUpdate
                enable = 'on';
            else
                enable = 'off';
            end
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            %BUILD Construct the window: summary, table, details, buttons.
            c = ndi.gui.cloudColors();
            w = 780; h = 460;
            pos = [200 200 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end

            obj.Figure = uifigure('Name', 'NDI Update', ...
                'Position',   pos, ...
                'Color',      c.darkBlue, ...
                'Visible',    visible, ...
                'WindowStyle','modal', ...
                'Tag',        'ndiNavigatorUpdate');

            g = uigridlayout(obj.Figure, [4 3]);
            g.RowHeight       = {'fit', '1x', 110, 'fit'};
            g.ColumnWidth     = {'1x', 'fit', 'fit'};
            g.RowSpacing      = 8;
            g.Padding         = [12 12 12 12];
            g.BackgroundColor = c.darkBlue;

            msg = uilabel(g, ...
                'Text',       char(obj.Summary.Message), ...
                'FontWeight', 'bold', ...
                'WordWrap',   'on', ...
                'FontColor',  c.white);
            msg.Layout.Row = 1;
            msg.Layout.Column = [1 3];

            obj.Table = uitable(g, ...
                'Data',                  ndi.gui.nav.updateDialog.tableData(obj.Rows), ...
                'ColumnName',            ndi.gui.nav.updateDialog.Columns, ...
                'ColumnWidth',           {170, 75, 75, 130, 60, 'auto'}, ...
                'RowName',               {}, ...
                'ColumnEditable',        false, ...
                'CellSelectionCallback', @(~, evt) obj.onSelect(evt), ...
                'Tag',                   'ndiUpdateTable');
            obj.Table.Layout.Row = 2;
            obj.Table.Layout.Column = [1 3];
            obj.styleTable(c);

            obj.DetailsArea = uitextarea(g, ...
                'Editable', 'off', ...
                'Value',    {'Select a package to see its notes.'}, ...
                'Tag',      'ndiUpdateDetails');
            obj.DetailsArea.Layout.Row = 3;
            obj.DetailsArea.Layout.Column = [1 3];
            % Start on the package that most needs reading.
            first = find([obj.Rows.Blocked], 1);
            if isempty(first)
                first = find(arrayfun(@(r) ~isempty(r.Notes) && r.WillUpdate, obj.Rows), 1);
            end
            if ~isempty(first)
                obj.showDetails(first);
            end

            [text, enable] = ndi.gui.nav.updateDialog.updateButtonState(obj.Summary);
            obj.UpdateButton = uibutton(g, ...
                'Text',            text, ...
                'Enable',          enable, ...
                'BackgroundColor', c.lightBlue, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             'ndiUpdateGo', ...
                'ButtonPushedFcn', @(~, ~) obj.choose("update"));
            obj.UpdateButton.Layout.Row = 4;
            obj.UpdateButton.Layout.Column = 2;

            if obj.Summary.AnyUpdate
                cancelText = 'Cancel';
            else
                cancelText = 'Close';
            end
            obj.CancelButton = uibutton(g, ...
                'Text',            cancelText, ...
                'BackgroundColor', c.white, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             'ndiUpdateCancel', ...
                'ButtonPushedFcn', @(~, ~) obj.choose("cancel"));
            obj.CancelButton.Layout.Row = 4;
            obj.CancelButton.Layout.Column = 3;

            obj.Figure.CloseRequestFcn = @(~, ~) obj.choose("cancel");
            % Enter should not stash someone's work: focus Cancel then.
            if strcmp(visible, 'on')
                try % focus needs R2022a
                    if obj.Summary.HasUserChanges || ~obj.Summary.CanUpdate
                        focus(obj.CancelButton);
                    else
                        focus(obj.UpdateButton);
                    end
                catch
                end
            end
        end

        function styleTable(obj, c)
            %STYLETABLE Bold the packages to be updated; icon the notes.
            notesCol = numel(ndi.gui.nav.updateDialog.Columns);
            willUpdate = find([obj.Rows.WillUpdate]);
            if ~isempty(willUpdate)
                addStyle(obj.Table, uistyle('FontWeight', 'bold'), 'row', willUpdate);
            end
            upToDate = find(arrayfun(@(r) r.Status == "Up to date", obj.Rows));
            if ~isempty(upToDate)
                addStyle(obj.Table, uistyle('FontColor', c.okGreen), 'cell', ...
                    [upToDate(:), repmat(4, numel(upToDate), 1)]);
            end
            for level = ["info", "warning", "error"]
                rows = find(arrayfun(@(r) r.NoteLevel == level, obj.Rows));
                if isempty(rows)
                    continue
                end
                cells = [rows(:), repmat(notesCol, numel(rows), 1)];
                try
                    addStyle(obj.Table, uistyle('Icon', char(level), ...
                        'IconAlignment', 'left'), 'cell', cells);
                catch
                    % Releases without predefined uistyle icons: colour instead.
                    colors = struct('info', c.lightBlue, 'warning', c.warnAmber, ...
                        'error', [0.8 0.1 0.1]);
                    addStyle(obj.Table, uistyle('FontColor', colors.(level)), ...
                        'cell', cells);
                end
            end
        end

        function onSelect(obj, evt)
            if ~isempty(evt.Indices)
                obj.showDetails(evt.Indices(1, 1));
            end
        end
    end
end
