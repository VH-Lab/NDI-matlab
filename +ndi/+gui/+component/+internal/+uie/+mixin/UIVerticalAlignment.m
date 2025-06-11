classdef UIVerticalAlignment < handle
    % UIVERTICALALIGNMENT A mixin class for describing vertical text alignment.
    %
    % Provides the 'VerticalAlignment' property for components that display text.

    properties
        % VerticalAlignment - The vertical alignment of the text within the component.
        %
        % Must be one of: 'top', 'center' (default), or 'bottom'.
        VerticalAlignment (1,:) char {mustBeMember(VerticalAlignment,{'top','center','bottom'})} = 'center'
    end

end