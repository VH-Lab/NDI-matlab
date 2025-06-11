classdef UIIconComponent < handle
    % UIICONCOMPONENT A mixin class for describing components that have an icon.

    properties
        % Icon - The image to be displayed on the component.
        %
        % This should be a character vector representing either a filename
        % (e.g., 'my_icon.png' or a full path) or a predefined MATLAB
        % icon name (e.g., 'success', 'error').
        Icon (1,:) char = ''

        % IconAlignment - The alignment of the icon relative to the text.
        %
        % Must be one of: 'left', 'right', 'top', 'bottom', 'leftmargin', 'rightmargin'.
        IconAlignment (1,:) char {mustBeMember(IconAlignment, ...
            {'left', 'right', 'top', 'bottom', 'leftmargin', 'rightmargin'})} = 'left'
    end
    
end