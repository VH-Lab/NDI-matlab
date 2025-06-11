classdef UIText < handle
    % UITEXT A mixin class that provides the 'Text' property.
    %
    % This is for any component that displays a primary string of text,
    % such as a label, button, or checkbox.

    properties
        % Text - The primary text displayed by the component.
        Text (1,:) char = ''
    end

end