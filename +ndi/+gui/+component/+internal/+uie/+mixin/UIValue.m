classdef UIValue < handle
    % UIVALUE A mixin class for describing a component that holds a value.
    %
    % This class provides a generic 'Value' property. The data type is
    % unrestricted and depends on the component (e.g., char for an edit
    % field, logical for a checkbox, numeric for a slider).

    properties
        % Value - The current value of the component.
        Value
    end

end