classdef UIButton < ndi.gui.component.internal.uie.UIElement & ...
                   ndi.gui.component.internal.uie.UIVisualComponent & ...
                   ndi.gui.component.internal.uie.UITextComponent & ...
                   ndi.gui.component.internal.uie.UIIconComponent & ...
                   ndi.gui.component.internal.uie.UIInteractiveComponent
    % UIBUTTON Describes a push button UI component.
    %
    % This class uses multiple inheritance to compose all necessary features
    % from the elemental, visual, text, icon, and interactive mixin classes.

    properties
        % We override the 'Text' property to provide a button-specific default.
        Text (1,:) char = 'Button'
        
        % Callback - The name of the function to be executed when the button is pushed.
        Callback (1,:) char = ''
    end
    
    % Note: All other properties (Tag, Position, FontSize, Icon, Enable, etc.)
    % are inherited automatically from the superclasses.

end