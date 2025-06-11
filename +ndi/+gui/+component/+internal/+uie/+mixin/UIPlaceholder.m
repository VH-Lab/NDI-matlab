classdef UIPlaceholder < handle
    % UIPLACEHOLDER A mixin class that provides the 'Placeholder' property.
    %
    % This is for editable components, like edit fields and text areas,
    % to display instructional text when the component's value is empty.

    properties
        % Placeholder - Text that appears in the component when it is empty.
        %
        % This text provides a hint to the user about what to enter.
        Placeholder (1,:) char = ''
    end

end