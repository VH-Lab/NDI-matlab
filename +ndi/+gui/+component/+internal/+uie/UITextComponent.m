classdef UITextComponent < ndi.gui.component.internal.uie.UIElement
    % UITEXTCOMPONENT A class for describing any UI element that contains text.

    properties
        FontWeight (1,:) char {mustBeMember(FontWeight,{'normal','bold'})} = 'normal'
        FontAngle (1,:) char {mustBeMember(FontAngle,{'normal','italic'})} = 'normal'
        FontSize (1,1) double {mustBeNumeric, mustBePositive} = 12
        FontColor {ndi.validators.mustBeValidColor(FontColor)} = [0 0 0]
        FontName (1,:) char {mustBeMember(FontName,{'Helvetica', 'Arial', 'Courier New', 'Times New Roman'})} = 'Helvetica'
    end

    methods (Static)
        function obj = fromAlphaNumericStruct(alphaS_in, options)
            % FROMALPHANUMERICSTRUCT Create a UITextComponent from an alphanumeric struct
            arguments
                alphaS_in (1,1) struct
                options.errorIfFieldNotPresent (1,1) logical = false
            end
            S_in = alphaS_in;
            obj = ndi.util.StructSerializable.fromStruct(mfilename('class'), S_in, 'errorIfFieldNotPresent', options.errorIfFieldNotPresent);
        end
    end
end