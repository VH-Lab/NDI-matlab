classdef UILabel < ndi.gui.component.internal.uie.UIElement & ...
                   ndi.gui.component.internal.uie.UIVisualComponent & ...
                   ndi.gui.component.internal.uie.UITextComponent
    % UILABEL Describes a static text label UI component.

    properties
        % Text - The text that appears in the label.
        Text (1,:) char = 'Label'
        
        % HorizontalAlignment - The horizontal alignment of the text.
        HorizontalAlignment (1,:) char {mustBeMember(HorizontalAlignment,{'left','center','right'})} = 'left'
        
        % VerticalAlignment - The vertical alignment of the text.
        VerticalAlignment (1,:) char {mustBeMember(VerticalAlignment,{'bottom','center','top'})} = 'center'
    end
end