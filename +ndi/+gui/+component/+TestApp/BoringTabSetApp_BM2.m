classdef BoringTabSetApp_BM2 < ndi.gui.component.internal.TabSetController_BM2
    % Bare-minimum subclass that inherits the manual startup behavior.

    methods (Access = private)
        % This overrides the parent's startupFcn
        function startupFcn(app)
            disp('BM2_SUBCLASS: startupFcn is now running!');
            app.MyFigure.Name = 'BM2 Subclass Has Taken Control!';
        end
    end

end