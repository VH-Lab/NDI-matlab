classdef UIMultiselect < handle
    % UIMULTISELECT A mixin class that provides the 'Multiselect' property.
    %
    % This is for components, like listboxes, where the user might be
    % allowed to select more than one item from a list.

    properties
        % Multiselect - Controls whether multiple items can be selected.
        %
        % Must be either 'on' or 'off' (default).
        Multiselect (1,:) char {mustBeMember(Multiselect,{'on','off'})} = 'off'
    end

end