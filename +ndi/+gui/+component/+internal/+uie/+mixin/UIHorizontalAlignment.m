classdef UIHorizontalAlignment < handle
    % UIHORIZONTALALIGNMENT A mixin class for describing horizontal text alignment.
    %
    % Provides the 'HorizontalAlignment' property for components that display text.

    properties
        % HorizontalAlignment - The horizontal alignment of the text within the component.
        %
        % Must be one of: 'left' (default), 'center', or 'right'.
        HorizontalAlignment (1,:) char {mustBeMember(HorizontalAlignment,{'left','center','right'})} = 'left'
    end

end