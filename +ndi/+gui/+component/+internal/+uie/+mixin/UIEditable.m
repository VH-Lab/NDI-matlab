classdef UIEditable < handle
    % UIEDITABLE A mixin class that provides the 'Editable' property.
    %
    % This is for components, like dropdowns or potentially listboxes,
    % where the user might be allowed to type a custom value in addition
    % to selecting from a list.

    properties
        % Editable - Controls whether the user can type a custom value.
        %
        % Must be either 'on' or 'off' (default).
        Editable (1,:) char {mustBeMember(Editable,{'on','off'})} = 'off'
    end

end