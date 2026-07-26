classdef cloudPane < ndi.gui.nav.pane
%NDI.GUI.NAV.CLOUDPANE The uncollapsible "NDI Cloud" pane.
%
%   A single-row pane with a bold "NDI Cloud" label on the left and, on the
%   right, three controls:
%       * a reload button (hover text "Refresh NDI Cloud login") that clears
%         the current NDI Cloud login by calling ndi.cloud.logout, so the
%         next NDI Cloud action re-authenticates with the default NDI Cloud
%         profile. This is a quick recovery when a cloud token has expired
%         and a stale login is otherwise being reused.
%       * a "C" button (hover text "Check NDI Cloud status of all datasets")
%         that checks, for every dataset in the Datasets pane, whether it is
%         linked to NDI Cloud and badges each one accordingly - the bulk
%         equivalent of the per-dataset "Check Cloud status" menu command, so
%         the user does not have to check them one by one. The "C" matches the
%         light-blue cloud badge drawn on datasets that are in the cloud.
%       * a "Profile" button that opens the NDI Cloud profile editor
%         (ndi.gui.profileEditor), where the user can view and manage their
%         cloud accounts and choose which one is active.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.profileEditor,
%             ndi.gui.nav.datasetsPane, ndi.cloud.logout

    methods
        function obj = cloudPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI Cloud', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            % Three controls share the right column: a compact reload button,
            % a compact "C" (check-all-cloud-status) button, and the wider
            % "Profile" button (mirrors the datasets pane's header layout).
            group = uigridlayout(parent, [1 3]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {26, 26, '1x'};
            group.RowHeight       = {'1x'};
            group.Padding         = [0 0 0 0];
            group.ColumnSpacing   = 4;
            group.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            reload = uibutton(group, ...
                'Text',            '', ...
                'Icon',            ndi.gui.nav.cloudPane.reloadIconFile(), ...
                'IconAlignment',   'center', ...
                'Tooltip',         'Refresh NDI Cloud login', ...
                'ButtonPushedFcn', @(~,~) obj.refreshLogin());
            reload.Layout.Row    = 1;
            reload.Layout.Column = 1;
            obj.accentButton(reload);

            checkAll = uibutton(group, ...
                'Text',            'C', ...
                'FontWeight',      'bold', ...
                'Tooltip',         'Check NDI Cloud status of all datasets', ...
                'ButtonPushedFcn', @(~,~) obj.onCheckAllCloud());
            checkAll.Layout.Row    = 1;
            checkAll.Layout.Column = 2;
            obj.accentButton(checkAll);

            profile = uibutton(group, ...
                'Text',            'Profile', ...
                'ButtonPushedFcn', @(~,~) ndi.gui.profileEditor());
            profile.Layout.Row    = 1;
            profile.Layout.Column = 3;
            obj.accentButton(profile);
        end

        function w = rightWidth(~)
            w = 122;   % 26 (reload) + 4 + 26 (C) + 4 + 62 (Profile)
        end
    end

    methods (Access = private)
        function onCheckAllCloud(obj)
            %ONCHECKALLCLOUD Check NDI Cloud status for every dataset at once.
            %   Finds the navigator's datasets pane and runs its bulk
            %   checkAllCloudStatus (each dataset's isInCloud is queried, its
            %   badge updated, and its state cached), under a progress dialog,
            %   then reports a one-line summary. This is the bulk equivalent of
            %   the per-dataset "Check Cloud status" command.
            fig = obj.Navigator.Figure;
            title = 'Check NDI Cloud status';
            dp = obj.Navigator.datasetsPaneHandle();
            if isempty(dp)
                uialert(fig, 'No datasets pane is available.', title);
                return;
            end
            dlg = uiprogressdlg(fig, 'Title', title, ...
                'Message', 'Checking datasets...', 'Value', 0);
            try
                report = dp.checkAllCloudStatus(dlg);
            catch ME
                delete(dlg);
                uialert(fig, ME.message, title);
                return;
            end
            delete(dlg);
            uialert(fig, ndi.gui.nav.datasetsPane.cloudSummaryMessage(report), ...
                title, 'Icon', 'info');
        end

        function refreshLogin(obj)
            %REFRESHLOGIN Clear the NDI Cloud login so the next call re-authenticates.
            %   Calls ndi.cloud.logout, which invalidates the current token on
            %   the server (best effort) and clears the local NDI_CLOUD_TOKEN
            %   and NDI_CLOUD_ORGANIZATION_ID environment variables. The next
            %   NDI Cloud action then signs in again using the default NDI
            %   Cloud profile. This recovers from an expired/stale token.
            ndi.cloud.logout();
            fig = obj.Navigator.Figure;
            if ~isempty(fig) && isvalid(fig)
                uialert(fig, ...
                    ['Cleared the current NDI Cloud login. The next NDI Cloud ' ...
                     'action will sign in again using your default NDI Cloud ' ...
                     'profile.'], ...
                    'NDI Cloud', 'Icon', 'success');
            end
        end
    end

    methods (Static, Access = private)
        function p = reloadIconFile()
            %RELOADICONFILE Absolute path to the reload button icon (SVG).
            p = fullfile(ndi.common.PathConstants.RootFolder, ...
                '+ndi', '+gui', 'reload_icon.svg');
        end
    end
end
