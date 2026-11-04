classdef ndiPane < ndi.gui.nav.pane
%NDI.GUI.NAV.NDIPANE The top, uncollapsible "NDI" pane.
%
%   A single-row pane with a 12-point bold "NDI" label on the left and, on
%   the right, a broom button that clears NDI's in-memory caches, an
%   "Update" button that checks for a newer NDI-matlab and offers to install
%   it, and a "Prefs" button that opens the preferences editor. This is
%   always the first pane in ndi.gui.navigator and cannot be collapsed.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.preferencesEditor,
%   ndi.fun.clearAllCaches, ndi.update.check, ndi.update.install,
%   ndi.gui.nav.updateDialog

    methods
        function obj = ndiPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            % Three buttons share the right header column: a compact broom
            % that clears the in-memory caches, then the wider "Update" and
            % "Prefs" buttons.
            grid = uigridlayout(parent, [1 3]);
            grid.Layout.Row     = 1;
            grid.Layout.Column  = 3;
            grid.ColumnWidth    = {28, 60, 60};
            grid.RowHeight      = {'1x'};
            grid.Padding        = [0 0 0 0];
            grid.ColumnSpacing  = 4;
            grid.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            % Broom emoji U+1F9F9. It is above the BMP, so MATLAB's UTF-16
            % char needs the surrogate pair (a bare char(129529) would
            % overflow); the HTML-backed uifigure renders the pair as one
            % glyph.
            broom = uibutton(grid, ...
                'Text',            char([55358 56825]), ... % U+1F9F9 broom
                'Tooltip',         ['Clear NDI in-memory caches (memoized ' ...
                                    'functions, probe-type map, calculator ' ...
                                    'list, document definitions, database ' ...
                                    'hierarchy)'], ...
                'ButtonPushedFcn', @(~,~) obj.clearCaches());
            broom.Layout.Row    = 1;
            broom.Layout.Column = 1;
            obj.accentButton(broom);

            prefs = uibutton(grid, ...
                'Text',            'Prefs', ...
                'Tooltip',         'Open the NDI preferences editor', ...
                'ButtonPushedFcn', @(~,~) obj.Navigator.openPreferences());
            prefs.Layout.Row    = 1;
            prefs.Layout.Column = 3;
            obj.accentButton(prefs);

            update = uibutton(grid, ...
                'Text',            'Update', ...
                'Tooltip',         'Check for a newer version of NDI-matlab, its calculators and NDI-python', ...
                'ButtonPushedFcn', @(~,~) obj.checkForUpdates());
            update.Layout.Row    = 1;
            update.Layout.Column = 2;
            obj.accentButton(update);
        end

        function w = rightWidth(~)
            % broom (28) + spacing (4) + Update (60) + spacing (4) + Prefs (60)
            w = 156;
        end
    end

    methods (Access = private)
        function clearCaches(obj)
            %CLEARCACHES Clear NDI's in-memory caches (broom button callback).
            %   Clears the global NDI/DID caches via ndi.fun.clearAllCaches and
            %   confirms on the navigator figure, matching the session context
            %   menu's "Clear Cache" feedback.
            try
                ndi.fun.clearAllCaches();
            catch ME
                uialert(obj.Navigator.Figure, ME.message, 'Clear Caches');
                return;
            end
            uialert(obj.Navigator.Figure, 'NDI in-memory caches were cleared.', ...
                'Clear Caches', 'Icon', 'success');
        end

        function checkForUpdates(obj)
            %CHECKFORUPDATES Check for, and offer to install, NDI updates.
            %   Update button callback. Runs ndi.update.check behind a busy
            %   dialog and lists every package in ndi.gui.nav.updateDialog:
            %   NDI-matlab (git clone or toolbox), its dependencies, the
            %   NDIcalc calculator repositories and NDI-python, each with
            %   its status, notes and a tick box. If the user presses Update,
            %   runs ndi.update.install for the ticked packages only, without
            %   its command-window prompts (the dialog has already shown what
            %   updating will do).
            fig = obj.Navigator.Figure;
            title = 'NDI Update';

            busy = uiprogressdlg(fig, 'Title', title, ...
                'Message', 'Checking for updates...', 'Indeterminate', 'on');
            try
                r = ndi.update.check(Verbose = false);
            catch ME
                close(busy);
                uialert(fig, ME.message, title);
                return;
            end
            close(busy);

            [go, packages] = ndi.gui.nav.updateDialog.ask(r, fig);
            if ~go || isempty(packages)
                return;
            end
            rows = ndi.update.packageStatus(r);
            updated = rows(ismember([rows.Name], packages));

            busy = uiprogressdlg(fig, 'Title', title, ...
                'Message', 'Installing the update. This can take a few minutes...', ...
                'Indeterminate', 'on');
            try
                ndi.update.install(Confirm = false, AllowModified = true, ...
                    Packages = packages);
            catch ME
                if isvalid(busy), close(busy); end
                uialert(fig, ME.message, title);
                return;
            end
            if isvalid(busy), close(busy); end
            done = sprintf('Updated: %s.', strjoin([updated.Name], ', '));
            if any(ismember([updated.Kind], ["ndi", "toolbox", "dependency", "calculator"]))
                done = sprintf(['%s\n\nRestart MATLAB to make sure the new ' ...
                    'versions are used.'], done);
            end
            uialert(fig, done, title, 'Icon', 'success');
        end
    end
end
