classdef updateDialog < handle
%NDI.GUI.NAV.UPDATEDIALOG Package table shown by the navigator's Update button.
%
%   D = NDI.GUI.NAV.UPDATEDIALOG(RESULT) opens a modal window listing each
%   package that ndi.update.install looks at (see ndi.update.packageStatus)
%   for RESULT, the output of ndi.update.check. The table shows, for each
%   package, a tick box saying whether to update it, its installed and
%   latest version, its status, and an icon for its most serious note:
%       info    - something to know (restart MATLAB, a package skipped)
%       warning - updating touches your work (edits stashed and put back,
%                 local commits merged, toolbox folder overwritten)
%       error   - the update cannot go ahead until you act (an untracked
%                 file in the way, NDI-matlab not on main)
%   Selecting a row shows its notes and the files they are about in the
%   box under the table.
%
%   Only ticked packages are updated, so you can leave alone a package you
%   are working on. Packages that need updating start ticked, except those
%   where updating touches your own work (edits, local commits); packages
%   that are up to date or blocked cannot be ticked. The Update button
%   names how many packages are ticked and is greyed out when none are;
%   it reads "Update anyway" when a ticked package has your changes, and
%   Cancel is then the default.
%
%   D = NDI.GUI.NAV.UPDATEDIALOG(..., 'Parent', FIG) centres the window
%   over the uifigure FIG, and 'Visible', 'off' builds it hidden (for
%   headless tests).
%
%   [GO, PACKAGES] = NDI.GUI.NAV.UPDATEDIALOG.ASK(RESULT, FIG) opens the
%   window, waits for it to close, and returns true if the user pressed
%   Update, with the names of the ticked packages (for the Packages option
%   of ndi.update.install).
%
%   See also: ndi.gui.nav.ndiPane, ndi.update.packageStatus,
%   ndi.update.check, ndi.update.install

    properties (SetAccess = protected)
        Rows             % structure array from ndi.update.packageStatus
        Summary          % summary structure from ndi.update.packageStatus
        Figure           % the uifigure
        Table            % the package uitable
        DetailsArea      % read-only uitextarea with the selected row's details
        UpdateButton     % "Update (N)" / "Update anyway (N)" uibutton
        CancelButton     % "Cancel" / "Close" uibutton
        Selected logical % which rows are ticked
        Choice (1,1) string = "cancel"  % "update" once Update is pressed
    end

    properties (Constant)
        Columns = {'Update', 'Package', 'Installed', 'Latest', 'Status', 'Notes'}
    end

    methods
        function obj = updateDialog(result, options)
            arguments
                result (1,1) struct
                options.Parent = []
                options.Visible (1,:) char = 'on'
            end
            [obj.Rows, obj.Summary] = ndi.update.packageStatus(result);
            obj.Selected = [obj.Rows.Selected];
            obj.build(options.Parent, options.Visible);
        end

        function setSelected(obj, row, tf)
            %SETSELECTED Tick (TF true) or untick table row ROW.
            %   A row that cannot be updated stays unticked.
            tf = tf && obj.Rows(row).Selectable;
            obj.Selected(row) = tf;
            obj.Table.Data{row, 1} = tf;
            obj.refreshUpdateButton();
        end

        function names = selectedPackages(obj)
            %SELECTEDPACKAGES Names of the ticked packages.
            names = [obj.Rows(obj.Selected).Name];
            if isempty(names)
                names = strings(1, 0);
            end
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
        function [go, packages] = ask(result, parent)
            %ASK Open the dialog and wait for it to close.
            %   GO is true for Update; PACKAGES names the ticked packages.
            d = ndi.gui.nav.updateDialog(result, 'Parent', parent);
            uiwait(d.Figure);
            go = d.Choice == "update";
            packages = d.selectedPackages();
        end

        function data = tableData(rows, selected)
            %TABLEDATA The uitable Data cell array for ROWS, ticked as SELECTED.
            n = numel(rows);
            data = cell(n, numel(ndi.gui.nav.updateDialog.Columns));
            for i = 1:n
                r = rows(i);
                data(i, :) = {logical(selected(i)), char(r.Name), char(r.Installed), ...
                    char(r.Latest), char(r.Status), ndi.gui.nav.updateDialog.noteText(r)};
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

        function [text, enable] = updateButtonState(rows, selected)
            %UPDATEBUTTONSTATE Text and Enable of the Update button.
            %   'Update (N)' for N ticked packages, 'Update anyway (N)' if a
            %   ticked package has your changes, and greyed out for none.
            n = nnz(selected);
            if n == 0
                text = 'Update';
                enable = 'off';
                return
            end
            enable = 'on';
            if any(selected(:)' & [rows.TouchesChanges])
                text = sprintf('Update anyway (%d)', n);
            else
                text = sprintf('Update (%d)', n);
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
                'Data',                  ndi.gui.nav.updateDialog.tableData(obj.Rows, obj.Selected), ...
                'ColumnName',            ndi.gui.nav.updateDialog.Columns, ...
                'ColumnWidth',           {55, 170, 75, 75, 130, 'auto'}, ...
                'RowName',               {}, ...
                'ColumnEditable',        [true false false false false false], ...
                'CellEditCallback',      @(~, evt) obj.onEdit(evt), ...
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

            [text, enable] = ndi.gui.nav.updateDialog.updateButtonState(obj.Rows, obj.Selected);
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
                    if strcmp(obj.UpdateButton.Enable, 'off') || ...
                            any(obj.Selected & [obj.Rows.TouchesChanges])
                        focus(obj.CancelButton);
                    else
                        focus(obj.UpdateButton);
                    end
                catch
                end
            end
        end

        function styleTable(obj, c)
            %STYLETABLE Bold the packages that can be updated; icon the notes.
            notesCol = numel(ndi.gui.nav.updateDialog.Columns);
            statusCol = 5;
            willUpdate = find([obj.Rows.WillUpdate]);
            if ~isempty(willUpdate)
                addStyle(obj.Table, uistyle('FontWeight', 'bold'), 'row', willUpdate);
            end
            upToDate = find(arrayfun(@(r) r.Status == "Up to date", obj.Rows));
            if ~isempty(upToDate)
                addStyle(obj.Table, uistyle('FontColor', c.okGreen), 'cell', ...
                    [upToDate(:), repmat(statusCol, numel(upToDate), 1)]);
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

        function onEdit(obj, evt)
            % A tick box changed. Rows that cannot be updated snap back.
            row = evt.Indices(1);
            obj.setSelected(row, logical(evt.NewData));
            if ~obj.Rows(row).Selectable
                obj.showDetails(row);
            end
        end

        function refreshUpdateButton(obj)
            [text, enable] = ndi.gui.nav.updateDialog.updateButtonState(obj.Rows, obj.Selected);
            obj.UpdateButton.Text = text;
            obj.UpdateButton.Enable = enable;
        end
    end
end
