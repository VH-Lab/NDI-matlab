classdef UIFigure < ndi.gui.component.internal.uie.mixin.UIContainer & ...
                   ndi.gui.component.internal.uie.mixin.UIInteractiveComponent & ...
                   ndi.gui.component.internal.uie.mixin.UITextComponent & ...
                   ndi.gui.component.internal.uie.mixin.UIVisualComponent & ...
                   ndi.gui.component.internal.uie.UIElement

    % UIFIGURE Describes the main application window (a uifigure).
    %
    % This class inherits all visual, interactive, and text properties from its
    % parents and adds properties specific to the main figure window.

    properties
        % Name - The text that appears in the title bar of the window.
        Name (1,:) char = 'MATLAB App'
        
        % CloseRequestCallback - The name of the function to be executed when the user
        % attempts to close the figure window.
        CloseRequestCallback (1,:) char = ''

        % WidthMin - The minimum allowable width for the figure.
        % The units are determined by the 'Units' property.
        WidthMin (1,1) {mustBeNumeric, mustBeNonnegative, mustBeFinite} = 0

        % WidthMax - The maximum allowable width for the figure.
        % The units are determined by the 'Units' property.
        WidthMax (1,1) {mustBeNumeric, mustBeNonnegative} = Inf

        % HeightMin - The minimum allowable height for the figure.
        % The units are determined by the 'Units' property.
        HeightMin (1,1) {mustBeNumeric, mustBeNonnegative, mustBeFinite} = 0
        
        % HeightMax - The maximum allowable height for the figure.
        % The units are determined by the 'Units' property.
        HeightMax (1,1) {mustBeNumeric, mustBeNonnegative} = Inf
    end

    methods
        function obj = UIFigure()
            % The constructor sets default values specific to a UIFigure.
            obj.BackgroundColor = [0.94 0.94 0.94]; % Standard MATLAB grey
        end
    end

end