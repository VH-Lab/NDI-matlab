classdef UITextArea < ndi.gui.component.internal.uie.UIElement & ...
                      ndi.gui.component.internal.uie.UIVisualComponent & ...
                      ndi.gui.component.internal.uie.UITextComponent & ...
                      ndi.gui.component.internal.uie.UIInteractiveComponent & ...
                      ndi.gui.component.internal.uie.UIValue & ...
                      ndi.gui.component.internal.uie.UIValueChangedFcn & ...
                      ndi.gui.component.internal.uie.UIValueChangingFcn
    % UITEXTAREA Describes an editable, multi-line text area.

    properties
        % Placeholder - Text that appears in the text area when it is empty.
        Placeholder (1,:) char = ''
    end
    
    methods
        function obj = UITextArea()
            % Override the default WordWrap from UITextComponent for this class
            obj.WordWrap = 'on';
        end
    end
    
    % Note: The 'Value' property is inherited from the UIValue mixin.
end