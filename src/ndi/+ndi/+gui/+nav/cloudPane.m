classdef cloudPane < ndi.gui.nav.pane
%NDI.GUI.NAV.CLOUDPANE The uncollapsible "NDI Cloud" pane.
%
%   A single-row pane with a bold "NDI Cloud" label on the left and, on the
%   right, two controls:
%       * a reload button (hover text "Refresh NDI Cloud login") that clears
%         the current NDI Cloud login by calling ndi.cloud.logout, so the
%         next NDI Cloud action re-authenticates with the default NDI Cloud
%         profile. This is a quick recovery when a cloud token has expired
%         and a stale login is otherwise being reused.
%       * a "Profile" button that opens the NDI Cloud profile editor
%         (ndi.gui.profileEditor), where the user can view and manage their
%         cloud accounts and choose which one is active.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.profileEditor,
%             ndi.cloud.logout

    methods
        function obj = cloudPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI Cloud', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            % Two controls share the right column: a compact reload button
            % and the wider "Profile" button (mirrors the datasets pane's
            % [icon | button] header layout).
            group = uigridlayout(parent, [1 2]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {26, '1x'};
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

            profile = uibutton(group, ...
                'Text',            'Profile', ...
                'ButtonPushedFcn', @(~,~) ndi.gui.profileEditor());
            profile.Layout.Row    = 1;
            profile.Layout.Column = 2;
            obj.accentButton(profile);
        end

        function w = rightWidth(~)
            w = 92;   % 26 (reload) + 4 (spacing) + 62 (Profile)
        end
    end

    methods (Access = private)
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
