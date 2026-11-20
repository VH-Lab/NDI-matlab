classdef cloudPane < ndi.gui.nav.pane
%NDI.GUI.NAV.CLOUDPANE The uncollapsible "NDI Cloud" pane.
%
%   A single-row pane with a bold "NDI Cloud" label on the left and, on the
%   right, four controls:
%       * a login indicator, a small coloured button that says whether NDI
%         Cloud access is set up (see loginStatus):
%             green  (check mark) - logged in: NDI_CLOUD_TOKEN holds a token
%                                   that has not expired;
%             yellow (circle)     - ready to log in: not logged in, but the
%                                   current (or default) profile has an email
%                                   and a stored password, or the
%                                   NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD
%                                   environment variables are both set, so
%                                   the next NDI Cloud action signs in;
%             red    (cross)      - not configured: no token and nothing to
%                                   log in with (no profile, or a profile
%                                   without a stored password).
%         Hovering shows a sentence saying which, and for whom. Clicking it
%         opens the profile editor. It is re-read every LoginRefreshSeconds
%         seconds (a token can expire while the navigator is open), when the
%         profile editor closes, after the reload button logs out, and on
%         every pane refresh.
%       * a reload button (hover text "Refresh NDI Cloud login (logout)") that clears
%         the current NDI Cloud login by calling ndi.cloud.logout, so the
%         next NDI Cloud action re-authenticates with the default NDI Cloud
%         profile. This is a quick recovery when a cloud token has expired
%         and a stale login is otherwise being reused.
%       * a "C" button (hover text "Check NDI Cloud status of all datasets")
%         that checks, for every dataset in the Datasets pane, whether it is
%         linked to NDI Cloud and badges each one accordingly - the bulk
%         equivalent of the per-dataset "Cloud info..." menu command, so
%         the user does not have to check them one by one. The "C" matches the
%         light-blue cloud badge drawn on datasets that are in the cloud.
%       * a "Profile" button that opens the NDI Cloud profile editor
%         (ndi.gui.profileEditor), where the user can view and manage their
%         cloud accounts and choose which one is active.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.profileEditor,
%             ndi.gui.nav.datasetsPane, ndi.cloud.logout

    properties (Constant)
        LoginRefreshSeconds = 30    % how often the login indicator re-reads its state
    end

    properties (SetAccess = protected)
        LoginIndicator              % uibutton showing the login state
        LoginState char = ''        % 'loggedin', 'ready' or 'notconfigured'
        LoginTimer                  % timer that re-reads the login state
    end

    methods
        function obj = cloudPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI Cloud', ...
                'Collapsible', false);
        end

        function refresh(obj)
            %REFRESH Re-read the NDI Cloud login state into the indicator.
            obj.updateLoginIndicator();
        end

        function status = updateLoginIndicator(obj)
            %UPDATELOGININDICATOR Show the current login state on the indicator.
            %   STATUS = UPDATELOGININDICATOR(OBJ) reads loginStatus() and
            %   colours the indicator, sets its glyph and hover text, and
            %   returns the status struct.
            status = ndi.gui.nav.cloudPane.loginStatus();
            obj.LoginState = status.state;
            b = obj.LoginIndicator;
            if isempty(b) || ~isvalid(b)
                return;
            end
            b.BackgroundColor = status.color;
            b.Text = status.glyph;
            b.Tooltip = status.tooltip;
        end

        function fig = openProfileEditor(obj)
            %OPENPROFILEEDITOR Open the profile editor; re-read the login when it closes.
            fig = ndi.gui.profileEditor();
            if ~isempty(fig) && isvalid(fig)
                addlistener(fig, 'ObjectBeingDestroyed', ...
                    @(~,~) obj.updateIfAlive());
            end
        end

        function delete(obj)
            obj.stopLoginTimer();
        end
    end

    methods (Static)
        function status = loginStatus()
            %LOGINSTATUS The NDI Cloud login state, read from this session.
            %
            %   STATUS = ndi.gui.nav.cloudPane.loginStatus() gathers what the
            %   indicator needs -- the NDI_CLOUD_TOKEN token and its expiry,
            %   the current (else default) profile and whether it has a stored
            %   password, and the NDI_CLOUD_USERNAME / NDI_CLOUD_PASSWORD
            %   environment variables -- and passes them to describeLogin.
            %   It never errors: anything it cannot read counts as absent.
            secondsLeft = NaN;
            tokenUser = getenv('NDI_CLOUD_USERNAME');
            token = getenv('NDI_CLOUD_TOKEN');
            if ~isempty(token)
                try
                    expiry = ndi.cloud.internal.getTokenExpiration(token);
                    secondsLeft = seconds(expiry - datetime('now', 'TimeZone', 'local'));
                catch
                    secondsLeft = NaN;   % unreadable token: not a login
                end
                if isempty(tokenUser)
                    try
                        claims = ndi.cloud.internal.decodeJwt(token);
                        if isfield(claims, 'email')
                            tokenUser = char(string(claims.email));
                        end
                    catch
                    end
                end
            end

            profile = [];
            hasPassword = false;
            try
                profile = ndi.cloud.profile.getCurrent();
                if isempty(profile)
                    profile = ndi.cloud.profile.getDefault();
                end
                if ~isempty(profile)
                    hasPassword = ~isempty(ndi.cloud.profile.getPassword(profile.UID));
                end
            catch
                hasPassword = false;
            end

            envCredentials = ~isempty(getenv('NDI_CLOUD_USERNAME')) && ...
                ~isempty(getenv('NDI_CLOUD_PASSWORD'));
            status = ndi.gui.nav.cloudPane.describeLogin(secondsLeft, tokenUser, ...
                profile, hasPassword, envCredentials);
        end

        function status = describeLogin(secondsLeft, userName, profile, hasPassword, envCredentials)
            %DESCRIBELOGIN Decide the login indicator's state and hover text.
            %
            %   STATUS = describeLogin(SECONDSLEFT, USERNAME, PROFILE,
            %   HASPASSWORD, ENVCREDENTIALS) returns a struct with fields
            %       state   - 'loggedin', 'ready' or 'notconfigured'
            %       color   - the indicator colour (ndi.gui.cloudColors)
            %       glyph   - the symbol drawn on it, so the state does not
            %                 rest on colour alone
            %       tooltip - the hover text
            %   SECONDSLEFT is the token's remaining life in seconds (NaN when
            %   there is no readable token; <= 0 when it has expired).
            %   USERNAME names the account the token or the environment
            %   variables are for ('' if unknown). PROFILE
            %   is the current-or-default profile struct, or [] for none.
            %   HASPASSWORD says whether that profile has a stored password.
            %   ENVCREDENTIALS says whether NDI_CLOUD_USERNAME and
            %   NDI_CLOUD_PASSWORD are both set.
            arguments
                secondsLeft (1,1) double
                userName = ''
                profile = []
                hasPassword (1,1) logical = false
                envCredentials (1,1) logical = false
            end
            c = ndi.gui.cloudColors();
            userName = char(userName);
            click = 'Click to view or edit your NDI Cloud profiles.';
            hasProfile = isstruct(profile) && ~isempty(profile);
            profileName = '';
            profileEmail = '';
            if hasProfile
                profileEmail = char(profile.Email);
                profileName = char(profile.Nickname);
            end

            if ~isnan(secondsLeft) && secondsLeft > 0
                asWhom = '';
                if ~isempty(userName)
                    asWhom = [' as ' userName];
                end
                status = makeStatus('loggedin', c.okGreen, char(10003), ...
                    sprintf('Logged in to NDI Cloud%s. The login expires in %s. %s', ...
                        asWhom, ndi.gui.nav.cloudPane.durationText(secondsLeft), click));
            elseif hasProfile && ~isempty(profileEmail) && hasPassword
                status = makeStatus('ready', c.warnAmber, char(9675), ...
                    sprintf(['Ready to log in to NDI Cloud as %s (profile "%s"). ' ...
                        'Not logged in yet: the next NDI Cloud action signs in.%s %s'], ...
                        profileEmail, profileName, expiredNote(secondsLeft), click));
            elseif envCredentials
                status = makeStatus('ready', c.warnAmber, char(9675), ...
                    sprintf(['Ready to log in to NDI Cloud as %s (from the ' ...
                        'NDI_CLOUD_USERNAME and NDI_CLOUD_PASSWORD environment ' ...
                        'variables). Not logged in yet: the next NDI Cloud action ' ...
                        'signs in.%s %s'], userName, ...
                        expiredNote(secondsLeft), click));
            elseif hasProfile
                status = makeStatus('notconfigured', c.alertRed, char(10005), ...
                    sprintf(['NDI Cloud login is not set up: profile "%s" has no ' ...
                        'stored email and password.%s Click to open the profile ' ...
                        'editor and set its password.'], profileName, expiredNote(secondsLeft)));
            else
                status = makeStatus('notconfigured', c.alertRed, char(10005), ...
                    sprintf(['NDI Cloud login is not set up: there is no NDI Cloud ' ...
                        'profile.%s Click to open the profile editor and add one ' ...
                        'with your NDI Cloud email and password.'], expiredNote(secondsLeft)));
            end

            function s = makeStatus(state, color, glyph, tooltip)
                s = struct('state', state, 'color', color, 'glyph', glyph, ...
                    'tooltip', tooltip);
            end

            function t = expiredNote(secondsLeft)
                if ~isnan(secondsLeft) && secondsLeft <= 0
                    t = sprintf(' (The last login expired %s ago.)', ...
                        ndi.gui.nav.cloudPane.durationText(-secondsLeft));
                else
                    t = '';
                end
            end
        end

        function t = durationText(secs)
            %DURATIONTEXT A rough, readable length of time ('about 3 hours').
            secs = abs(double(secs));
            if secs < 90
                t = 'less than 2 minutes';
            elseif secs < 90*60
                t = sprintf('%d minutes', round(secs/60));
            elseif secs < 36*3600
                t = sprintf('about %d hours', round(secs/3600));
            else
                t = sprintf('about %d days', round(secs/86400));
            end
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            % Four controls share the right column: the login indicator, a
            % compact reload button, a compact "C" (check-all-cloud-status)
            % button, and the wider "Profile" button (mirrors the datasets
            % pane's header layout).
            group = uigridlayout(parent, [1 4]);
            group.Layout.Row      = 1;
            group.Layout.Column   = 3;
            group.ColumnWidth     = {26, 26, 26, '1x'};
            group.RowHeight       = {'1x'};
            group.Padding         = [0 0 0 0];
            group.ColumnSpacing   = 4;
            group.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            obj.LoginIndicator = uibutton(group, ...
                'Text',            '', ...
                'FontWeight',      'bold', ...
                'FontColor',       ndi.gui.cloudColors().white, ...
                'Tag',             'ndiNavigatorCloudLoginIndicator', ...
                'ButtonPushedFcn', @(~,~) obj.openProfileEditor());
            obj.LoginIndicator.Layout.Row    = 1;
            obj.LoginIndicator.Layout.Column = 1;
            obj.updateLoginIndicator();
            obj.startLoginTimer();

            reload = obj.refreshButton(group, 'Refresh NDI Cloud login (logout)', ...
                @(~,~) obj.refreshLogin());
            reload.Layout.Row    = 1;
            reload.Layout.Column = 2;

            checkAll = uibutton(group, ...
                'Text',            'C', ...
                'FontWeight',      'bold', ...
                'Tooltip',         'Check NDI Cloud status of all datasets', ...
                'ButtonPushedFcn', @(~,~) obj.onCheckAllCloud());
            checkAll.Layout.Row    = 1;
            checkAll.Layout.Column = 3;
            obj.accentButton(checkAll);

            profile = uibutton(group, ...
                'Text',            'Profile', ...
                'Tooltip',         ['Open the NDI Cloud profile editor to ' ...
                                    'manage your cloud accounts and choose the active one'], ...
                'ButtonPushedFcn', @(~,~) obj.openProfileEditor());
            profile.Layout.Row    = 1;
            profile.Layout.Column = 4;
            obj.accentButton(profile);
        end

        function w = rightWidth(~)
            w = 152;   % 26 (login) + 4 + 26 (reload) + 4 + 26 (C) + 4 + 62 (Profile)
        end
    end

    methods (Access = private)
        function startLoginTimer(obj)
            %STARTLOGINTIMER Re-read the login state every LoginRefreshSeconds.
            %   The timer stops itself once the indicator is gone, and the
            %   indicator's destruction stops it too, so closing the
            %   navigator leaves no timer behind.
            obj.stopLoginTimer();
            obj.LoginTimer = timer( ...
                'Name',          'ndiNavigatorCloudLoginTimer', ...
                'ExecutionMode', 'fixedSpacing', ...
                'Period',        obj.LoginRefreshSeconds, ...
                'StartDelay',    obj.LoginRefreshSeconds, ...
                'BusyMode',      'drop', ...
                'TimerFcn',      @(~,~) obj.onLoginTimer());
            addlistener(obj.LoginIndicator, 'ObjectBeingDestroyed', ...
                @(~,~) obj.stopLoginTimer());
            start(obj.LoginTimer);
        end

        function stopLoginTimer(obj)
            t = obj.LoginTimer;
            obj.LoginTimer = [];
            if ~isempty(t) && isvalid(t)
                stop(t);
                delete(t);
            end
        end

        function onLoginTimer(obj)
            if ~isvalid(obj) || isempty(obj.LoginIndicator) || ~isvalid(obj.LoginIndicator)
                if isvalid(obj)
                    obj.stopLoginTimer();
                end
                return;
            end
            try
                obj.updateLoginIndicator();
            catch
                % A failed read must not stop the timer or spam the console.
            end
        end

        function updateIfAlive(obj)
            if isvalid(obj)
                obj.updateLoginIndicator();
            end
        end

        function onCheckAllCloud(obj)
            %ONCHECKALLCLOUD Check NDI Cloud status for every dataset at once.
            %   Finds the navigator's datasets pane and runs its bulk
            %   checkAllCloudStatus (each dataset's isInCloud is queried, its
            %   badge updated, and its state cached), under a progress dialog,
            %   then reports a one-line summary. This is the bulk equivalent of
            %   the per-dataset "Cloud info..." command.
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
            %   and the cached list of the user's organizations. The next
            %   NDI Cloud action then signs in again using the default NDI
            %   Cloud profile. This recovers from an expired/stale token.
            ndi.cloud.logout();
            obj.updateLoginIndicator();
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
end
