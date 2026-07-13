classdef navigator < handle
%NDI.GUI.NAVIGATOR A small, resizable NDI navigator window.
%
%   NDI.GUI.NAVIGATOR opens a compact navigator built from a vertical
%   stack of panes. The window is resizable but never smaller than its
%   content requires (and never narrower than 250 pixels).
%
%   Syntax:
%       ndi.gui.navigator()
%       ndi.gui.navigator(Position=[x y w h])
%       nav = ndi.gui.navigator(...)
%
%   Name-value arguments:
%       Position - 1x4 double, the figure Position in pixels.
%                  Default [100 100 300 500].
%       Visible  - 'on' (default) or 'off'. Create the window hidden when
%                  'off' (used by headless tests).
%
%   Panes (top to bottom):
%       NDI        - uncollapsible; 12-point bold "NDI" label and a
%                    "Prefs" button that opens the preferences editor.
%       NDI Cloud  - uncollapsible; "NDI Cloud" label and a popup menu
%                    showing / selecting the active cloud account.
%       Datasets   - collapsible and resizable; a "Paths" button and a
%                    scrollable tree of datasets and their sessions.
%       Progress   - collapsible; hosts progress bars and hugs the bottom.
%
%   Layout model ("content-driven height, elastic filler panes"):
%       * The panes fill the window top-to-bottom with no dead space, so
%         the Progress pane always hugs the bottom edge.
%       * Resizable panes (Datasets) are elastic: they share whatever
%         height is left after the fixed panes, down to their minimum.
%         Dragging the window edge therefore grows / shrinks Datasets.
%       * Structural actions resize the window: collapsing a pane shrinks
%         the window by that pane's body height and expanding grows it.
%       * Content changes (progress bars appearing / finishing) do NOT
%         resize the window; the elastic panes shrink to make room and the
%         progress area scrolls once they reach their minimum.
%
%   The pane stack is object-oriented: every pane is an
%   ndi.gui.nav.pane subclass. New panes can be added by writing a
%   subclass (choosing collapsible or not, resizable or not, a minimum
%   engaged height, and a title) and appending it in buildPanes.
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
        RootGrid     % uigridlayout: one row per pane
        Panes        % cell array of ndi.gui.nav.pane handles
    end

    properties (Constant)
        MinWidth  = 250   % minimum figure width, in pixels
        MinHeight = 300   % absolute minimum figure height, in pixels
    end

    properties (Constant, Access = private)
        Pad       = 6     % root-grid padding, in pixels
        Spacing   = 4     % root-grid row spacing, in pixels
    end

    properties (Access = private)
        Busy (1,1) logical = false   % guards against re-entrant resizing
    end

    methods
        function obj = navigator(options)
            arguments
                options.Position (1,4) double = [100 100 300 500]
                options.Visible (1,1) matlab.lang.OnOffSwitchState = "on"
            end

            pos = options.Position;
            pos(3) = max(pos(3), obj.MinWidth);
            pos(4) = max(pos(4), obj.MinHeight);

            c = ndi.gui.cloudColors();
            obj.Figure = uifigure('Name', 'NDI Navigator', ...
                'Position',         pos, ...
                'Tag',              'ndiNavigator', ...
                'Visible',          options.Visible, ...
                'Color',            c.darkBlue, ...
                'AutoResizeChildren', 'on');
            obj.Figure.SizeChangedFcn = @(~,~) obj.onFigureResized();

            obj.buildPanes();
            obj.layout();

            % Store a back-reference on the figure so the navigator object
            % can be recovered from its figure handle (see findOpen). This
            % is how ndi.gui.component.ProgressBarWindow discovers an open
            % navigator to dock progress bars into.
            guidata(obj.Figure, obj);
        end

        function p = progressPaneHandle(obj)
            %PROGRESSPANEHANDLE Return the navigator's progress pane, if any.
            %
            %   P = PROGRESSPANEHANDLE(OBJ) returns the
            %   ndi.gui.nav.progressPane in this navigator's pane stack, or
            %   an empty ndi.gui.nav.progressPane array if none is present.
            p = ndi.gui.nav.progressPane.empty;
            for i = 1:numel(obj.Panes)
                if isa(obj.Panes{i}, 'ndi.gui.nav.progressPane')
                    p = obj.Panes{i};
                    return;
                end
            end
        end
    end

    methods (Static)
        function nav = findOpen()
            %FINDOPEN Return open ndi.gui.navigator instances, newest last.
            %
            %   NAV = NDI.GUI.NAVIGATOR.FINDOPEN() searches the open figures
            %   for NDI navigator windows and returns their navigator
            %   objects. The result is an ndi.gui.navigator array (empty if
            %   no navigator is open); when several are open they are
            %   returned in figure-stacking order, so NAV(end) is the most
            %   recently created.
            nav = ndi.gui.navigator.empty;
            figs = findall(groot, 'Type', 'figure', 'Tag', 'ndiNavigator');
            for i = 1:numel(figs)
                g = guidata(figs(i));
                if isa(g, 'ndi.gui.navigator') && isvalid(g)
                    nav(end+1) = g; %#ok<AGROW>
                end
            end
        end
    end

    methods
        function layout(obj)
            %LAYOUT Distribute the window height across the pane rows.
            %
            %   Fixed (non-elastic) panes take the height they request; the
            %   elastic panes (Resizable, engaged) share the remaining space
            %   equally, floored at their minimum. When no elastic pane is
            %   engaged the window is shrunk to fit the content exactly so no
            %   dead space is left below the panes.
            if obj.Busy || isempty(obj.RootGrid) || ~isvalid(obj.RootGrid)
                return;
            end

            n = numel(obj.Panes);
            elastic = obj.elasticMask();
            want = zeros(1, n);
            for i = 1:n
                want(i) = obj.Panes{i}.currentHeight();
            end

            if any(elastic)
                contentH = obj.contentHeight(obj.Figure.Position(4));
                fixedSum = sum(want(~elastic));
                leftover = contentH - fixedSum;
                nEl      = sum(elastic);
                share    = leftover / nEl;
                for i = find(elastic)
                    want(i) = max(share, obj.Panes{i}.MinHeight);
                end
            else
                % No elastic pane: size the window to the content so the
                % panes hug both edges (this is what shrinks the window when
                % the last resizable pane is collapsed).
                needFigH = obj.figureHeightForContent(sum(want));
                if abs(needFigH - obj.Figure.Position(4)) > 1
                    obj.setFigureHeight(needFigH);
                end
            end

            heights = cell(1, n);
            for i = 1:n
                heights{i} = want(i);
                obj.Panes{i}.setRenderedHeight(want(i));
            end
            obj.RootGrid.RowHeight = heights;
        end

        function paneToggled(obj, pane)
            %PANETOGGLED Resize the window after a user collapse/expand.
            %   Grows the window by the pane's body height when it was just
            %   expanded, or shrinks it by the pane's former body height when
            %   it was just collapsed, then re-lays out.
            if pane.Engaged
                delta = pane.currentHeight() - pane.HeaderHeight;   % body added
            else
                prev = pane.RenderedHeight;
                if isnan(prev) || prev < pane.HeaderHeight
                    prev = pane.HeaderHeight;
                end
                delta = pane.HeaderHeight - prev;                   % body removed (<= 0)
            end
            obj.resizeFigureBy(delta);
            obj.layout();
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
            obj.RootGrid = uigridlayout(obj.Figure, [n, 1]);
            obj.RootGrid.ColumnWidth     = {'1x'};
            obj.RootGrid.Padding         = [obj.Pad obj.Pad obj.Pad obj.Pad];
            obj.RootGrid.RowSpacing      = obj.Spacing;
            obj.RootGrid.BackgroundColor = ndi.gui.cloudColors().darkBlue;

            for i = 1:n
                obj.Panes{i}.build(obj.RootGrid, i);
            end
        end

        function mask = elasticMask(obj)
            %ELASTICMASK Logical mask of engaged, resizable (filler) panes.
            n = numel(obj.Panes);
            mask = false(1, n);
            for i = 1:n
                p = obj.Panes{i};
                mask(i) = isprop(p, 'Resizable') && p.Resizable ...
                    && p.Collapsible && p.Engaged;
            end
        end

        function h = contentHeight(obj, figH)
            %CONTENTHEIGHT Pixels available to the pane rows within FIGH.
            n = numel(obj.Panes);
            h = figH - 2 * obj.Pad - (n - 1) * obj.Spacing;
        end

        function figH = figureHeightForContent(obj, contentSum)
            %FIGUREHEIGHTFORCONTENT Figure height that fits CONTENTSUM rows.
            n = numel(obj.Panes);
            figH = contentSum + 2 * obj.Pad + (n - 1) * obj.Spacing;
            figH = max(figH, obj.minFigureHeight());
        end

        function h = minFigureHeight(obj)
            %MINFIGUREHEIGHT Smallest figure height that fits the panes.
            %   Collapsed panes need only their header; elastic panes need
            %   their minimum; other engaged panes need their current height.
            n = numel(obj.Panes);
            s = 0;
            for i = 1:n
                p = obj.Panes{i};
                if p.Collapsible && ~p.Engaged
                    s = s + p.HeaderHeight;
                elseif isprop(p, 'Resizable') && p.Resizable
                    s = s + p.MinHeight;
                else
                    s = s + p.currentHeight();
                end
            end
            h = max(s + 2 * obj.Pad + (n - 1) * obj.Spacing, obj.MinHeight);
        end

        function onFigureResized(obj)
            %ONFIGURERESIZED Handle a user resize of the window.
            if obj.Busy
                return;
            end
            obj.enforceMinSize();
            obj.layout();
        end

        function enforceMinSize(obj)
            %ENFORCEMINSIZE Keep the figure at or above the minimum size.
            pos  = obj.Figure.Position;
            newW = max(pos(3), obj.MinWidth);
            newH = max(pos(4), obj.minFigureHeight());
            if newW ~= pos(3) || newH ~= pos(4)
                % Keep the top-left corner fixed when clamping the height.
                top = pos(2) + pos(4);
                obj.setFigurePosition([pos(1), top - newH, newW, newH]);
            end
        end

        function resizeFigureBy(obj, delta)
            %RESIZEFIGUREBY Change the figure height by DELTA, top-anchored.
            pos  = obj.Figure.Position;
            newH = max(pos(4) + delta, obj.minFigureHeight());
            obj.setFigureHeight(newH);
        end

        function setFigureHeight(obj, newH)
            %SETFIGUREHEIGHT Set the figure height, keeping the top fixed.
            pos = obj.Figure.Position;
            top = pos(2) + pos(4);
            obj.setFigurePosition([pos(1), top - newH, pos(3), newH]);
        end

        function setFigurePosition(obj, p)
            %SETFIGUREPOSITION Set Figure.Position without re-entering layout.
            obj.Busy = true;
            obj.Figure.Position = p;
            obj.Busy = false;
        end
    end
end
