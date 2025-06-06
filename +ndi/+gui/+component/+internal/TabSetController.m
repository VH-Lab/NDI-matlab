classdef TabSetController < matlab.apps.AppBase

    properties (Access = public)
        TSCFigure               matlab.ui.Figure
        MainGridLayout          matlab.ui.container.GridLayout
        TabGroup                matlab.ui.container.TabGroup
        Footer                  struct
        tabControllers = ndi.gui.component.internal.TabController.empty(0,1)
        FigureMinWidth = 400;
        FigureMinHeight = 400;
    end

    properties(Access = private)
        previousTab
        ResizeTimer
    end

    % --- CONSTRUCTOR THAT MANUALLY STARTS THE APP ---
    methods (Access = public)
        function app = TabSetController()
            createComponents(app);
            registerApp(app, app.TSCFigure);
            runStartupFcn(app, @(app)startupFcn(app));
            if nargout == 0, clear app, end
        end
    end

    methods (Access = public) % Public API methods
        function performReset(app)
        end

        function delete(app)
            if ~isempty(app.ResizeTimer) && isvalid(app.ResizeTimer)
                stop(app.ResizeTimer);
                delete(app.ResizeTimer);
            end

            if isvalid(app.TSCFigure) && ~strcmp(app.TSCFigure.BeingDeleted, 'on')
                delete(app.TSCFigure);
            end
        end
    end

    % --- PROTECTED LIFECYCLE AND HELPER METHODS ---
    methods (Access = protected)
        function startupFcn(app)
            newTab = uitab(app.TabGroup, 'Title', 'Base Tab');
            uilabel(newTab, 'Text', 'This tab should be replaced by the subclass.', 'HorizontalAlignment', 'center');
            
            app.ResizeTimer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.25, ...
                'TimerFcn', @(~,~) app.checkAndEnforceMinSize());
            start(app.ResizeTimer);

            app.onTabChanged();
        end
        
        function onTabChanged(app)
            % Handle selecting/deselecting tab controllers
            if ~isempty(app.tabControllers) && ~isempty(app.previousTab) && isvalid(app.previousTab) && ~isempty(app.previousTab.UserData)
                prevControllerIdx = app.previousTab.UserData;
                if prevControllerIdx <= numel(app.tabControllers) && ~isempty(app.tabControllers(prevControllerIdx)) && isvalid(app.tabControllers(prevControllerIdx))
                    app.tabControllers(prevControllerIdx).tabDeSelected();
                end
            end
            currentTab = app.TabGroup.SelectedTab;
            if ~isempty(app.tabControllers) && isvalid(currentTab) && ~isempty(currentTab.UserData)
                currentControllerIdx = currentTab.UserData;
                 if currentControllerIdx <= numel(app.tabControllers) && ~isempty(app.tabControllers(currentControllerIdx)) && isvalid(app.tabControllers(currentControllerIdx))
                    app.tabControllers(currentControllerIdx).tabSelected();
                end
            end
            app.previousTab = currentTab;
            
            % Update button visibility
            if ~isempty(app.TabGroup.Children)
                allTabs = app.TabGroup.Children;
                numTabs = numel(allTabs);
                selectedTab = app.TabGroup.SelectedTab;
                
                tabIdx = find(allTabs == selectedTab, 1);
                
                app.Footer.PreviousTabButton.Visible = (tabIdx > 1);
                app.Footer.NextTabButton.Visible = (tabIdx < numTabs);
            else
                app.Footer.PreviousTabButton.Visible = 'off';
                app.Footer.NextTabButton.Visible = 'off';
            end
        end

        function missingField = checkRequiredFields(app, tabHandle)
            if ~isempty(app.tabControllers) && isvalid(tabHandle) && ~isempty(tabHandle.UserData)
                controllerIdx = tabHandle.UserData;
                missingField = app.tabControllers(controllerIdx).checkRequiredFields();
            else; missingField = []; end
        end
        
        function alertRequiredFieldsMissing(app, fieldName)
            uialert(app.TSCFigure, ['Please fill in the required field: ' fieldName], 'Validation Error');
        end
        
        function changeTab(app, newTabHandle)
            if isequal(app.TabGroup.SelectedTab, newTabHandle), return; end
            app.TabGroup.SelectedTab = newTabHandle;
            app.onTabChanged();
        end
        
        function TabSetControllerUIFigureCloseRequest(app, event)
            delete(app);
        end
    end

    % --- PRIVATE COMPONENTS AND CALLBACKS ---
    methods (Access = private)
        
        function createComponents(app)
            app.TSCFigure = uifigure('Visible', 'off');
            app.TSCFigure.Position = [100 100 650 480];
            app.TSCFigure.Name = 'TabSet Controller';
            app.TSCFigure.CloseRequestFcn = createCallbackFcn(app, @TabSetControllerUIFigureCloseRequest, true);
            
            app.MainGridLayout = uigridlayout(app.TSCFigure);
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.RowHeight = {'1x', 50};

            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            app.Footer = struct(); 
            
            app.Footer.FooterGridLayout = uigridlayout(app.MainGridLayout);
            app.Footer.FooterGridLayout.Layout.Row = 2;
            app.Footer.FooterGridLayout.Layout.Column = 1;
            app.Footer.FooterGridLayout.ColumnWidth = {120, '1x', 120, 100};
            app.Footer.FooterGridLayout.RowHeight = {'1x'};
            app.Footer.FooterGridLayout.Padding = [10 10 10 10];
            
            app.Footer.PreviousTabButton = uibutton(app.Footer.FooterGridLayout, 'push', 'Text', 'Previous Tab', 'ButtonPushedFcn', createCallbackFcn(app, @PreviousTabButtonPushed, true));
            app.Footer.PreviousTabButton.Layout.Row = 1;
            app.Footer.PreviousTabButton.Layout.Column = 1;

            app.Footer.NextTabButton = uibutton(app.Footer.FooterGridLayout, 'push', 'Text', 'Next Tab', 'ButtonPushedFcn', createCallbackFcn(app, @NextTabButtonPushed, true));
            app.Footer.NextTabButton.Layout.Row = 1;
            app.Footer.NextTabButton.Layout.Column = 3;
            
            app.Footer.LogoImage = uiimage(app.Footer.FooterGridLayout);
            app.Footer.LogoImage.Layout.Row = 1;
            app.Footer.LogoImage.Layout.Column = 4;

            app.TSCFigure.Visible = 'on';
        end

        function TabGroupSelectionChanged(app, event)
            app.onTabChanged();
        end

        function PreviousTabButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find(app.TabGroup.Children == currentTab, 1);
            if tabIdx > 1
                missingRequiredField = app.checkRequiredFields(currentTab);
                if ~isempty(missingRequiredField)
                    app.alertRequiredFieldsMissing(missingRequiredField);
                    return;
                end
                app.changeTab(app.TabGroup.Children(tabIdx - 1)); 
            end
        end

        function NextTabButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find(app.TabGroup.Children == currentTab, 1);
            if tabIdx < numel(app.TabGroup.Children)
                missingRequiredField = app.checkRequiredFields(currentTab);
                if ~isempty(missingRequiredField)
                    app.alertRequiredFieldsMissing(missingRequiredField);
                    return;
                end
                app.changeTab(app.TabGroup.Children(tabIdx + 1));
            end
        end

        % --- UPDATED METHOD ---
        function checkAndEnforceMinSize(app)
            % This function is called periodically by the timer.
            
            if ~isvalid(app.TSCFigure)
                return;
            end
            
            originalPos = app.TSCFigure.Position;
            newPos = originalPos;
            needsResize = false;
            
            % Check and adjust width
            if newPos(3) < app.FigureMinWidth
                newPos(3) = app.FigureMinWidth;
                needsResize = true;
            end
            
            % Check and adjust height, keeping top edge fixed
            if newPos(4) < app.FigureMinHeight
                originalTop = originalPos(2) + originalPos(4);
                newPos(4) = app.FigureMinHeight; % Set new height
                newPos(2) = originalTop - newPos(4); % Adjust bottom to keep top fixed
                needsResize = true;
            end
            
            if needsResize
                app.TSCFigure.Position = newPos;
            end
        end
        % ---
    end
end