classdef navigator < handle
%NDI.GUI.NAVIGATOR A small, resizable NDI navigator window.
%
%   NDI.GUI.NAVIGATOR opens a compact navigator built from a vertical
%   stack of panes. The window is resizable but never smaller than
%   250 x 300 pixels.
%
%   Syntax:
%       ndi.gui.navigator()
%       ndi.gui.navigator(Position=[x y w h])
%       nav = ndi.gui.navigator(...)
%
%   Name-value arguments:
%       Position - 1x4 double, the figure Position in pixels.
%                  Default [100 100 300 500].
%
%   Panes (top to bottom):
%       NDI        - uncollapsible; 12-point bold "NDI" label and a
%                    "Prefs" button that opens the preferences editor.
%       NDI Cloud  - uncollapsible; "NDI Cloud" label and a popup menu
%                    showing / selecting the active cloud account.
%       Datasets   - collapsible and resizable; a "Paths" button and a
%                    scrollable tree of datasets and their sessions.
%       Progress   - collapsible; reserved (empty) space for now.
%
%   The pane stack is object-oriented: every pane is an
%   ndi.gui.nav.pane subclass. New panes can be added by writing a
%   subclass (choosing collapsible or not, a minimum engaged height,
%   and a title) and appending it in buildPanes.
%
%   Outputs:
%       nav - the ndi.gui.navigator handle. The window stays open even
%             when the handle is not captured, because its callbacks
%             retain a reference to the object.
%
%   Example:
%       ndi.gui.navigator();
%
%   See also: ndi.gui.nav.pane, ndi.gui.preferencesEditor

    properties (SetAccess = protected)
        Figure       % the uifigure
        RootGrid     % uigridlayout: one row per pane plus a spacer row
        Panes        % cell array of ndi.gui.nav.pane handles
    end

    properties (Constant)
        MinWidth  = 250   % minimum figure width, in pixels
        MinHeight = 300   % minimum figure height, in pixels
    end

    properties (Constant, Access = private)
        Pad       = 6     % root-grid padding, in pixels
        Spacing   = 4     % root-grid row spacing, in pixels
        GripPixels = 6    % drag hit-test tolerance around a pane edge
    end

    properties (Access = private)
        Dragging     (1,1) logical = false
        DragPaneIdx  (1,1) double  = 0   % index into Panes being resized
    end

    methods
        function obj = navigator(options)
            arguments
                options.Position (1,4) double = [100 100 300 500]
            end

            pos = options.Position;
            pos(3) = max(pos(3), obj.MinWidth);
            pos(4) = max(pos(4), obj.MinHeight);

            obj.Figure = uifigure('Name', 'NDI Navigator', ...
                'Position',         pos, ...
                'Tag',              'ndiNavigator', ...
                'AutoResizeChildren', 'on');
            obj.Figure.SizeChangedFcn        = @(~,~) obj.enforceMinSize();
            obj.Figure.WindowButtonDownFcn   = @(~,~) obj.onButtonDown();
            obj.Figure.WindowButtonMotionFcn = @(~,~) obj.onMouseMotion();
            obj.Figure.WindowButtonUpFcn     = @(~,~) obj.onButtonUp();

            obj.buildPanes();
            obj.layout();
        end

        function layout(obj)
            %LAYOUT Update the root grid row heights from the panes.
            n = numel(obj.Panes);
            heights = cell(1, n + 1);
            for i = 1:n
                heights{i} = obj.Panes{i}.currentHeight();
            end
            heights{n + 1} = '1x';   % spacer absorbs any extra space
            obj.RootGrid.RowHeight = heights;
        end

        function openPreferences(~)
            %OPENPREFERENCES Open the NDI preferences editor.
            ndi.gui.preferencesEditor();
        end

        function refresh(obj)
            %REFRESH Ask every pane to re-read its model state.
            for i = 1:numel(obj.Panes)
                obj.Panes{i}.refresh();
            end
        end
    end

    methods (Access = private)
        function buildPanes(obj)
            %BUILDPANES Instantiate the pane stack and build the root grid.
            obj.Panes = { ...
                ndi.gui.nav.ndiPane(obj), ...
                ndi.gui.nav.cloudPane(obj), ...
                ndi.gui.nav.datasetsPane(obj), ...
                ndi.gui.nav.progressPane(obj) };

            n = numel(obj.Panes);
            obj.RootGrid = uigridlayout(obj.Figure, [n + 1, 1]);
            obj.RootGrid.ColumnWidth = {'1x'};
            obj.RootGrid.Padding     = [obj.Pad obj.Pad obj.Pad obj.Pad];
            obj.RootGrid.RowSpacing  = obj.Spacing;

            for i = 1:n
                obj.Panes{i}.build(obj.RootGrid, i);
            end
        end

        function enforceMinSize(obj)
            %ENFORCEMINSIZE Keep the figure at or above the minimum size.
            pos = obj.Figure.Position;
            newW = max(pos(3), obj.MinWidth);
            newH = max(pos(4), obj.MinHeight);
            if newW ~= pos(3) || newH ~= pos(4)
                obj.Figure.Position = [pos(1) pos(2) newW newH];
            end
        end

        function idx = resizablePaneIndex(obj)
            %RESIZABLEPANEINDEX Index of the (single) drag-resizable pane.
            idx = 0;
            for i = 1:numel(obj.Panes)
                p = obj.Panes{i};
                if isprop(p, 'Resizable') && p.Resizable ...
                        && p.Collapsible && p.Engaged
                    idx = i;
                    return;
                end
            end
        end

        function y = paneBottomEdge(obj, idx)
            %PANEBOTTOMEDGE Y (from figure bottom, px) of pane IDX's lower edge.
            figH   = obj.Figure.Position(4);
            fromTop = obj.Pad + obj.Spacing * (idx - 1);
            for i = 1:idx
                fromTop = fromTop + obj.Panes{i}.currentHeight();
            end
            y = figH - fromTop;
        end

        function onButtonDown(obj)
            %ONBUTTONDOWN Begin a resize drag if the click is on a pane edge.
            idx = obj.resizablePaneIndex();
            if idx == 0; return; end
            cp = obj.Figure.CurrentPoint;
            edgeY = obj.paneBottomEdge(idx);
            if abs(cp(2) - edgeY) <= obj.GripPixels
                obj.Dragging    = true;
                obj.DragPaneIdx = idx;
            end
        end

        function onMouseMotion(obj)
            %ONMOUSEMOTION Drive an in-progress drag or show the edge cursor.
            if obj.Dragging
                obj.applyDrag();
                return;
            end
            idx = obj.resizablePaneIndex();
            if idx == 0
                return;
            end
            cp = obj.Figure.CurrentPoint;
            if abs(cp(2) - obj.paneBottomEdge(idx)) <= obj.GripPixels
                obj.Figure.Pointer = 'hand';
            else
                obj.Figure.Pointer = 'arrow';
            end
        end

        function onButtonUp(obj)
            %ONBUTTONUP End a resize drag.
            if obj.Dragging
                obj.Dragging    = false;
                obj.DragPaneIdx = 0;
                obj.Figure.Pointer = 'arrow';
            end
        end

        function applyDrag(obj)
            %APPLYDRAG Set the dragged pane's height from the pointer.
            idx = obj.DragPaneIdx;
            if idx < 1 || idx > numel(obj.Panes); return; end
            p = obj.Panes{idx};

            n    = numel(obj.Panes);
            figH = obj.Figure.Position(4);
            cp   = obj.Figure.CurrentPoint;

            aboveHeights = 0;
            for i = 1:(idx - 1)
                aboveHeights = aboveHeights + obj.Panes{i}.currentHeight();
            end
            belowHeights = 0;
            for i = (idx + 1):n
                belowHeights = belowHeights + obj.Panes{i}.currentHeight();
            end

            % Pane top edge from the figure top; its bottom edge follows the
            % pointer, so figH - cp(2) = topEdge + h.
            topEdge   = obj.Pad + obj.Spacing * (idx - 1) + aboveHeights;
            newHeight = figH - cp(2) - topEdge;

            % Upper bound leaves the panes below at their current heights and
            % the spacer row non-negative: the grid consumes 2*Pad + n row
            % spacings + all pane heights + spacer = figH.
            maxHeight = figH - 2 * obj.Pad - n * obj.Spacing ...
                - aboveHeights - belowHeights;
            maxHeight = max(maxHeight, p.MinHeight);

            p.Height = min(max(newHeight, p.MinHeight), maxHeight);
            obj.layout();
        end
    end
end
