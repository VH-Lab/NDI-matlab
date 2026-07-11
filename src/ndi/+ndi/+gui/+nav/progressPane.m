classdef progressPane < ndi.gui.nav.pane
%NDI.GUI.NAV.PROGRESSPANE Collapsible "Progress" pane.
%
%   A collapsible pane whose body is, for now, 50 pixels of empty space.
%   It is a placeholder that later versions will fill with progress
%   indicators. When engaged the pane is HeaderHeight + 50 pixels tall.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane

    properties (Constant, Access = private)
        BodyHeight = 50   % pixels of body content when engaged
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
        end

        function tf = HasBody(~)
            tf = true;
        end
    end

    methods (Access = protected)
        function buildBody(obj, container)
            % Reserved empty space; content is added in a later version.
            uilabel(container, 'Text', '');
        end
    end
end
