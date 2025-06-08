classdef UIElement < ndi.util.StructSerializable & matlab.mixin.Heterogeneous
    % UIELEMENT A base class for describing a generic UI element.

    properties
        ParentTag (1,:) char = ''
        Visible (1,:) char {mustBeMember(Visible,{'on','off'})} = 'on'
        Tag (1,:) char = ''
        UserData
    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            error('UIElement:NoDefaultObject', 'You cannot create a default UIElement object.');
        end
    end
end