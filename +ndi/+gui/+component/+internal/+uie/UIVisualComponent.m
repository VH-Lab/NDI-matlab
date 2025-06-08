classdef UIVisualComponent < ndi.gui.component.internal.uie.UIElement
    % UIVISUALCOMPONENT A class for describing visual UI properties.

    properties
        Position (1,4) {mustBeNumeric} = [0 0 100 22]
        Units (1,:) char {mustBeMember(Units,{'pixels','normalized','inches','centimeters','points','characters'})} = 'pixels'
        BackgroundColor {ndi.validators.mustBeValidColor(BackgroundColor)} = [0.94 0.94 0.94]
        Layout (1,1) ndi.gui.component.internal.uie.UILayout = ndi.gui.component.internal.uie.UILayout()
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UIVisualComponent from an alphanumeric struct
            arguments
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            S_in = alphaS_in;
            obj = ndi.util.StructSerializable.fromStruct(mfilename('class'), S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
        end
    end
end