classdef UICheckbox < ndi.gui.component.internal.uie.UIElement & ...
                      ndi.gui.component.internal.uie.UIVisualComponent & ...
                      ndi.gui.component.internal.uie.UITextComponent & ...
                      ndi.gui.component.internal.uie.UIInteractiveComponent & ...
                      ndi.gui.component.internal.uie.UIValue & ...
                      ndi.gui.component.internal.uie.UIValueChangedFcn
    % UICHECKBOX Describes a checkbox UI component.
    %
    % This class uses multiple inheritance to compose all necessary features
    % from the elemental, visual, text, interactive, and value mixin classes.

    properties
        % We override the 'Text' property to provide a more specific default.
        Text (1,:) char = 'Checkbox'
    end
    
    % Note: All other properties (Tag, Position, Value, Enable, etc.)
    % are inherited automatically from the superclasses.

end