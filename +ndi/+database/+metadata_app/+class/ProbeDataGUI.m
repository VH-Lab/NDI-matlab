classdef ProbeDataGUI < handle
    %PROBEDATAGUI Manages the GUI elements and interactions for Probe Data.

    properties (Access = public)
        ParentApp % Handle to the main MetadataEditorApp instance
        UITableProbe matlab.ui.control.Table
        % Add other UI components for this tab if needed (e.g., Add/Remove buttons)
    end

    properties (Access = private)
        UIBaseContainer % The parent uipanel or uigridlayout provided by MetadataEditorApp
        ResourcesPath   % Path to resources, specifically icons (if needed for this GUI)
    end

    methods
        function obj = ProbeDataGUI(parentAppHandle, uiParentContainerForProbes)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainerForProbes;

            % Determine ResourcesPath (if ProbeDataGUI uses icons)
            % Assuming MetadataEditorApp has a ResourcesPath property
            if isprop(obj.ParentApp, 'ResourcesPath')
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                % Fallback if ParentApp.ResourcesPath is not defined
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources', 'icons');
                fprintf(2, 'Warning (ProbeDataGUI): ParentApp.ResourcesPath not found. Using fallback relative path for icons.\n');
            end
            
            obj.createProbeUIComponents();
        end

        function initialize(obj)
            % Set up callbacks for probe UI components
            obj.UITableProbe.CellEditCallback = @(src,event) obj.uiTableProbeCellEditCallback(event);
            obj.UITableProbe.DoubleClickedFcn = @(src,event) obj.uiTableProbeDoubleClickedCallback(event);
            
            % Initial drawing of probe data
            obj.drawProbeData();
        end

        function createProbeUIComponents(obj)
            % Create UI elements within the UIBaseContainer (e.g., app.ProbeInfoPanel)
            
            % Main grid layout for the probe info panel content
            gridLayout = uigridlayout(obj.UIBaseContainer, [1 1]);
            gridLayout.ColumnWidth = {'1x'};
            gridLayout.RowHeight = {'1x'};
            gridLayout.Padding = [0 0 0 0]; % Use padding from ProbeInfoPanel if needed

            obj.UITableProbe = uitable(gridLayout, ...
                'ColumnName', {'Probe Name'; 'Probe type'; 'Status'}, ...
                'RowName', {}, ...
                'SelectionType', 'row', ...
                'ColumnEditable', [false true false], ... % Example: Probe type might be editable
                'Multiselect', 'off');
            obj.UITableProbe.Layout.Row = 1;
            obj.UITableProbe.Layout.Column = 1;

            % TODO: Add "Add Probe", "Remove Probe", "Edit Probe" buttons if desired
            % For example:
            % buttonGrid = uigridlayout(gridLayout); % Potentially a second row or a side column
            % buttonGrid.Layout.Row = 2; buttonGrid.Layout.Column = 1;
            % obj.AddProbeButton = uibutton(buttonGrid, 'push', 'Text', 'Add Probe');
            % obj.AddProbeButton.ButtonPushedFcn = @(~,~) obj.addProbeButtonPushed();
        end

        function drawProbeData(obj)
            % Fetches formatted probe data and updates the UI table
            fprintf('DEBUG (ProbeDataGUI): Drawing Probe Data.\n');
            probeTableData = [];
            if isprop(obj.ParentApp, 'ProbeData') && ismethod(obj.ParentApp.ProbeData, 'formatTable')
                try
                    probeTableData = obj.ParentApp.ProbeData.formatTable();
                catch ME_format
                    fprintf(2, 'Error in ProbeData.formatTable(): %s\n', ME_format.message);
                    probeTableData = struct('Name',{},'ClassType',{},'Status',{}); % Ensure empty table with fields
                end
            end

            if ~isempty(probeTableData) || (isstruct(probeTableData) && numel(fieldnames(probeTableData))>0)
                try
                    obj.UITableProbe.Data = struct2table(probeTableData, 'AsArray', true);
                catch ME_table
                    fprintf(2, 'Error converting probe data to table: %s. Data was:\n', ME_table.message);
                    disp(probeTableData);
                    obj.UITableProbe.Data = table(); % Fallback to empty table
                end
            else
                obj.UITableProbe.Data = table(); % Empty table if no data
            end
        end

        % --- Callbacks ---
        function uiTableProbeCellEditCallback(obj, event)
            % Handles direct edits in the UITableProbe.
            % This is a placeholder and might need to be more sophisticated if direct editing is complex.
            % For now, assume edits directly modify simple properties if allowed.
            
            indices = event.Indices; % [row, col]
            newData = event.NewData;
            
            fprintf('DEBUG (ProbeDataGUI): UITableProbe Cell Edit - Row: %d, Col: %d, NewData: %s\n', indices(1), indices(2), string(newData));

            % Example: If column 2 ('Probe type') is editable
            if indices(2) == 2 % 'Probe type' column
                probeIndexInList = indices(1); % Assuming table row maps directly to ProbeList index
                if probeIndexInList <= numel(obj.ParentApp.ProbeData.ProbeList)
                    try
                        % This is tricky because ProbeList might contain objects or structs
                        % Direct modification like this assumes ProbeList contains structs with a settable 'ClassType'
                        % or objects where 'ClassType' can be directly set and is the correct type.
                        % A more robust approach would be to open the probe form for editing.
                        
                        % For simplicity, let's log and re-draw. Proper editing should use the form.
                        % obj.ParentApp.ProbeData.ProbeList{probeIndexInList}.ClassType = newData; 
                        % obj.ParentApp.saveDatasetInformationStruct();
                        % obj.drawProbeData();
                        
                        obj.ParentApp.inform('For complex probe edits, please double-click to open the probe form.', 'Info');
                        obj.drawProbeData(); % Revert to original data from model if edit is not fully supported here
                    catch ME_cellEdit
                        fprintf(2, 'Error in uiTableProbeCellEditCallback: %s\n', ME_cellEdit.message);
                        obj.drawProbeData(); % Revert
                    end
                end
            end
        end

        function uiTableProbeDoubleClickedCallback(obj, event)
            if isempty(event.InteractionInformation) || isempty(event.InteractionInformation.Row)
                return; 
            end
            selectedRow = event.InteractionInformation.Row(1); % Take first if multiple rows somehow selected
            
            fprintf('DEBUG (ProbeDataGUI): UITableProbe Double Clicked - Row: %d\n', selectedRow);

            if selectedRow > 0 && selectedRow <= numel(obj.ParentApp.ProbeData.ProbeList)
                currentProbeEntry = obj.ParentApp.ProbeData.ProbeList{selectedRow};
                probeType = '';
                probeName = '';

                if isobject(currentProbeEntry) && isprop(currentProbeEntry, 'ClassType')
                    probeType = currentProbeEntry.ClassType;
                elseif isstruct(currentProbeEntry) && isfield(currentProbeEntry, 'ClassType')
                    probeType = currentProbeEntry.ClassType;
                end
                
                if isobject(currentProbeEntry) && isprop(currentProbeEntry, 'Name')
                    probeName = currentProbeEntry.Name;
                elseif isstruct(currentProbeEntry) && isfield(currentProbeEntry, 'Name')
                    probeName = currentProbeEntry.Name;
                end

                if isempty(probeType) && isfield(currentProbeEntry, 'type') % Fallback if ClassType isn't there but 'type' is
                    probeType = currentProbeEntry.type;
                end
                
                if isempty(probeType)
                    % Try to infer from table if direct object access failed
                    if selectedRow <= size(obj.UITableProbe.Data,1)
                        try
                            probeType = obj.UITableProbe.Data{selectedRow, 'ProbeType'}{1}; % Assuming ProbeType is 2nd col
                        catch
                             fprintf(2, 'Could not determine probe type for editing.\n');
                             return;
                        end
                    else
                        fprintf(2, 'Selected row index out of bounds for UITableProbe.Data.\n');
                        return;
                    end
                end
                
                fprintf('DEBUG (ProbeDataGUI): Opening form for probe type: %s, index: %d\n', probeType, selectedRow);

                % Call ParentApp's openProbeForm. This method needs to be adapted.
                % It should handle opening the form, and if saved, update app.ProbeData.
                % It should return a status indicating if an update occurred.
                updateOccurred = obj.ParentApp.openProbeForm(probeType, selectedRow, currentProbeEntry);

                if updateOccurred 
                    % ParentApp.openProbeForm has already updated app.ProbeData and saved.
                    obj.drawProbeData(); % Refresh the table in this GUI
                end
            end
        end

        % Placeholder for Add Probe button if implemented
        % function addProbeButtonPushed(obj)
        %     % Logic to open a form for a new probe
        %     % newProbeData = obj.ParentApp.openProbeForm('NewProbeType', [], []); % Example
        %     % if ~isempty(newProbeData)
        %     %    % Add to obj.ParentApp.ProbeData
        %     %    % obj.ParentApp.saveDatasetInformationStruct();
        %     %    % obj.drawProbeData();
        %     % end
        %     obj.ParentApp.inform('Add Probe functionality not yet implemented.', 'Info');
        % end

    end
end
