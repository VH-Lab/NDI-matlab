classdef UIInteractiveComponent < ndi.util.StructSerializable
    % UIINTERACTIVECOMPONENT A mixin for describing interactive UI properties.
    properties
        % Enable - Controls whether the component can be interacted with.
        Enable (1,:) char {mustBeMember(Enable,{'on','off'})} = 'on'
    end
end