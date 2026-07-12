classdef pane < handle
%NDI.GUI.NAV.PANE Abstract base class for a pane in ndi.gui.navigator.
%
%   A pane is a single horizontal region of the navigator window. Every
%   pane owns a uipanel that occupies one row of the navigator's root
%   uigridlayout. The first (header) row of a pane is always visible and
%   holds a disclosure triangle (for collapsible panes), a title label,
%   and an optional right-hand control. Panes that carry a body (a tree,
%   a progress area, ...) render it in a second row that is shown only
%   when the pane is engaged (expanded).
%
%   This class is not used directly; concrete panes subclass it and
%   override the small set of hooks below. See ndi.gui.nav.ndiPane,
%   ndi.gui.nav.cloudPane, ndi.gui.nav.datasetsPane and
%   ndi.gui.nav.progressPane for examples.
%
%   Construction (name-value):
%       Title       - char/string shown in the header. Default ''.
%       Collapsible - logical; if true a disclosure triangle is drawn on
%                     the left of the header and the pane can be collapsed
%                     to its header row only. Default false.
%       Engaged     - logical; initial expanded state of a collapsible
%                     pane. Ignored (treated as true) when Collapsible is
%                     false. Default true.
%       MinHeight   - minimum total pane height, in pixels, while engaged.
%                     Must be at least HeaderHeight. Default HeaderHeight.
%       Height      - initial total pane height, in pixels, while engaged.
%                     Clamped up to MinHeight. Default MinHeight.
%
%   Overridable hooks (protected):
%       buildBody(obj, container)    - populate the body; only called for
%                                      panes whose HasBody is true.
%       buildHeaderRight(obj, parent)- add the right-hand header control.
%       rightWidth(obj)              - pixel width of the right control
%                                      column (0 if none).
%       refresh(obj)                 - re-read model state into widgets.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.datasetsPane

    properties
        Title       (1,1) string  = ""
        Collapsible (1,1) logical = false
        Engaged     (1,1) logical = true
        MinHeight   (1,1) double  = ndi.gui.nav.pane.HeaderHeight
        Height      (1,1) double  = ndi.gui.nav.pane.HeaderHeight
    end

    properties (SetAccess = protected)
        Navigator                 % handle to the owning ndi.gui.navigator
        Panel                     % uipanel that occupies the navigator row
        Grid                      % uigridlayout inside Panel (header + body)
        HeaderGrid                % uigridlayout for the header row
        DisclosureButton          % uibutton showing the collapse triangle
        TitleLabel                % uilabel showing Title
        BodyContainer             % uigridlayout that holds the pane body
    end

    properties (Constant)
        HeaderHeight = 28         % header row height, in pixels
    end

    properties (Constant, Access = protected)
        TriangleRight = char(9654)  % '>' disclosure glyph (collapsed)
        TriangleDown  = char(9660)  % 'v' disclosure glyph (expanded)
    end

    methods
        function obj = pane(navigator, options)
            arguments
                navigator
                options.Title       (1,1) string  = ""
                options.Collapsible (1,1) logical = false
                options.Engaged     (1,1) logical = true
                options.MinHeight   (1,1) double  = ndi.gui.nav.pane.HeaderHeight
                options.Height      (1,1) double  = NaN
            end
            obj.Navigator   = navigator;
            obj.Title       = options.Title;
            obj.Collapsible = options.Collapsible;
            obj.Engaged     = options.Engaged || ~options.Collapsible;
            obj.MinHeight   = max(options.MinHeight, ndi.gui.nav.pane.HeaderHeight);
            if isnan(options.Height)
                obj.Height = obj.MinHeight;
            else
                obj.Height = max(options.Height, obj.MinHeight);
            end
        end

        function tf = HasBody(~)
            %HASBODY True if the pane renders a body below the header.
            %   Non-collapsible single-row panes return false; panes with
            %   content (datasets, progress) override this to return true.
            tf = false;
        end

        function build(obj, parentGrid, row)
            %BUILD Create the pane's uipanel and contents in a grid row.
            %
            %   BUILD(OBJ, PARENTGRID, ROW) creates OBJ.Panel as the ROW-th
            %   child of PARENTGRID (the navigator root grid), lays out the
            %   header, and, for panes with a body, the body container.
            c = ndi.gui.cloudColors();

            obj.Panel = uipanel(parentGrid, ...
                'BorderType',      'line', ...
                'BackgroundColor', c.white);
            obj.Panel.Layout.Row    = row;
            obj.Panel.Layout.Column = 1;

            if obj.HasBody()
                obj.Grid = uigridlayout(obj.Panel, [2 1]);
                obj.Grid.RowHeight = {obj.HeaderHeight, '1x'};
            else
                obj.Grid = uigridlayout(obj.Panel, [1 1]);
                obj.Grid.RowHeight = {'1x'};
            end
            obj.Grid.ColumnWidth     = {'1x'};
            obj.Grid.Padding         = [0 0 0 0];
            obj.Grid.RowSpacing      = 0;
            obj.Grid.BackgroundColor = c.white;

            obj.buildHeader();

            if obj.HasBody()
                obj.BodyContainer = uigridlayout(obj.Grid, [1 1]);
                obj.BodyContainer.Layout.Row     = 2;
                obj.BodyContainer.Layout.Column  = 1;
                obj.BodyContainer.Padding        = [0 0 0 0];
                obj.BodyContainer.BackgroundColor = c.white;
                obj.buildBody(obj.BodyContainer);
                obj.applyEngagedState();
            end
        end

        function h = currentHeight(obj)
            %CURRENTHEIGHT Pixel height this pane requests in the navigator.
            %   Header-only when collapsed; otherwise its engaged height.
            if obj.Collapsible && ~obj.Engaged
                h = obj.HeaderHeight;
            else
                h = max(obj.Height, obj.MinHeight);
            end
        end

        function toggle(obj)
            %TOGGLE Flip a collapsible pane between engaged and collapsed.
            if ~obj.Collapsible
                return;
            end
            obj.Engaged = ~obj.Engaged;
            obj.updateDisclosure();
            obj.applyEngagedState();
            obj.Navigator.layout();
        end

        function setEngaged(obj, tf)
            %SETENGAGED Force the engaged state of a collapsible pane.
            if ~obj.Collapsible || logical(tf) == obj.Engaged
                return;
            end
            obj.toggle();
        end

        function refresh(~)
            %REFRESH Re-read model state into the pane widgets. Default no-op.
        end
    end

    methods (Access = protected)
        function buildHeader(obj)
            %BUILDHEADER Lay out the always-visible header row.
            c = ndi.gui.cloudColors();

            leftWidth = 0;
            if obj.Collapsible
                leftWidth = 22;
            end

            % The header row is a navy NDI Cloud bar with white text.
            obj.HeaderGrid = uigridlayout(obj.Grid, [1 3]);
            obj.HeaderGrid.Layout.Row       = 1;
            obj.HeaderGrid.Layout.Column    = 1;
            obj.HeaderGrid.ColumnWidth      = {leftWidth, '1x', obj.rightWidth()};
            obj.HeaderGrid.RowHeight        = {'1x'};
            obj.HeaderGrid.Padding          = [5 0 5 0];
            obj.HeaderGrid.ColumnSpacing    = 4;
            obj.HeaderGrid.BackgroundColor  = c.darkBlue;

            if obj.Collapsible
                % The disclosure triangle blends into the navy header bar.
                obj.DisclosureButton = uibutton(obj.HeaderGrid, ...
                    'Text',            obj.disclosureGlyph(), ...
                    'FontSize',        10, ...
                    'BackgroundColor', c.darkBlue, ...
                    'FontColor',       c.white, ...
                    'ButtonPushedFcn', @(~,~) obj.toggle());
                obj.DisclosureButton.Layout.Row    = 1;
                obj.DisclosureButton.Layout.Column = 1;
            else
                % Placeholder so the title always sits in column 2.
                placeholder = uilabel(obj.HeaderGrid, 'Text', '');
                placeholder.Layout.Row    = 1;
                placeholder.Layout.Column = 1;
            end

            obj.TitleLabel = uilabel(obj.HeaderGrid, ...
                'Text',                char(obj.Title), ...
                'FontSize',            12, ...
                'FontWeight',          'bold', ...
                'FontColor',           c.white, ...
                'VerticalAlignment',   'center', ...
                'HorizontalAlignment', 'left');
            obj.TitleLabel.Layout.Row    = 1;
            obj.TitleLabel.Layout.Column = 2;

            obj.buildHeaderRight(obj.HeaderGrid);
        end

        function buildHeaderRight(~, ~)
            %BUILDHEADERRIGHT Add the right-hand header control. Default none.
        end

        function accentButton(~, btn)
            %ACCENTBUTTON Style a header uibutton in the NDI Cloud accent.
            %   ACCENTBUTTON(OBJ, BTN) gives BTN a light-blue fill with bold
            %   navy text so the header buttons read as one family against
            %   the navy header bar.
            if isempty(btn) || ~isvalid(btn)
                return;
            end
            c = ndi.gui.cloudColors();
            btn.BackgroundColor = c.lightBlue;
            btn.FontColor       = c.darkBlue;
            btn.FontWeight      = 'bold';
        end

        function buildBody(~, ~)
            %BUILDBODY Populate the pane body. Default none.
        end

        function w = rightWidth(~)
            %RIGHTWIDTH Pixel width of the right header column. Default 0.
            w = 0;
        end

        function g = disclosureGlyph(obj)
            %DISCLOSUREGLYPH Triangle for the current engaged state.
            if obj.Engaged
                g = obj.TriangleDown;
            else
                g = obj.TriangleRight;
            end
        end

        function updateDisclosure(obj)
            %UPDATEDISCLOSURE Refresh the disclosure triangle glyph.
            if ~isempty(obj.DisclosureButton) && isvalid(obj.DisclosureButton)
                obj.DisclosureButton.Text = obj.disclosureGlyph();
            end
        end

        function applyEngagedState(obj)
            %APPLYENGAGEDSTATE Show or hide the body to match Engaged.
            if isempty(obj.BodyContainer) || ~isvalid(obj.BodyContainer)
                return;
            end
            if obj.Collapsible && ~obj.Engaged
                obj.BodyContainer.Visible = 'off';
            else
                obj.BodyContainer.Visible = 'on';
            end
        end
    end
end
