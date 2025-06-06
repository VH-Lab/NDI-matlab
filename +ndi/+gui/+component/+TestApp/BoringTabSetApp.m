classdef BoringTabSetApp < ndi.gui.component.internal.TabSetController
    
    methods (Access = protected)
        % This overrides the parent's startupFcn
        function startupFcn(app)
            % --- FIX IS HERE: Explicitly call the parent's startup function ---
            % This ensures the base class setup (like setFigureMinSize) is run.
            startupFcn@ndi.gui.component.internal.TabSetController(app);
            % ---

            % Now, continue with the subclass-specific setup
            
            % Clear any placeholder tabs from the base class
            delete(app.TabGroup.Children);
            
            % Create custom tabs
            numTabs = 3;
            
            for i = 1:numTabs
                newTab = uitab(app.TabGroup, 'Title', ['Boring Tab ' num2str(i)]);
                
                % Create a controller for the new tab.
                newController = ndi.gui.component.TestApp.BoringTabController(newTab);
                
                % This will now build the typed array dynamically without errors
                app.tabControllers(i) = newController;
                newTab.UserData = i;
            end
            
            % --- Showcase UI Customization in Subclass ---
            
            % 1. Load the logo image
            try
                app.Footer.LogoImage.ImageSource = fullfile(ndi.toolboxdir,'resources','images','ndi_logo.png');
            catch ME
                warning('Could not load NDI logo image. Error: %s', ME.message);
            end

            % 2. Change background colors to match a theme
            footerColor = [0.902 0.902 0.902];
            app.Footer.FooterGridLayout.BackgroundColor = footerColor;
            app.Footer.PreviousTabButton.BackgroundColor = footerColor;
            app.Footer.NextTabButton.BackgroundColor = footerColor;
            
            % ---

            % Call onTabChanged to initialize the view for the first tab
            if ~isempty(app.TabGroup.Children)
                app.onTabChanged();
            end
        end
        
        % --- Demonstration override for the close request ---
        function TabSetControllerUIFigureCloseRequest(app, event)
            % This method overrides the parent's close request function.
            
            % Step 1: Add subclass-specific behavior
            disp('BoringTabSetApp is closing!');
            
            % Step 2: Explicitly call the parent's version of this method
            % to ensure the original behavior (deleting the app) still runs.
            TabSetControllerUIFigureCloseRequest@ndi.gui.component.internal.TabSetController(app, event);
        end
    end
end