classdef SubjectInfoGUI < handle
    %SUBJECTINFOGUI Manages UI for the Subject Information tab.
    properties (Access = public)
        ParentApp % Handle to the MetadataEditorApp instance
        UIBaseContainer % This will now be obj.SubjectInfoPanel, created by this class
        
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

        % NEW PROPERTIES for base layout elements
        SubjectInfoGridLayout matlab.ui.container.GridLayout
        SubjectInfoLabel matlab.ui.control.Label
        SubjectInfoPanel matlab.ui.container.Panel % Panel where detailed UI is built
    end

    properties (Access = private)
        ResourcesPath % Path to resources, e.g., for icons
    end

    methods
        % MODIFIED CONSTRUCTOR
        function obj = SubjectInfoGUI(parentAppHandle, subjectInfoTabHandle) % Accepts SubjectInfoTab
            obj.ParentApp = parentAppHandle;

            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath;
            else
                guiFilePath = fileparts(mfilename('fullpath'));
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources');
                fprintf(2, 'Warning (SubjectInfoGUI): ParentApp.ResourcesPath not found. Using fallback.\n');
            end
            
            obj.createSubjectInfoTabBaseLayout(subjectInfoTabHandle); % Create base structure in SubjectInfoTab
            obj.createSubjectInfoUIComponents(); % Populate the self-created SubjectInfoPanel
        end

        % NEW METHOD to create the base layout for the Subject Info tab content
        function createSubjectInfoTabBaseLayout(obj, subjectInfoTabHandle)
            % subjectInfoTabHandle is app.SubjectInfoTab passed from MetadataEditorApp
            obj.SubjectInfoGridLayout = uigridlayout(subjectInfoTabHandle, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            obj.SubjectInfoLabel = uilabel(obj.SubjectInfoGridLayout, 'Text', 'Subject Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            obj.SubjectInfoLabel.Layout.Row=1; obj.SubjectInfoLabel.Layout.Column=1;
            obj.SubjectInfoPanel = uipanel(obj.SubjectInfoGridLayout, 'BorderType', 'none');
            obj.SubjectInfoPanel.Layout.Row=2; obj.SubjectInfoPanel.Layout.Column=1;
            
            % Set UIBaseContainer to the newly created SubjectInfoPanel.
            % createSubjectInfoUIComponents will use this as its parent.
            obj.UIBaseContainer = obj.SubjectInfoPanel; 
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
            
            obj.loadSpecies(); 

            obj.populateBiologicalSexList(); 
            obj.populateSpeciesList();  
            obj.populateStrainList();  

            obj.drawSubjectInfo(); 
        end

        function createSubjectInfoUIComponents(obj)
            % This method now uses obj.UIBaseContainer, which is obj.SubjectInfoPanel
            parent = obj.UIBaseContainer; 
            mainGrid = uigridlayout(parent); 
            mainGrid.ColumnWidth = {'1x'}; 
            mainGrid.RowHeight = {'2x', '3x'}; 
            mainGrid.RowSpacing = 20; 
            mainGrid.Padding = [10 10 10 10]; 

            obj.UITableSubject = uitable(mainGrid, 'ColumnName', {'Subject'; 'Biological Sex'; 'Species'; 'Strain'}, 'RowName', {}); 
            obj.UITableSubject.Layout.Row = 1; 
            obj.UITableSubject.Layout.Column = 1; 

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
            subjectTableData = obj.ParentApp.SubjectData.formatTable(); % This returns a struct array

            % Define the variable names for the 4 columns to be displayed
            columnsToDisplay = {'SubjectName', 'BiologicalSexList', 'SpeciesList', 'StrainList'};
            
            % Default to an empty table with the correct display column structure
            % if subjectTableData is empty or leads to an error.
            defaultDisplayTable = table('Size', [0, numel(columnsToDisplay)], ...
                                       'VariableTypes', repmat({'string'}, 1, numel(columnsToDisplay)), ...
                                       'VariableNames', columnsToDisplay);

            if ~isempty(subjectTableData) || (isstruct(subjectTableData) && numel(fieldnames(subjectTableData)) > 0)
                try
                    fullTable = struct2table(subjectTableData, 'AsArray', true); % Convert struct array to table
                    
                    % Check if fullTable is empty (e.g. if subjectTableData was a 0xN struct)
                    if height(fullTable) == 0
                        % If fullTable is empty but has columns, select to get an empty table with correct structure
                        if all(ismember(columnsToDisplay, fullTable.Properties.VariableNames))
                            displayTable = fullTable(:, columnsToDisplay);
                        else
                            fprintf(2, 'Warning (SubjectInfoGUI/drawSubjectInfo): Empty subjectTableData resulted in a table missing expected columns. Using default empty table.\n');
                            displayTable = defaultDisplayTable;
                        end
                    else
                        % Ensure all desired columns exist in non-empty fullTable before selecting
                        missingCols = setdiff(columnsToDisplay, fullTable.Properties.VariableNames);
                        if ~isempty(missingCols)
                            fprintf(2, 'Error (SubjectInfoGUI/drawSubjectInfo): The following expected columns are missing from subjectTableData: %s. Using default empty table.\n', strjoin(missingCols, ', '));
                            displayTable = defaultDisplayTable;
                        else
                            displayTable = fullTable(:, columnsToDisplay);
                        end
                    end
                    obj.UITableSubject.Data = displayTable;
                catch ME_table
                    fprintf(2,'Error converting or subsetting subject data to table: %s\n', ME_table.message);
                    obj.UITableSubject.Data = defaultDisplayTable; % Fallback to correctly structured empty table
                end
            else
                obj.UITableSubject.Data = defaultDisplayTable; % Handles empty or malformed subjectTableData
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
                [names_display, sortIdx] = sort(names_display); 
                options_data = options_data(sortIdx); 
            end
            obj.SpeciesListBox.Items = names_display; 
            obj.SpeciesListBox.ItemsData = cellstr(options_data);  
            if ~isempty(obj.SpeciesListBox.ItemsData) 
                firstValidDataIdx = find(~strcmp(obj.SpeciesListBox.ItemsData, '') & ~cellfun(@(x) isstring(x) && ismissing(x), obj.SpeciesListBox.ItemsData), 1, 'first'); 
                if ~isempty(firstValidDataIdx), obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{firstValidDataIdx}; 
                elseif ~isempty(obj.SpeciesListBox.ItemsData) , obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{1};  
                else, obj.SpeciesListBox.Items = {'(No species available)'}; obj.SpeciesListBox.ItemsData = {''}; 
                obj.SpeciesListBox.Value = ''; end 
            else, obj.SpeciesListBox.Items = {'(No species available)'}; 
            obj.SpeciesListBox.ItemsData = {''}; obj.SpeciesListBox.Value = ''; end 
        end

        function populateStrainList(obj)
            items_display = "Select a Species"; 
            items_data = {''};  
            if isprop(obj, 'SpeciesListBox') && ~isempty(obj.SpeciesListBox.Value) && ~(isstring(obj.SpeciesListBox.Value) && ismissing(obj.SpeciesListBox.Value)) && ~strcmp(obj.SpeciesListBox.Value,'') 
                selectedSpeciesID = obj.SpeciesListBox.Value; 
                selectedSpeciesDisplayName = ''; 
                idx = find(strcmp(obj.SpeciesListBox.ItemsData, selectedSpeciesID),1); 
                if ~isempty(idx) && idx <= numel(obj.SpeciesListBox.Items), selectedSpeciesDisplayName = obj.SpeciesListBox.Items{idx}; end 
                
                if ~isempty(selectedSpeciesDisplayName) && ~strcmp(selectedSpeciesDisplayName, '(No species available)') && ~strcmp(selectedSpeciesDisplayName, 'Select a Species') 
                    strainCatalog = obj.getStrainInstances(); 
                    if isprop(strainCatalog,'NumItems') && strainCatalog.NumItems == 0 
                        items_display = "No Strains Available"; 
                        items_data = {''}; 
                    elseif isstruct(strainCatalog) && ~isempty(strainCatalog) 
                        speciesMatchIdx = arrayfun(@(x) isfield(x,'species') && strcmp(x.species, selectedSpeciesDisplayName), strainCatalog); 
                        if ~any(speciesMatchIdx) 
                            items_display = "No Strains for this Species"; 
                            items_data = {''}; 
                        else
                            filteredStrains = strainCatalog(speciesMatchIdx); 
                            if ~isempty(filteredStrains), items_display = string({filteredStrains.name}'); items_data = cellstr(items_display);  
                            else, items_display = "No Strains for this Species"; items_data = {''}; 
                            end
                        end
                    elseif isempty(strainCatalog) 
                        items_display = "No Strains Available"; 
                        items_data = {''}; 
                    end
                end
            end
            obj.StrainListBox.Items = items_display; 
            obj.StrainListBox.ItemsData = items_data;  
            if ~isempty(items_data) && ~isempty(items_data{1}) && ~(isstring(items_data{1}) && ismissing(items_data{1})) && ~strcmp(items_data{1},'') 
                obj.StrainListBox.Value = items_data{1}; 
            else, obj.StrainListBox.Value = ''; end 
        end

        function updateSubjectTableColumnData(obj, columnName, newValue)
            selectedRows = obj.UITableSubject.Selection; 
            if isempty(selectedRows)
                % obj.ParentApp.inform('Please select a subject from the table first.', 'No Subject Selected'); % Optional
                return; 
            end 

            numTableRows = size(obj.UITableSubject.Data, 1);

            for i = 1:numel(selectedRows) 
                subjectIndexInTable = selectedRows(i); 
                
                if subjectIndexInTable > numTableRows || subjectIndexInTable < 1
                    fprintf(2,'Warning: Selected row index %d is out of bounds for the subject table with %d rows.\n', subjectIndexInTable, numTableRows);
                    continue; 
                end

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
                            speciesValue = char(newValue); % This can be an @id or a name
                            speciesObjToAssign = ndi.database.metadata_app.class.Species.empty(1,0);

                            if startsWith(speciesValue, 'https://openminds.ebrains.eu/instances/species/') || startsWith(speciesValue, 'https://openminds.om-i.org/instances/species/')
                                % It's an @id
                                fprintf('DEBUG (SubjectInfoGUI): Species @id "%s" provided. Parsing and creating local Species object.\n', speciesValue);
                                try
                                    % Attempt to get the openMINDS instance details
                                    parsedOMInstance = ndi.database.metadata_app.fun.parseOpenMINDSAtID(speciesValue);
                                    omInstance = openminds.internal.getControlledInstance(parsedOMInstance.Name, parsedOMInstance.Type); % This gets the openMINDS object
                                    
                                    % Create an instance of your class ndi.database.metadata_app.class.Species
                                    % Ensure your Species class constructor or a factory method can handle this
                                    speciesObjToAssign = ndi.database.metadata_app.class.Species(omInstance.name, speciesValue, omInstance.synonym); %
                                catch ME_om_id
                                    fprintf(2,'Warning: Could not create/assign ndi.database.metadata_app.class.Species for @id "%s": %s\n', speciesValue, ME_om_id.message);
                                end
                            else
                                % Assume speciesValue is a name
                                speciesObjFound = obj.ParentApp.SpeciesData.getItem(speciesValue); 
                                if ~isempty(speciesObjFound) && isa(speciesObjFound, 'ndi.database.metadata_app.class.Species')
                                    speciesObjToAssign = speciesObjFound;
                                else
                                    fprintf('DEBUG (SubjectInfoGUI): Species name "%s" not in local SpeciesData. Attempting openMINDS lookup by name.\n', speciesValue);
                                    try
                                        % This attempts to find/create an openMINDS object by name
                                        omInstance = openminds.controlledterms.Species('name', speciesValue); 
                                        % Convert openMINDS object to your internal Species object
                                        speciesObjToAssign = ndi.database.metadata_app.class.Species(omInstance.name, omInstance.preferredOntologyIdentifier, omInstance.synonym); %
                                    catch ME_om_name
                                        fprintf(2,'Warning: Could not create/assign ndi.database.metadata_app.class.Species for name "%s": %s\n', speciesValue, ME_om_name.message);
                                    end
                                end
                            end
                            
                            if ~isempty(speciesObjToAssign) && isa(speciesObjToAssign, 'ndi.database.metadata_app.class.Species')
                                currentSubjectObj.SpeciesList = speciesObjToAssign; % Assign the correct type
                            else
                                fprintf(2,'Warning: Failed to obtain a valid ndi.database.metadata_app.class.Species object for "%s". Subject.SpeciesList not updated.\n', speciesValue);
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

            numTableRows = size(obj.UITableSubject.Data, 1);

            for i = 1:numel(selectedRows) 
                subjectIndexInTable = selectedRows(i); 
                if subjectIndexInTable > numTableRows || subjectIndexInTable < 1
                    fprintf(2,'Warning: Selected row index %d for deletion is out of bounds for the subject table with %d rows.\n', subjectIndexInTable, numTableRows);
                    continue; 
                end
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

        % --- MOVED METHODS ---
        function loadSpecies(obj) 
            import ndi.database.metadata_app.fun.loadUserInstances
            
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp)
                fprintf(2, 'Error (SubjectInfoGUI/loadSpecies): ParentApp is not valid.\n');
                return;
            end
            if ~isprop(obj.ParentApp, 'SpeciesInstancesUser') || ~isprop(obj.ParentApp, 'SpeciesData')
                fprintf(2, 'Error (SubjectInfoGUI/loadSpecies): ParentApp missing SpeciesInstancesUser or SpeciesData property.\n');
                return;
            end
            if ~isobject(obj.ParentApp.SpeciesData) || ~ismethod(obj.ParentApp.SpeciesData, 'addItem')
                fprintf(2, 'Error (SubjectInfoGUI/loadSpecies): ParentApp.SpeciesData is not a valid object with addItem method.\n');
                return;
            end

            obj.ParentApp.SpeciesInstancesUser = loadUserInstances('species'); 
            [names, ~] = ndi.database.metadata_app.fun.getOpenMindsInstances('Species'); 
            for i = 1:numel(names) 
                thisName = char(names(i)); 
                speciesInstance = openminds.internal.getControlledInstance(thisName, 'Species'); 
                obj.ParentApp.SpeciesData.addItem(speciesInstance.name, speciesInstance.preferredOntologyIdentifier, speciesInstance.synonym); 
            end
            if ~isempty(obj.ParentApp.SpeciesInstancesUser) 
                for i = 1:numel(obj.ParentApp.SpeciesInstancesUser) 
                    speciesInstance = obj.ParentApp.SpeciesInstancesUser(i); 
                    if isfield(speciesInstance, 'name') && isfield(speciesInstance, 'ontologyIdentifier') && isfield(speciesInstance, 'synonyms') 
                        obj.ParentApp.SpeciesData.addItem(speciesInstance.name, speciesInstance.ontologyIdentifier, speciesInstance.synonyms); 
                    else
                        fprintf(2, 'Warning (SubjectInfoGUI/loadSpecies): User species instance missing required fields.\n');
                    end
                end
            end
        end

        function saveSpecies(obj) 
            import ndi.database.metadata_app.fun.saveUserInstances 
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp) || ~isprop(obj.ParentApp, 'SpeciesInstancesUser')
                fprintf(2, 'Error (SubjectInfoGUI/saveSpecies): ParentApp or ParentApp.SpeciesInstancesUser is not valid.\n');
                return;
            end
            saveUserInstances('species', obj.ParentApp.SpeciesInstancesUser); 
        end

        function strainInstances = getStrainInstances(obj) 
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog 
            strainInstances = loadUserInstanceCatalog('Strain'); 
        end
        
        function S = openSpeciesForm(obj, speciesInfoStruct) 
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp) || ~ismethod(obj.ParentApp, 'openForm')
                fprintf(2, 'Error (SubjectInfoGUI/openSpeciesForm): ParentApp is not valid or missing openForm method.\n');
                S = struct.empty;
                return;
            end
            editExisting = (nargin > 1 && ~isempty(speciesInfoStruct)); 
            S = obj.ParentApp.openForm('Species', speciesInfoStruct, editExisting); 
        end
        
        % --- Callbacks for UI Components ---
        function biologicalSexListBoxValueChanged(obj, event)
        end
        function biologicalSexListBoxClicked(obj, event)
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
            returnedSpeciesStruct = obj.openSpeciesForm(newSpeciesStruct); 
            
            if ~isempty(returnedSpeciesStruct) && isfield(returnedSpeciesStruct, 'name') && ~isempty(strtrim(returnedSpeciesStruct.name)) 
                obj.ParentApp.SpeciesInstancesUser(end+1) = returnedSpeciesStruct; 
                obj.ParentApp.SpeciesData.addItem(returnedSpeciesStruct.name, returnedSpeciesStruct.ontologyIdentifier, returnedSpeciesStruct.synonyms); 
                obj.saveSpecies(); 
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
                obj.ParentApp.alert('Please enter a strain name to add.', 'Strain Name Empty'); 
                return; 
            end
            if isempty(selectedSpeciesName) || strcmp(selectedSpeciesName, "Select a Species") || strcmp(selectedSpeciesName, "(No species available)") 
                obj.ParentApp.alert('Please select a species before adding a strain.', 'Species Not Selected'); 
                return; 
            end
            
            % Placeholder: Actual saving/management of strains would go here.
            % For example, adding to obj.ParentApp.SpeciesData if it can store strains,
            % or saving to a user instances file for strains.
            % Currently, this just informs and saves the main struct.
            
            obj.populateStrainList(); 
            obj.StrainEditField.Value = ''; 
            obj.ParentApp.inform(sprintf('Strain "%s" for species "%s" added (Note: save logic is placeholder).', strainName, selectedSpeciesName), 'Strain Added (Placeholder)'); 
            obj.ParentApp.saveDatasetInformationStruct(); 
        end
        
        function missingFields = checkRequiredFields(obj)
            missingFields = string.empty(0,1); 
            if isempty(obj.ParentApp.SubjectData.SubjectList) 
                % missingFields(end+1) = "At least one Subject"; 
            end
        end

        function markRequiredFields(obj)
            % Placeholder: Mark labels of required fields in this GUI 
            % e.g. 
            % obj.UITableSubjectLabel.Text = [obj.UITableSubjectLabel.Text ' *']; 
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
