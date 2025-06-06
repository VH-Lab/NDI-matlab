classdef SimpleApp < matlab.apps.AppBase
    % A standalone app to test the core AppBase framework.
    % This file should be in a simple directory, NOT in a package.
    
    properties (Access = protected)
        MyFigure matlab.ui.Figure
        MyButton matlab.ui.control.Button
    end

    methods (Access = protected)
        function createComponents(app)
            disp('--- SimpleApp: createComponents IS RUNNING! ---');
            
            % Create a simple figure and a button
            app.MyFigure = uifigure('Name', 'Standalone Test App');
            app.MyButton = uibutton(app.MyFigure, 'push', 'Text', 'Success!');
            app.MyButton.Position = [100 100 100 22];
        end
    end
end
