classdef SubjectInfoGUI < handle
    %SUBJECTINFOGUI Manages UI for the Subject Information tab.

    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % Parent uicontainer for this GUI's elements
        
        % UI Components
        UITableSubject matlab.ui.control.Table
        BiologicalSexListBox matlab.ui.control.ListBox
        SpeciesListBox matlab.ui.control.ListBox
        StrainListBox matlab.ui.control.ListBox
        
        AssignBiologicalSexButton matlab.ui.control.Button
        BiologicalSexClearButton matlab.ui.control.Button
        AssignSpeciesButton matlab.ui.control.Button
        SpeciesClearButton matlab.ui.control.Button
        AssignStrainButton matlab.ui.control.Button
        StrainClearButton matlab.ui.control.Button
        
        SpeciesEditField matlab.ui.control.EditField
        AddSpeciesButton matlab.ui.control.Button
        StrainEditField matlab.ui.control.EditField
        AddStrainButton matlab.ui.control.Button

        % Labels
        BiologicalSexLabel matlab.ui.control.Label
        SpeciesLabel_2 matlab.ui.control.Label % To match original name
        StrainLabel matlab.ui.control.Label
    end

    properties (Access = private)
        ResourcesPath % Path to resources, e.g., for icons
    end

    methods
        function obj = SubjectInfoGUI(parentAppHandle, uiParentContainer)
            obj.ParentApp = parentAppHandle;
            obj.UIBaseContainer = uiParentContainer;

            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources');
                 fprintf(2, 'Warning (SubjectInfoGUI): ParentApp.ResourcesPath not found. Using fallback.\n');
            end
            
            obj.createSubjectInfoUIComponents();
        end

        function initialize(obj)
            % Set up callbacks
            obj.BiologicalSexListBox.ValueChangedFcn = @(~,event) obj.biologicalSexListBoxValueChanged(event);
            obj.BiologicalSexListBox.ClickedFcn = @(~,event) obj.biologicalSexListBoxClicked(event); 
            obj.SpeciesListBox.ValueChangedFcn = @(~,event) obj.speciesListBoxValueChanged(event);
            obj.SpeciesListBox.ClickedFcn = @(~,event) obj.speciesListBoxClicked(event);
            obj.StrainListBox.ValueChangedFcn = @(~,event) obj.strainListBoxValueChanged(event);
            obj.StrainListBox.ClickedFcn = @(~,event) obj.strainListBoxClicked(event);
            obj.StrainListBox.DoubleClickedFcn = @(~,event) obj.strainListBoxDoubleClicked(event);

            obj.AssignBiologicalSexButton.ButtonPushedFcn = @(~,event) obj.assignBiologicalSexButtonPushed(event);
            obj.BiologicalSexClearButton.ButtonPushedFcn = @(~,event) obj.biologicalSexClearButtonPushed(event);
            obj.AssignSpeciesButton.ButtonPushedFcn = @(~,event) obj.assignSpeciesButtonPushed(event);
            obj.SpeciesClearButton.ButtonPushedFcn = @(~,event) obj.speciesClearButtonPushed(event);
            obj.AssignStrainButton.ButtonPushedFcn = @(~,event) obj.assignStrainButtonPushed(event);
            obj.StrainClearButton.ButtonPushedFcn = @(~,event) obj.strainClearButtonPushed(event);
            
            obj.AddSpeciesButton.ButtonPushedFcn = @(~,event) obj.addSpeciesButtonPushed(event);
            obj.AddStrainButton.ButtonPushedFcn = @(~,event) obj.addStrainButtonPushed(event);
            
            obj.populateBiologicalSexList();
            obj.populateSpeciesList();
            obj.populateStrainList(); 

            obj.drawSubjectInfo();
        end

        function createSubjectInfoUIComponents(obj)
            parent = obj.UIBaseContainer; 

            mainGrid = uigridlayout(parent);
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.RowHeight = {'2x', '3x'}; % Corrected from 'fr' to 'x'
            mainGrid.RowSpacing = 20;
            mainGrid.Padding = [10 10 10 10];

            obj.UITableSubject = uitable(mainGrid, 'ColumnName', {'Subject'; 'Biological Sex'; 'Species'; 'Strain'}, 'RowName', {});
            obj.UITableSubject.Layout.Row = 1; obj.UITableSubject.Layout.Column = 1;

            controlsGrid = uigridlayout(mainGrid);
            controlsGrid.Layout.Row = 2; controlsGrid.Layout.Column = 1;
            controlsGrid.ColumnWidth = {'1x','1x','1x'}; 
            controlsGrid.RowHeight = {23,'1x', 'fit', 'fit'}; 
            controlsGrid.ColumnSpacing = 20; controlsGrid.RowSpacing = 5;

            obj.BiologicalSexLabel = uilabel(controlsGrid, 'Text', 'Biological Sex'); 
            obj.BiologicalSexLabel.Layout.Row=1; obj.BiologicalSexLabel.Layout.Column=1;
            obj.BiologicalSexListBox = uilistbox(controlsGrid);
            obj.BiologicalSexListBox.Layout.Row=2; obj.BiologicalSexListBox.Layout.Column=1;
            
            sexButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5); 
            sexButtonsGrid.Layout.Row=3; sexButtonsGrid.Layout.Column=1;
            obj.AssignBiologicalSexButton = uibutton(sexButtonsGrid, 'push', 'Text', 'Assign');
            obj.BiologicalSexClearButton = uibutton(sexButtonsGrid, 'push', 'Text', 'Clear');

            obj.SpeciesLabel_2 = uilabel(controlsGrid, 'Text', 'Species'); 
            obj.SpeciesLabel_2.Layout.Row=1; obj.SpeciesLabel_2.Layout.Column=2;
            obj.SpeciesListBox = uilistbox(controlsGrid);
            obj.SpeciesListBox.Layout.Row=2; obj.SpeciesListBox.Layout.Column=2;

            speciesButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5);
            speciesButtonsGrid.Layout.Row=3; speciesButtonsGrid.Layout.Column=2;
            obj.AssignSpeciesButton = uibutton(speciesButtonsGrid, 'push', 'Text', 'Assign');
            obj.SpeciesClearButton = uibutton(speciesButtonsGrid, 'push', 'Text', 'Clear');

            speciesAddGrid = uigridlayout(controlsGrid, [1,2],'ColumnWidth',{'1x',50}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5); 
            speciesAddGrid.Layout.Row=4; speciesAddGrid.Layout.Column=2;
            obj.SpeciesEditField = uieditfield(speciesAddGrid, 'text', 'Placeholder', 'New species name');
            obj.SpeciesEditField.Layout.Row=1; obj.SpeciesEditField.Layout.Column=1;
            obj.AddSpeciesButton = uibutton(speciesAddGrid, 'push', 'Text', 'Add');
            obj.AddSpeciesButton.Layout.Row=1; obj.AddSpeciesButton.Layout.Column=2;
            
            obj.StrainLabel = uilabel(controlsGrid, 'Text', 'Strain'); 
            obj.StrainLabel.Layout.Row=1; obj.StrainLabel.Layout.Column=3;
            obj.StrainListBox = uilistbox(controlsGrid);
            obj.StrainListBox.Layout.Row=2; obj.StrainListBox.Layout.Column=3;

            strainButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5);
            strainButtonsGrid.Layout.Row=3; strainButtonsGrid.Layout.Column=3;
            obj.AssignStrainButton = uibutton(strainButtonsGrid, 'push', 'Text', 'Assign');
            obj.StrainClearButton = uibutton(strainButtonsGrid, 'push', 'Text', 'Clear');
            
            strainAddGrid = uigridlayout(controlsGrid,[1,2],'ColumnWidth',{'1x',50}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5); 
            strainAddGrid.Layout.Row=4; strainAddGrid.Layout.Column=3;
            obj.StrainEditField = uieditfield(strainAddGrid, 'text', 'Placeholder', 'New strain name');
            obj.StrainEditField.Layout.Row=1; obj.StrainEditField.Layout.Column=1;
            obj.AddStrainButton = uibutton(strainAddGrid, 'push', 'Text', 'Add');
            obj.AddStrainButton.Layout.Row=1; obj.AddStrainButton.Layout.Column=2;
        end

        function drawSubjectInfo(obj)
            fprintf('DEBUG (SubjectInfoGUI): Drawing Subject Info UI (Table).\n');
            subjectTableData = obj.ParentApp.SubjectData.formatTable();
            if ~isempty(subjectTableData) || (isstruct(subjectTableData) && numel(fieldnames(subjectTableData)) > 0)
                try
                    obj.UITableSubject.Data = struct2table(subjectTableData, 'AsArray', true);
                catch ME_table
                     fprintf(2,'Error converting subject data to table: %s\n', ME_table.message);
                     obj.UITableSubject.Data = table();
                end
            else
                obj.UITableSubject.Data = table();
            end
        end

        function populateBiologicalSexList(obj)
            [biologicalSexData, biologicalSexDisplay] = ndi.database.metadata_app.fun.getOpenMindsInstances('BiologicalSex');
            obj.BiologicalSexListBox.Items = biologicalSexDisplay;
            obj.BiologicalSexListBox.ItemsData = biologicalSexData;
            if ~isempty(biologicalSexData) && ~isempty(biologicalSexData{1}) && ~(isstring(biologicalSexData{1}) && ismissing(biologicalSexData{1}))
                obj.BiologicalSexListBox.Value = biologicalSexData{1}; 
            else
                obj.BiologicalSexListBox.Items = {'(No sexes available)'};
                obj.BiologicalSexListBox.ItemsData = {''};
                obj.BiologicalSexListBox.Value = '';
            end
        end

        function populateSpeciesList(obj)
            import ndi.database.metadata_app.fun.expandDropDownItems;
            openMindsType = 'Species';
            speciesCatalog = ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog(openMindsType);
            options_data = string.empty(0,1); names_display = string.empty(0,1);   
            if ~isempty(speciesCatalog)
                options_data = string( {speciesCatalog(:).at_id}' );
                names_display = string( {speciesCatalog(:).name}' );
                options_data(ismissing(options_data)) = ''; 
            end
            [names_display, options_data] = expandDropDownItems(names_display, options_data, openMindsType, "AddSelectOption", true);
            if ~isempty(obj.ParentApp.SpeciesInstancesUser)
                customNames = {obj.ParentApp.SpeciesInstancesUser.name}'; 
                customOptions = customNames; customOptions(ismissing(customOptions)) = ''; 
                names_display = [names_display; customNames]; options_data = [options_data; customOptions]; 
                [names_display, sortIdx] = sort(names_display); options_data = options_data(sortIdx);
            end
            obj.SpeciesListBox.Items = names_display;
            obj.SpeciesListBox.ItemsData = cellstr(options_data); 
            if ~isempty(obj.SpeciesListBox.ItemsData)
                firstValidDataIdx = find(~strcmp(obj.SpeciesListBox.ItemsData, '') & ~cellfun(@(x) isstring(x) && ismissing(x), obj.SpeciesListBox.ItemsData), 1, 'first');
                if ~isempty(firstValidDataIdx), obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{firstValidDataIdx};
                elseif ~isempty(obj.SpeciesListBox.ItemsData) , obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{1}; 
                else, obj.SpeciesListBox.Items = {'(No species available)'}; obj.SpeciesListBox.ItemsData = {''}; obj.SpeciesListBox.Value = ''; end
            else, obj.SpeciesListBox.Items = {'(No species available)'}; obj.SpeciesListBox.ItemsData = {''}; obj.SpeciesListBox.Value = ''; end
        end

        function populateStrainList(obj)
            items_display = "Select a Species"; items_data = {''}; 
            if isprop(obj, 'SpeciesListBox') && ~isempty(obj.SpeciesListBox.Value) && ~(isstring(obj.SpeciesListBox.Value) && ismissing(obj.SpeciesListBox.Value)) && ~strcmp(obj.SpeciesListBox.Value,'')
                selectedSpeciesID = obj.SpeciesListBox.Value; 
                selectedSpeciesDisplayName = '';
                idx = find(strcmp(obj.SpeciesListBox.ItemsData, selectedSpeciesID),1);
                if ~isempty(idx) && idx <= numel(obj.SpeciesListBox.Items), selectedSpeciesDisplayName = obj.SpeciesListBox.Items{idx}; end
                
                if ~isempty(selectedSpeciesDisplayName) && ~strcmp(selectedSpeciesDisplayName, '(No species available)') && ~strcmp(selectedSpeciesDisplayName, 'Select a Species')
                    strainCatalog = obj.ParentApp.getStrainInstances(); 
                    if isprop(strainCatalog,'NumItems') && strainCatalog.NumItems == 0
                        items_display = "No Strains Available"; items_data = {''};
                    elseif isstruct(strainCatalog) && ~isempty(strainCatalog)
                        speciesMatchIdx = arrayfun(@(x) isfield(x,'species') && strcmp(x.species, selectedSpeciesDisplayName), strainCatalog);
                        if ~any(speciesMatchIdx)
                            items_display = "No Strains for this Species"; items_data = {''};
                        else
                            filteredStrains = strainCatalog(speciesMatchIdx);
                            if ~isempty(filteredStrains), items_display = string({filteredStrains.name}'); items_data = cellstr(items_display); 
                            else, items_display = "No Strains for this Species"; items_data = {''}; end
                        end
                    elseif isempty(strainCatalog)
                         items_display = "No Strains Available"; items_data = {''};
                    end
                end
            end
            obj.StrainListBox.Items = items_display; obj.StrainListBox.ItemsData = items_data; 
            if ~isempty(items_data) && ~isempty(items_data{1}) && ~(isstring(items_data{1}) && ismissing(items_data{1})) && ~strcmp(items_data{1},'')
                obj.StrainListBox.Value = items_data{1}; 
            else, obj.StrainListBox.Value = ''; end
        end

        function updateSubjectTableColumnData(obj, columnName, newValue)
            selectedRows = obj.UITableSubject.Selection;
            if isempty(selectedRows), return; end 

            for i = 1:numel(selectedRows)
                subjectIndexInTable = selectedRows(i);
                subjectNameInTable = obj.UITableSubject.Data{subjectIndexInTable, 'SubjectName'}; 
                
                subjectObjIndex = -1;
                for k=1:numel(obj.ParentApp.SubjectData.SubjectList)
                    if strcmp(obj.ParentApp.SubjectData.SubjectList(k).SubjectName, subjectNameInTable)
                        subjectObjIndex = k;
                        break;
                    end
                end

                if subjectObjIndex > 0
                    currentSubjectObj = obj.ParentApp.SubjectData.SubjectList(subjectObjIndex);
                    switch columnName
                        case 'BiologicalSex'
                            currentSubjectObj.BiologicalSexList = {char(newValue)};
                        case 'Species'
                            speciesName = char(newValue); 
                            speciesObj = obj.ParentApp.SpeciesData.getItem(speciesName); 
                            if ~isempty(speciesObj) 
                                currentSubjectObj.SpeciesList = speciesObj; 
                            else 
                                 fprintf('DEBUG (SubjectInfoGUI): Species "%s" not in SpeciesData. Attempting openMINDS lookup.\n', speciesName);
                                 try
                                    omSpecies = openminds.controlledterms.Species('name',speciesName);
                                    currentSubjectObj.SpeciesList = omSpecies; 
                                 catch ME_om
                                     fprintf(2,'Warning: Could not create/assign openminds.controlledterms.Species "%s": %s\n', speciesName, ME_om.message);
                                 end
                            end
                        case 'Strain'
                            currentSubjectObj.addStrain(char(newValue)); 
                    end
                else
                    fprintf(2,'Warning: Subject "%s" not found in SubjectData for update.\n', subjectNameInTable);
                end
            end
            obj.drawSubjectInfo(); 
            obj.ParentApp.saveDatasetInformationStruct();
        end

        function deleteSubjectTableColumnData(obj, columnName)
            selectedRows = obj.UITableSubject.Selection;
            if isempty(selectedRows), return; end

            for i = 1:numel(selectedRows)
                subjectIndexInTable = selectedRows(i);
                subjectNameInTable = obj.UITableSubject.Data{subjectIndexInTable, 'SubjectName'};
                
                subjectObjIndex = -1;
                for k=1:numel(obj.ParentApp.SubjectData.SubjectList)
                    if strcmp(obj.ParentApp.SubjectData.SubjectList(k).SubjectName, subjectNameInTable)
                        subjectObjIndex = k;
                        break;
                    end
                end

                if subjectObjIndex > 0
                    currentSubjectObj = obj.ParentApp.SubjectData.SubjectList(subjectObjIndex);
                    switch columnName
                        case 'BiologicalSex', currentSubjectObj.deleteBiologicalSex();
                        case 'Species'
                            currentSubjectObj.deleteSpeciesList();
                            currentSubjectObj.deleteStrainList(); 
                        case 'Strain', currentSubjectObj.deleteStrainList();
                    end
                end
            end
            obj.drawSubjectInfo(); 
            obj.ParentApp.saveDatasetInformationStruct();
        end

        % --- Callbacks for UI Components ---
        function biologicalSexListBoxValueChanged(obj, event)
            % obj.ParentApp.saveDatasetInformationStruct(); 
        end
        function biologicalSexListBoxClicked(obj, event)
            % obj.updateSubjectTableColumnData('BiologicalSex', obj.BiologicalSexListBox.Value);
        end
        function speciesListBoxValueChanged(obj, event)
            obj.populateStrainList(); 
        end
        function speciesListBoxClicked(obj, event)
            obj.populateStrainList(); 
        end
        function strainListBoxValueChanged(obj, event)
        end
        function strainListBoxClicked(obj, event)
            % obj.updateSubjectTableColumnData('Strain', obj.StrainListBox.Value);
        end
        function strainListBoxDoubleClicked(obj, event)
        end

        function assignBiologicalSexButtonPushed(obj, event)
            obj.updateSubjectTableColumnData('BiologicalSex', obj.BiologicalSexListBox.Value);
        end
        function biologicalSexClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('BiologicalSex');
        end
        function assignSpeciesButtonPushed(obj, event)
            obj.updateSubjectTableColumnData('Species', obj.SpeciesListBox.Value);
            obj.populateStrainList(); 
        end
        function speciesClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('Species');
            obj.populateStrainList(); 
        end
        function assignStrainButtonPushed(obj, event)
             obj.updateSubjectTableColumnData('Strain', obj.StrainListBox.Value);
        end
        function strainClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('Strain');
        end
        
        function addSpeciesButtonPushed(obj, event)
            speciesName = obj.SpeciesEditField.Value;
            if isempty(strtrim(speciesName))
                obj.ParentApp.alert('Please enter a species name to add.', 'Species Name Empty');
                return;
            end
            newSpeciesStruct = struct('name', speciesName, 'ontologyIdentifier', '', 'synonyms', {{}});
            returnedSpeciesStruct = obj.ParentApp.openSpeciesForm(newSpeciesStruct); 
            
            if ~isempty(returnedSpeciesStruct) && isfield(returnedSpeciesStruct, 'name') && ~isempty(strtrim(returnedSpeciesStruct.name))
                obj.ParentApp.SpeciesInstancesUser(end+1) = returnedSpeciesStruct; 
                obj.ParentApp.SpeciesData.addItem(returnedSpeciesStruct.name, returnedSpeciesStruct.ontologyIdentifier, returnedSpeciesStruct.synonyms);
                obj.ParentApp.saveSpecies(); 
                obj.populateSpeciesList(); 
                obj.SpeciesEditField.Value = ''; 
                obj.ParentApp.inform(sprintf('Species "%s" added.', returnedSpeciesStruct.name), 'Species Added');
            else
                obj.ParentApp.inform('Species addition cancelled or failed.', 'Info');
            end
        end

        function addStrainButtonPushed(obj, event)
            strainName = obj.StrainEditField.Value;
            selectedSpeciesName = '';
            if ~isempty(obj.SpeciesListBox.Value)
                idx = strcmp(obj.SpeciesListBox.ItemsData, obj.SpeciesListBox.Value);
                if any(idx)
                    selectedSpeciesName = obj.SpeciesListBox.Items{idx};
                end
            end

            if isempty(strtrim(strainName))
                obj.ParentApp.alert('Please enter a strain name to add.', 'Strain Name Empty'); return;
            end
            if isempty(selectedSpeciesName) || strcmp(selectedSpeciesName, "Select a Species") || strcmp(selectedSpeciesName, "(No species available)")
                 obj.ParentApp.alert('Please select a species before adding a strain.', 'Species Not Selected'); return;
            end
            
            obj.populateStrainList(); 
            obj.StrainEditField.Value = '';
            obj.ParentApp.inform(sprintf('Strain "%s" for species "%s" added (Note: save logic is placeholder).', strainName, selectedSpeciesName), 'Strain Added (Placeholder)');
            obj.ParentApp.saveDatasetInformationStruct(); 
        end
        
        function missingFields = checkRequiredFields(obj)
            % Placeholder: Add checks if SubjectInfo tab has specific required fields
            % beyond what's managed by app.SubjectData object itself.
            % For example, if at least one subject must be present.
            missingFields = string.empty(0,1);
            if isempty(obj.ParentApp.SubjectData.SubjectList)
                % missingFields(end+1) = "At least one Subject"; 
                % This might be too strict, depends on requirements.
            end
        end

        function markRequiredFields(obj)
            % Placeholder: Mark labels of required fields in this GUI
            % e.g. obj.UITableSubjectLabel.Text = [obj.UITableSubjectLabel.Text ' *'];
        end

    end
end

% Helper function for conditional assignment (inline if-else)
function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval;
    else
        result = falseval;
    end
end
