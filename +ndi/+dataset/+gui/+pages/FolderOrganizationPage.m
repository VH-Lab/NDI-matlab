classdef FolderOrganizationPage < ndi.gui.window.wizard.abstract.Page

% Todo:
%   Pass button through the subfolder preview functions?

    properties (Constant)
        Name = "Subfolders"
        Title = "Folder Organization"
        Description = "Specify how subfolders are organized"
    end

    properties % UI Data 
        RootDirectory
        DataModel
        PresetFolderModels (1,:) string
    end

    properties (Access = private) % Custom UI Components
        UITable ndi.dataset.gui.pages.component.FolderOrganizationTable
        UIToolbar ndi.dataset.gui.pages.component.FolderOrganizationToolbar
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
                obj.UITable.SubfolderStructure = dataModel.FolderLevels; %#ok<MCSUP>
            end
        end

        function set.RootDirectory(obj, rootDirectory)
            obj.RootDirectory = rootDirectory;
            if obj.IsInitialized
                obj.UITable.RootDirectory = rootDirectory; %#ok<MCSUP>
            end
        end

        function set.PresetFolderModels(obj, value)
            obj.PresetFolderModels = value;
            if obj.IsInitialized
                obj.UIToolbar.PresetFolderModels = value; %#ok<MCSUP>
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
            % Subclasses may override
        end

        function onPageExited(obj)
            % Update model data based on UITable data.
            if obj.IsInitialized
                S = obj.UITable.getSubfolderStructure();
                if ~isempty(obj.DataModel)
                    obj.DataModel.updateFolderLevelFromStruct(S)
                end
            end
        end

        function createComponents(obj)
        % createComponents - Create components for page.   

            args = { 'Parent', obj.UIPanel };
            
            obj.UITable = ndi.dataset.gui.pages.component.FolderOrganizationTable(obj.DataModel, args{:});
            obj.UITable.hideAdvancedOptions()
            if ~isempty(obj.RootDirectory)
                obj.UITable.RootDirectory = obj.RootDirectory;
            end

            obj.UIToolbar = ndi.dataset.gui.pages.component.FolderOrganizationToolbar(obj.ParentApp.BodyGridLayout);
            obj.UIToolbar.Layout.Row = 2;
            obj.UIToolbar.Layout.Column = 1;
            obj.UIToolbar.Theme = obj.ParentApp.Theme;
            
            % Set callback functions
            obj.UIToolbar.MenuButtonPushedFcn = @obj.onMenuButtonPushed;
            obj.UIToolbar.ShowFiltersButtonPushedFcn = @obj.onShowFiltersButtonPushed;
            obj.UIToolbar.PreviewButtonPushedFcn = @obj.onFolderPreviewButtonClicked;
            obj.UIToolbar.SelectTemplateDropDownValueChangedFcn = @obj.onPresetTemplateSelected;

            % Todo:
            obj.ContextMenu = uicontextmenu(obj.ParentApp.UIFigure);

            obj.SaveMenu = uimenu(obj.ContextMenu);
            %obj.SaveMenu.MenuSelectedFcn = createCallbackFcn(obj, @DiseaseMenuSelected, true);
            obj.SaveMenu.Text = 'Save to template file';

            obj.LoadMenu = uimenu(obj.ContextMenu);
            %obj.LoadMenu.MenuSelectedFcn = createCallbackFcn(obj, @DiseaseMenuSelected, true);
            obj.LoadMenu.Text = 'Load from template file';
        end

        function onMenuButtonPushed(obj, event)
            pos = getpixelposition(event.Source, true);
            obj.ContextMenu.open(pos(1)+12, pos(2)-5)
        end
        
        function onShowFiltersButtonPushed(obj, event)
            if event.Value
                obj.UITable.showAdvancedOptions()
            else
                obj.UITable.hideAdvancedOptions()
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
            filePath = obj.ParentApp.PresetFolderModels( event.Value );
            folderModel = ndi.dataset.gui.models.FolderOrganizationModel.fromJson(filePath);
            obj.UITable.SubfolderStructure = folderModel.FolderLevels;
        end
    end

    % % % % Methods for the folder listing figure and table
    methods (Access = private) 

        function createFolderListViewer(obj)

            obj.FolderListViewer = nansen.config.dloc.FolderPathViewer(obj.ParentApp.UIFigure);
            obj.FolderListViewer.Theme = obj.ParentApp.Theme;
            
            addlistener(obj.FolderListViewer, 'ObjectBeingDestroyed', ...
                @(s, e) obj.onFolderListViewerDeleted);
            
            obj.FolderOrganizationFilterListener = listener(obj.UITable, ...
                'FilterChanged', @(s,e) obj.updateFolderList);
            
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
            
            % Make sure data location model is updated with current values
            S = obj.UITable.getSubfolderStructure();
            folderPath = cellstr(obj.RootDirectory);

            for i = 1:numel(S)
                [folderPath, ~] = utility.path.listSubDir(...
                    folderPath, S(i).Expression, S(i).IgnoreList);
            end

            if isempty(folderPath); folderPath = {''}; end
            
            % Remove the root path from the displayed paths.
            folderPath = strrep(folderPath, obj.RootDirectory, sprintf('<Dataset>'));
            
            % Update table data in folderlist viewer
            obj.FolderListViewer.Data = folderPath';
        end
    end  
end