classdef cloudInfoDialog < handle
%NDI.GUI.NAV.CLOUDINFODIALOG Result window for the "Cloud info" command.
%
%   NDI.GUI.NAV.CLOUDINFODIALOG(INCLOUD, CLOUDDATASETID) opens a small
%   window reporting whether a dataset is linked to NDI Cloud. Below the
%   status message it shows three read-only, selectable rows, each with a
%   "Copy" button that puts the value on the system clipboard:
%       Dataset name      - the local dataset's reference
%       Local path        - the folder that holds this local copy
%       Cloud dataset ID  - the NDI Cloud dataset id
%   When the dataset is not in the cloud there is no id: that field reads
%   "(not in NDI Cloud)" and its Copy button is greyed out (Enable 'off').
%   Likewise an unknown name or path reads "(unknown)" with Copy greyed out.
%
%   Showing the local path matters because one cloud dataset can have
%   several local copies; the path says which copy this window describes.
%
%   NDI.GUI.NAV.CLOUDINFODIALOG(..., 'DatasetName', NAME, 'LocalPath', P)
%   supplies the name and path. 'Parent', FIG centres the window over the
%   uifigure FIG (e.g. the navigator), and 'Visible', 'off' builds it hidden
%   (for headless tests).
%
%   It is the target of the navigator's per-dataset "Cloud > Cloud info..."
%   menu item (see ndi.gui.nav.datasetsPane). It was called
%   ndi.gui.nav.cloudStatusDialog ("Check Cloud status") before the name and
%   path rows were added.
%
%   Syntax:
%       ndi.gui.nav.cloudInfoDialog(true, '668b0539f13096e04f1feccd', ...
%           'DatasetName', 'mydataset', 'LocalPath', '/data/mydataset')
%       obj = ndi.gui.nav.cloudInfoDialog(false, '', 'Parent', navFig)
%
%   See also: ndi.gui.nav.datasetsPane, ndi.gui.nav.cloudComparison,
%             ndi.dataset/isInCloud

    properties (SetAccess = protected)
        InCloud (1,1) logical = false   % whether the dataset is in NDI Cloud
        CloudDatasetId char = ''        % the NDI Cloud dataset id, or ''
        DatasetName char = ''           % the local dataset's reference, or ''
        LocalPath char = ''             % the local copy's folder, or ''
        Figure                          % the uifigure
        IdField                         % read-only uieditfield showing the id
        CopyButton                      % "Copy" uibutton for the id
        NameField                       % read-only uieditfield showing the name
        NameCopyButton                  % "Copy" uibutton for the name
        PathField                       % read-only uieditfield showing the path
        PathCopyButton                  % "Copy" uibutton for the path
    end

    methods
        function obj = cloudInfoDialog(inCloud, cloudDatasetId, options)
            arguments
                inCloud (1,1) logical
                cloudDatasetId = ''
                options.DatasetName = ''
                options.LocalPath = ''
                options.Parent = []
                options.Visible (1,:) char = 'on'
            end
            obj.InCloud = inCloud;
            obj.CloudDatasetId = char(cloudDatasetId);
            obj.DatasetName = char(options.DatasetName);
            obj.LocalPath = char(options.LocalPath);
            obj.build(options.Parent, options.Visible);
        end

        function copyId(obj)
            %COPYID Copy the cloud dataset id to the system clipboard.
            %   Does nothing when there is no id to copy.
            if ~ndi.gui.nav.cloudInfoDialog.canCopy(obj.InCloud, obj.CloudDatasetId)
                return;
            end
            clipboard('copy', obj.CloudDatasetId);
            obj.CopyButton.Text = 'Copied';
        end

        function copyName(obj)
            %COPYNAME Copy the dataset name to the system clipboard.
            if isempty(obj.DatasetName)
                return;
            end
            clipboard('copy', obj.DatasetName);
            obj.NameCopyButton.Text = 'Copied';
        end

        function copyPath(obj)
            %COPYPATH Copy the local path to the system clipboard.
            if isempty(obj.LocalPath)
                return;
            end
            clipboard('copy', obj.LocalPath);
            obj.PathCopyButton.Text = 'Copied';
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            %BUILD Construct the window: message, name/path/id rows, OK button.
            c = ndi.gui.cloudColors();
            w = 560; h = 240;
            pos = [200 200 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end

            obj.Figure = uifigure('Name', 'Cloud Info', ...
                'Position',   pos, ...
                'Color',      c.darkBlue, ...
                'Resize',     'off', ...
                'Visible',    visible, ...
                'WindowStyle','modal', ...
                'Tag',        'ndiNavigatorCloudInfo');

            g = uigridlayout(obj.Figure, [5 3]);
            g.RowHeight       = {'1x', 'fit', 'fit', 'fit', 'fit'};
            g.ColumnWidth     = {'fit', '1x', 'fit'};
            g.RowSpacing      = 10;
            g.Padding         = [12 12 12 12];
            g.BackgroundColor = c.darkBlue;

            msg = uilabel(g, ...
                'Text',      ndi.gui.nav.cloudInfoDialog.statusMessage(obj.InCloud), ...
                'WordWrap',  'on', ...
                'FontColor', c.white);
            msg.Layout.Row = 1;
            msg.Layout.Column = [1 3];

            [obj.NameField, obj.NameCopyButton] = obj.addRow(g, 2, c, ...
                'Dataset name:', ...
                ndi.gui.nav.cloudInfoDialog.valueText(obj.DatasetName), ...
                ndi.gui.nav.cloudInfoDialog.enableFor(~isempty(obj.DatasetName)), ...
                'ndiDatasetName', 'Copy the dataset name to the clipboard', ...
                @(~,~) obj.copyName());

            [obj.PathField, obj.PathCopyButton] = obj.addRow(g, 3, c, ...
                'Local path:', ...
                ndi.gui.nav.cloudInfoDialog.valueText(obj.LocalPath), ...
                ndi.gui.nav.cloudInfoDialog.enableFor(~isempty(obj.LocalPath)), ...
                'ndiDatasetLocalPath', 'Copy the local path to the clipboard', ...
                @(~,~) obj.copyPath());

            [obj.IdField, obj.CopyButton] = obj.addRow(g, 4, c, ...
                'Cloud dataset ID:', ...
                ndi.gui.nav.cloudInfoDialog.idText(obj.InCloud, obj.CloudDatasetId), ...
                ndi.gui.nav.cloudInfoDialog.copyEnable(obj.InCloud, obj.CloudDatasetId), ...
                'ndiCloudDatasetId', 'Copy the cloud dataset ID to the clipboard', ...
                @(~,~) obj.copyId());

            ok = uibutton(g, ...
                'Text',            'OK', ...
                'BackgroundColor', c.white, ...
                'FontColor',       c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) delete(obj.Figure));
            ok.Layout.Row = 5;
            ok.Layout.Column = 3;
        end

        function [field, button] = addRow(~, g, row, c, label, value, enable, tag, tip, fcn)
            %ADDROW One "label | read-only value | Copy" row.
            lbl = uilabel(g, ...
                'Text',       label, ...
                'FontWeight', 'bold', ...
                'FontColor',  c.white);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;

            % A read-only edit field (rather than a label) so the value can
            % also be selected and copied by hand.
            field = uieditfield(g, 'text', ...
                'Value',    value, ...
                'Editable', 'off', ...
                'Tag',      tag);
            field.Layout.Row = row;
            field.Layout.Column = 2;

            button = uibutton(g, ...
                'Text',            'Copy', ...
                'Tooltip',         tip, ...
                'Enable',          enable, ...
                'BackgroundColor', c.lightBlue, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             [tag 'Copy'], ...
                'ButtonPushedFcn', fcn);
            button.Layout.Row = row;
            button.Layout.Column = 3;
        end
    end

    methods (Static)
        function msg = statusMessage(inCloud)
            %STATUSMESSAGE The status sentence shown at the top of the window.
            if inCloud
                msg = 'This dataset is linked to NDI Cloud.';
            else
                msg = ['This dataset is not in NDI Cloud. Use ' ...
                    '"Upload to Cloud" to add it.'];
            end
        end

        function tf = canCopy(inCloud, cloudDatasetId)
            %CANCOPY True when there is a cloud dataset id to copy.
            tf = logical(inCloud) && ~isempty(cloudDatasetId);
        end

        function e = copyEnable(inCloud, cloudDatasetId)
            %COPYENABLE 'on' or 'off' for the id Copy button's Enable property.
            e = ndi.gui.nav.cloudInfoDialog.enableFor( ...
                ndi.gui.nav.cloudInfoDialog.canCopy(inCloud, cloudDatasetId));
        end

        function t = idText(inCloud, cloudDatasetId)
            %IDTEXT Text shown in the id field.
            if ndi.gui.nav.cloudInfoDialog.canCopy(inCloud, cloudDatasetId)
                t = char(cloudDatasetId);
            else
                t = '(not in NDI Cloud)';
            end
        end

        function t = valueText(value)
            %VALUETEXT Text shown in the name or path field.
            if isempty(value)
                t = '(unknown)';
            else
                t = char(value);
            end
        end

        function e = enableFor(tf)
            %ENABLEFOR 'on' when TF is true, otherwise 'off'.
            if tf
                e = 'on';
            else
                e = 'off';
            end
        end
    end
end
