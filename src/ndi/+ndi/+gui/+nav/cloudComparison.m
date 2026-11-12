classdef cloudComparison < handle
%NDI.GUI.NAV.CLOUDCOMPARISON Compare a local dataset with NDI Cloud, and sync.
%
%   NDI.GUI.NAV.CLOUDCOMPARISON(DS) opens a window that compares the
%   documents of the local ndi.dataset DS with the documents of the NDI
%   Cloud dataset it is linked to, and offers the sync operations as
%   buttons. It is the navigator's only way to sync: the per-operation menu
%   items were removed so that a user always sees the state of both sides
%   before changing either (see ndi.gui.nav.datasetsPane).
%
%   WHICH COPY IS BEING COMPARED. One cloud dataset can have several local
%   copies, and the comparison depends on which one is used. The top of the
%   window therefore names, prominently and with Copy buttons, the local
%   dataset name, the folder of THIS local copy, and the cloud dataset id.
%
%   THE COMPARISON. ndi.cloud.sync.documentDifference compares document
%   ids only (it downloads no document contents), so it is cheap enough to
%   run whenever the window opens or Refresh is pressed. The summary line
%   counts documents only in the cloud, only local, and in both, and the
%   table lists each document id with where it is. "Check content" runs
%   ndi.cloud.sync.validate instead, which also downloads the remote
%   documents and flags documents present on both sides whose content
%   differs; it is slower, so it only runs when asked.
%
%   The window opens at once and shows "Computing..." while the comparison
%   runs, so a large dataset does not leave the user waiting on nothing.
%
%   SYNC BUTTONS. One per ndi.cloud.sync.enum.SyncMode:
%       Download New from Cloud  ndi.cloud.sync.downloadNew      adds only
%       Upload New to Cloud      ndi.cloud.sync.uploadNew        adds only
%       Two Way Sync             ndi.cloud.sync.twoWaySync       adds only
%       Mirror from Cloud        ndi.cloud.sync.mirrorFromRemote DELETES local-only docs
%       Mirror to Cloud          ndi.cloud.sync.mirrorToRemote   DELETES cloud-only docs
%   The two Mirror buttons are destructive and ask for confirmation first;
%   the warning states how many documents will be deleted, taken from the
%   current comparison. Two options apply to every operation:
%       Also sync data files  (SyncFiles) - download the binary files too
%       Dry run               (DryRun)    - report what would happen only
%   After an operation the comparison is recomputed automatically.
%
%   NDI.GUI.NAV.CLOUDCOMPARISON(DS, 'Parent', FIG) centres the window over
%   FIG. 'CloudDatasetId', ID names the cloud dataset (by default it is read
%   from DS). 'Visible', 'off' builds it hidden and 'Compute', false skips
%   the initial comparison (both for headless tests).
%
%   Syntax:
%       ndi.gui.nav.cloudComparison(D)
%       obj = ndi.gui.nav.cloudComparison(D, 'Parent', navFig)
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.nav.cloudInfoDialog,
%             ndi.cloud.sync.documentDifference, ndi.cloud.sync.validate,
%             ndi.cloud.sync.enum.SyncMode

    properties (SetAccess = protected)
        Dataset                         % the local ndi.dataset
        CloudDatasetId char = ''        % the linked NDI Cloud dataset id
        DatasetName char = ''           % the local dataset's reference
        LocalPath char = ''             % the folder of this local copy
        Report = []                     % last comparison report, or []
        ContentChecked (1,1) logical = false % Report came from validate
        Figure                          % the uifigure
        SummaryLabel                    % one-line comparison summary
        Table                           % document id | where
        StatusLabel                     % progress / result line
        SyncFilesBox                    % "Also sync data files" checkbox
        DryRunBox                       % "Dry run" checkbox
        ActionButtons                   % the sync buttons (struct array of handles)
    end

    methods
        function obj = cloudComparison(ds, options)
            arguments
                ds (1,1)
                options.Parent = []
                options.CloudDatasetId = ''
                options.Visible (1,:) char = 'on'
                options.Compute (1,1) logical = true
            end
            obj.Dataset = ds;
            obj.DatasetName = ndi.gui.nav.cloudComparison.safeCall(@() char(ds.reference()));
            obj.LocalPath = ndi.gui.nav.cloudComparison.safeCall(@() char(ds.path));
            id = char(options.CloudDatasetId);
            if isempty(id)
                id = ndi.gui.nav.cloudComparison.safeCall(@() ...
                    char(ndi.cloud.internal.getCloudDatasetIdForLocalDataset(ds)));
            end
            obj.CloudDatasetId = id;
            obj.build(options.Parent, options.Visible);
            if options.Compute
                obj.refresh();
            end
        end

        function refresh(obj)
            %REFRESH Recompute the id-only comparison and redraw.
            obj.compute(false);
        end

        function checkContent(obj)
            %CHECKCONTENT Recompute with content checking (slower).
            obj.compute(true);
        end

        function runAction(obj, mode)
            %RUNACTION Run sync MODE (a SyncMode function name), then refresh.
            spec = ndi.gui.nav.cloudComparison.actionSpec(mode);
            fig = obj.Figure;
            dryRun = logical(obj.DryRunBox.Value);
            if spec.Destructive && ~dryRun
                sel = uiconfirm(fig, ...
                    ndi.gui.nav.cloudComparison.mirrorWarning(mode, obj.Report, ...
                        obj.LocalPath, obj.CloudDatasetId), ...
                    spec.Label, ...
                    'Options', {'Delete and mirror', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
                if ~strcmp(sel, 'Delete and mirror')
                    return;
                end
            end
            dlg = uiprogressdlg(fig, 'Title', spec.Label, ...
                'Message', 'Synchronizing with NDI Cloud...', 'Indeterminate', 'on');
            try
                [success, errorMessage, report] = feval(['ndi.cloud.sync.' mode], ...
                    obj.Dataset, 'Verbose', false, ...
                    'SyncFiles', logical(obj.SyncFilesBox.Value), ...
                    'DryRun', dryRun);
            catch ME
                delete(dlg);
                uialert(fig, ME.message, spec.Label);
                return;
            end
            delete(dlg);
            if success
                msg = ndi.gui.nav.datasetsPane.syncResultMessage(report);
                if dryRun
                    msg = ['Dry run - nothing was changed. ' msg];
                end
                obj.setStatus([spec.Label ': ' strrep(msg, newline, ', ')]);
                uialert(fig, msg, spec.Label, 'Icon', 'success');
            else
                uialert(fig, ['Sync did not complete: ' char(errorMessage)], spec.Label);
            end
            if ~dryRun
                obj.refresh();
            end
        end
    end

    methods (Access = private)
        function compute(obj, checkContent)
            %COMPUTE Run documentDifference (or validate) and redraw.
            if isempty(obj.CloudDatasetId)
                obj.SummaryLabel.Text = ['This dataset is not linked to NDI Cloud. ' ...
                    'Use "Upload to Cloud" first.'];
                obj.setButtonsEnabled(false);
                return;
            end
            obj.SummaryLabel.Text = 'Computing...';
            obj.Table.Data = cell(0, 2);
            obj.setButtonsEnabled(false);
            drawnow;
            try
                if checkContent
                    report = ndi.cloud.sync.validate(obj.Dataset, ...
                        'Verbose', false, 'cloudDatasetId', obj.CloudDatasetId);
                else
                    report = ndi.cloud.sync.documentDifference(obj.Dataset, ...
                        'cloudDatasetId', obj.CloudDatasetId);
                end
            catch ME
                obj.SummaryLabel.Text = ['Could not compare: ' ME.message];
                obj.setButtonsEnabled(true);
                return;
            end
            obj.showReport(report, checkContent);
        end

        function showReport(obj, report, checkContent)
            obj.Report = report;
            obj.ContentChecked = checkContent;
            obj.SummaryLabel.Text = ndi.gui.nav.cloudComparison.summaryText(report);
            obj.Table.Data = ndi.gui.nav.cloudComparison.comparisonRows(report);
            obj.setButtonsEnabled(true);
            obj.setStatus(sprintf('Compared at %s.', ...
                char(datetime('now', 'Format', 'HH:mm:ss'))));
        end

        function setButtonsEnabled(obj, tf)
            for i = 1:numel(obj.ActionButtons)
                if isvalid(obj.ActionButtons(i))
                    obj.ActionButtons(i).Enable = ndi.gui.nav.cloudInfoDialog.enableFor(tf);
                end
            end
        end

        function setStatus(obj, msg)
            if ~isempty(obj.StatusLabel) && isvalid(obj.StatusLabel)
                obj.StatusLabel.Text = msg;
            end
        end

        function build(obj, parent, visible)
            c = ndi.gui.cloudColors();
            w = 760; h = 560;
            pos = [150 150 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end
            obj.Figure = uifigure('Name', 'Cloud Comparison', ...
                'Position', pos, 'Color', c.offWhite, 'Visible', visible, ...
                'Tag', 'ndiNavigatorCloudComparison');

            g = uigridlayout(obj.Figure, [6 1]);
            g.RowHeight = {'fit', 'fit', '1x', 'fit', 'fit', 22};
            g.RowSpacing = 8;
            g.BackgroundColor = c.offWhite;

            % --- Header: which local copy, which cloud dataset -------------
            hdr = uigridlayout(g, [4 3]);
            hdr.Layout.Row = 1;
            hdr.RowHeight = {'fit', 'fit', 'fit', 'fit'};
            hdr.ColumnWidth = {'fit', '1x', 'fit'};
            hdr.BackgroundColor = c.darkBlue;
            hdr.Padding = [10 8 10 8];
            t = uilabel(hdr, 'Text', 'Comparing this local copy with its NDI Cloud dataset', ...
                'FontColor', c.white, 'FontWeight', 'bold', 'FontSize', 14);
            t.Layout.Row = 1; t.Layout.Column = [1 3];
            obj.headerRow(hdr, 2, c, 'Dataset name:', obj.DatasetName, 'ndiCompareName');
            obj.headerRow(hdr, 3, c, 'Local copy (this folder):', obj.LocalPath, 'ndiComparePath');
            obj.headerRow(hdr, 4, c, 'Cloud dataset ID:', obj.CloudDatasetId, 'ndiCompareCloudId');

            % --- Summary + Refresh / Check content -------------------------
            sg = uigridlayout(g, [1 3]);
            sg.Layout.Row = 2;
            sg.ColumnWidth = {'1x', 'fit', 'fit'};
            sg.Padding = [0 0 0 0];
            sg.BackgroundColor = c.offWhite;
            obj.SummaryLabel = uilabel(sg, 'Text', '', 'FontWeight', 'bold', ...
                'FontColor', c.darkBlue, 'WordWrap', 'on');
            b = uibutton(sg, 'Text', 'Refresh', ...
                'Tooltip', 'Recompute the comparison (document ids only; fast)', ...
                'ButtonPushedFcn', @(~,~) obj.refresh());
            ndi.gui.nav.cloudComparison.accent(b, c);
            b = uibutton(sg, 'Text', 'Check content', ...
                'Tooltip', ['Also compare the contents of documents on both sides ' ...
                    '(downloads the cloud documents; slower)'], ...
                'ButtonPushedFcn', @(~,~) obj.checkContent());
            ndi.gui.nav.cloudComparison.accent(b, c);

            % --- Table -----------------------------------------------------
            obj.Table = uitable(g, 'ColumnName', {'Document ID', 'Where'}, ...
                'Data', cell(0, 2), 'ColumnSortable', true, ...
                'ColumnWidth', {'auto', 200});
            obj.Table.Layout.Row = 3;

            % --- Options ---------------------------------------------------
            og = uigridlayout(g, [1 3]);
            og.Layout.Row = 4;
            og.ColumnWidth = {'fit', 'fit', '1x'};
            og.Padding = [0 0 0 0];
            og.BackgroundColor = c.offWhite;
            obj.SyncFilesBox = uicheckbox(og, 'Text', 'Also sync data files', ...
                'Value', false, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Download the binary data files as well as the documents (SyncFiles)');
            obj.DryRunBox = uicheckbox(og, 'Text', 'Dry run (preview only)', ...
                'Value', false, 'FontColor', c.darkBlue, ...
                'Tooltip', 'Report what the operation would do without changing anything (DryRun)');

            % --- Sync buttons ----------------------------------------------
            specs = ndi.gui.nav.cloudComparison.actionSpecs();
            ag = uigridlayout(g, [1 numel(specs)]);
            ag.Layout.Row = 5;
            ag.ColumnWidth = repmat({'1x'}, 1, numel(specs));
            ag.Padding = [0 0 0 0];
            ag.BackgroundColor = c.offWhite;
            buttons = gobjects(1, numel(specs));
            for i = 1:numel(specs)
                s = specs(i);
                buttons(i) = uibutton(ag, 'Text', s.Label, 'Tooltip', s.Tooltip, ...
                    'ButtonPushedFcn', @(~,~) obj.runAction(s.Mode));
                if s.Destructive
                    buttons(i).BackgroundColor = [0.85 0.33 0.10];
                    buttons(i).FontColor = [1 1 1];
                else
                    ndi.gui.nav.cloudComparison.accent(buttons(i), c);
                end
            end
            obj.ActionButtons = buttons;

            obj.StatusLabel = uilabel(g, 'Text', '', 'FontColor', c.darkBlue);
            obj.StatusLabel.Layout.Row = 6;
        end

        function headerRow(~, hdr, row, c, label, value, tag)
            lbl = uilabel(hdr, 'Text', label, 'FontColor', c.white, 'FontWeight', 'bold');
            lbl.Layout.Row = row; lbl.Layout.Column = 1;
            f = uieditfield(hdr, 'text', 'Editable', 'off', 'Tag', tag, ...
                'Value', ndi.gui.nav.cloudInfoDialog.valueText(value));
            f.Layout.Row = row; f.Layout.Column = 2;
            b = uibutton(hdr, 'Text', 'Copy', 'BackgroundColor', c.lightBlue, ...
                'FontColor', c.darkBlue, 'Tag', [tag 'Copy'], ...
                'Enable', ndi.gui.nav.cloudInfoDialog.enableFor(~isempty(value)));
            b.ButtonPushedFcn = @(~,~) ndi.gui.nav.cloudComparison.copyTo(b, value);
            b.Layout.Row = row; b.Layout.Column = 3;
        end
    end

    methods (Static)
        function specs = actionSpecs()
            %ACTIONSPECS The sync buttons, in display order.
            %   A struct array with fields Mode (the ndi.cloud.sync function
            %   name), Label, Tooltip and Destructive.
            specs = struct( ...
                'Mode', {'downloadNew', 'uploadNew', 'twoWaySync', ...
                         'mirrorFromRemote', 'mirrorToRemote'}, ...
                'Label', {'Download New from Cloud', 'Upload New to Cloud', ...
                          'Two Way Sync', 'Mirror from Cloud', 'Mirror to Cloud'}, ...
                'Tooltip', { ...
                    'Add documents that are only in the cloud to this local copy. Deletes nothing.', ...
                    'Add documents that are only in this local copy to the cloud. Deletes nothing.', ...
                    'Add missing documents in both directions. Deletes nothing.', ...
                    'Make this local copy match the cloud. DELETES local-only documents.', ...
                    'Make the cloud match this local copy. DELETES cloud-only documents.'}, ...
                'Destructive', {false, false, false, true, true});
        end

        function spec = actionSpec(mode)
            %ACTIONSPEC The actionSpecs entry for MODE (errors if unknown).
            specs = ndi.gui.nav.cloudComparison.actionSpecs();
            k = find(strcmp({specs.Mode}, char(mode)), 1);
            if isempty(k)
                error('NDI:cloudComparison:BadMode', 'Unknown sync mode "%s".', char(mode));
            end
            spec = specs(k);
        end

        function msg = summaryText(report)
            %SUMMARYTEXT One-line summary of a comparison report.
            [nRemote, nLocal, nBoth, nDiff] = ndi.gui.nav.cloudComparison.counts(report);
            msg = sprintf('Only in cloud: %d    Only local: %d    In both: %d', ...
                nRemote, nLocal, nBoth);
            if ~isnan(nDiff)
                msg = [msg sprintf('    Content differs: %d', nDiff)];
            end
            if nRemote == 0 && nLocal == 0 && (isnan(nDiff) || nDiff == 0)
                msg = [msg '    (in sync)'];
            end
        end

        function [nRemote, nLocal, nBoth, nDiff] = counts(report)
            %COUNTS Document counts from a documentDifference or validate report.
            %   NDIFF is NaN when the report did not check content.
            nRemote = numel(ndi.gui.nav.cloudComparison.ids(report, 'remote_only_ids'));
            nLocal  = numel(ndi.gui.nav.cloudComparison.ids(report, 'local_only_ids'));
            nBoth   = numel(ndi.gui.nav.cloudComparison.ids(report, 'common_ids'));
            if isstruct(report) && isfield(report, 'mismatched_ids')
                nDiff = numel(ndi.gui.nav.cloudComparison.ids(report, 'mismatched_ids'));
            else
                nDiff = NaN;
            end
        end

        function rows = comparisonRows(report)
            %COMPARISONROWS N-by-2 cell {document id, where} for the table.
            %   Documents only in the cloud come first, then only local, then
            %   those whose content differs (validate reports only), then those
            %   in both.
            remote = ndi.gui.nav.cloudComparison.ids(report, 'remote_only_ids');
            local  = ndi.gui.nav.cloudComparison.ids(report, 'local_only_ids');
            both   = ndi.gui.nav.cloudComparison.ids(report, 'common_ids');
            diffs  = ndi.gui.nav.cloudComparison.ids(report, 'mismatched_ids');
            same   = setdiff(both, diffs, 'stable');
            rows = [ ...
                [remote(:), repmat({'Only in cloud'}, numel(remote), 1)]; ...
                [local(:),  repmat({'Only local'}, numel(local), 1)]; ...
                [diffs(:),  repmat({'In both - content differs'}, numel(diffs), 1)]; ...
                [same(:),   repmat({'In both'}, numel(same), 1)]];
            if isempty(rows)
                rows = cell(0, 2);
            end
        end

        function msg = mirrorWarning(mode, report, localPath, cloudId)
            %MIRRORWARNING Confirmation text for a destructive mirror.
            %   Names the side that loses documents and, when REPORT is
            %   known, how many documents will be deleted.
            if isempty(localPath), localPath = '(unknown)'; end
            if isempty(cloudId), cloudId = '(unknown)'; end
            switch char(mode)
                case 'mirrorFromRemote'
                    field = 'local_only_ids';
                    what = sprintf(['Mirror from Cloud will make the local copy in\n%s\n' ...
                        'an exact copy of cloud dataset %s.'], localPath, cloudId);
                    where = 'from this local copy';
                case 'mirrorToRemote'
                    field = 'remote_only_ids';
                    what = sprintf(['Mirror to Cloud will make cloud dataset %s\n' ...
                        'an exact copy of the local copy in\n%s.'], cloudId, localPath);
                    where = 'from the cloud dataset';
                otherwise
                    error('NDI:cloudComparison:BadMode', ...
                        'Only the mirror modes are destructive; got "%s".', char(mode));
            end
            if isempty(report)
                countText = sprintf(['Documents that are not on the other side will be ' ...
                    'permanently DELETED %s.'], where);
            else
                n = numel(ndi.gui.nav.cloudComparison.ids(report, field));
                if n == 1
                    countText = sprintf('1 document will be permanently DELETED %s.', where);
                else
                    countText = sprintf('%d documents will be permanently DELETED %s.', n, where);
                end
                countText = [countText ' (Counts are from the last comparison; ' ...
                    'press Refresh first if things may have changed.)'];
            end
            msg = sprintf('%s\n\n%s\n\nThis cannot be undone. Are you sure?', what, countText);
        end
    end

    methods (Static, Access = private)
        function c = ids(report, field)
            %IDS Field of REPORT as a cell row of char ({} if absent).
            c = {};
            if isstruct(report) && isfield(report, field) && ~isempty(report.(field))
                c = cellstr(string(report.(field)));
                c = c(:)';
            end
        end

        function v = safeCall(f)
            try
                v = f();
            catch
                v = '';
            end
        end

        function copyTo(button, value)
            if isempty(value), return; end
            clipboard('copy', char(value));
            button.Text = 'Copied';
        end

        function accent(btn, c)
            btn.BackgroundColor = c.lightBlue;
            btn.FontColor = c.darkBlue;
        end
    end
end
