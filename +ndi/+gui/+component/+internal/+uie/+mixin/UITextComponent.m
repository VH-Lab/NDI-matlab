classdef UITextComponent < handle
    % UITEXTCOMPONENT An abstract class for describing any UI element that contains text.

    properties
        FontWeight (1,:) char {mustBeMember(FontWeight,{'normal','bold'})} = 'normal'
        FontAngle (1,:) char {mustBeMember(FontAngle,{'normal','italic'})} = 'normal'
        FontSize (1,1) double {mustBeNumeric, mustBePositive} = 12
        FontColor {ndi.validators.mustBeValidColor(FontColor)} = [0 0 0]
        FontName (1,:) char {mustBeMember(FontName,{'Helvetica', 'Arial', 'Courier New', 'Times New Roman'})} = 'Helvetica'
    end
    
end