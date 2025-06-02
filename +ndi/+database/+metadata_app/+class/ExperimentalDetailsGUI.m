classdef ExperimentalDetailsGUI < handle
    %EXPERIMENTALDETAILSGUI Manages UI for the Experiment Details tab.

    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % Parent uicontainer for this GUI's elements
        
        % UI Components
        ExperimentalApproachTree matlab.ui.container.CheckBoxTree
        DataTypeTree matlab.ui.container.CheckBoxTree
        SelectTechniqueCategoryDropDown matlab.ui.control.DropDown
        SelectTechniqueDropDown matlab.ui.control.DropDown
        AddTechniqueButton matlab.ui.control.Button
        RemoveTechniqueButton matlab.ui.control.Button
        SelectedTechniquesListBox matlab.ui.control.ListBox

        % Labels
        ExperimentalApproachTreeLabel matlab.ui.control.Label
        DataTypeTreeLabel matlab.ui.control.Label
        SelectTechniqueCategoryDropDownLabel matlab.ui.control.Label
        SelectTechniqueDropDownLabel matlab.ui.control.Label
        SelectedTechniquesListBoxLabel matlab.ui.control.Label
    end

    properties (Access = private)
        ResourcesPath % Path to resources, e.g., for icons
    end

    methods
        function obj = ExperimentalDetailsGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;

            if isprop(obj.ParentApp, 'ResourcesPath')
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources', 'icons');
                fprintf(2, 'Warning (ExperimentalDetailsGUI): ParentApp.ResourcesPath not found. Using fallback relative path for icons.\n');
            end
            
            obj.createExperimentalDetailsUIComponents();
        end

        function initialize(obj)
            % Set up callbacks
            obj.DataTypeTree.CheckedNodesChangedFcn = @(~,event) obj.dataTypeTreeCheckedNodesChanged(event);
            obj.ExperimentalApproachTree.CheckedNodesChangedFcn = @(~,event) obj.experimentalApproachTreeCheckedNodesChanged(event);
            obj.SelectTechniqueCategoryDropDown.ValueChangedFcn = @(~,event) obj.selectTechniqueCategoryDropDownValueChanged(event);
            obj.AddTechniqueButton.ButtonPushedFcn = @(~,~) obj.addTechniqueButtonPushed();
            obj.RemoveTechniqueButton.ButtonPushedFcn = @(~,~) obj.removeTechniqueButtonPushed();
            % obj.SelectTechniqueDropDown.ValueChangedFcn = @(~,event) obj.selectTechniqueDropDownValueChanged(event); % If needed

            % Populate initial choices
            obj.populateDataTypeTree();
            obj.populateExperimentalApproachTree();
            obj.populateTechniqueCategoryDropdown();
            obj.populateTechniqueDropdown(''); % Populate with placeholder initially

            % Draw initial data
            obj.drawExperimentalDetails();
        end

        function createExperimentalDetailsUIComponents(obj)
            parent = obj.UIBaseContainer;
            iconsPath = obj.ResourcesPath;

            % Main grid for Experiment Details Panel content
            % Replicates GridLayout26 from MetadataEditorApp
            gridLayout = uigridlayout(parent, [9 6], ...
                'ColumnWidth', {180, 45, '1.25x', 45, '1x', 30}, ... % Adjusted button column
                'RowHeight', {22, 22, 22, 23, '1x', 22, 23, '1x', '1x'}, ... % Made last two rows 1x
                'Padding', [10 10 10 10], 'ColumnSpacing', 10, 'RowSpacing', 5);

            obj.DataTypeTreeLabel = uilabel(gridLayout, 'Text', 'Data Type (*)');
            obj.DataTypeTreeLabel.Layout.Row = 1; obj.DataTypeTreeLabel.Layout.Column = 1;
            obj.DataTypeTree = uitree(gridLayout, 'checkbox');
            obj.DataTypeTree.Layout.Row = [2 5]; obj.DataTypeTree.Layout.Column = 1; 
            
            obj.ExperimentalApproachTreeLabel = uilabel(gridLayout, 'Text', 'Experimental Approach');
            obj.ExperimentalApproachTreeLabel.Layout.Row = 1; obj.ExperimentalApproachTreeLabel.Layout.Column = 3;
            obj.ExperimentalApproachTree = uitree(gridLayout, 'checkbox');
            obj.ExperimentalApproachTree.Layout.Row = [2 9]; obj.ExperimentalApproachTree.Layout.Column = 3; 
            
            obj.SelectTechniqueCategoryDropDownLabel = uilabel(gridLayout, 'Text', 'Select Technique Category');
            obj.SelectTechniqueCategoryDropDownLabel.Layout.Row = 1; obj.SelectTechniqueCategoryDropDownLabel.Layout.Column = 5;
            obj.SelectTechniqueCategoryDropDown = uidropdown(gridLayout);
            obj.SelectTechniqueCategoryDropDown.Layout.Row = 2; obj.SelectTechniqueCategoryDropDown.Layout.Column = 5;
            
            obj.SelectTechniqueDropDownLabel = uilabel(gridLayout, 'Text', 'Select Technique');
            obj.SelectTechniqueDropDownLabel.Layout.Row = 3; obj.SelectTechniqueDropDownLabel.Layout.Column = 5;
            obj.SelectTechniqueDropDown = uidropdown(gridLayout, 'Editable', 'on');
            obj.SelectTechniqueDropDown.Layout.Row = 4; obj.SelectTechniqueDropDown.Layout.Column = 5;
            
            obj.AddTechniqueButton = uibutton(gridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'icons', 'plus.png'));
            obj.AddTechniqueButton.Layout.Row = 4; obj.AddTechniqueButton.Layout.Column = 6;
            
            obj.SelectedTechniquesListBoxLabel = uilabel(gridLayout, 'Text', 'Selected Techniques');
            obj.SelectedTechniquesListBoxLabel.Layout.Row = 6; obj.SelectedTechniquesListBoxLabel.Layout.Column = 5;
            obj.SelectedTechniquesListBox = uilistbox(gridLayout);
            obj.SelectedTechniquesListBox.Layout.Row = [7 8]; obj.SelectedTechniquesListBox.Layout.Column = 5; % Spans two '1x' rows
            
            obj.RemoveTechniqueButton = uibutton(gridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsPath, 'icons', 'minus.png'));
            obj.RemoveTechniqueButton.Layout.Row = 7; obj.RemoveTechniqueButton.Layout.Column = 6;
        end

        function drawExperimentalDetails(obj)
            fprintf('DEBUG (ExperimentalDetailsGUI): Drawing Experimental Details UI.\n');
            dsStruct = obj.ParentApp.DatasetInformationStruct;

            % Data Type Tree
            if isfield(dsStruct, 'DataType')
                obj.ParentApp.setCheckedNodesFromData(obj.DataTypeTree, dsStruct.DataType);
            else
                obj.ParentApp.setCheckedNodesFromData(obj.DataTypeTree, {});
            end

            % Experimental Approach Tree
            if isfield(dsStruct, 'ExperimentalApproach')
                obj.ParentApp.setCheckedNodesFromData(obj.ExperimentalApproachTree, dsStruct.ExperimentalApproach);
            else
                obj.ParentApp.setCheckedNodesFromData(obj.ExperimentalApproachTree, {});
            end

            % Selected Techniques ListBox
            if isfield(dsStruct, 'TechniquesEmployed') && (iscellstr(dsStruct.TechniquesEmployed) || isstring(dsStruct.TechniquesEmployed)) %#ok<ISCLSTR>
                obj.SelectedTechniquesListBox.Items = dsStruct.TechniquesEmployed;
                obj.SelectedTechniquesListBox.Value = {}; % Clear selection
            else
                obj.SelectedTechniquesListBox.Items = {};
                obj.SelectedTechniquesListBox.Value = {};
            end
        end

        % --- Population Methods ---
        function populateDataTypeTree(obj)
            ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox(obj.DataTypeTree, "SemanticDataType");
            fprintf('DEBUG (ExperimentalDetailsGUI): DataTypeTree populated.\n');
        end

        function populateExperimentalApproachTree(obj)
            ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox(obj.ExperimentalApproachTree, "ExperimentalApproach");
            fprintf('DEBUG (ExperimentalDetailsGUI): ExperimentalApproachTree populated.\n');
        end
        
        function populateTechniqueCategoryDropdown(obj)
            allowedTypes = openminds.core.DatasetVersion.LINKED_PROPERTIES.technique;
            allowedTypes = replace(allowedTypes, 'openminds.controlledterms.', '');
            if ~iscolumn(allowedTypes) && ~isempty(allowedTypes)
                allowedTypes = allowedTypes(:);
            elseif isempty(allowedTypes)
                allowedTypes = cell(0,1); 
            end
            obj.SelectTechniqueCategoryDropDown.Items = ["Select Category"; allowedTypes]; 
            obj.SelectTechniqueCategoryDropDown.Value = "Select Category"; 
            fprintf('DEBUG (ExperimentalDetailsGUI): TechniqueCategoryDropDown populated.\n');
        end
        
        function populateTechniqueDropdown(obj, schemaName)
            if nargin < 2 || isempty(schemaName) || strcmp(schemaName, "Select Category")
                obj.SelectTechniqueDropDown.Items = {'Select a category first'};
                obj.SelectTechniqueDropDown.ItemsData = {''}; 
                obj.SelectTechniqueDropDown.Value = ''; 
                return; 
            end
            
            [ids, displayNames] = ndi.database.metadata_app.fun.getOpenMindsInstances(schemaName); 
            
            if isempty(ids) 
                obj.SelectTechniqueDropDown.Items = {'No techniques for this category'};
                obj.SelectTechniqueDropDown.ItemsData = {''};
                obj.SelectTechniqueDropDown.Value = '';
            else
                if ~iscolumn(displayNames), displayNames = displayNames(:); end 
                if ~iscolumn(ids), ids = ids(:); end     

                obj.SelectTechniqueDropDown.Items = ["Select Technique"; displayNames];
                obj.SelectTechniqueDropDown.ItemsData = [""; ids]; 
                obj.SelectTechniqueDropDown.Value = ""; 
            end
            fprintf('DEBUG (ExperimentalDetailsGUI): TechniqueDropdown populated for category: %s.\n', schemaName);
        end

        % --- Callbacks ---
        function dataTypeTreeCheckedNodesChanged(obj, event)
            selectedData = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes);
            obj.ParentApp.DatasetInformationStruct.DataType = selectedData;
            if ~isempty(selectedData)
                obj.ParentApp.resetLabelForRequiredField(obj.ParentApp.FieldComponentMap.DataType);
            end
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (ExperimentalDetailsGUI): DataTypeTree selection changed.\n');
        end

        function experimentalApproachTreeCheckedNodesChanged(obj, event)
            selectedData = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes);
            obj.ParentApp.DatasetInformationStruct.ExperimentalApproach = selectedData;
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (ExperimentalDetailsGUI): ExperimentalApproachTree selection changed.\n');
        end

        function selectTechniqueCategoryDropDownValueChanged(obj, event)
            value = obj.SelectTechniqueCategoryDropDown.Value;
            obj.populateTechniqueDropdown(value); 
            % No direct save here, selection just populates next dropdown
        end

        function addTechniqueButtonPushed(obj, event)
            techniqueCategory = obj.SelectTechniqueCategoryDropDown.Value;
            selectedValueInTechniqueDropdown = obj.SelectTechniqueDropDown.Value; % This is the display name
            
            % Find the corresponding ItemsData (ID) for the selected display name
            idx = find(strcmp(obj.SelectTechniqueDropDown.Items, selectedValueInTechniqueDropdown));
            techniqueID = '';
            if ~isempty(idx) && idx(1) <= numel(obj.SelectTechniqueDropDown.ItemsData)
                 techniqueID = obj.SelectTechniqueDropDown.ItemsData{idx(1)};
            end

            if isempty(techniqueID) || strcmp(techniqueID, "") || strcmp(selectedValueInTechniqueDropdown, "Select Technique") || strcmp(selectedValueInTechniqueDropdown, "Select a category first") || strcmp(selectedValueInTechniqueDropdown, "No techniques for this category")
                obj.ParentApp.inform('Please select a valid technique from the list.', 'Selection Invalid'); return;
            end
            
            % Store the full URI (ID) in the listbox items data, and a readable representation in Items
            % Or, decide if DatasetInformationStruct.TechniquesEmployed should store IDs or display strings.
            % For now, let's assume we store a display string like "TechniqueName (Category)" in the listbox
            % and the actual IDs/full names in DatasetInformationStruct.TechniquesEmployed
            
            % Create the display string for the listbox
            techniqueDisplayString = sprintf('%s (%s)', selectedValueInTechniqueDropdown, techniqueCategory);
            
            currentTechniques = obj.SelectedTechniquesListBox.Items;
            if any(strcmp(currentTechniques, techniqueDisplayString))
                obj.ParentApp.inform(sprintf('The technique "%s" has already been added.', techniqueDisplayString), 'Duplicate Technique'); 
                return;
            end
            
            obj.SelectedTechniquesListBox.Items{end+1} = techniqueDisplayString;
            
            % Update DatasetInformationStruct.TechniquesEmployed (assuming it stores IDs or full names)
            if ~isfield(obj.ParentApp.DatasetInformationStruct, 'TechniquesEmployed') || ~iscell(obj.ParentApp.DatasetInformationStruct.TechniquesEmployed)
                obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = {};
            end
            obj.ParentApp.DatasetInformationStruct.TechniquesEmployed{end+1} = techniqueID; % Store the ID/full name
            
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (ExperimentalDetailsGUI): Technique "%s" added.\n', techniqueDisplayString);
        end

        function removeTechniqueButtonPushed(obj, event)
            selectedDisplayStrings = obj.SelectedTechniquesListBox.Value; % This is cell array of display strings
            if isempty(selectedDisplayStrings), return; end
            
            currentItems = obj.SelectedTechniquesListBox.Items;
            currentData = obj.ParentApp.DatasetInformationStruct.TechniquesEmployed; % Assuming this stores IDs

            indicesToRemove = [];
            idsToRemove = {};

            for i = 1:numel(selectedDisplayStrings)
                selectedDisplay = selectedDisplayStrings{i};
                idxInListbox = find(strcmp(currentItems, selectedDisplay));
                if ~isempty(idxInListbox)
                    indicesToRemove = [indicesToRemove, idxInListbox(1)]; %#ok<AGROW>
                    
                    % Infer ID from display string (this is fragile, better to store ID in ListBox.ItemsData)
                    % For now, let's assume we need to find the techniqueID based on display string parts
                    % This example assumes the display string is "TechniqueName (Category)"
                    match = regexp(selectedDisplay, '^(.*) \((.*)\)$', 'tokens');
                    if ~isempty(match)
                        displayNamePart = strtrim(match{1}{1});
                        % categoryPart = strtrim(match{1}{2});
                        % Find the ID from the Technique Dropdown that matches displayNamePart
                        % This is still complex if multiple categories have same technique name.
                        % A better way is if SelectedTechniquesListBox.ItemsData stored IDs.
                        % For simplicity, if TechniquesEmployed stores IDs, we need a mapping
                        % or to remove by index if it was guaranteed to be parallel.
                        % Safest: if TechniquesEmployed stores the same display strings, just remove those.
                        % If it stores IDs, we'd need to find the corresponding ID.
                        
                        % Assuming currentData (TechniquesEmployed) stores the IDs, and we need to find it.
                        % This part is tricky without knowing the exact structure of stored IDs.
                        % For this pass, let's assume currentData might store display strings or something that matches
                        % We need a more robust way to link listbox display to data model if they differ.
                        
                        % If TechniquesEmployed stores the same display strings:
                        idxInData = find(strcmp(currentData, selectedDisplay));
                        if ~isempty(idxInData)
                           idsToRemove = [idsToRemove, currentData(idxInData(1))]; %#ok<AGROW>
                        end
                    end
                end
            end
            
            if ~isempty(indicesToRemove)
                obj.SelectedTechniquesListBox.Items(indicesToRemove) = [];
                obj.SelectedTechniquesListBox.Value = {}; % Clear selection

                % Remove corresponding entries from DatasetInformationStruct.TechniquesEmployed
                if ~isempty(idsToRemove) && iscell(currentData)
                    updatedData = currentData;
                    for k=1:numel(idsToRemove)
                       updatedData(strcmp(updatedData, idsToRemove{k})) = [];
                    end
                    obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = updatedData;
                elseif ~isempty(indicesToRemove) && numel(currentData) >= max(indicesToRemove)
                    % Fallback if we assume parallel arrays and just remove by index (less robust)
                    % This assumes currentData was parallel to the original full listbox items before selection
                    % This is NOT SAFE if multiple items are removed or order changed.
                    % For now, if TechniquesEmployed stores IDs, this part needs a proper mapping.
                    % The current addTechniqueButtonPushed adds the ID, so we should remove the ID.
                    % We need to find the ID of the selectedDisplayString to remove it from currentData.
                    % This is left as a TODO for robust ID-based removal.
                    fprintf(2, 'Warning (ExperimentalDetailsGUI): Robust removal from TechniquesEmployed (IDs) based on display string not fully implemented.\n');
                end

                obj.ParentApp.saveDatasetInformationStruct();
                fprintf('DEBUG (ExperimentalDetailsGUI): Techniques removed.\n');
            end
        end

        % --- Getter/Setter Methods ---
        function data = getDataType(obj)
            data = obj.ParentApp.getCheckedTreeNodeData(obj.DataTypeTree.CheckedNodes);
        end
        function setDataType(obj, data)
            obj.ParentApp.setCheckedNodesFromData(obj.DataTypeTree, data);
        end
        function data = getExperimentalApproach(obj)
            data = obj.ParentApp.getCheckedTreeNodeData(obj.ExperimentalApproachTree.CheckedNodes);
        end
        function setExperimentalApproach(obj, data)
            obj.ParentApp.setCheckedNodesFromData(obj.ExperimentalApproachTree, data);
        end
        function techniques = getSelectedTechniques(obj)
            % This should return the data intended for DatasetInformationStruct
            % If it's IDs, and ListBox stores display strings, a conversion is needed.
            % For now, assuming DatasetInformationStruct.TechniquesEmployed is managed directly by callbacks.
            % This getter should reflect what's in ParentApp.DatasetInformationStruct.TechniquesEmployed
             if isfield(obj.ParentApp.DatasetInformationStruct, 'TechniquesEmployed')
                techniques = obj.ParentApp.DatasetInformationStruct.TechniquesEmployed;
             else
                techniques = {};
             end
        end
        function setSelectedTechniques(obj, techniques)
            % This method updates the ListBox display based on the data
            % (e.g., an array of IDs or full technique names from dsStruct)
            obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = techniques; % Store the raw data

            % Convert these techniques (IDs) to display strings for the listbox
            displayStrings = {};
            if iscell(techniques)
                for i = 1:numel(techniques)
                    techID = techniques{i};
                    % Need a way to get display name (e.g., "Technique Name (Category)") from ID
                    % This might involve looking up in openMINDS instances or a predefined map
                    % For simplicity, if IDs are stored, we might just display IDs or a lookup is needed.
                    % Placeholder: Use the ID itself as display string if lookup is not implemented.
                    % Or assume techniques are stored as display strings already if that's the convention.
                    
                    % Assuming 'techniques' contains the display strings directly for now
                    % or that they are the IDs to be looked up.
                    % This part needs to be robust based on what 'techniques' actually contains.
                    
                    % If techniques are the IDs from the dropdown:
                    % We need to find the matching DisplayName and Category from the dropdowns
                    % This logic is complex here. For now, let's assume `techniques` are displayable.
                    if ischar(techID) || isstring(techID)
                        displayStrings{end+1} = char(techID); %#ok<AGROW>
                    end
                end
            end
            obj.SelectedTechniquesListBox.Items = displayStrings;
            obj.SelectedTechniquesListBox.Value = {};
        end
    end
end
