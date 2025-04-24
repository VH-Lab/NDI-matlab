classdef FolderOrganizationPage < ndi.gui.window.wizard.abstract.Page

% Todo:
%   Pass button through the subfolder preview functions?

    properties (Constant)
        Name = "Subfolders"
        Title = "Folder Organization"
        Description = "Specify how subfolders are organized"
    end

    properties % UI Data % TODO: move to model?
        RootDirectory
        PresetFolderModels (1,1) dictionary
    end
 
    properties % Model - View - Controller (MVC pattern)
        DataModel (1,1) ndi.dataset.gui.models.FolderOrganizationModel
        View (1,1) ndi.dataset.gui.folderorganization.FolderOrganizationTableView
        Controller (1,1) ndi.dataset.gui.folderorganization.FolderOrganizationTableController
    end

    properties (Access = private) % Custom UI Components
        UITable %ndi.dataset.gui.pages.component.FolderOrganizationTable
        UIToolbar ndi.dataset.gui.pages.component.FolderOrganizationToolbar % move to controller...
        TableGridLayout
    end

    properties (Access = private) % Generic UI Components
        ContextMenu
        SaveMenu
        LoadMenu
    end

    properties (Access = private)
        FolderListViewer
        FolderListViewerActive = false
        FolderOrganizationFilterListener
    end

    methods
        function obj = FolderOrganizationPage( )
            obj.DoCreatePanel = true;
        end
    end

    methods
        function set.DataModel(obj, dataModel)
            obj.DataModel = dataModel;
            if obj.IsInitialized
                % Todo: update differently....
                obj.View.update() %#ok<MCSUP>
            end
        end

        function set.RootDirectory(obj, rootDirectory)
            obj.RootDirectory = rootDirectory;
            if obj.IsInitialized
                % Todo(?) Update data model root directory
            end
        end

        function set.PresetFolderModels(obj, value)
            obj.PresetFolderModels = value;
            obj.postSetPresetFolderModels()
        end
    end

    methods (Access = private)
        function postSetPresetFolderModels(obj)
            if ~isempty( obj.UIToolbar ) 
                obj.UIToolbar.PresetFolderModels = keys(obj.PresetFolderModels);
            end
        end
    end

    methods (Access = protected)

        function onVisiblePropertyValueSet(obj)
            onVisiblePropertyValueSet@ndi.gui.window.wizard.abstract.Page(obj)

            if ~isempty(obj.UIToolbar)
                obj.UIToolbar.Visible = obj.Visible;
            end
        end

        function onPageEntered(obj)
            % No action needed
        end

        function onPageExited(obj)
            % Todo: Close folder viewer if it is open.
        end

        function createComponents(obj)
        % createComponents - Create components for page.   

            defaultTableData = obj.DataModel.getDefaultFolderLevelTable();

            obj.TableGridLayout = uigridlayout(obj.UIPanel);
            obj.TableGridLayout.ColumnWidth={'1x'};
            obj.TableGridLayout.RowHeight={'1x'};
            obj.TableGridLayout.Padding = [20,0,20,0];
            obj.TableGridLayout.BackgroundColor = 'w';

            parent = obj.TableGridLayout;
            %parent = obj.UIPanel;

            obj.UITable = WidgetTable(parent, 'ItemName', 'Folder Level');
            obj.UITable.HeaderBackgroundColor = "#FFFFFF";
            obj.UITable.HeaderForegroundColor = "#002054";
            obj.UITable.BackgroundColor = 'w';
            obj.UITable.ColumnNames = defaultTableData.Properties.CustomProperties.VariableTitle;
            obj.UITable.ColumnWidth = {185, 175, 150, 150};
            %obj.UITable.ColumnWidget = {'', '', '', customColumnFcn};
            obj.UITable.TableBorderType = 'none';
            obj.UITable.MinimumColumnWidth = 120;
            obj.UITable.ColumnHeaderHelpFcn = @ndi.dataset.gui.getTooltipMessage;
            
            obj.UITable.setDefaultRowData(defaultTableData)
            
            obj.View = ndi.dataset.gui.folderorganization.FolderOrganizationTableView(obj.DataModel, obj.UITable);
            obj.Controller = ndi.dataset.gui.folderorganization.FolderOrganizationTableController(obj.DataModel, obj.UITable);
            obj.View.update()

            obj.UIToolbar = ndi.dataset.gui.pages.component.FolderOrganizationToolbar(obj.ParentApp.BodyGridLayout);
            obj.UIToolbar.Layout.Row = 2;
            obj.UIToolbar.Layout.Column = 1;
            obj.UIToolbar.Theme = obj.ParentApp.Theme;
            
            % Set callback functions
            obj.UIToolbar.MenuButtonPushedFcn = @obj.onMenuButtonPushed;
            obj.UIToolbar.ShowFiltersButtonPushedFcn = @obj.onShowFiltersButtonPushed;
            obj.UIToolbar.PreviewButtonPushedFcn = @obj.onFolderPreviewButtonClicked;
            obj.UIToolbar.SelectTemplateDropDownValueChangedFcn = @obj.onPresetTemplateSelected;

            % Todo: (allow saving a model as a template?)
            % Note: This could be a menu on a button next to the template
            % dropdown
            obj.ContextMenu = uicontextmenu(obj.ParentApp.UIFigure);

            obj.SaveMenu = uimenu(obj.ContextMenu);
            obj.SaveMenu.Text = 'Save to template file';

            obj.LoadMenu = uimenu(obj.ContextMenu);
            obj.LoadMenu.Text = 'Load from template file';

            % Do this last.
            obj.loadPresetFolderModels()
        end

        function onMenuButtonPushed(obj, event)
            pos = getpixelposition(event.Source, true);
            obj.ContextMenu.open(pos(1)+12, pos(2)-5)
        end
        
        function onShowFiltersButtonPushed(obj, event)
            if event.Value
                obj.View.showAdvancedOptions();
                %obj.UITable.showAdvancedOptions()
            else
                obj.View.hideAdvancedOptions();
                %obj.UITable.hideAdvancedOptions()
            end
        end
        
        function onFolderPreviewButtonClicked(obj, event)
        %onFolderPreviewButtonClicked Button callback
        %
        %   This callback toggles visibility a figure that displays all the
        %   folders that are detected using current configuration
        
            if ~isempty(obj.FolderListViewer) && isvalid(obj.FolderListViewer)
                if strcmp(obj.FolderListViewer.Visible, 'on')
                    obj.FolderListViewerActive = false;
                    obj.hideFolderListViewer()
                    event.Source.FontWeight = 'normal';
                elseif strcmp(obj.FolderListViewer.Visible, 'off')
                    obj.FolderListViewerActive = true;
                    obj.showFolderListViewer()
                    event.Source.FontWeight = 'bold';
                end
            else
                obj.FolderListViewerActive = true;
                obj.showFolderListViewer()
                event.Source.FontWeight = 'bold';
            end
        end

        function onPresetTemplateSelected(obj, event)
            filePath = obj.PresetFolderModels( event.Value );
            templateFolderModel = ndi.dataset.gui.models.FolderOrganizationModel.fromJson(filePath);
            
            oldFolderLevels = obj.DataModel.FolderLevels;
            newFolderLevels = templateFolderModel.FolderLevels;
           
            % Update names based on current selections
            for i = 1:numel(newFolderLevels)
                if i <= numel(oldFolderLevels)
                    newFolderLevels(i).Name = oldFolderLevels(i).Name;
                end
            end

            obj.DataModel.FolderLevels = newFolderLevels;

            obj.View.update()
        end
    end

    % % % % Methods for the folder listing figure and table
    methods (Access = private) 

        function createFolderListViewer(obj)

            obj.FolderListViewer = nansen.config.dloc.FolderPathViewer(obj.ParentApp.UIFigure);
            obj.FolderListViewer.Theme = obj.ParentApp.Theme;
            
            addlistener(obj.FolderListViewer, 'ObjectBeingDestroyed', ...
                @(s, e) obj.onFolderListViewerDeleted);
            
            obj.FolderOrganizationFilterListener = listener(obj.DataModel, ...
                'FolderModelChanged', @(s,e) obj.updateFolderList);
            
            % Give focus to the app figure
            figure(obj.ParentApp.UIFigure)
        end
    
        function showFolderListViewer(obj)
                        
            [screenSize, ~] = ndi.gui.utility.getCurrentScreenSize(obj.ParentApp.UIFigure);
            obj.ParentApp.UIFigure.Position(1) = screenSize(1) + 10;

            if isempty(obj.FolderListViewer) || ~isvalid(obj.FolderListViewer)
                obj.createFolderListViewer()
                obj.updateFolderList()
            end
            
            %obj.PreviewButton.ImageSource = nansen.internal.getIconPathName('look3.png');
            obj.FolderListViewer.Visible = 'on';
            pause(0.01)
            
            if ~isempty(obj.ParentApp.UIFigure)
                figure(obj.ParentApp.UIFigure)
            end
        end
                
        function hideFolderListViewer(obj)
            
            if ~isempty(obj.FolderListViewer) && isvalid(obj.FolderListViewer)
                %obj.PreviewButton.ImageSource = nansen.internal.getIconPathName('look2.png');
                obj.FolderListViewer.Visible = 'off';

                if ~isempty(obj.ParentApp.UIFigure)
                    ndi.gui.utility.centerFigureOnScreen(obj.ParentApp.UIFigure)
                end
            end
        end
        
        function onFolderListViewerDeleted(obj)
            if ~isvalid(obj); return; end
            
            obj.FolderListViewerActive = false;
            %obj.PreviewButton.ImageSource = nansen.internal.getIconPathName('look2.png');
            obj.FolderListViewer = [];
        end

        function updateFolderList(obj)
        
            if isempty(obj.FolderListViewer) || ~isvalid(obj.FolderListViewer)
                return
            end

            folderPath = obj.DataModel.listAllFolders();

            if isempty(folderPath); folderPath = {''}; end
            
            % Remove the root path from the displayed paths.
            folderPath = strrep(folderPath, obj.RootDirectory, sprintf('<Dataset>'));
            
            % Update table data in folderlist viewer
            obj.FolderListViewer.Data = folderPath';
        end

        function loadPresetFolderModels(obj)
            rootDirectory = fileparts( fileparts (mfilename('fullpath') ) );
            L = dir( fullfile(rootDirectory, 'resources', 'preset', '*.json') );

            for i = 1:numel(L)
                [~, name] = fileparts(L(i).name);
                obj.PresetFolderModels(name) = fullfile(L(i).folder, L(i).name);
            end
        end
    end
end