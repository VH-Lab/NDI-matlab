classdef UITitle < handle
    % UITITLE A mixin class that provides the 'Title' property.
    %
    % This is for components that have a title, such as panels and tabs.

    properties
        % Title - The text that appears as the title of the component.
        Title (1,:) char = ''
    end

end