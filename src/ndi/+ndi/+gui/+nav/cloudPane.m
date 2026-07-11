classdef cloudPane < ndi.gui.nav.pane
%NDI.GUI.NAV.CLOUDPANE The uncollapsible "NDI Cloud" pane.
%
%   A single-row pane with an "NDI Cloud" label on the left and a popup
%   menu on the right. The popup lists the user's NDI Cloud profile
%   accounts (ndi.cloud.profile) and marks which one is currently active;
%   selecting a different account makes it the active (current) profile.
%
%   The collapsed popup shows a rightward-pointing triangle affordance;
%   opening it reveals the account list.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.cloud.profile

    properties (Access = private)
        AccountMenu       % uidropdown listing the cloud accounts
        AccountUIDs = {}  % UID for each dropdown item, same order as Items
    end

    properties (Constant, Access = private)
        NoAccountsText = char(9654)   % '>' shown when there are no profiles
    end

    methods
        function obj = cloudPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI Cloud', ...
                'Collapsible', false);
        end

        function refresh(obj)
            obj.populateAccounts();
        end
    end

    methods (Access = protected)
        function buildHeader(obj)
            buildHeader@ndi.gui.nav.pane(obj);
            obj.TitleLabel.FontWeight = 'bold';
        end

        function buildHeaderRight(obj, parent)
            obj.AccountMenu = uidropdown(parent, ...
                'Items',           {obj.NoAccountsText}, ...
                'ValueChangedFcn', @(src,~) obj.onAccountChanged(src));
            obj.AccountMenu.Layout.Row    = 1;
            obj.AccountMenu.Layout.Column = 3;
            obj.populateAccounts();
        end

        function w = rightWidth(~)
            w = 150;
        end
    end

    methods (Access = private)
        function populateAccounts(obj)
            %POPULATEACCOUNTS Fill the dropdown from ndi.cloud.profile.
            if isempty(obj.AccountMenu) || ~isvalid(obj.AccountMenu)
                return;
            end

            items    = {};
            uids     = {};
            activeIx = [];
            try
                profiles = ndi.cloud.profile.list();
                cur      = ndi.cloud.profile.getCurrent();
                if isempty(cur); curUID = ''; else; curUID = cur.UID; end
                for i = 1:numel(profiles)
                    label = profiles(i).Nickname;
                    if isempty(label)
                        label = profiles(i).Email;
                    end
                    if strcmp(profiles(i).UID, curUID)
                        label = [char(9679) ' ' label];   % active marker
                        activeIx = numel(items) + 1;
                    end
                    items{end+1} = label;                 %#ok<AGROW>
                    uids{end+1}  = profiles(i).UID;        %#ok<AGROW>
                end
            catch
                % ndi.cloud.profile unavailable; fall through to empty list.
            end

            if isempty(items)
                obj.AccountMenu.Items = {obj.NoAccountsText};
                obj.AccountMenu.Enable = 'off';
                obj.AccountUIDs = {};
                return;
            end

            obj.AccountMenu.Enable = 'on';
            obj.AccountMenu.Items   = items;
            obj.AccountUIDs         = uids;
            if ~isempty(activeIx)
                obj.AccountMenu.Value = items{activeIx};
            end
        end

        function onAccountChanged(obj, src)
            %ONACCOUNTCHANGED Make the chosen account the current profile.
            ix = find(strcmp(src.Items, src.Value), 1);
            if isempty(ix) || ix > numel(obj.AccountUIDs)
                return;
            end
            try
                ndi.cloud.profile.setCurrent(obj.AccountUIDs{ix});
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'Set account failed');
            end
            obj.populateAccounts();
        end
    end
end
