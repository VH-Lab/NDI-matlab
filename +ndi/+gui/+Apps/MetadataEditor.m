classdef MetadataEditor < ndi.gui.component.internal.TabSetController
    % METADATAEDITOR - An application for editing NDI metadata.
    
    methods (Access = protected)
        
        % This overrides the parent's startupFcn
        function startupFcn(app)
            % --- FIX IS HERE: Explicitly call the parent's startup function ---
            % This ensures the base class setup (like creating the resize timer) is run.
            startupFcn@ndi.gui.component.internal.TabSetController(app);
            % ---

            % --- Customize Figure Properties ---
            app.TSCFigure.Position = [100 100 900 610];
            app.TSCFigure.Name = 'NDI Metadata Editor';
            app.FigureMinHeight = 610;
            app.FigureMinWidth = 840;

            % --- Customize Footer UI ---
            footerColor = [0.902 0.902 0.902];
            app.Footer.FooterGridLayout.BackgroundColor = footerColor;
            app.Footer.PreviousTabButton.BackgroundColor = footerColor;
            app.Footer.NextTabButton.BackgroundColor = footerColor;
            
            try
                app.Footer.LogoImage.ImageSource = fullfile(ndi.toolboxdir,'resources','images','ndi_logo.png');
            catch ME
                warning('Could not load NDI logo image. Error: %s', ME.message);
            end

            % --- Application-Specific Tab Creation ---
            
            % Clear any placeholder tabs from the base class
            delete(app.TabGroup.Children);
            
            % 1. Create the 'Title/Abstract' Tab
            titleTab = uitab(app.TabGroup, 'Title', 'Title/Abstract');
            
            titleController = ndi.gui.component.metadataEditor.class.TitleAbstractTabController(titleTab);
            
            app.tabControllers(1) = titleController;
            titleTab.UserData = 1;

            % (Future tabs will be created here)
            
            % --- Finalize Startup ---
            % Call onTabChanged to initialize the view for the first tab
            if ~isempty(app.TabGroup.Children)
                app.onTabChanged();
            end
        end
        
        % Overridden close request function
        function TabSetControllerUIFigureCloseRequest(app, event)
            % This method overrides the parent's close request function.
            
            % Add custom logic here for saving or confirmation dialogs
            disp('MetadataEditor is closing!');
            
            % Explicitly call the parent's version to ensure the app deletes
            TabSetControllerUIFigureCloseRequest@ndi.gui.component.internal.TabSetController(app, event);
        end
    end
end