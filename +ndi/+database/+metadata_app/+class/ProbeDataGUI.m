classdef ProbeDataGUI < handle
    %PROBEDATAGUI Manages the GUI elements and interactions for Probe Data.
    properties (Access = public)
        ParentApp % Handle to the main MetadataEditorApp instance
        UIBaseContainer % This will now be obj.ProbeInfoPanel, created by this class
        UITableProbe matlab.ui.control.Table
        % Add other UI components for this tab if needed (e.g., Add/Remove buttons)

        % NEW PROPERTIES for base layout elements
        ProbeInfoGridLayout matlab.ui.container.GridLayout
        ProbeInfoLabel matlab.ui.control.Label
        ProbeInfoPanel matlab.ui.container.Panel % Panel where detailed UI is built
    end

    properties (Access = private)
        ResourcesPath   % Path to resources, specifically icons (if needed for this GUI)
    end

    methods
        % MODIFIED CONSTRUCTOR
        function obj = ProbeDataGUI(parentAppHandle, probeInfoTabHandle) % Accepts ProbeInfoTab
            obj.ParentApp = parentAppHandle; % [cite: 1536]

            % Determine ResourcesPath 
            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath) % Modified check
                obj.ResourcesPath = obj.ParentApp.ResourcesPath; % [cite: 1537]
            else
                % Fallback if ParentApp.ResourcesPath is not defined
                guiFilePath = fileparts(mfilename('fullpath')); % [cite: 1538]
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources', 'icons'); % [cite: 1539]
                fprintf(2, 'Warning (ProbeDataGUI): ParentApp.ResourcesPath not found. Using fallback relative path for icons.\n'); % [cite: 1539]
            end
            
            obj.createProbeInfoTabBaseLayout(probeInfoTabHandle); % Create base structure
            obj.createProbeUIComponents(); % Populate the self-created panel [cite: 1540]
        end

        % NEW METHOD to create the base layout for the Probe Info tab content
        function createProbeInfoTabBaseLayout(obj, probeInfoTabHandle)
            % probeInfoTabHandle is app.ProbeInfoTab passed from MetadataEditorApp
            obj.ProbeInfoGridLayout = uigridlayout(probeInfoTabHandle, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]); %
            obj.ProbeInfoLabel = uilabel(obj.ProbeInfoGridLayout, 'Text', 'Probe Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold'); %
            obj.ProbeInfoLabel.Layout.Row=1; obj.ProbeInfoLabel.Layout.Column=1; %
            obj.ProbeInfoPanel = uipanel(obj.ProbeInfoGridLayout, 'BorderType', 'none'); %
            obj.ProbeInfoPanel.Layout.Row=2; obj.ProbeInfoPanel.Layout.Column=1; %
            
            % Set UIBaseContainer to the newly created ProbeInfoPanel.
            obj.UIBaseContainer = obj.ProbeInfoPanel;
        end

        function initialize(obj)
            % Set up callbacks for probe UI components
            obj.UITableProbe.CellEditCallback = @(src,event) obj.uiTableProbeCellEditCallback(event); % [cite: 1541]
            obj.UITableProbe.DoubleClickedFcn = @(src,event) obj.uiTableProbeDoubleClickedCallback(event); % [cite: 1542]
            
            % Initial drawing of probe data
            obj.drawProbeData(); % [cite: 1542]
        end

        function createProbeUIComponents(obj)
            % This method now uses obj.UIBaseContainer, which is obj.ProbeInfoPanel
            parent = obj.UIBaseContainer;
            
            % Main grid layout for the probe info panel content
            gridLayout = uigridlayout(parent, [1 1]); % [cite: 1543]
            gridLayout.ColumnWidth = {'1x'}; % [cite: 1544]
            gridLayout.RowHeight = {'1x'}; % [cite: 1544]
            gridLayout.Padding = [0 0 0 0]; % [cite: 1544]

            obj.UITableProbe = uitable(gridLayout, ... % [cite: 1545]
                'ColumnName', {'Probe Name'; 'Probe type'; 'Status'}, ... % [cite: 1545]
                'RowName', {}, ... % [cite: 1545]
                'SelectionType', 'row', ... % [cite: 1546]
                'ColumnEditable', [false true false], ...  % [cite: 1546]
                'Multiselect', 'off'); % [cite: 1547]
            obj.UITableProbe.Layout.Row = 1; % [cite: 1547]
            obj.UITableProbe.Layout.Column = 1; % [cite: 1547]

            % TODO: Add "Add Probe", "Remove Probe", "Edit Probe" buttons if desired
            % For example:
            % buttonGrid = uigridlayout(gridLayout); % [cite: 1547]
            % Potentially a second row or a side column % [cite: 1548]
            % buttonGrid.Layout.Row = 2; % [cite: 1548]
            % buttonGrid.Layout.Column = 1; % [cite: 1549]
            % obj.AddProbeButton = uibutton(buttonGrid, 'push', 'Text', 'Add Probe'); % [cite: 1549]
            % obj.AddProbeButton.ButtonPushedFcn = @(~,~) obj.addProbeButtonPushed(); % [cite: 1549]
        end

        function drawProbeData(obj)
            % Fetches formatted probe data and updates the UI table
            fprintf('DEBUG (ProbeDataGUI): Drawing Probe Data.\n'); % [cite: 1550]
            probeTableData = []; % [cite: 1551]
            if isprop(obj.ParentApp, 'ProbeData') && ismethod(obj.ParentApp.ProbeData, 'formatTable') % [cite: 1551]
                try
                    probeTableData = obj.ParentApp.ProbeData.formatTable(); % [cite: 1551]
                catch ME_format % [cite: 1552]
                    fprintf(2, 'Error in ProbeData.formatTable(): %s\n', ME_format.message); % [cite: 1552]
                    probeTableData = struct('Name',{},'ClassType',{},'Status',{}); % Ensure empty table with fields % [cite: 1553]
                end
            end

            if ~isempty(probeTableData) || (isstruct(probeTableData) && numel(fieldnames(probeTableData))>0) % [cite: 1553]
                try
                    obj.UITableProbe.Data = struct2table(probeTableData, 'AsArray', true); % [cite: 1554]
                catch ME_table % [cite: 1555]
                    fprintf(2, 'Error converting probe data to table: %s. Data was:\n', ME_table.message); % [cite: 1555]
                    disp(probeTableData); % [cite: 1556]
                    obj.UITableProbe.Data = table(); % Fallback to empty table % [cite: 1556]
                end
            else
                obj.UITableProbe.Data = table(); % [cite: 1557]
            end
        end

        % --- Callbacks ---
        function uiTableProbeCellEditCallback(obj, event)
            indices = event.Indices; % [cite: 1559]
            newData = event.NewData; % [cite: 1650]
            fprintf('DEBUG (ProbeDataGUI): UITableProbe Cell Edit - Row: %d, Col: %d, NewData: %s\n', indices(1), indices(2), string(newData)); % [cite: 1561]
            if indices(2) == 2 % 'Probe type' column % [cite: 1562]
                probeIndexInList = indices(1); % [cite: 1562]
                if probeIndexInList <= numel(obj.ParentApp.ProbeData.ProbeList) % [cite: 1563]
                    try % [cite: 1563]
                        obj.ParentApp.inform('For complex probe edits, please double-click to open the probe form.', 'Info'); % [cite: 1567]
                        obj.drawProbeData(); % [cite: 1567]
                    catch ME_cellEdit % [cite: 1568]
                        fprintf(2, 'Error in uiTableProbeCellEditCallback: %s\n', ME_cellEdit.message); % [cite: 1568]
                        obj.drawProbeData(); % Revert % [cite: 1569]
                    end
                end
            end
        end

        function uiTableProbeDoubleClickedCallback(obj, event)
            if isempty(event.InteractionInformation) || isempty(event.InteractionInformation.Row) % [cite: 1569]
                return; % [cite: 1570]
            end
            selectedRow = event.InteractionInformation.Row(1); % [cite: 1571]
            
            fprintf('DEBUG (ProbeDataGUI): UITableProbe Double Clicked - Row: %d\n', selectedRow); % [cite: 1572]
            if selectedRow > 0 && selectedRow <= numel(obj.ParentApp.ProbeData.ProbeList) % [cite: 1573]
                currentProbeEntry = obj.ParentApp.ProbeData.ProbeList{selectedRow}; % [cite: 1573]
                probeType = ''; % [cite: 1574]
                probeName = ''; % [cite: 1574]

                if isobject(currentProbeEntry) && isprop(currentProbeEntry, 'ClassType') % [cite: 1574]
                    probeType = currentProbeEntry.ClassType; % [cite: 1574]
                elseif isstruct(currentProbeEntry) && isfield(currentProbeEntry, 'ClassType') % [cite: 1575]
                    probeType = currentProbeEntry.ClassType; % [cite: 1575]
                end
                
                if isobject(currentProbeEntry) && isprop(currentProbeEntry, 'Name') % [cite: 1576]
                    probeName = currentProbeEntry.Name; % [cite: 1577]
                elseif isstruct(currentProbeEntry) && isfield(currentProbeEntry, 'Name') % [cite: 1577]
                    probeName = currentProbeEntry.Name; % [cite: 1578]
                end

                if isempty(probeType) && isfield(currentProbeEntry, 'type') % Fallback if ClassType isn't there but 'type' is % [cite: 1578]
                    probeType = currentProbeEntry.type; % [cite: 1579]
                end
                
                if isempty(probeType) % [cite: 1579]
                    if selectedRow <= size(obj.UITableProbe.Data,1) % [cite: 1579]
                          try % [cite: 1580]
                            % Assuming 'ProbeType' is the correct column name from formatTable
                            % It might be 'ClassType' or similar depending on ProbeData.formatTable output
                            probeTypeFromTable = obj.UITableProbe.Data{selectedRow, 'Probe type'}; % Check if this column exists
                            if iscell(probeTypeFromTable)
                                probeType = probeTypeFromTable{1};
                            else
                                probeType = probeTypeFromTable;
                            end
                        catch ME_ProbeType %
                             fprintf(2, 'Could not determine probe type for editing from table: %s.\n', ME_ProbeType.message); % [cite: 1581]
                             return; % [cite: 1582]
                        end
                    else
                        fprintf(2, 'Selected row index out of bounds for UITableProbe.Data.\n'); % [cite: 1582]
                        return; % [cite: 1583]
                    end
                end
                
                fprintf('DEBUG (ProbeDataGUI): Opening form for probe type: %s, index: %d\n', probeType, selectedRow); % [cite: 1583]
                updateOccurred = obj.openProbeForm(probeType, selectedRow, currentProbeEntry); 
                if updateOccurred  % [cite: 1587]
                    obj.drawProbeData(); % Refresh the table in this GUI % [cite: 1588]
                end
            end
        end
        
        function success = openProbeForm(obj, probeType, probeIndexOrData, probeObjIn) 
            parentApp = obj.ParentApp; 
            success = false; % [cite: 554]
            formHandle = []; % [cite: 555]
            
            if isempty(parentApp) || ~isvalid(parentApp) || ~isprop(parentApp, 'UIForm')
                fprintf(2, 'Error (ProbeDataGUI/openProbeForm): ParentApp or ParentApp.UIForm is not available.\n');
                return;
            end

            switch probeType % [cite: 555]
                case "Electrode" % [cite: 555]
                    if ~isfield(parentApp.UIForm, 'Electrode') || ~isvalid(parentApp.UIForm.Electrode) % [cite: 555]
                        parentApp.UIForm.Electrode = ndi.database.metadata_app.Apps.ElectrodeForm(); % [cite: 556]
                    end
                    formHandle = parentApp.UIForm.Electrode; % [cite: 557]
                case "Pipette" % [cite: 558]
                    if ~isfield(parentApp.UIForm, 'Pipette') || ~isvalid(parentApp.UIForm.Pipette) % [cite: 558]
                        parentApp.UIForm.Pipette = ndi.database.metadata_app.Apps.PipetteForm(); % [cite: 559]
                    end
                    formHandle = parentApp.UIForm.Pipette; % [cite: 560]
                otherwise
                    if isprop(parentApp, 'alert') && ismethod(parentApp, 'alert') % [cite: 561]
                        parentApp.alert(['Probe form for type "' probeType '" not implemented.'], 'Error'); % [cite: 561]
                    else
                        fprintf(2, 'Alert: Probe form for type "%s" not implemented.\n', probeType);
                    end
                    return; % [cite: 562]
            end
            
            if isempty(formHandle) 
                fprintf(2, 'Error (ProbeDataGUI/openProbeForm): Form handle not created for probe type "%s".\n', probeType);
                return;
            end

            formHandle.Visible = 'on'; % [cite: 562]
            if nargin > 3 && ~isempty(probeObjIn)  % [cite: 563]
                formHandle.setProbeDetails(probeObjIn); % [cite: 563]
            end
            
            if isprop(parentApp, 'NDIMetadataEditorUIFigure') && isvalid(parentApp.NDIMetadataEditorUIFigure) % [cite: 564]
                ndi.gui.utility.centerFigure(formHandle.UIFigure, parentApp.NDIMetadataEditorUIFigure); % [cite: 564]
            else
                 fprintf(2, 'Warning (ProbeDataGUI/openProbeForm): ParentApp.NDIMetadataEditorUIFigure not available for centering.\n');
            end

            formHandle.waitfor(); % [cite: 564]
            if strcmp(formHandle.FinishState, "Save") % [cite: 565]
                updatedProbeObjDetails = formHandle.getProbeDetails(); % [cite: 565]
                if isprop(parentApp, 'ProbeData') && ismethod(parentApp.ProbeData, 'replaceProbe') % [cite: 566]
                    parentApp.ProbeData.replaceProbe(probeIndexOrData, updatedProbeObjDetails); % [cite: 566]
                else
                     fprintf(2, 'Error (ProbeDataGUI/openProbeForm): ParentApp.ProbeData.replaceProbe is not available.\n');
                end
                if ismethod(parentApp, 'saveDatasetInformationStruct') % [cite: 566]
                    parentApp.saveDatasetInformationStruct(); % [cite: 566]
                else
                    fprintf(2, 'Error (ProbeDataGUI/openProbeForm): ParentApp.saveDatasetInformationStruct is not available.\n');
                end
                success = true; % [cite: 566]
            end
            formHandle.reset(); % [cite: 566]
            formHandle.Visible = 'off'; % [cite: 567]
        end

    end
end