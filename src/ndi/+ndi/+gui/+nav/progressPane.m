classdef progressPane < ndi.gui.nav.pane
%NDI.GUI.NAV.PROGRESSPANE Collapsible "Progress" pane.
%
%   A collapsible pane that hosts progress bars. When idle it shows a thin
%   empty body; when an ndi.gui.component.ProgressBarWindow docks into it
%   (which happens automatically whenever a navigator is open), the bars
%   are drawn in this pane and the pane grows to fit them, cascading
%   multiple concurrent tasks. The body is scrollable, so a tall cascade
%   never exceeds the pane's maximum height.
%
%   The docking handshake is:
%       * ProgressBarWindow calls adoptBarGrid() to obtain the uigridlayout
%         it renders its bars into, and records itself as the ActiveApp.
%       * As bars are added/removed it calls fitToBars() to resize the pane.
%       * When the last bar is gone it calls releaseBars() to clear the pane
%         back to its idle placeholder.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane,
%             ndi.gui.component.ProgressBarWindow

    properties (SetAccess = protected)
        ActiveApp   % the docked ndi.gui.component.ProgressBarWindow (or empty)
        BarGrid     % uigridlayout the docked app renders its bars into
    end

    properties (Access = private)
        Placeholder    % idle-state label shown when no bars are docked
        DesiredBodyPx  % pixel height the pane body currently wants
    end

    properties (Constant, Access = private)
        BodyHeight  = 50    % pixels of body content when idle
        RowUnitPx   = 32    % pixels per grid "x" unit; tall enough that label
                            %   descenders (p, g, y) are not clipped
        MaxBodyPx   = 240   % cap on body pixels; taller cascades scroll
    end

    methods
        function obj = progressPane(navigator)
            h = ndi.gui.nav.pane.HeaderHeight + ndi.gui.nav.progressPane.BodyHeight;
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'Progress', ...
                'Collapsible', true, ...
                'Engaged',     true, ...
                'MinHeight',   h, ...
                'Height',      h);
            obj.DesiredBodyPx = obj.BodyHeight;
        end

        function tf = HasBody(~)
            tf = true;
        end

        function h = currentHeight(obj)
            %CURRENTHEIGHT Header height when collapsed, else header + body.
            %   The body is content-driven (see fitToBars) and capped, so a
            %   tall cascade scrolls rather than making the pane unbounded.
            if obj.Collapsible && ~obj.Engaged
                h = obj.HeaderHeight;
            else
                h = obj.HeaderHeight + obj.DesiredBodyPx;
            end
        end

        function g = adoptBarGrid(obj)
            %ADOPTBARGRID Prepare and return the grid docked bars render into.
            %
            %   G = ADOPTBARGRID(OBJ) clears any idle placeholder, creates a
            %   fresh uigridlayout in the pane body with the same column
            %   layout the standalone ProgressBarWindow uses (bar / percent /
            %   close-button), and returns it. The docked app adopts G as its
            %   ProgressGrid.
            obj.clearBody();

            obj.BodyContainer.RowHeight    = {'1x'};
            obj.BodyContainer.ColumnWidth  = {'1x'};
            obj.BodyContainer.Scrollable   = 'on';

            obj.BarGrid = uigridlayout(obj.BodyContainer, ...
                'ColumnWidth', {'17.5x', '1.5x', '1x'}, ...
                'RowHeight',   {}, ...
                'RowSpacing',  0);
            obj.BarGrid.Layout.Row    = 1;
            obj.BarGrid.Layout.Column = 1;

            g = obj.BarGrid;
        end

        function registerApp(obj, app)
            %REGISTERAPP Record the docked app so later tasks can reuse it.
            obj.ActiveApp = app;
        end

        function fitToBars(obj, totalRowHeight)
            %FITTOBARS Grow the pane to fit TOTALROWHEIGHT grid "x" units.
            %
            %   FITTOBARS(OBJ, TOTALROWHEIGHT) mirrors ProgressBarWindow's
            %   figure sizing: it converts the sum of the bar grid's "x" row
            %   heights into pixels, sizes the (scrollable) body to that, and
            %   caps the pane height at HeaderHeight + MaxBodyPx so a tall
            %   cascade scrolls rather than crowding out the other panes.
            arguments
                obj
                totalRowHeight (1,1) {mustBeNonnegative}
            end
            bodyPx = max(totalRowHeight * obj.RowUnitPx, obj.BodyHeight);

            if ~isempty(obj.BarGrid) && isvalid(obj.BarGrid)
                % A fixed-pixel row makes the body scroll once it exceeds the
                % (capped) visible area rather than compressing the bars.
                obj.BodyContainer.RowHeight = {bodyPx};
            end

            % Content-driven: request a (capped) body height and let the
            % navigator shrink the elastic panes to make room. This never
            % grows the window, so a background task cannot resize it.
            obj.DesiredBodyPx = min(bodyPx, obj.MaxBodyPx);
            obj.setEngagedQuietly(true);
            obj.Navigator.layout();
        end

        function releaseBars(obj)
            %RELEASEBARS Return the pane to its idle placeholder state.
            %
            %   RELEASEBARS(OBJ) drops the reference to the docked app, clears
            %   the bar grid, restores the empty placeholder, and shrinks the
            %   pane back to its idle height. It never deletes the navigator.
            obj.ActiveApp = [];
            obj.clearBody();
            obj.showPlaceholder();

            % Back to the idle body height; the elastic panes reclaim the
            % space the bars had taken (window size unchanged).
            obj.DesiredBodyPx = obj.BodyHeight;
            if ~isempty(obj.Navigator) && isvalid(obj.Navigator)
                obj.Navigator.layout();
            end
        end
    end

    methods (Access = protected)
        function buildBody(obj, ~)
            % Idle body: a thin empty placeholder. Real content appears only
            % when a ProgressBarWindow docks (adoptBarGrid).
            obj.showPlaceholder();
        end
    end

    methods (Access = private)
        function clearBody(obj)
            %CLEARBODY Delete every child of the pane body container.
            if isempty(obj.BodyContainer) || ~isvalid(obj.BodyContainer)
                return;
            end
            delete(obj.BodyContainer.Children);
            obj.BarGrid     = [];
            obj.Placeholder = [];
            obj.BodyContainer.Scrollable = 'off';
            obj.BodyContainer.RowHeight   = {'1x'};
            obj.BodyContainer.ColumnWidth = {'1x'};
        end

        function showPlaceholder(obj)
            %SHOWPLACEHOLDER Ensure the idle empty-space label is present.
            if isempty(obj.BodyContainer) || ~isvalid(obj.BodyContainer)
                return;
            end
            if isempty(obj.Placeholder) || ~isvalid(obj.Placeholder)
                obj.Placeholder = uilabel(obj.BodyContainer, 'Text', '');
            end
        end
    end
end
