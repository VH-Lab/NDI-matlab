classdef DAQSystemConfigurator < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        MainGridLayout                matlab.ui.container.GridLayout
        FooterGridLayout              matlab.ui.container.GridLayout
        ExportDaqSystemButton         matlab.ui.control.Button
        ImportDAQSystemButton         matlab.ui.control.Button
        TabGroup                      matlab.ui.container.TabGroup
        CreateDAQSystemTab            matlab.ui.container.Tab
        DaqSystemPageLayout           matlab.ui.container.GridLayout
        DAQSystemNameLabel            matlab.ui.control.Label
        DaqSystemNameEditField        matlab.ui.control.EditField
        HelpButton_DS                 matlab.ui.control.Button
        HelpButton_DR                 matlab.ui.control.Button
        HelpButton_MDR                matlab.ui.control.Button
        HelpButton_PM                 matlab.ui.control.Button
        CreateNewButton_DS            matlab.ui.control.Button
        CreateNewButton_DR            matlab.ui.control.Button
        CreateNewButton_MDR           matlab.ui.control.Button
        CreateNewButton_PM            matlab.ui.control.Button
        LoadProbesFromFileSwitch      matlab.ui.control.Switch
        LoadProbesFromFileLabel       matlab.ui.control.Label
        SelectDAQEpochProbemapClassDropDown  matlab.ui.control.DropDown
        SelectDAQEpochProbemapClassDropDownLabel  matlab.ui.control.Label
        SelectDAQMetadataReaderDropDown  matlab.ui.control.DropDown
        SelectDAQMetadataReaderDropDownLabel  matlab.ui.control.Label
        SelectDAQReaderDropDown       matlab.ui.control.DropDown
        SelectDAQReaderDropDownLabel  matlab.ui.control.Label
        DAQSystemBaseDropDown         matlab.ui.control.DropDown
        LogoImage                     matlab.ui.control.Image
        DAQSystemBaseDropDownLabel    matlab.ui.control.Label
        LinkFilesTab                  matlab.ui.container.Tab
        LinkedFilePageGridLayout      matlab.ui.container.GridLayout
        SelectReaderTypeforLinkingFilesLabel  matlab.ui.control.Label
        FileSelectionGridLayout       matlab.ui.container.GridLayout
        FileTree                      matlab.ui.container.CheckBoxTree
        FileTreeFilterEditField       matlab.ui.control.EditField
        DAQReaderButton               matlab.ui.control.StateButton
        MetadataReaderButton          matlab.ui.control.StateButton
        EpochProbeMapButton           matlab.ui.control.StateButton
        RegularExpressionEditField    matlab.ui.control.EditField
        RegularExpressionSwitch       matlab.ui.control.Switch
        UseRegularExpressionforSelectedFileLabel  matlab.ui.control.Label
        ProbesTab                     matlab.ui.container.Tab
        ProbePageGridLayout           matlab.ui.container.GridLayout
        ProbeTableToolbarGridLayout   matlab.ui.container.GridLayout
        CustomizeprobesperepochCheckBox  matlab.ui.control.CheckBox
        SelectEpochDropDown           matlab.ui.control.DropDown
        SelectEpochDropDownLabel      matlab.ui.control.Label
        ProbeTablePanel               matlab.ui.container.Panel
        ProbeTableGridLayout          matlab.ui.container.GridLayout
        HiddenTabGroupLabel           matlab.ui.control.Label
        HiddenTabGroup                matlab.ui.container.TabGroup
        Tab                           matlab.ui.container.Tab
        HiddenTreeLabel               matlab.ui.control.Label
        HiddenTree                    matlab.ui.container.CheckBoxTree
    end

    % Todo / Tests:
    % [ ] Import / export
    % [ ] Update each individual field 

    properties (SetAccess = private)
        % DaqSystemConfiguration - DAQ System Configuration object.
        %   This object will be updated based on user input in this app and
        %   can be exported to file.
        DaqSystemConfiguration ndi.setup.DaqSystemConfiguration
             
        % FinishState - State of app pending user input. 
        FinishState = "Incomplete"
    end

    properties (Access = private) % Private data properties
        % RootDirectory - Root directory of a dataset
        RootDirectory (1,1) string = missing
                
        % EpochFolder - Pathname of an epoch folder
        EpochFolder (1,1) string = missing
        
        % EpochOrganization - Describes how epochs are organized in folders. 
        %   Value is "flat" if files from different epochs exist in the same
        %   folder and "nested" if files from different epohchs exists in
        %   individual subfolders
        EpochOrganization (1,1) string ...
            {mustBeMember(EpochOrganization, ["flat", "nested"])} = "flat"

        % FileParameters - A list of file parameters for a DAQ system. 
        %   Representetd by a FileParameterSpecification object.
        FileParameters (1,:) ndi.file.internal.FileParameterSpecification

        % CurrentFileParameterSelectionIndex - Index of currently selected file.
        CurrentFileParameterSelectionIndex = []
    end

    properties (Access = private) % Custom UI Components
        % UIForm - A struct for storing handles of form / dialog windows
        %   that can be opened from this app 
        UIForm (1,1) struct = struct

        % ProbeTable - UITable for probes. Users can interactively add and
        % remove probes as well as modifying existing probes
        ProbeTable
    end

    properties (Dependent, Access = private)
        % CheckedNodes - Private store for checked nodes of the FileTree
        CheckedNodes
        % CheckedNodes - Private store for selected nodes of the FileTree
        SelectedNodes
    end

    properties (Access = private)
        % Todo: Define/describe this...
        Theme = ndi.ui.dataset.WizardTheme %ndi.graphics.theme.NDITheme

        % WaitFor - Boolean flag indicating if MATLAB execution is blocked
        % by this app.
        WaitFor (1,1) logical = false
    end

    methods % Public methods
        function uiwait(app)
        % uiwait - Blocks program execution until users clicks "Save Changes"
            
            % Change appearance of import button to. Button is renamed to 
            % "Save Changes" and program execution is block until button is
            % pushed.
            app.ImportDAQSystemButton.Text = "Save Changes";
            pathToMLAPP = fileparts(mfilename('fullpath'));            
            app.ImportDAQSystemButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'save.png');
            app.ImportDAQSystemButton.ButtonPushedFcn = createCallbackFcn(app, @SaveChangesButtonPushed, true);
            
            app.FinishState = "Incomplete";
            app.WaitFor = true;
            uiwait(app.UIFigure) %#ok<ADMTHDINV>
        end
    end
    
    % Property set methods
    methods 
        function set.DaqSystemConfiguration(app, value)
            app.DaqSystemConfiguration = value;
            app.postSetDaqSystemConfiguration()
        end

        function value = get.CheckedNodes(app)
            value = [app.FileTree.CheckedNodes; app.HiddenTree.CheckedNodes];
        end
    end

    % Property post set methods
    methods (Access = private)
        function postSetDaqSystemConfiguration(app)
            
            app.DaqSystemNameEditField.Value = app.DaqSystemConfiguration.Name;

            daqReaderSplit = strsplit(app.DaqSystemConfiguration.DaqReaderClass, '.');
            app.SelectDAQReaderDropDown.Value = daqReaderSplit{end};

            if ~isempty( app.DaqSystemConfiguration.MetadataReaderClass )
                mdReaderSplit = strsplit(app.DaqSystemConfiguration.MetadataReaderClass, '.');
                app.SelectDAQMetadataReaderDropDown.Value = mdReaderSplit{end};
            else
                app.SelectDAQMetadataReaderDropDown.Value = app.SelectDAQMetadataReaderDropDown.Items{1};
            end
        end
    end

    methods (Access = private)
        function probeData = initializeProbeData(app)
            % Todo: Initialize probe data based on dataset...
            probeData = struct(...
                'Name', "ctx", ...
                'Reference', uint8(1), ...
        	    'Type', "n-trode", ...
            	'DeviceString', "ced_daqsystem:ai11", ...
                'Subject', categorical("treeshrew_12345@mylab.org") );

            % List supported probe types in NDI:
            ndi.globals
            probe_type_file = fullfile(ndi_globals.path.commonpath, 'probe', 'probetype2object.json');
            probeTable = jsondecode(fileread(probe_type_file));
            probeTypes = string( {probeTable.type} );

            % Create a categorical value
            probeData.Type = categorical({'n-trode'}, probeTypes);

            % Convert to table.
            probeData = struct2table(probeData, "AsArray", true);
        end
    end

    % Methods for populating and updating uicontrols
    methods (Access = private)
        function initializeProbeTable(app)
        % initializeProbeTable - Initialize the probe table component   
            probeData = app.initializeProbeData();

            %app.ProbeTable = ndi.gui.control.WidgetTable(app.ProbeTableGridLayout);
            % Create the WidgetTable component.
            app.ProbeTable = WidgetTable(app.ProbeTableGridLayout);
            app.ProbeTable.ShowColumnHeaderHelp = 'off';
            app.ProbeTable.ColumnWidth = {100, 90, 80, '1x', 150};
            app.ProbeTable.Data = probeData;
            drawnow
            app.ProbeTable.HeaderBackgroundColor = "#002054";
            app.ProbeTable.HeaderForegroundColor = '#FDF7FA';
            app.ProbeTable.HeaderTextColor = '#FDF7FA';
            app.ProbeTable.BackgroundColor = "white";
            app.ProbeTable.MinimumColumnWidth = 120;
            %app.ProbeTable.redraw()
            %app.ProbeTable.TableBorderType = 'none';
        end
        
        function populateDaqSystemClassOptions(app)
            names = ndi.setup.daq.listDaqSystemClasses();
            app.DAQSystemBaseDropDown.Items = names;
            app.DAQSystemBaseDropDown.Value = names{1};
        end

        function populateDaqReaderOptions(app)
            names = ndi.setup.daq.listDaqReaders();
            names = [{'<No Selection>', '<Select File...>'}, names];
            app.SelectDAQReaderDropDown.Items = names;
            app.SelectDAQReaderDropDown.Value = names{1};
        end

        function populateDaqMetadataReaderOptions(app)
            names = ndi.setup.daq.listDaqMetadataReaders();
            names = [{'<No Selection>', '<Select File...>'}, names];
            app.SelectDAQMetadataReaderDropDown.Items = names;
            app.SelectDAQMetadataReaderDropDown.Value = names{1};
        end

        function populateEpochProbeMapClass(app)
            names = ndi.setup.daq.listDaqEpochProbemapClass();
            names = [{'<No Selection>', '<Select File...>'}, names];
            app.SelectDAQEpochProbemapClassDropDown.Items = names;
            app.SelectDAQEpochProbemapClassDropDown.Value = names{1};
        end

        function populateFileViewer(app, treeList)
        % populateFileViewer - Add a file hierarchy to the file viewer (uitree)
            delete(app.FileTree.Children)
            app.addFileTreeNode(treeList, app.FileTree, true)
            app.FileTree.ContextMenu = [];
        end

        function addFileTreeNode(app, treeList, hParentNode, isRoot)
        % addFileTreeNode - Recursively adds nodes to the FileTree.
        %
        %   treeList is a struct representing a nested list of files and
        %   folders as returned by the treeDir function.
            for i = 1:numel(treeList)
                if ~isRoot
                    hChildNode = uitreenode(hParentNode);
                    hChildNode.Text = treeList.FolderName;
                else
                    hChildNode = hParentNode;
                end

                if ~isempty(treeList(i).Subfolders)
                    for j = 1:numel(treeList(i).Subfolders)
                        app.addFileTreeNode(treeList(i).Subfolders(j), hChildNode, false)
                    end
                end

                if ~isempty(treeList(i).Files)
                    for j = 1:numel(treeList(i).Files)
                        hFileNode = uitreenode(hChildNode);
                        hFileNode.Text = treeList(i).Files(j).name;
                    end
                end
            end
        end
        
        function onDatasetDirectoryChanged(app, rootPath)
        % onDatasetDirectoryChanged - Handles changes to the dataset root folder
            if nargin < 2
                rootPath = fullfile(app.RootDirectory, app.EpochFolder);
            end

            if isfolder(rootPath)
                S = treeDir(rootPath);
                app.populateFileViewer(S)
            else
                uialert(app.UIFigure, 'The provided folderpath is not valid')
            end
        end

        function dataClass = getCurrentDataClassSelection(app)
            if app.DAQReaderButton.Value
                dataClass = "DAQ Reader";
            elseif app.MetadataReaderButton.Value
                dataClass = "Metadata Reader";
            elseif app.EpochProbeMapButton.Value
                dataClass = "Epoch Probe Map";
            else
                error('This should not happen')
            end
        end

        function updateCheckedNodes(app)
            % Determine which nodes to check in the FileTree based on which 
            % nodes are currently visible (i.e unfiltered) and which dataclass 
            % is currently selected.
            % This method is typically called when the filter is updated or
            % the data class selection changes.
            
            dataClass = app.getCurrentDataClassSelection();
            
            % Get visible nodes:
            nodes = app.FileTree.Children;
            if ~isempty(nodes)
                visibleFileNames = {nodes.Text};
            else
                return
            end

            checkedItems = [app.FileParameters.ClassType] == dataClass;

            namesToCheck = string( [ app.FileParameters(checkedItems).OriginalFilename ] );

            [~, iA] = intersect(visibleFileNames, namesToCheck, 'stable');
            if isempty(iA)
                app.FileTree.CheckedNodes = [];
            else
                app.FileTree.CheckedNodes = nodes(iA);
            end
        end
    
        function disableFileParameterComponents(app)
            app.RegularExpressionEditField.Enable = "off";
            app.RegularExpressionSwitch.Enable = "off";
        end

        function enableFileParameterComponents(app)
            app.RegularExpressionEditField.Enable = "on";
            app.RegularExpressionSwitch.Enable = "on";
        end

        function updateFileParameterComponents(app, fileParameter)
            app.enableFileParameterComponents()
            
            if fileParameter.UseRegularExpression
                app.RegularExpressionSwitch.Value = 'On';
            else
                app.RegularExpressionSwitch.Value = 'Off';
            end
            app.RegularExpressionSwitchValueChanged([])

            if ~ismissing( fileParameter.RegularExpression )
                app.RegularExpressionEditField.Value = fileParameter.RegularExpression;
            else
                app.RegularExpressionEditField.Value = "";
            end
        end

        function resetFileParameterComponents(app)
            app.disableFileParameterComponents()
            app.RegularExpressionSwitch.Value = "Off";
            app.RegularExpressionSwitchValueChanged([])
            app.RegularExpressionEditField.Value = "";
        end
    end

    methods (Access = private)
        function applyTheme(app)
            for i = 1:numel(app.TabGroup.Children)
                %app.TabGroup.Children(i).BackgroundColor = app.Theme.FigureBgColor;
            end
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, rootDirectory, epochFolder, epochOrganization, daqSystemConfiguration)
            arguments
                app (1,1) DAQSystemConfigurator
                rootDirectory (1,1) string = missing
                epochFolder (1,1) string = missing
                epochOrganization (1,1) string ...
                    {mustBeMember(epochOrganization, ["flat", "nested"])} = "flat"
                daqSystemConfiguration (1,1) ndi.setup.DaqSystemConfiguration = ndi.setup.DaqSystemConfiguration;
            end

            app.RootDirectory = rootDirectory;
            app.EpochFolder = epochFolder;
            app.EpochOrganization = epochOrganization;

            app.populateDaqSystemClassOptions()
            app.populateDaqReaderOptions()
            app.populateDaqMetadataReaderOptions()
            app.populateEpochProbeMapClass()
            
            app.DaqSystemConfiguration = daqSystemConfiguration;

            % Hide the probe tab by default
            app.ProbesTab.Parent = app.HiddenTabGroup;
            
            app.applyTheme()
            
            if ~ismissing(app.RootDirectory) && isfolder(app.RootDirectory)
                app.onDatasetDirectoryChanged()
            end

            app.disableFileParameterComponents()
            
            app.initializeProbeTable()
        end

        % Selection changed function: FileTree
        function FileTreeSelectionChanged(app, event)
            % Check if the selected node is also checked, and update file
            % parameter components accordingly.
            % If selected node is checked, update file parameter components
            % based on the file parameters for the selected file
            % If selected node is not checked, reset and disable the file
            % parameter components.

            selectedNodes = app.FileTree.SelectedNodes;
            checkedNodes = app.FileTree.CheckedNodes;

            if isempty(selectedNodes)
                selectedNodeNames = string.empty;
            else
                selectedNodeNames = string( {selectedNodes.Text} );
            end

            if isempty(checkedNodes)
                checkedNodeNames = string.empty;
            else
                checkedNodeNames = string( {checkedNodes.Text} );
            end

            if ~any(strcmp(checkedNodeNames, selectedNodeNames))
                fileParameterIndex = false;
            else
                fileParameterIndex = strcmp( [app.FileParameters.OriginalFilename], selectedNodeNames );
            end

            app.CurrentFileParameterSelectionIndex = find(fileParameterIndex);

            if any(fileParameterIndex)
                fileParameter = app.FileParameters(fileParameterIndex);
                app.updateFileParameterComponents(fileParameter)
                app.enableFileParameterComponents()
            else
                app.resetFileParameterComponents()
                app.disableFileParameterComponents()
            end
        end

        % Callback function: FileTree
        function FileTreeCheckedNodesChanged(app, event)
        % Find out if any checked nodes have been added or removed and
        % update the FileParameters property accordingly.

            checkedNodes = event.CheckedNodes;
            previousCheckedNodes = event.PreviousCheckedNodes;

            if isempty(checkedNodes)
                currentNames = string.empty;
            else
                currentNames = string( {checkedNodes.Text} );
            end

            if isempty(previousCheckedNodes)
                previousNames = string.empty;
            else
                previousNames = string( {previousCheckedNodes.Text} );
            end

            [addedNames, ~] = setdiff( currentNames, previousNames );
            [removedNames, iRemoved]  = setdiff( previousNames, currentNames );

            nodeIsAdded = ~isempty(addedNames);
            nodeIsRemoved = ~isempty(removedNames);

            allSelectedNames = string( [app.FileParameters.OriginalFilename] );

            if nodeIsAdded
                % Check if node is already added to another file reader...
                if any(strcmp(allSelectedNames, addedNames))
                    idx = strcmp(allSelectedNames, addedNames);
                    uialert(app.UIFigure, '"%s" is already added for %s', addedNames, app.FileParameters(idx).ClassType)
                    return
                
                else % Add a new file parameter
                    app.FileParameters(end+1) = ndi.file.internal.FileParameterSpecification(...
                        "OriginalFilename", addedNames{1}, ...
                        "RegularExpression", addedNames{1}, ...
                        "ClassType", app.getCurrentDataClassSelection );
                    app.updateFileParameterComponents( app.FileParameters(end) );
                    app.FileTreeSelectionChanged()
                end
            end

            if nodeIsRemoved
                app.FileParameters(iRemoved) = [];
                if ~isequal(iRemoved, app.CurrentFileParameterSelectionIndex)
                    warning('Something unexpected happened.')
                    %keyboard % Debug
                end
                app.CurrentFileParameterSelectionIndex = [];
                app.resetFileParameterComponents( );
            end
        end

        % Value changed function: RegularExpressionSwitch
        function RegularExpressionSwitchValueChanged(app, event)
            value = app.RegularExpressionSwitch.Value;
            if value=="On"
                app.RegularExpressionEditField.Visible = 'on';
            else
                app.RegularExpressionEditField.Visible = 'off';
            end
                       
            if ~isempty(app.CurrentFileParameterSelectionIndex)
                app.FileParameters(app.CurrentFileParameterSelectionIndex).UseRegularExpression = value=="On";
            end
        end

        % Value changed function: DAQReaderButton
        function DAQReaderButtonValueChanged(app, event)
            value = app.DAQReaderButton.Value;
            if value
                app.MetadataReaderButton.Value = false;
                app.EpochProbeMapButton.Value = false;
            else
                if ~app.MetadataReaderButton.Value && ~ app.EpochProbeMapButton.Value
                     app.DAQReaderButton.Value = true;
                     return
                end
            end
            app.updateCheckedNodes()
            app.FileTreeSelectionChanged()
        end

        % Value changed function: MetadataReaderButton
        function MetadataReaderButtonValueChanged(app, event)
            value = app.MetadataReaderButton.Value;
            if value
                app.DAQReaderButton.Value = false;
                app.EpochProbeMapButton.Value = false;
            else
                if ~app.DAQReaderButton.Value && ~app.EpochProbeMapButton.Value
                     app.MetadataReaderButton.Value = true;
                     return
                end
            end
            app.updateCheckedNodes()
            app.FileTreeSelectionChanged()
        end

        % Value changed function: EpochProbeMapButton
        function EpochProbeMapButtonValueChanged(app, event)
            value = app.EpochProbeMapButton.Value;
            if value
                app.MetadataReaderButton.Value = false;
                app.DAQReaderButton.Value = false;
            else
                if ~app.MetadataReaderButton.Value && ~ app.DAQReaderButton.Value
                     app.EpochProbeMapButton.Value = true;
                     return
                end
            end
            app.updateCheckedNodes()
            app.FileTreeSelectionChanged()
        end

        % Value changed function: RegularExpressionEditField
        function RegularExpressionEditFieldValueChanged(app, event)
            value = app.RegularExpressionEditField.Value;
            if ~isempty(app.CurrentFileParameterSelectionIndex)
                app.FileParameters(app.CurrentFileParameterSelectionIndex).RegularExpression = value;
            end  
        end

        % Callback function
        function SelectSpecificHandlerDropDownValueChanged(app, event)
            % Todo: Update how this is writte to the FileParameters object list
            value = app.SelectSpecificHandlerDropDown.Value;
            if ~isempty(app.CurrentFileParameterSelectionIndex)
                app.FileParameters(app.CurrentFileParameterSelectionIndex).ClassName = value;
            end
        end

        % Callback function
        function AddProbeButtonPushed(app, event)
            probeData =  app.ProbeTable.getDefaultProbe();
            app.ProbeTable.addRow([], probeData)
        end

        % Value changing function: FileTreeFilterEditField
        function FileTreeFilterEditFieldValueChanging(app, event)
            changingValue = event.Value;

            nodes = [app.FileTree.Children; app.HiddenTree.Children];
            wasSelected = ~isempty(app.FileTree.SelectedNodes);

            allNames = {nodes.Text};

            % Sort nodes by name
            [allNames, idx] = sort(allNames);
            nodes = nodes(idx);
            
            % Determine which nodes to keep after filtering
            keep = contains(allNames, changingValue);

            nodesKeep = [nodes(keep)];
            nodesHide = [nodes(~keep)];

            set(nodesKeep, 'Parent', app.FileTree);
            set(nodesHide, 'Parent', app.HiddenTree);

            if wasSelected && isempty(app.FileTree.SelectedNodes)
                app.CurrentFileParameterSelectionIndex = [];
                app.resetFileParameterComponents();
                app.disableFileParameterComponents();
            end

            app.updateCheckedNodes()
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            if selectedTab == app.ProbesTab
                app.ProbeTable.redraw()
            end
        end

        % Value changed function: CustomizeprobesperepochCheckBox
        function CustomizeProbesPerEpochCheckBoxValueChanged(app, event)
            value = app.CustomizeprobesperepochCheckBox.Value;
            if value
                app.SelectEpochDropDown.Visible = "on";
                app.SelectEpochDropDownLabel.Visible = 'on';

            else
                app.SelectEpochDropDown.Visible = "off";
                app.SelectEpochDropDownLabel.Visible = 'off';
            end
        end

        % Button pushed function: HelpButton_DR, HelpButton_DS, 
        % ...and 2 other components
        function HelpButtonPushed(app, event)
            switch event.Source
                case app.HelpButton_DS
                    msg = 'Information about DAQ system';
                case app.HelpButton_DR
                    msg = 'Information about DAQ reader';                
                case app.HelpButton_MDR
                    msg = 'Information about DAQ metadata reader';                
                case app.HelpButton_PM
                    msg = 'Information about DAQ probe table reader';
            end
            uialert(app.UIFigure, msg, "Help", "Icon", "info")
        end

        % Button pushed function: ImportDAQSystemButton
        function ImportDAQSystemButtonPushed(app, event)
            % Open (external app) where user can select DAQ system
            if ~isfield(app.UIForm, 'SelectDaqSystemDialog')
                app.UIForm.SelectDaqSystemDialog = uiSelectDaqSystem(); % Create the form
            else
                app.UIForm.SelectDaqSystemDialog.Visible = 'on'; % Make the form visible
            end

            app.UIForm.SelectDaqSystemDialog.waitfor(); % Wait for user to proceed
            
            % Get user-inputs from form
            selectedConfigFile = app.UIForm.SelectDaqSystemDialog.getSelection();

            % Update data in table if user pressed save.
            mode = app.UIForm.SelectDaqSystemDialog.FinishState;
            if mode == "Save"
                app.DaqSystemConfiguration = ...
                    ndi.setup.DaqSystemConfiguration.fromConfigFile(selectedConfigFile);
            end

            app.UIForm.SelectDaqSystemDialog.reset()
            app.UIForm.SelectDaqSystemDialog.Visible = 'off'; % Hide the form (for later reuse)
        end

        % Button pushed function: ExportDaqSystemButton
        function ExportDaqSystemButtonPushed(app, event)
            [fileName, folderPath] = uiputfile('*.json','');
            if fileName == 0; return; end

            savePath = fullfile(folderPath, fileName);

            % Export DAQ System
            app.DaqSystemConfiguration.export(savePath)
        end

        % Value changed function: LoadProbesFromFileSwitch
        function LoadProbesFromFileSwitchValueChanged(app, event)
            value = app.LoadProbesFromFileSwitch.Value;

            app.SelectDAQEpochProbemapClassDropDown.Visible = value;
            app.SelectDAQEpochProbemapClassDropDownLabel.Visible = value;
            app.HelpButton_PM.Visible = value;
            app.CreateNewButton_PM.Visible = value;

            if strcmp(value, 'On')    
                app.ProbesTab.Parent = app.HiddenTabGroup;
            else
                app.ProbesTab.Parent = app.TabGroup;
                uistack(app.ProbesTab, 'bottom')
            end
        end

        % Button pushed function: CreateNewButton_DR
        function CreateNewButton_DRPushed(app, event)
            uiCreateDaqReader()
        end

        % Callback function
        function SaveChangesButtonPushed(app, event)
            uiresume(app.UIFigure)
            app.FinishState = "Complete";
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            if app.WaitFor
                app.FinishState = "Aborted";
                uiresume(app.UIFigure)
            else
                delete(app)
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 873 567];
            app.UIFigure.Name = 'Configure DAQ System';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create HiddenTree
            app.HiddenTree = uitree(app.UIFigure, 'checkbox');
            app.HiddenTree.Visible = 'off';
            app.HiddenTree.Position = [6 -148 231 109];

            % Create HiddenTreeLabel
            app.HiddenTreeLabel = uilabel(app.UIFigure);
            app.HiddenTreeLabel.Position = [6 -40 229 22];
            app.HiddenTreeLabel.Text = 'Hidden tree (for hiding filtered tree nodes)';

            % Create HiddenTabGroup
            app.HiddenTabGroup = uitabgroup(app.UIFigure);
            app.HiddenTabGroup.Visible = 'off';
            app.HiddenTabGroup.Position = [289 -148 263 109];

            % Create Tab
            app.Tab = uitab(app.HiddenTabGroup);

            % Create HiddenTabGroupLabel
            app.HiddenTabGroupLabel = uilabel(app.UIFigure);
            app.HiddenTabGroupLabel.Position = [289 -40 212 22];
            app.HiddenTabGroupLabel.Text = 'Hidden tabgroup (for hiding probe tab)';

            % Create MainGridLayout
            app.MainGridLayout = uigridlayout(app.UIFigure);
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.RowHeight = {'1x', 70};
            app.MainGridLayout.RowSpacing = 0;
            app.MainGridLayout.Padding = [0 0 0 0];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            % Create CreateDAQSystemTab
            app.CreateDAQSystemTab = uitab(app.TabGroup);
            app.CreateDAQSystemTab.Title = 'Create DAQ System';
            app.CreateDAQSystemTab.BackgroundColor = [0.9608 0.9608 0.9608];

            % Create DaqSystemPageLayout
            app.DaqSystemPageLayout = uigridlayout(app.CreateDAQSystemTab);
            app.DaqSystemPageLayout.ColumnWidth = {300, 100, 25, '1x', 150};
            app.DaqSystemPageLayout.RowHeight = {25, 25, 3, '0.5x', 25, 25, 3, '0.5x', 25, 25, 3, '0.5x', 25, 25, 10, '0.5x', 23, 25, 25, 3, '0.5x', 50};
            app.DaqSystemPageLayout.RowSpacing = 5;
            app.DaqSystemPageLayout.Padding = [35 35 35 35];
            app.DaqSystemPageLayout.BackgroundColor = [0.9804 0.9804 0.9804];

            % Create DAQSystemBaseDropDownLabel
            app.DAQSystemBaseDropDownLabel = uilabel(app.DaqSystemPageLayout);
            app.DAQSystemBaseDropDownLabel.VerticalAlignment = 'bottom';
            app.DAQSystemBaseDropDownLabel.Layout.Row = 5;
            app.DAQSystemBaseDropDownLabel.Layout.Column = 1;
            app.DAQSystemBaseDropDownLabel.Text = 'DAQ System Base';

            % Create LogoImage
            app.LogoImage = uiimage(app.DaqSystemPageLayout);
            app.LogoImage.Layout.Row = 1;
            app.LogoImage.Layout.Column = 5;
            app.LogoImage.ImageSource = fullfile(pathToMLAPP, 'resources', 'ndi_logo.png');

            % Create DAQSystemBaseDropDown
            app.DAQSystemBaseDropDown = uidropdown(app.DaqSystemPageLayout);
            app.DAQSystemBaseDropDown.Layout.Row = 6;
            app.DAQSystemBaseDropDown.Layout.Column = 1;

            % Create SelectDAQReaderDropDownLabel
            app.SelectDAQReaderDropDownLabel = uilabel(app.DaqSystemPageLayout);
            app.SelectDAQReaderDropDownLabel.VerticalAlignment = 'bottom';
            app.SelectDAQReaderDropDownLabel.Layout.Row = 9;
            app.SelectDAQReaderDropDownLabel.Layout.Column = 1;
            app.SelectDAQReaderDropDownLabel.Text = 'Select DAQ Reader';

            % Create SelectDAQReaderDropDown
            app.SelectDAQReaderDropDown = uidropdown(app.DaqSystemPageLayout);
            app.SelectDAQReaderDropDown.Layout.Row = 10;
            app.SelectDAQReaderDropDown.Layout.Column = 1;

            % Create SelectDAQMetadataReaderDropDownLabel
            app.SelectDAQMetadataReaderDropDownLabel = uilabel(app.DaqSystemPageLayout);
            app.SelectDAQMetadataReaderDropDownLabel.VerticalAlignment = 'bottom';
            app.SelectDAQMetadataReaderDropDownLabel.Layout.Row = 13;
            app.SelectDAQMetadataReaderDropDownLabel.Layout.Column = 1;
            app.SelectDAQMetadataReaderDropDownLabel.Text = 'Select DAQ Metadata Reader';

            % Create SelectDAQMetadataReaderDropDown
            app.SelectDAQMetadataReaderDropDown = uidropdown(app.DaqSystemPageLayout);
            app.SelectDAQMetadataReaderDropDown.Layout.Row = 14;
            app.SelectDAQMetadataReaderDropDown.Layout.Column = 1;

            % Create SelectDAQEpochProbemapClassDropDownLabel
            app.SelectDAQEpochProbemapClassDropDownLabel = uilabel(app.DaqSystemPageLayout);
            app.SelectDAQEpochProbemapClassDropDownLabel.VerticalAlignment = 'bottom';
            app.SelectDAQEpochProbemapClassDropDownLabel.Layout.Row = 18;
            app.SelectDAQEpochProbemapClassDropDownLabel.Layout.Column = 1;
            app.SelectDAQEpochProbemapClassDropDownLabel.Text = 'Select DAQ Epoch Probemap Class';

            % Create SelectDAQEpochProbemapClassDropDown
            app.SelectDAQEpochProbemapClassDropDown = uidropdown(app.DaqSystemPageLayout);
            app.SelectDAQEpochProbemapClassDropDown.Layout.Row = 19;
            app.SelectDAQEpochProbemapClassDropDown.Layout.Column = 1;

            % Create LoadProbesFromFileLabel
            app.LoadProbesFromFileLabel = uilabel(app.DaqSystemPageLayout);
            app.LoadProbesFromFileLabel.FontWeight = 'bold';
            app.LoadProbesFromFileLabel.Layout.Row = 17;
            app.LoadProbesFromFileLabel.Layout.Column = [1 2];
            app.LoadProbesFromFileLabel.Text = 'Load Probes From File';

            % Create LoadProbesFromFileSwitch
            app.LoadProbesFromFileSwitch = uiswitch(app.DaqSystemPageLayout, 'slider');
            app.LoadProbesFromFileSwitch.Items = {'On', 'Off'};
            app.LoadProbesFromFileSwitch.ValueChangedFcn = createCallbackFcn(app, @LoadProbesFromFileSwitchValueChanged, true);
            app.LoadProbesFromFileSwitch.Layout.Row = 17;
            app.LoadProbesFromFileSwitch.Layout.Column = 2;
            app.LoadProbesFromFileSwitch.Value = 'On';

            % Create CreateNewButton_PM
            app.CreateNewButton_PM = uibutton(app.DaqSystemPageLayout, 'push');
            app.CreateNewButton_PM.Layout.Row = 19;
            app.CreateNewButton_PM.Layout.Column = 2;
            app.CreateNewButton_PM.Text = 'Create New';

            % Create CreateNewButton_MDR
            app.CreateNewButton_MDR = uibutton(app.DaqSystemPageLayout, 'push');
            app.CreateNewButton_MDR.Layout.Row = 14;
            app.CreateNewButton_MDR.Layout.Column = 2;
            app.CreateNewButton_MDR.Text = 'Create New';

            % Create CreateNewButton_DR
            app.CreateNewButton_DR = uibutton(app.DaqSystemPageLayout, 'push');
            app.CreateNewButton_DR.ButtonPushedFcn = createCallbackFcn(app, @CreateNewButton_DRPushed, true);
            app.CreateNewButton_DR.Layout.Row = 10;
            app.CreateNewButton_DR.Layout.Column = 2;
            app.CreateNewButton_DR.Text = 'Create New';

            % Create CreateNewButton_DS
            app.CreateNewButton_DS = uibutton(app.DaqSystemPageLayout, 'push');
            app.CreateNewButton_DS.Layout.Row = 6;
            app.CreateNewButton_DS.Layout.Column = 2;
            app.CreateNewButton_DS.Text = 'Create New';

            % Create HelpButton_PM
            app.HelpButton_PM = uibutton(app.DaqSystemPageLayout, 'push');
            app.HelpButton_PM.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton_PM.Layout.Row = 19;
            app.HelpButton_PM.Layout.Column = 3;
            app.HelpButton_PM.Text = '?';

            % Create HelpButton_MDR
            app.HelpButton_MDR = uibutton(app.DaqSystemPageLayout, 'push');
            app.HelpButton_MDR.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton_MDR.Layout.Row = 14;
            app.HelpButton_MDR.Layout.Column = 3;
            app.HelpButton_MDR.Text = '?';

            % Create HelpButton_DR
            app.HelpButton_DR = uibutton(app.DaqSystemPageLayout, 'push');
            app.HelpButton_DR.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton_DR.Layout.Row = 10;
            app.HelpButton_DR.Layout.Column = 3;
            app.HelpButton_DR.Text = '?';

            % Create HelpButton_DS
            app.HelpButton_DS = uibutton(app.DaqSystemPageLayout, 'push');
            app.HelpButton_DS.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton_DS.Layout.Row = 6;
            app.HelpButton_DS.Layout.Column = 3;
            app.HelpButton_DS.Text = '?';

            % Create DaqSystemNameEditField
            app.DaqSystemNameEditField = uieditfield(app.DaqSystemPageLayout, 'text');
            app.DaqSystemNameEditField.Layout.Row = 2;
            app.DaqSystemNameEditField.Layout.Column = 1;

            % Create DAQSystemNameLabel
            app.DAQSystemNameLabel = uilabel(app.DaqSystemPageLayout);
            app.DAQSystemNameLabel.Layout.Row = 1;
            app.DAQSystemNameLabel.Layout.Column = 1;
            app.DAQSystemNameLabel.Text = 'DAQ System Name';

            % Create LinkFilesTab
            app.LinkFilesTab = uitab(app.TabGroup);
            app.LinkFilesTab.Title = 'Link Files';
            app.LinkFilesTab.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create LinkedFilePageGridLayout
            app.LinkedFilePageGridLayout = uigridlayout(app.LinkFilesTab);
            app.LinkedFilePageGridLayout.ColumnWidth = {'2x', '1x'};
            app.LinkedFilePageGridLayout.RowHeight = {20, '1x'};
            app.LinkedFilePageGridLayout.ColumnSpacing = 30;
            app.LinkedFilePageGridLayout.Padding = [35 35 35 35];

            % Create FileSelectionGridLayout
            app.FileSelectionGridLayout = uigridlayout(app.LinkedFilePageGridLayout);
            app.FileSelectionGridLayout.ColumnWidth = {125, 125, 125, '1x'};
            app.FileSelectionGridLayout.RowHeight = {23, 23, 20, '1x', 23, 20, 23};
            app.FileSelectionGridLayout.Padding = [20 10 10 10];
            app.FileSelectionGridLayout.Layout.Row = 2;
            app.FileSelectionGridLayout.Layout.Column = 1;

            % Create UseRegularExpressionforSelectedFileLabel
            app.UseRegularExpressionforSelectedFileLabel = uilabel(app.FileSelectionGridLayout);
            app.UseRegularExpressionforSelectedFileLabel.FontWeight = 'bold';
            app.UseRegularExpressionforSelectedFileLabel.Layout.Row = 6;
            app.UseRegularExpressionforSelectedFileLabel.Layout.Column = [1 2];
            app.UseRegularExpressionforSelectedFileLabel.Text = 'Use Regular Expression for Selected File';

            % Create RegularExpressionSwitch
            app.RegularExpressionSwitch = uiswitch(app.FileSelectionGridLayout, 'slider');
            app.RegularExpressionSwitch.ValueChangedFcn = createCallbackFcn(app, @RegularExpressionSwitchValueChanged, true);
            app.RegularExpressionSwitch.Layout.Row = 6;
            app.RegularExpressionSwitch.Layout.Column = 3;

            % Create RegularExpressionEditField
            app.RegularExpressionEditField = uieditfield(app.FileSelectionGridLayout, 'text');
            app.RegularExpressionEditField.ValueChangedFcn = createCallbackFcn(app, @RegularExpressionEditFieldValueChanged, true);
            app.RegularExpressionEditField.Layout.Row = 7;
            app.RegularExpressionEditField.Layout.Column = [1 3];

            % Create EpochProbeMapButton
            app.EpochProbeMapButton = uibutton(app.FileSelectionGridLayout, 'state');
            app.EpochProbeMapButton.ValueChangedFcn = createCallbackFcn(app, @EpochProbeMapButtonValueChanged, true);
            app.EpochProbeMapButton.Text = 'Epoch Probe Map';
            app.EpochProbeMapButton.Layout.Row = 1;
            app.EpochProbeMapButton.Layout.Column = 3;

            % Create MetadataReaderButton
            app.MetadataReaderButton = uibutton(app.FileSelectionGridLayout, 'state');
            app.MetadataReaderButton.ValueChangedFcn = createCallbackFcn(app, @MetadataReaderButtonValueChanged, true);
            app.MetadataReaderButton.Text = 'Metadata Reader';
            app.MetadataReaderButton.Layout.Row = 1;
            app.MetadataReaderButton.Layout.Column = 2;

            % Create DAQReaderButton
            app.DAQReaderButton = uibutton(app.FileSelectionGridLayout, 'state');
            app.DAQReaderButton.ValueChangedFcn = createCallbackFcn(app, @DAQReaderButtonValueChanged, true);
            app.DAQReaderButton.Text = 'DAQ Reader';
            app.DAQReaderButton.Layout.Row = 1;
            app.DAQReaderButton.Layout.Column = 1;
            app.DAQReaderButton.Value = true;

            % Create FileTreeFilterEditField
            app.FileTreeFilterEditField = uieditfield(app.FileSelectionGridLayout, 'text');
            app.FileTreeFilterEditField.ValueChangingFcn = createCallbackFcn(app, @FileTreeFilterEditFieldValueChanging, true);
            app.FileTreeFilterEditField.Placeholder = 'Enter text here to filter list';
            app.FileTreeFilterEditField.Layout.Row = 3;
            app.FileTreeFilterEditField.Layout.Column = [1 3];

            % Create FileTree
            app.FileTree = uitree(app.FileSelectionGridLayout, 'checkbox');
            app.FileTree.SelectionChangedFcn = createCallbackFcn(app, @FileTreeSelectionChanged, true);
            app.FileTree.Layout.Row = 4;
            app.FileTree.Layout.Column = [1 3];

            % Assign Checked Nodes
            app.FileTree.CheckedNodesChangedFcn = createCallbackFcn(app, @FileTreeCheckedNodesChanged, true);

            % Create SelectReaderTypeforLinkingFilesLabel
            app.SelectReaderTypeforLinkingFilesLabel = uilabel(app.LinkedFilePageGridLayout);
            app.SelectReaderTypeforLinkingFilesLabel.FontWeight = 'bold';
            app.SelectReaderTypeforLinkingFilesLabel.Layout.Row = 1;
            app.SelectReaderTypeforLinkingFilesLabel.Layout.Column = 1;
            app.SelectReaderTypeforLinkingFilesLabel.Text = 'Select Reader Type for Linking Files';

            % Create ProbesTab
            app.ProbesTab = uitab(app.TabGroup);
            app.ProbesTab.Title = 'Probes';
            app.ProbesTab.BackgroundColor = [0.9137 0.9294 0.9569];

            % Create ProbePageGridLayout
            app.ProbePageGridLayout = uigridlayout(app.ProbesTab);
            app.ProbePageGridLayout.ColumnWidth = {'1x'};
            app.ProbePageGridLayout.RowHeight = {25, '1x'};
            app.ProbePageGridLayout.Padding = [50 50 50 50];
            app.ProbePageGridLayout.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create ProbeTablePanel
            app.ProbeTablePanel = uipanel(app.ProbePageGridLayout);
            app.ProbeTablePanel.BorderType = 'none';
            app.ProbeTablePanel.BackgroundColor = [1 1 1];
            app.ProbeTablePanel.Layout.Row = 2;
            app.ProbeTablePanel.Layout.Column = 1;

            % Create ProbeTableGridLayout
            app.ProbeTableGridLayout = uigridlayout(app.ProbeTablePanel);
            app.ProbeTableGridLayout.ColumnWidth = {'1x'};
            app.ProbeTableGridLayout.RowHeight = {'1x'};
            app.ProbeTableGridLayout.Padding = [0 0 0 0];
            app.ProbeTableGridLayout.BackgroundColor = [1 1 1];

            % Create ProbeTableToolbarGridLayout
            app.ProbeTableToolbarGridLayout = uigridlayout(app.ProbePageGridLayout);
            app.ProbeTableToolbarGridLayout.ColumnWidth = {75, 100, 75, 150, '1x', 100};
            app.ProbeTableToolbarGridLayout.RowHeight = {'1x'};
            app.ProbeTableToolbarGridLayout.Padding = [0 0 0 0];
            app.ProbeTableToolbarGridLayout.Layout.Row = 1;
            app.ProbeTableToolbarGridLayout.Layout.Column = 1;
            app.ProbeTableToolbarGridLayout.BackgroundColor = [0.9412 0.9412 0.9412];

            % Create SelectEpochDropDownLabel
            app.SelectEpochDropDownLabel = uilabel(app.ProbeTableToolbarGridLayout);
            app.SelectEpochDropDownLabel.Visible = 'off';
            app.SelectEpochDropDownLabel.Layout.Row = 1;
            app.SelectEpochDropDownLabel.Layout.Column = 3;
            app.SelectEpochDropDownLabel.Text = 'Select Epoch';

            % Create SelectEpochDropDown
            app.SelectEpochDropDown = uidropdown(app.ProbeTableToolbarGridLayout);
            app.SelectEpochDropDown.Items = {'Epoch 1', 'Epoch 2', 'Epoch 3', 'Epoch 4'};
            app.SelectEpochDropDown.Visible = 'off';
            app.SelectEpochDropDown.Layout.Row = 1;
            app.SelectEpochDropDown.Layout.Column = 4;
            app.SelectEpochDropDown.Value = 'Epoch 1';

            % Create CustomizeprobesperepochCheckBox
            app.CustomizeprobesperepochCheckBox = uicheckbox(app.ProbeTableToolbarGridLayout);
            app.CustomizeprobesperepochCheckBox.ValueChangedFcn = createCallbackFcn(app, @CustomizeProbesPerEpochCheckBoxValueChanged, true);
            app.CustomizeprobesperepochCheckBox.Text = 'Customize probes per epoch';
            app.CustomizeprobesperepochCheckBox.Layout.Row = 1;
            app.CustomizeprobesperepochCheckBox.Layout.Column = [1 2];

            % Create FooterGridLayout
            app.FooterGridLayout = uigridlayout(app.MainGridLayout);
            app.FooterGridLayout.RowHeight = {'1x', 35, '1x'};
            app.FooterGridLayout.ColumnSpacing = 50;
            app.FooterGridLayout.Padding = [35 0 35 0];
            app.FooterGridLayout.Layout.Row = 2;
            app.FooterGridLayout.Layout.Column = 1;
            app.FooterGridLayout.BackgroundColor = [0.9176 0.9294 0.9529];

            % Create ImportDAQSystemButton
            app.ImportDAQSystemButton = uibutton(app.FooterGridLayout, 'push');
            app.ImportDAQSystemButton.ButtonPushedFcn = createCallbackFcn(app, @ImportDAQSystemButtonPushed, true);
            app.ImportDAQSystemButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'import.png');
            app.ImportDAQSystemButton.BackgroundColor = [1 1 1];
            app.ImportDAQSystemButton.FontWeight = 'bold';
            app.ImportDAQSystemButton.FontColor = [0 0.1255 0.3294];
            app.ImportDAQSystemButton.Layout.Row = 2;
            app.ImportDAQSystemButton.Layout.Column = 1;
            app.ImportDAQSystemButton.Text = 'Import DAQ System';

            % Create ExportDaqSystemButton
            app.ExportDaqSystemButton = uibutton(app.FooterGridLayout, 'push');
            app.ExportDaqSystemButton.ButtonPushedFcn = createCallbackFcn(app, @ExportDaqSystemButtonPushed, true);
            app.ExportDaqSystemButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'export.png');
            app.ExportDaqSystemButton.BackgroundColor = [1 1 1];
            app.ExportDaqSystemButton.FontWeight = 'bold';
            app.ExportDaqSystemButton.FontColor = [0 0.1255 0.3294];
            app.ExportDaqSystemButton.Layout.Row = 2;
            app.ExportDaqSystemButton.Layout.Column = 2;
            app.ExportDaqSystemButton.Text = 'Export Daq System';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = DAQSystemConfigurator(varargin)

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @(app)startupFcn(app, varargin{:}))

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end