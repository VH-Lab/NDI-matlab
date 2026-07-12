classdef cloudPane < ndi.gui.nav.pane
%NDI.GUI.NAV.CLOUDPANE The uncollapsible "NDI Cloud" pane.
%
%   A single-row pane with a bold "NDI Cloud" label on the left and a
%   "Profile" button on the right that opens the NDI Cloud profile editor
%   (ndi.gui.profileEditor), where the user can view and manage their
%   cloud accounts and choose which one is active.
%
%   See also: ndi.gui.navigator, ndi.gui.nav.pane, ndi.gui.profileEditor

    methods
        function obj = cloudPane(navigator)
            obj@ndi.gui.nav.pane(navigator, ...
                'Title',       'NDI Cloud', ...
                'Collapsible', false);
        end
    end

    methods (Access = protected)
        function buildHeader(obj)
            buildHeader@ndi.gui.nav.pane(obj);
            obj.TitleLabel.FontWeight = 'bold';
        end

        function buildHeaderRight(obj, parent)
            btn = uibutton(parent, ...
                'Text',            'Profile', ...
                'ButtonPushedFcn', @(~,~) ndi.gui.profileEditor());
            btn.Layout.Row    = 1;
            btn.Layout.Column = 3;
            obj.accentButton(btn);
        end

        function w = rightWidth(~)
            w = 60;
        end
    end
end
