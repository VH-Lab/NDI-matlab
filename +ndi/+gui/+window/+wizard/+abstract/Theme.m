classdef Theme < handle

    properties (Abstract, Constant)
        FontName;
    
        HeaderBgColor
        HeaderMidColor
        HeaderFgColor
        
        FigureBgColor
        FigureFgColor
        
        ControlPanelsBgColor
    end
end

