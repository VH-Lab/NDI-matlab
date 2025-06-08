classdef UIElement < ndi.util.StructSerializable & matlab.mixin.Heterogeneous
    % UIELEMENT A base class for describing a generic UI element.

    properties
        ParentTag (1,:) char = ''
        Visible (1,:) char {mustBeMember(Visible,{'on','off'})} = 'on'
        Tag (1,:) char = ''
        UserData
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UIElement from an alphanumeric struct.
            arguments
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            S_in = alphaS_in;
            obj = ndi.util.StructSerializable.fromStruct(mfilename('class'), S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
        end
    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            error('UIElement:NoDefaultObject', 'You cannot create a default UIElement object.');
        end
    end
end