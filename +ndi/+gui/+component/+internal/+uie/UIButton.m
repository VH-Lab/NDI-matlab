classdef UIButton < ndi.gui.component.internal.uie.UIElement & ...
                   ndi.gui.component.internal.uie.mixin.UIVisualComponent & ...
                   ndi.gui.component.internal.uie.mixin.UITextComponent & ...
                   ndi.gui.component.internal.uie.mixin.UIIconComponent & ...
                   ndi.gui.component.internal.uie.mixin.UIInteractiveComponent & ...
                   ndi.gui.component.internal.uie.mixin.UIText
    % UIBUTTON Describes a push button UI component.
    %
    % This class uses multiple inheritance to compose all necessary features
    % from the elemental, visual, text, icon, and interactive mixin classes.

    properties
        % ButtonPushedFcn - The name of the function to be executed when the button is pushed.
        ButtonPushedFcn (1,:) char = ''
    end
   
end