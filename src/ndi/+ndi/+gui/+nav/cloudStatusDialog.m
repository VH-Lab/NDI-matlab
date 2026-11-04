classdef cloudStatusDialog < handle
%NDI.GUI.NAV.CLOUDSTATUSDIALOG Result window for "Check Cloud status".
%
%   NDI.GUI.NAV.CLOUDSTATUSDIALOG(INCLOUD, CLOUDDATASETID) opens a small
%   window reporting whether a dataset is linked to NDI Cloud. It shows the
%   status message, the NDI Cloud dataset id (cloudDatasetId) in a
%   read-only, selectable field, and a "Copy" button that puts the id on
%   the system clipboard. When the dataset is not in the cloud there is no
%   id: the field reads "(not in NDI Cloud)" and the Copy button is greyed
%   out (Enable 'off').
%
%   NDI.GUI.NAV.CLOUDSTATUSDIALOG(..., 'Parent', FIG) centres the window
%   over the uifigure FIG (e.g. the navigator), and 'Visible', 'off' builds
%   it hidden (for headless tests).
%
%   It is the target of the navigator's per-dataset "Cloud > Check Cloud
%   status" menu item (see ndi.gui.nav.datasetsPane).
%
%   Syntax:
%       ndi.gui.nav.cloudStatusDialog(true, '668b0539f13096e04f1feccd')
%       obj = ndi.gui.nav.cloudStatusDialog(false, '', 'Parent', navFig)
%
%   See also: ndi.gui.nav.datasetsPane, ndi.dataset/isInCloud

    properties (SetAccess = protected)
        InCloud (1,1) logical = false   % whether the dataset is in NDI Cloud
        CloudDatasetId char = ''        % the NDI Cloud dataset id, or ''
        Figure                          % the uifigure
        IdField                         % read-only uieditfield showing the id
        CopyButton                      % "Copy" uibutton
    end

    methods
        function obj = cloudStatusDialog(inCloud, cloudDatasetId, options)
            arguments
                inCloud (1,1) logical
                cloudDatasetId = ''
                options.Parent = []
                options.Visible (1,:) char = 'on'
            end
            obj.InCloud = inCloud;
            obj.CloudDatasetId = char(cloudDatasetId);
            obj.build(options.Parent, options.Visible);
        end

        function copyId(obj)
            %COPYID Copy the cloud dataset id to the system clipboard.
            %   Does nothing when there is no id to copy.
            if ~ndi.gui.nav.cloudStatusDialog.canCopy(obj.InCloud, obj.CloudDatasetId)
                return;
            end
            clipboard('copy', obj.CloudDatasetId);
            obj.CopyButton.Text = 'Copied';
        end
    end

    methods (Access = private)
        function build(obj, parent, visible)
            %BUILD Construct the window: message, id row, OK button.
            c = ndi.gui.cloudColors();
            w = 460; h = 170;
            pos = [200 200 w h];
            if ~isempty(parent) && isvalid(parent)
                p = parent.Position;
                pos(1:2) = [p(1) + (p(3) - w)/2, p(2) + (p(4) - h)/2];
            end

            obj.Figure = uifigure('Name', 'Check Cloud Status', ...
                'Position',   pos, ...
                'Color',      c.darkBlue, ...
                'Resize',     'off', ...
                'Visible',    visible, ...
                'WindowStyle','modal', ...
                'Tag',        'ndiNavigatorCloudStatus');

            g = uigridlayout(obj.Figure, [3 3]);
            g.RowHeight       = {'1x', 'fit', 'fit'};
            g.ColumnWidth     = {'fit', '1x', 'fit'};
            g.RowSpacing      = 10;
            g.Padding         = [12 12 12 12];
            g.BackgroundColor = c.darkBlue;

            msg = uilabel(g, ...
                'Text',      ndi.gui.nav.cloudStatusDialog.statusMessage(obj.InCloud), ...
                'WordWrap',  'on', ...
                'FontColor', c.white);
            msg.Layout.Row = 1;
            msg.Layout.Column = [1 3];

            lbl = uilabel(g, ...
                'Text',       'Cloud dataset ID:', ...
                'FontWeight', 'bold', ...
                'FontColor',  c.white);
            lbl.Layout.Row = 2;
            lbl.Layout.Column = 1;

            % A read-only edit field (rather than a label) so the id can also
            % be selected and copied by hand.
            obj.IdField = uieditfield(g, 'text', ...
                'Value',    ndi.gui.nav.cloudStatusDialog.idText(obj.InCloud, obj.CloudDatasetId), ...
                'Editable', 'off', ...
                'Tag',      'ndiCloudDatasetId');
            obj.IdField.Layout.Row = 2;
            obj.IdField.Layout.Column = 2;

            obj.CopyButton = uibutton(g, ...
                'Text',            'Copy', ...
                'Tooltip',         'Copy the cloud dataset ID to the clipboard', ...
                'Enable',          ndi.gui.nav.cloudStatusDialog.copyEnable(obj.InCloud, obj.CloudDatasetId), ...
                'BackgroundColor', c.lightBlue, ...
                'FontColor',       c.darkBlue, ...
                'Tag',             'ndiCloudDatasetIdCopy', ...
                'ButtonPushedFcn', @(~,~) obj.copyId());
            obj.CopyButton.Layout.Row = 2;
            obj.CopyButton.Layout.Column = 3;

            ok = uibutton(g, ...
                'Text',            'OK', ...
                'BackgroundColor', c.white, ...
                'FontColor',       c.darkBlue, ...
                'ButtonPushedFcn', @(~,~) delete(obj.Figure));
            ok.Layout.Row = 3;
            ok.Layout.Column = 3;
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
            %COPYENABLE 'on' or 'off' for the Copy button's Enable property.
            if ndi.gui.nav.cloudStatusDialog.canCopy(inCloud, cloudDatasetId)
                e = 'on';
            else
                e = 'off';
            end
        end

        function t = idText(inCloud, cloudDatasetId)
            %IDTEXT Text shown in the id field.
            if ndi.gui.nav.cloudStatusDialog.canCopy(inCloud, cloudDatasetId)
                t = char(cloudDatasetId);
            else
                t = '(not in NDI Cloud)';
            end
        end
    end
end
