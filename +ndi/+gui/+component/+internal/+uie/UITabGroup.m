classdef UITabGroup < ndi.gui.component.internal.uie.mixin.UIContainer & ...
                ndi.gui.component.internal.uie.mixin.UIVisualComponent & ...
                ndi.gui.component.internal.uie.UIElement
    % UITABGROUP Describes a container for a group of tabs.

    properties
        % TabLocation - The location of the tab labels within the container.
        TabLocation (1,:) char {mustBeMember(TabLocation,{'top','bottom','left','right'})} = 'top'

        % SelectedTab - The Tag of the UITab that should be selected by default.
        SelectedTab (1,:) char = ''
    end
end