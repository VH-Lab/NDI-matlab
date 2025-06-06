classdef TabSetController_BM2 < matlab.apps.AppBase
    % Bare-minimum base class using the "Manual Invocation" pattern.
    
    properties (Access = public)
        MyFigure matlab.ui.Figure
    end

    methods (Access = public)
        % Constructor that manually controls the app creation process
        function app = TabSetController_BM2()
            disp('BM2_BASE: Constructor called. Manually starting app creation...');
            
            % Manually call the private methods to build and start the app
            createComponents(app);
            registerApp(app, app.MyFigure);
            runStartupFcn(app, @startupFcn);

            disp('BM2_BASE: App startup process complete.');
            if nargout == 0, clear app, end
        end
    end

    methods (Access = private)
        function createComponents(app)
            disp('BM2_BASE: createComponents is now running!');
            app.MyFigure = uifigure('Name', 'BM2 Base Class Figure');
        end
        
        function startupFcn(app)
            % This is a placeholder that will be overridden by the subclass.
            disp('BM2_BASE: (Parent) startupFcn was called.');
        end
    end
end