classdef ndiPane < ndi.gui.nav.pane
%NDI.GUI.NAV.NDIPANE The top, uncollapsible "NDI" pane.
%
%   A single-row pane with a 12-point bold "NDI" label on the left and, on
%   the right, a broom button that clears NDI's in-memory caches followed by
%   a "Prefs" button that opens the preferences editor. This is always the
%   first pane in ndi.gui.navigator and cannot be collapsed.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.preferencesEditor,
%   ndi.fun.clearAllCaches

    methods
        function obj = ndiPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            % Two buttons share the right header column: a compact broom that
            % clears the in-memory caches, then the wider "Prefs" button.
            grid = uigridlayout(parent, [1 2]);
            grid.Layout.Row     = 1;
            grid.Layout.Column  = 3;
            grid.ColumnWidth    = {28, 60};
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
            prefs.Layout.Column = 2;
            obj.accentButton(prefs);
        end

        function w = rightWidth(~)
            % broom (28) + spacing (4) + Prefs (60)
            w = 92;
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
    end
end
