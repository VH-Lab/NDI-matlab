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
        ResourcesPath % Path to resources directory (parent of 'icons')
    end

    methods
        function obj = ExperimentalDetailsGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;

            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources'); 
                if ~isfolder(obj.ResourcesPath)
                    fprintf(2, 'Warning (ExperimentalDetailsGUI): Calculated ResourcesPath does not exist: %s\n', obj.ResourcesPath);
                    projectRootGuess = fullfile(guiFilePath, '..', '..', '..', '..'); 
                    fallbackPath = fullfile(projectRootGuess, 'resources');
                    if isfolder(fallbackPath)
                        obj.ResourcesPath = fallbackPath;
                    else
                         fprintf(2, 'Warning (ExperimentalDetailsGUI): Fallback project-level ResourcesPath also does not exist: %s\n', fallbackPath);
                    end
                end
            end
            obj.createExperimentalDetailsUIComponents();
        end

        function initialize(obj)
            obj.DataTypeTree.CheckedNodesChangedFcn = @(~,event) obj.dataTypeTreeCheckedNodesChanged(event);
            obj.ExperimentalApproachTree.CheckedNodesChangedFcn = @(~,event) obj.experimentalApproachTreeCheckedNodesChanged(event);
            obj.SelectTechniqueCategoryDropDown.ValueChangedFcn = @(~,event) obj.selectTechniqueCategoryDropDownValueChanged(event);
            obj.AddTechniqueButton.ButtonPushedFcn = @(~,~) obj.addTechniqueButtonPushed();
            obj.RemoveTechniqueButton.ButtonPushedFcn = @(~,~) obj.removeTechniqueButtonPushed();

            obj.populateDataTypeTree();
            obj.populateExperimentalApproachTree();
            obj.populateTechniqueCategoryDropdown();
            obj.populateTechniqueDropdown(''); 
            obj.drawExperimentalDetails();
        end

        function createExperimentalDetailsUIComponents(obj)
            parent = obj.UIBaseContainer;
            iconsBasePath = obj.ResourcesPath; 

            gridLayout = uigridlayout(parent, [9 6], ...
                'ColumnWidth', {180, 45, '1.25x', 45, '1x', 30}, ... 
                'RowHeight', {22, 22, 22, 23, '1x', 22, 23, '1x', '1x'}, ... 
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
            
            obj.AddTechniqueButton = uibutton(gridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsBasePath, 'icons', 'plus.png'));
            obj.AddTechniqueButton.Layout.Row = 4; obj.AddTechniqueButton.Layout.Column = 6;
            
            obj.SelectedTechniquesListBoxLabel = uilabel(gridLayout, 'Text', 'Selected Techniques');
            obj.SelectedTechniquesListBoxLabel.Layout.Row = 6; obj.SelectedTechniquesListBoxLabel.Layout.Column = 5;
            obj.SelectedTechniquesListBox = uilistbox(gridLayout);
            obj.SelectedTechniquesListBox.Layout.Row = [7 8]; obj.SelectedTechniquesListBox.Layout.Column = 5; 
            
            obj.RemoveTechniqueButton = uibutton(gridLayout, 'push', 'Text', '', 'Icon', fullfile(iconsBasePath, 'icons', 'minus.png'));
            obj.RemoveTechniqueButton.Layout.Row = 7; obj.RemoveTechniqueButton.Layout.Column = 6;
        end

        function drawExperimentalDetails(obj)
            fprintf('DEBUG (ExperimentalDetailsGUI): Drawing Experimental Details UI.\n');
            dsStruct = obj.ParentApp.DatasetInformationStruct;

            if isfield(dsStruct, 'DataType')
                obj.ParentApp.setCheckedNodesFromData(obj.DataTypeTree, dsStruct.DataType);
            else
                obj.ParentApp.setCheckedNodesFromData(obj.DataTypeTree, {});
            end

            if isfield(dsStruct, 'ExperimentalApproach')
                obj.ParentApp.setCheckedNodesFromData(obj.ExperimentalApproachTree, dsStruct.ExperimentalApproach);
            else
                obj.ParentApp.setCheckedNodesFromData(obj.ExperimentalApproachTree, {});
            end

            if isfield(dsStruct, 'TechniquesEmployed') 
                obj.setSelectedTechniques(dsStruct.TechniquesEmployed); % This populates the ListBox
            else
                obj.SelectedTechniquesListBox.Items = {};
                obj.SelectedTechniquesListBox.Value = {};
            end
        end

        % --- Population Methods ---
        function populateDataTypeTree(obj)
            ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox(obj.DataTypeTree, "SemanticDataType");
        end

        function populateExperimentalApproachTree(obj)
            ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox(obj.ExperimentalApproachTree, "ExperimentalApproach");
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
        end

        % --- Callbacks ---
        function dataTypeTreeCheckedNodesChanged(obj, event)
            selectedData = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes);
            obj.ParentApp.DatasetInformationStruct.DataType = selectedData;
            if ~isempty(selectedData)
                obj.ParentApp.resetLabelForRequiredField('DataType');
            else
                requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
                if isfield(requiredFields, 'DataType') && requiredFields.DataType
                    obj.ParentApp.highlightLabelForRequiredField('DataType');
                end
            end
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function experimentalApproachTreeCheckedNodesChanged(obj, event)
            selectedData = obj.ParentApp.getCheckedTreeNodeData(event.CheckedNodes);
            obj.ParentApp.DatasetInformationStruct.ExperimentalApproach = selectedData;
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function selectTechniqueCategoryDropDownValueChanged(obj, event)
            value = obj.SelectTechniqueCategoryDropDown.Value;
            obj.populateTechniqueDropdown(value); 
        end

        function addTechniqueButtonPushed(obj, event)
            techniqueCategory = obj.SelectTechniqueCategoryDropDown.Value;
            techniqueID = char(obj.SelectTechniqueDropDown.Value); 
            
            isPlaceholderID = false;
            if isempty(techniqueID) || strcmp(techniqueID, "")
                isPlaceholderID = true;
            else 
                if ~isempty(obj.SelectTechniqueDropDown.ItemsData) && strcmp(techniqueID, obj.SelectTechniqueDropDown.ItemsData{1}) && strcmp(obj.SelectTechniqueDropDown.ItemsData{1},"")
                    isPlaceholderID = true; 
                end
            end
            
            if isPlaceholderID || strcmp(techniqueCategory, "Select Category")
                obj.ParentApp.inform('Please select a valid technique category and technique from the list.', 'Selection Invalid');
                return;
            end

            idx_for_display = find(strcmp(obj.SelectTechniqueDropDown.ItemsData, techniqueID));
            actualDisplayName = '';
            if ~isempty(idx_for_display)
                idx_for_display = idx_for_display(1);
                if idx_for_display <= numel(obj.SelectTechniqueDropDown.Items)
                    actualDisplayName = obj.SelectTechniqueDropDown.Items{idx_for_display};
                else
                    obj.ParentApp.alert('Internal error: Mismatch in technique dropdown items. Please report.','Error'); return;
                end
            else
                 obj.ParentApp.alert(sprintf('Selected technique ID "%s" not found in internal data. Please re-select from the list.', techniqueID), 'Selection Error'); return;
            end
            
            techniqueDisplayString = sprintf('%s (%s)', actualDisplayName, techniqueCategory);
            
            if any(strcmp(obj.SelectedTechniquesListBox.Items, techniqueDisplayString))
                obj.ParentApp.inform(sprintf('The technique "%s" has already been added.', techniqueDisplayString), 'Duplicate Technique'); 
                return;
            end
            
            obj.SelectedTechniquesListBox.Items{end+1} = techniqueDisplayString; 
            obj.updateTechniquesEmployedFromListBox(); % This will update dsStruct and save
        end

        function removeTechniqueButtonPushed(obj, event)
            selectedDisplayItem_char = char(obj.SelectedTechniquesListBox.Value); 
            if isempty(selectedDisplayItem_char)
                obj.ParentApp.inform('Please select a technique to remove.', 'No Selection');
                return;
            end
            
            currentItems_Display = obj.SelectedTechniquesListBox.Items;
            idxInListbox = find(strcmp(currentItems_Display, selectedDisplayItem_char), 1);
            
            if isempty(idxInListbox)
                fprintf(2, 'Warning (removeTechniqueButtonPushed): Selected display string "%s" not found in ListBox items.\n', selectedDisplayItem_char);
                return;
            end
            
            obj.SelectedTechniquesListBox.Items(idxInListbox) = [];
            obj.SelectedTechniquesListBox.Value = {}; 
            
            obj.updateTechniquesEmployedFromListBox(); % This will update dsStruct and save
        end
        
        function updateTechniquesEmployedFromListBox(obj)
            % Reads all items from SelectedTechniquesListBox, converts them to IDs,
            % and updates DatasetInformationStruct.TechniquesEmployed.
            fprintf('DEBUG (updateTechniquesEmployedFromListBox): Updating data model from listbox.\n');
            listBoxItems_Display = obj.SelectedTechniquesListBox.Items;
            newTechniqueIDs = {};

            if isempty(listBoxItems_Display)
                obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = {};
                obj.ParentApp.saveDatasetInformationStruct();
                fprintf('DEBUG (updateTechniquesEmployedFromListBox): ListBox is empty. TechniquesEmployed set to {}.\n');
                return;
            end

            for i = 1:numel(listBoxItems_Display)
                displayString = listBoxItems_Display{i};
                match = regexp(displayString, '^(.*) \((.*)\)$', 'tokens');
                if ~isempty(match)
                    displayNamePart = strtrim(match{1}{1});
                    categoryNamePart = strtrim(match{1}{2});
                    
                    idFound = '';
                    % Temporarily populate technique dropdown for this category to get its items/data
                    % This is necessary to map display name + category back to ID
                    originalCatDropdownVal = obj.SelectTechniqueCategoryDropDown.Value;
                    originalTechDropdownItems = obj.SelectTechniqueDropDown.Items;
                    originalTechDropdownItemsData = obj.SelectTechniqueDropDown.ItemsData;
                    originalTechDropdownValue = obj.SelectTechniqueDropDown.Value;

                    obj.populateTechniqueDropdown(categoryNamePart); % Populates SelectTechniqueDropDown for this category
                    
                    currentTechDropdownItems = obj.SelectTechniqueDropDown.Items;
                    currentTechDropdownItemsData = obj.SelectTechniqueDropDown.ItemsData;

                    for dd_idx = 1:numel(currentTechDropdownItems)
                        if strcmp(currentTechDropdownItems{dd_idx}, displayNamePart) && dd_idx <= numel(currentTechDropdownItemsData)
                            idFound = currentTechDropdownItemsData{dd_idx};
                            break;
                        end
                    end
                    
                    % Restore original technique dropdown state
                    obj.SelectTechniqueCategoryDropDown.Value = originalCatDropdownVal; % Set category back
                    obj.populateTechniqueDropdown(originalCatDropdownVal); % Re-populate for original category
                    obj.SelectTechniqueDropDown.Value = originalTechDropdownValue; % Attempt to restore selection

                    if ~isempty(idFound) && ~strcmp(idFound,"")
                        newTechniqueIDs{end+1} = idFound; %#ok<AGROW>
                    else
                        fprintf(2,'Warning (updateTechniquesEmployedFromListBox): Could not map display "%s" back to an ID.\n', displayString);
                    end
                else
                    fprintf(2,'Warning (updateTechniquesEmployedFromListBox): Could not parse display string "%s".\n', displayString);
                end
            end
            
            obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = newTechniqueIDs;
            obj.ParentApp.saveDatasetInformationStruct();
            fprintf('DEBUG (updateTechniquesEmployedFromListBox): TechniquesEmployed in dsStruct updated to: %s\n', strjoin(newTechniqueIDs, '; '));
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
        function techniques_ids = getSelectedTechniques(obj)
             currentTechniques = {}; 
             if isfield(obj.ParentApp.DatasetInformationStruct, 'TechniquesEmployed')
                rawData = obj.ParentApp.DatasetInformationStruct.TechniquesEmployed;
                if iscell(rawData)
                    currentTechniques = rawData;
                elseif ~isempty(rawData) 
                    currentTechniques = {char(rawData)}; 
                end
                if ~isempty(currentTechniques)
                    currentTechniques(cellfun('isempty', currentTechniques)) = [];
                end
             end
             techniques_ids = currentTechniques;
        end
        function setSelectedTechniques(obj, techniques_data_ids) 
            if ~iscell(techniques_data_ids)
                if ischar(techniques_data_ids) || isstring(techniques_data_ids)
                    if isempty(techniques_data_ids) || (isstring(techniques_data_ids) && techniques_data_ids == "")
                        techniques_data_ids = {};
                    else
                        techniques_data_ids = {char(techniques_data_ids)}; 
                    end
                else
                    techniques_data_ids = {}; 
                end
            else 
                techniques_data_ids = cellfun(@char, techniques_data_ids, 'UniformOutput', false);
                techniques_data_ids(cellfun('isempty', techniques_data_ids)) = [];
            end
            
            obj.ParentApp.DatasetInformationStruct.TechniquesEmployed = techniques_data_ids; 
            fprintf('DEBUG (setSelectedTechniques): TechniquesEmployed in dsStruct set to: %s\n', strjoin(techniques_data_ids, ' | '));

            displayStrings = {};
            if ~isempty(techniques_data_ids)
                allCategories = obj.SelectTechniqueCategoryDropDown.Items;
                idToDisplayInfoMap = containers.Map('KeyType', 'char', 'ValueType', 'any');

                originalCatVal = obj.SelectTechniqueCategoryDropDown.Value;
                originalTechVal = obj.SelectTechniqueDropDown.Value;
                originalTechItems = obj.SelectTechniqueDropDown.Items;
                originalTechItemsData = obj.SelectTechniqueDropDown.ItemsData;

                for cat_idx = 1:numel(allCategories)
                    categoryName = allCategories{cat_idx};
                    if strcmp(categoryName, "Select Category"), continue; end
                    
                    obj.populateTechniqueDropdown(categoryName); % Temporarily populate to build map
                    temp_ids = obj.SelectTechniqueDropDown.ItemsData;
                    temp_displayNames = obj.SelectTechniqueDropDown.Items;

                    for id_idx = 1:numel(temp_ids)
                        if ~isempty(temp_ids{id_idx}) && ~isKey(idToDisplayInfoMap, temp_ids{id_idx}) && id_idx <= numel(temp_displayNames)
                           idToDisplayInfoMap(temp_ids{id_idx}) = struct('name', temp_displayNames{id_idx}, 'category', categoryName);
                        end
                    end
                end
                
                % Restore original state of dropdowns
                obj.SelectTechniqueCategoryDropDown.Value = originalCatVal;
                obj.SelectTechniqueDropDown.Items = originalTechItems;
                obj.SelectTechniqueDropDown.ItemsData = originalTechItemsData;
                obj.SelectTechniqueDropDown.Value = originalTechVal;


                for i = 1:numel(techniques_data_ids)
                    tech_id = char(techniques_data_ids{i});
                    if isempty(tech_id), continue; end
                    
                    if isKey(idToDisplayInfoMap, tech_id)
                        info = idToDisplayInfoMap(tech_id);
                        displayStrings{end+1} = sprintf('%s (%s)', info.name, info.category); %#ok<AGROW>
                    else
                        displayStrings{end+1} = tech_id; %#ok<AGROW>
                         fprintf('Warning (setSelectedTechniques): Could not find full display info for technique ID: %s. Displaying ID.\n', tech_id);
                    end
                end
            end
            obj.SelectedTechniquesListBox.Items = displayStrings;
            obj.SelectedTechniquesListBox.Value = {};
        end
    end
end
