classdef ndiPane < ndi.gui.nav.pane
%NDI.GUI.NAV.NDIPANE The top, uncollapsible "NDI" pane.
%
%   A single-row pane with a 12-point bold "NDI" label on the left and a
%   "Prefs" button on the right that opens the preferences editor. This
%   is always the first pane in ndi.gui.navigator and cannot be collapsed.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.preferencesEditor

    methods
        function obj = ndiPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeaderRight(obj, parent)
            btn = uibutton(parent, ...
                'Text',            'Prefs', ...
                'ButtonPushedFcn', @(~,~) obj.Navigator.openPreferences());
            btn.Layout.Row    = 1;
            btn.Layout.Column = 3;
            obj.accentButton(btn);
        end

        function w = rightWidth(~)
            w = 60;
        end
    end
end
