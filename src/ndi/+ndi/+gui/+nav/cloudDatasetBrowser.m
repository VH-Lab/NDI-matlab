classdef cloudDatasetBrowser < handle
%NDI.GUI.NAV.CLOUDDATASETBROWSER Browse, open and delete your NDI Cloud datasets.
%
%   NDI.GUI.NAV.CLOUDDATASETBROWSER() opens a window listing every NDI Cloud
%   dataset in every organization the signed-in user belongs to
%   (ndi.cloud.api.datasets.listDatasets). For each dataset it shows:
%       Name, Organization, Documents, Files, Created, Last changed
%   "Created" is when the dataset was created on NDI Cloud, which is when
%   its first documents were added; "Last changed" is the dataset's last
%   update time on NDI Cloud. Selecting a row shows the dataset's details,
%   including its cloud dataset id with a Copy button; counts or dates the
%   list did not include are fetched then with ndi.cloud.api.datasets.getDataset.
%
%   The "Sort by" control orders the list by any column, either direction.
%   Refresh reloads the list from NDI Cloud.
%
%   OPEN hands the selected dataset to the 'OpenFcn' callback (the
%   navigator uses it to download the dataset's documents to a folder and
%   add it to the Datasets pane, exactly as "Open Private Cloud dataset..."
%   does). Without an OpenFcn the Open button is hidden.
%
%   DELETE asks first, in a dialog built to be hard to click through
%   (ndi.gui.nav.cloudDatasetBrowser.confirmDelete). The dialog names the
%   dataset, its id and organization, when it was created and how many
%   documents and files it has. Delete stays disabled until the user ticks
%   "I understand..." and types the dataset's name. When the dataset is in a
%   group organization (one shared with other people, not the user's own),
%   a second box must also be ticked: "This is in a group organization. Are
%   you sure you want to delete it?" Deletion calls
%   ndi.cloud.api.datasets.deleteDataset, whose default is a delayed
%   deletion: the dataset is removed permanently after 7 days and can be
%   restored until then with ndi.cloud.api.datasets.undeleteDataset.
%
%   NDI Cloud does not currently say directly whether an organization is a
%   personal one; see isGroupOrganization for how this is decided.
%
%   NDI.GUI.NAV.CLOUDDATASETBROWSER(..., 'Parent', FIG) centres the window
%   over FIG; 'Visible', 'off' builds it hidden and 'Load', false skips the
%   initial fetch (both for headless tests).
%
%   Syntax:
%       ndi.gui.nav.cloudDatasetBrowser()
%       ndi.gui.nav.cloudDatasetBrowser('OpenFcn', @(id, name) disp(id))
%
%   See also: ndi.gui.nav.datasetsPane, ndi.cloud.api.datasets.listDatasets,
%             ndi.cloud.api.datasets.getDataset,
%             ndi.cloud.api.datasets.deleteDataset,
%             ndi.cloud.api.datasets.undeleteDataset

    properties (Constant)
        ColumnNames = {'Name', 'Organization', 'Documents', 'Files', ...
            'Created', 'Last changed'}
    end

    properties (SetAccess = protected)
        Entries = struct([])            % listed datasets, in table order
        Organizations = struct('id', {}, 'name', {}, 'canUploadDataset', {})
        SelectedIndex = []              % row of Entries that is selected
        SortColumn char = 'Name'
        SortDescending (1,1) logical = false
        OpenFcn = []                    % @(cloudDatasetId, name) or []
        Figure
        Table
        DetailsField                    % multi-line text area with details
        IdField
        IdCopyButton
        OpenButton
        DeleteButton
        StatusLabel
        SortDirButton
    end

    methods
        function obj = cloudDatasetBrowser(options)
            arguments
                options.Parent = []
                options.OpenFcn = []
                options.Visible (1,:) char = 'on'
                options.Load (1,1) logical = true
            end
            obj.OpenFcn = options.OpenFcn;
            obj.Entries = ndi.gui.nav.cloudDatasetBrowser.emptyEntries();
            obj.build(options.Parent, options.Visible);
            if options.Load
                obj.refresh();
            end
        end

        function refresh(obj)
            %REFRESH Reload the dataset list from NDI Cloud.
            obj.setStatus('Contacting NDI Cloud...');
            obj.Table.Data = cell(0, numel(obj.ColumnNames));
            drawnow;
            try
                [b, answer] = ndi.cloud.api.datasets.listDatasets();
                if ~b
                    error('NDI:cloudDatasetBrowser:ListFailed', ...
                        'Could not retrieve your NDI Cloud datasets.');
                end
                try
                    obj.Organizations = ndi.cloud.internal.getOrganizations();
                catch
                    obj.Organizations = struct('id', {}, 'name', {}, 'canUploadDataset', {});
                end
            catch ME
                obj.setStatus(['Could not load datasets: ' ME.message]);
                return;
            end
            obj.setEntries(ndi.gui.nav.cloudDatasetBrowser.entriesFromList(answer));
            obj.setStatus(sprintf('%d dataset(s).', numel(obj.Entries)));
        end

        function setEntries(obj, entries)
            %SETENTRIES Show ENTRIES (sorted by the current sort choice).
            obj.Entries = ndi.gui.nav.cloudDatasetBrowser.sortEntries( ...
                entries, obj.SortColumn, obj.SortDescending);
            obj.redraw();
            obj.select([]);
        end

        function setSort(obj, column, descending)
            %SETSORT Order the list by COLUMN (a ColumnNames entry).
            obj.SortColumn = char(column);
            obj.SortDescending = logical(descending);
            obj.setEntries(obj.Entries);
            obj.SortDirButton.Text = ndi.gui.app.LightsheetManager.sortDirText(descending);
        end

        function select(obj, idx)
            %SELECT Make row IDX current ([] for none) and show its details.
            obj.SelectedIndex = idx;
            has = ~isempty(idx);
            obj.DeleteButton.Enable = ndi.gui.nav.cloudInfoDialog.enableFor(has);
            obj.OpenButton.Enable = ndi.gui.nav.cloudInfoDialog.enableFor(has);
            obj.IdCopyButton.Enable = ndi.gui.nav.cloudInfoDialog.enableFor(has);
            obj.IdCopyButton.Text = 'Copy';
            if ~has
                obj.IdField.Value = '';
                obj.DetailsField.Value = {'Select a dataset to see its details.'};
                return;
            end
            obj.fillDetails(idx);
            e = obj.Entries(idx);
            obj.IdField.Value = e.id;
            obj.DetailsField.Value = ndi.gui.nav.cloudDatasetBrowser.detailsText( ...
                obj.Entries(idx), obj.isGroup(obj.Entries(idx)));
        end
    end

    methods (Access = private)
        function fillDetails(obj, idx)
            %FILLDETAILS Fetch counts/dates the list did not include.
            e = obj.Entries(idx);
            if e.detailed
                return;
            end
            try
                [b, d] = ndi.cloud.api.datasets.getDataset(e.id);
            catch
                b = false;
            end
            if b
                full = ndi.gui.nav.cloudDatasetBrowser.entryFromStruct(d);
                obj.Entries(idx) = ndi.gui.nav.cloudDatasetBrowser.mergeEntry(e, full);
            end
            obj.Entries(idx).detailed = true;
            obj.redraw();
        end

        function tf = isGroup(obj, e)
            org = struct('id', e.organizationId, 'name', e.organizationName);
            k = find(strcmp({obj.Organizations.id}, e.organizationId), 1);
            if ~isempty(k)
                org = obj.Organizations(k);
            end
            tf = ndi.gui.nav.cloudDatasetBrowser.isGroupOrganization(org);
        end

        function redraw(obj)
            obj.Table.Data = ndi.gui.nav.cloudDatasetBrowser.entriesToCell(obj.Entries);
        end

        function setStatus(obj, msg)
            if ~isempty(obj.StatusLabel) && isvalid(obj.StatusLabel)
                obj.StatusLabel.Text = msg;
            end
        end

        function onCellSelect(obj, evt)
            if isempty(evt.Indices)
                obj.select([]);
            else
                obj.select(evt.Indices(1, 1));
            end
        end

        function onOpen(obj)
            if isempty(obj.SelectedIndex) || isempty(obj.OpenFcn)
                return;
            end
            e = obj.Entries(obj.SelectedIndex);
            obj.OpenFcn(e.id, e.name);
        end

        function onDelete(obj)
            if isempty(obj.SelectedIndex)
                return;
            end
            e = obj.Entries(obj.SelectedIndex);
            if ~ndi.gui.nav.cloudDatasetBrowser.confirmDelete(e, obj.isGroup(e), obj.Figure)
                obj.setStatus('Delete cancelled.');
                return;
            end
            dlg = uiprogressdlg(obj.Figure, 'Title', 'Delete dataset', ...
                'Message', 'Deleting dataset on NDI Cloud...', 'Indeterminate', 'on');
            try
                [b, answer] = ndi.cloud.api.datasets.deleteDataset(e.id);
            catch ME
                delete(dlg);
                uialert(obj.Figure, ME.message, 'Delete dataset');
                return;
            end
            delete(dlg);
            if ~b
                msg = 'NDI Cloud did not delete the dataset.';
                if isstruct(answer) && isfield(answer, 'message')
                    msg = [msg ' ' char(string(answer.message))];
                end
                uialert(obj.Figure, msg, 'Delete dataset');
                return;
            end
            uialert(obj.Figure, sprintf(['"%s" was deleted. NDI Cloud removes it ' ...
                'permanently after 7 days; until then it can be restored with ' ...
                'ndi.cloud.api.datasets.undeleteDataset(''%s'').'], e.name, e.id), ...
                'Delete dataset', 'Icon', 'success');
            obj.refresh();
        end

        function build(obj, parent, visible)
            c = ndi.gui.cloudColors();
            w = 900; h = 560;
            pos = [120 120 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end
            obj.Figure = uifigure('Name', 'NDI Cloud Datasets', 'Position', pos, ...
                'Color', c.offWhite, 'Visible', visible, ...
                'Tag', 'ndiNavigatorCloudDatasetBrowser');
            g = uigridlayout(obj.Figure, [7 1]);
            g.RowHeight = {28, 26, '1x', 'fit', 110, 30, 22};
            g.BackgroundColor = c.offWhite;

            hb = uigridlayout(g, [1 1]);
            hb.Layout.Row = 1;
            hb.Padding = [8 0 8 0];
            hb.BackgroundColor = c.darkBlue;
            uilabel(hb, 'Text', 'My NDI Cloud datasets', 'FontColor', c.white, ...
                'FontWeight', 'bold', 'FontSize', 14);

            sg = uigridlayout(g, [1 4]);
            sg.Layout.Row = 2;
            sg.ColumnWidth = {'fit', 160, 100, '1x'};
            sg.Padding = [0 0 0 0];
            sg.BackgroundColor = c.offWhite;
            uilabel(sg, 'Text', 'Sort by:', 'FontColor', c.darkBlue);
            uidropdown(sg, 'Items', obj.ColumnNames, 'Value', obj.SortColumn, ...
                'ValueChangedFcn', @(dd,~) obj.setSort(dd.Value, obj.SortDescending));
            obj.SortDirButton = uibutton(sg, ...
                'Text', ndi.gui.app.LightsheetManager.sortDirText(obj.SortDescending), ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) obj.setSort(obj.SortColumn, ~obj.SortDescending));

            obj.Table = uitable(g, 'ColumnName', obj.ColumnNames, ...
                'Data', cell(0, numel(obj.ColumnNames)), ...
                'CellSelectionCallback', @(~, evt) obj.onCellSelect(evt));
            obj.Table.Layout.Row = 3;

            ig = uigridlayout(g, [1 3]);
            ig.Layout.Row = 4;
            ig.ColumnWidth = {'fit', '1x', 'fit'};
            ig.Padding = [0 0 0 0];
            ig.BackgroundColor = c.offWhite;
            uilabel(ig, 'Text', 'Cloud dataset ID:', 'FontWeight', 'bold', 'FontColor', c.darkBlue);
            obj.IdField = uieditfield(ig, 'text', 'Editable', 'off', 'Tag', 'ndiBrowserCloudId');
            obj.IdCopyButton = uibutton(ig, 'Text', 'Copy', 'Enable', 'off', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(b,~) obj.copyId(b));

            obj.DetailsField = uitextarea(g, 'Editable', 'off', ...
                'Value', {'Select a dataset to see its details.'});
            obj.DetailsField.Layout.Row = 5;

            bg = uigridlayout(g, [1 4]);
            bg.Layout.Row = 6;
            bg.ColumnWidth = {'1x', 100, 100, 100};
            bg.Padding = [0 0 0 0];
            bg.BackgroundColor = c.offWhite;
            b = uibutton(bg, 'Text', 'Refresh', 'ButtonPushedFcn', @(~,~) obj.refresh(), ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue);
            b.Layout.Column = 2;
            obj.OpenButton = uibutton(bg, 'Text', 'Open...', 'Enable', 'off', ...
                'Tooltip', 'Download this dataset''s documents to a folder and add it to the Datasets list', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'Visible', ndi.gui.nav.cloudInfoDialog.enableFor(~isempty(obj.OpenFcn)), ...
                'ButtonPushedFcn', @(~,~) obj.onOpen());
            obj.OpenButton.Layout.Column = 3;
            obj.DeleteButton = uibutton(bg, 'Text', 'Delete...', 'Enable', 'off', ...
                'Tooltip', 'Delete this dataset from NDI Cloud (asks first)', ...
                'BackgroundColor', [0.80 0.15 0.15], 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) obj.onDelete());
            obj.DeleteButton.Layout.Column = 4;

            obj.StatusLabel = uilabel(g, 'Text', '', 'FontColor', c.darkBlue);
            obj.StatusLabel.Layout.Row = 7;
        end

        function copyId(obj, b)
            if isempty(obj.IdField.Value), return; end
            clipboard('copy', obj.IdField.Value);
            b.Text = 'Copied';
        end
    end

    methods (Static)
        function ok = confirmDelete(entry, isGroup, parent)
            %CONFIRMDELETE Modal "are you really sure" dialog for one dataset.
            %
            %   OK = confirmDelete(ENTRY, ISGROUP, PARENT) shows the facts about
            %   the dataset (name, id, organization, created, documents, files)
            %   and returns true only if the user satisfied every check and
            %   pressed Delete. Cancel is the default and closing the window
            %   cancels. The checks are deleteAllowed's.
            arguments
                entry (1,1) struct
                isGroup (1,1) logical
                parent = []
            end
            ok = false;
            c = ndi.gui.cloudColors();
            w = 560; h = 470;
            pos = [200 200 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end
            f = uifigure('Name', 'Delete NDI Cloud dataset?', 'Position', pos, ...
                'WindowStyle', 'modal', 'Color', c.offWhite, 'Resize', 'off', ...
                'Tag', 'ndiCloudDatasetDeleteConfirm');
            g = uigridlayout(f, [8 2]);
            g.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit', 'fit', 'fit', 30};
            g.ColumnWidth = {'1x', '1x'};
            g.BackgroundColor = c.offWhite;

            warn = uilabel(g, 'Text', ['You are about to DELETE this dataset from ' ...
                'NDI Cloud. Everyone who uses it will lose access to it.'], ...
                'WordWrap', 'on', 'FontWeight', 'bold', 'FontSize', 14, ...
                'FontColor', [0.75 0.10 0.10]);
            warn.Layout.Row = 1; warn.Layout.Column = [1 2];
            note = uilabel(g, 'WordWrap', 'on', 'FontColor', c.darkBlue, 'Text', ...
                ['Local copies are not affected. NDI Cloud removes the dataset ' ...
                 'permanently after 7 days.']);
            note.Layout.Row = 2; note.Layout.Column = [1 2];
            facts = uitextarea(g, 'Editable', 'off', ...
                'Value', ndi.gui.nav.cloudDatasetBrowser.detailsText(entry, isGroup));
            facts.Layout.Row = 3; facts.Layout.Column = [1 2];

            understand = uicheckbox(g, 'Text', ...
                'I understand that this deletes the dataset from NDI Cloud.', ...
                'Value', false, 'FontColor', c.darkBlue);
            understand.Layout.Row = 4; understand.Layout.Column = [1 2];
            groupBox = uicheckbox(g, 'Text', ...
                'This is in a group organization. Are you sure you want to delete it?', ...
                'Value', false, 'FontColor', [0.75 0.10 0.10], 'FontWeight', 'bold', ...
                'Visible', ndi.gui.nav.cloudInfoDialog.enableFor(isGroup));
            groupBox.Layout.Row = 5; groupBox.Layout.Column = [1 2];
            prompt = uilabel(g, 'FontColor', c.darkBlue, 'Text', ...
                sprintf('Type the dataset name (%s) to confirm:', entry.name));
            prompt.Layout.Row = 6; prompt.Layout.Column = [1 2];
            typed = uieditfield(g, 'text', 'Value', '');
            typed.Layout.Row = 7; typed.Layout.Column = [1 2];

            cancelBtn = uibutton(g, 'Text', 'Cancel', ...
                'BackgroundColor', c.lightBlue, 'FontColor', c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) uiresume(f));
            cancelBtn.Layout.Row = 8; cancelBtn.Layout.Column = 1;
            deleteBtn = uibutton(g, 'Text', 'Delete dataset', 'Enable', 'off', ...
                'BackgroundColor', [0.80 0.15 0.15], 'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(~,~) onDeletePressed());
            deleteBtn.Layout.Row = 8; deleteBtn.Layout.Column = 2;

            update = @(~,~) set(deleteBtn, 'Enable', ndi.gui.nav.cloudInfoDialog.enableFor( ...
                ndi.gui.nav.cloudDatasetBrowser.deleteAllowed(entry.name, typed.Value, ...
                    understand.Value, isGroup, groupBox.Value)));
            understand.ValueChangedFcn = update;
            groupBox.ValueChangedFcn = update;
            typed.ValueChangingFcn = @(~, evt) set(deleteBtn, 'Enable', ...
                ndi.gui.nav.cloudInfoDialog.enableFor( ...
                    ndi.gui.nav.cloudDatasetBrowser.deleteAllowed(entry.name, evt.Value, ...
                        understand.Value, isGroup, groupBox.Value)));
            typed.ValueChangedFcn = update;
            f.CloseRequestFcn = @(~,~) uiresume(f);
            try
                focus(cancelBtn);   % R2022a+; Cancel is the safe default
            catch
            end

            pressed = false;
            uiwait(f);
            if isvalid(f)
                ok = pressed && ndi.gui.nav.cloudDatasetBrowser.deleteAllowed( ...
                    entry.name, typed.Value, understand.Value, isGroup, groupBox.Value);
                delete(f);
            end

            function onDeletePressed()
                pressed = true;
                uiresume(f);
            end
        end

        function tf = deleteAllowed(name, typedName, understood, isGroup, groupConfirmed)
            %DELETEALLOWED True when every delete confirmation is satisfied.
            %   The typed name must match NAME exactly (surrounding spaces are
            %   ignored), the "I understand" box must be ticked, and for a group
            %   organization the group box must be ticked too.
            tf = logical(understood) && ...
                strcmp(strtrim(char(typedName)), strtrim(char(name))) && ...
                ~isempty(strtrim(char(name))) && ...
                (~logical(isGroup) || logical(groupConfirmed));
        end

        function tf = isGroupOrganization(org)
            %ISGROUPORGANIZATION True unless ORG is known to be personal.
            %
            %   NDI Cloud's organization records (id, name, canUploadDataset)
            %   do not currently say whether an organization is a personal one.
            %   This uses whichever of these fields is present, in order:
            %       isPersonal / personal  - personal when true
            %       type                   - personal when 'personal'
            %       memberCount            - personal when 1 or fewer members
            %   and otherwise treats the organization as a group, so that the
            %   extra confirmation is shown rather than skipped when unsure.
            tf = true;
            if ~isstruct(org) || isempty(org)
                return;
            end
            if isfield(org, 'isPersonal') && ~isempty(org.isPersonal)
                tf = ~logical(org.isPersonal);
            elseif isfield(org, 'personal') && ~isempty(org.personal)
                tf = ~logical(org.personal);
            elseif isfield(org, 'type') && ~isempty(org.type)
                tf = ~strcmpi(char(string(org.type)), 'personal');
            elseif isfield(org, 'memberCount') && ~isempty(org.memberCount)
                tf = double(org.memberCount) > 1;
            end
        end

        function e = emptyEntries()
            e = struct('id', {}, 'name', {}, 'organizationId', {}, ...
                'organizationName', {}, 'documentCount', {}, 'fileCount', {}, ...
                'createdAt', {}, 'updatedAt', {}, 'detailed', {});
        end

        function entries = entriesFromList(answer)
            %ENTRIESFROMLIST listDatasets answer -> struct array of entries.
            list = ndi.gui.nav.cloudDatasetBrowser.toCellList(answer);
            entries = ndi.gui.nav.cloudDatasetBrowser.emptyEntries();
            for i = 1:numel(list)
                e = ndi.gui.nav.cloudDatasetBrowser.entryFromStruct(list{i});
                if ~isempty(e.id)
                    entries(end+1) = e; %#ok<AGROW>
                end
            end
        end

        function e = entryFromStruct(d)
            %ENTRYFROMSTRUCT One dataset struct (list or getDataset) -> entry.
            %   Counts that are absent are NaN and dates that are absent are ''.
            F = @(names) ndi.gui.nav.cloudDatasetBrowser.firstField(d, names);
            e = struct();
            e.id = char(string(F({'id', 'x_id', 'datasetId'})));
            e.name = char(string(F({'name', 'datasetName', 'branchName'})));
            if isempty(e.name), e.name = e.id; end
            e.organizationId = char(string(F({'organizationId', 'organization'})));
            e.organizationName = char(string(F({'organizationName'})));
            e.documentCount = ndi.gui.nav.cloudDatasetBrowser.toCount(F({'documentCount', 'numberOfDocuments'}));
            e.fileCount = ndi.gui.nav.cloudDatasetBrowser.toCount(F({'fileCount', 'numberOfFiles'}));
            e.createdAt = char(string(F({'createdAt', 'created'})));
            e.updatedAt = char(string(F({'updatedAt', 'lastModified', 'modifiedAt'})));
            e.detailed = ~isnan(e.documentCount) && ~isnan(e.fileCount) && ...
                ~isempty(e.createdAt) && ~isempty(e.updatedAt);
        end

        function e = mergeEntry(e, full)
            %MERGEENTRY Fill E's missing values from FULL.
            fn = {'name', 'organizationId', 'organizationName', 'createdAt', 'updatedAt'};
            for i = 1:numel(fn)
                if isempty(e.(fn{i})) && ~isempty(full.(fn{i}))
                    e.(fn{i}) = full.(fn{i});
                end
            end
            fn = {'documentCount', 'fileCount'};
            for i = 1:numel(fn)
                if isnan(e.(fn{i}))
                    e.(fn{i}) = full.(fn{i});
                end
            end
        end

        function entries = sortEntries(entries, column, descending)
            %SORTENTRIES Order entries by one of ColumnNames (stable).
            %   Unknown counts and dates sort last in either direction.
            if isempty(entries) || isempty(column)
                return;
            end
            n = numel(entries);
            switch char(column)
                case 'Name',          key = lower({entries.name});
                case 'Organization',  key = lower({entries.organizationName});
                case 'Created',       key = {entries.createdAt};
                case 'Last changed',  key = {entries.updatedAt};
                case 'Documents',     key = [entries.documentCount];
                case 'Files',         key = [entries.fileCount];
                otherwise
                    error('NDI:cloudDatasetBrowser:BadSortColumn', ...
                        'Unknown column "%s".', char(column));
            end
            if iscell(key)
                missing = cellfun(@isempty, key);
                [~, ~, rank] = unique(key);
                rank = rank(:)';
            else
                missing = isnan(key);
                rank = key;
                rank(missing) = 0;
            end
            if descending
                rank = -rank;
            end
            % Sort by (missing, rank): numeric sort is stable.
            [~, order] = sortrows([double(missing(:)), double(rank(:)), (1:n)']);
            entries = entries(order);
        end

        function c = entriesToCell(entries)
            %ENTRIESTOCELL Table data, one row per entry.
            c = cell(numel(entries), 6);
            for i = 1:numel(entries)
                e = entries(i);
                c{i,1} = e.name;
                c{i,2} = e.organizationName;
                c{i,3} = ndi.gui.nav.cloudDatasetBrowser.countText(e.documentCount);
                c{i,4} = ndi.gui.nav.cloudDatasetBrowser.countText(e.fileCount);
                c{i,5} = ndi.gui.nav.cloudDatasetBrowser.dateText(e.createdAt);
                c{i,6} = ndi.gui.nav.cloudDatasetBrowser.dateText(e.updatedAt);
            end
        end

        function lines = detailsText(e, isGroup)
            %DETAILSTEXT The facts about one dataset, one per line.
            if isGroup
                orgKind = 'group organization';
            else
                orgKind = 'your own organization';
            end
            lines = { ...
                sprintf('Name:          %s', e.name), ...
                sprintf('Cloud ID:      %s', e.id), ...
                sprintf('Organization:  %s (%s)', ...
                    ndi.gui.nav.cloudInfoDialog.valueText(e.organizationName), orgKind), ...
                sprintf('Created:       %s', ndi.gui.nav.cloudDatasetBrowser.dateText(e.createdAt)), ...
                sprintf('Last changed:  %s', ndi.gui.nav.cloudDatasetBrowser.dateText(e.updatedAt)), ...
                sprintf('Documents:     %s', ndi.gui.nav.cloudDatasetBrowser.countText(e.documentCount)), ...
                sprintf('Files:         %s', ndi.gui.nav.cloudDatasetBrowser.countText(e.fileCount))};
        end

        function t = dateText(s)
            %DATETEXT '2024-05-01T12:34:56.789Z' -> '2024-05-01 12:34 UTC'.
            s = char(s);
            if isempty(s)
                t = '(unknown)';
            elseif numel(s) >= 16 && s(11) == 'T'
                t = [s(1:10) ' ' s(12:16) ' UTC'];
            else
                t = s;
            end
        end

        function t = countText(n)
            if isempty(n) || isnan(n)
                t = '(unknown)';
            else
                t = sprintf('%d', round(n));
            end
        end
    end

    methods (Static, Access = private)
        function list = toCellList(answer)
            list = {};
            payload = answer;
            if isstruct(answer) && isscalar(answer) && isfield(answer, 'datasets')
                payload = answer.datasets;
            end
            if iscell(payload)
                list = payload;
            elseif isstruct(payload)
                list = num2cell(payload(:)');
            end
        end

        function v = firstField(d, names)
            v = '';
            if ~isstruct(d), return; end
            for i = 1:numel(names)
                if isfield(d, names{i}) && ~isempty(d.(names{i}))
                    v = d.(names{i});
                    return;
                end
            end
        end

        function n = toCount(v)
            n = NaN;
            if isnumeric(v) && isscalar(v)
                n = double(v);
            elseif (ischar(v) || isstring(v)) && ~isempty(v)
                n = str2double(v);
            end
        end
    end
end
