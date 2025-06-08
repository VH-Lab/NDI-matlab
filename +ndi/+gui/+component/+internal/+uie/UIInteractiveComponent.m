classdef UIInteractiveComponent < ndi.gui.component.internal.uie.UIVisualComponent
    % UIINTERACTIVECOMPONENT A class for describing UI elements that the user can interact with.

    properties
        Enable (1,:) char {mustBeMember(Enable,{'on','off'})} = 'on'
        Tooltip (1,:) char = ''
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create an UIInteractiveComponent from an alphanumeric struct
            arguments
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            S_in = alphaS_in;
            obj = ndi.util.StructSerializable.fromStruct(mfilename('class'), S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
        end
    end
end