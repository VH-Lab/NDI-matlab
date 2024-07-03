classdef WizardTheme < ndi.gui.window.wizard.abstract.Theme

    properties (Constant)
        FontName = 'helvetica';
    
        HeaderBgColor = ndi.gui.internal.theme.NDITheme.PrimaryColorA;
        HeaderMidColor = ndi.gui.internal.theme.NDITheme.PrimaryColorB
        HeaderFgColor = ndi.gui.internal.theme.NDITheme.SecondaryColorC
        
        %FigureBgColor = ndi.gui.internal.theme.NDITheme.SecondaryColorC
        FigureBgColor = [246,248,252]/255;
        FigureFgColor = ndi.gui.internal.theme.NDITheme.PrimaryColorA
        
        MatlabBlue = [16,119,166]/255;
        ControlPanelsBgColor = [1,1,1];
    end
end

