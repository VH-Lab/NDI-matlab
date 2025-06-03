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
            obj.ParentApp = parentAppHandle; %

            if isprop(obj.ParentApp, 'ResourcesPath') && isfolder(obj.ParentApp.ResourcesPath)
                obj.ResourcesPath = obj.ParentApp.ResourcesPath; %
            else
                guiFilePath = fileparts(mfilename('fullpath')); %
                obj.ResourcesPath = fullfile(guiFilePath, '..', '+Apps', 'resources'); %
                 fprintf(2, 'Warning (SubjectInfoGUI): ParentApp.ResourcesPath not found. Using fallback.\n'); %
            end
            
            obj.createSubjectInfoTabBaseLayout(subjectInfoTabHandle); % Create base structure in SubjectInfoTab [cite: 1924]
            obj.createSubjectInfoUIComponents(); % Populate the self-created SubjectInfoPanel [cite: 1924]
        end

        % NEW METHOD to create the base layout for the Subject Info tab content
        function createSubjectInfoTabBaseLayout(obj, subjectInfoTabHandle)
            % subjectInfoTabHandle is app.SubjectInfoTab passed from MetadataEditorApp
            obj.SubjectInfoGridLayout = uigridlayout(subjectInfoTabHandle, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]); %
            obj.SubjectInfoLabel = uilabel(obj.SubjectInfoGridLayout, 'Text', 'Subject Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold'); %
            obj.SubjectInfoLabel.Layout.Row=1; obj.SubjectInfoLabel.Layout.Column=1; %
            obj.SubjectInfoPanel = uipanel(obj.SubjectInfoGridLayout, 'BorderType', 'none'); %
            obj.SubjectInfoPanel.Layout.Row=2; obj.SubjectInfoPanel.Layout.Column=1; %
            
            % Set UIBaseContainer to the newly created SubjectInfoPanel.
            % createSubjectInfoUIComponents will use this as its parent.
            obj.UIBaseContainer = obj.SubjectInfoPanel; 
        end

        function initialize(obj)
            % Set up callbacks
            obj.BiologicalSexListBox.ValueChangedFcn = @(~,event) obj.biologicalSexListBoxValueChanged(event); % [cite: 1925]
            obj.BiologicalSexListBox.ClickedFcn = @(~,event) obj.biologicalSexListBoxClicked(event);  % [cite: 1926]
            obj.SpeciesListBox.ValueChangedFcn = @(~,event) obj.speciesListBoxValueChanged(event); % [cite: 1926]
            obj.SpeciesListBox.ClickedFcn = @(~,event) obj.speciesListBoxClicked(event); % [cite: 1926]
            obj.StrainListBox.ValueChangedFcn = @(~,event) obj.strainListBoxValueChanged(event); % [cite: 1926]
            obj.StrainListBox.ClickedFcn = @(~,event) obj.strainListBoxClicked(event);  % [cite: 1927]
            obj.StrainListBox.DoubleClickedFcn = @(~,event) obj.strainListBoxDoubleClicked(event); % [cite: 1927]

            obj.AssignBiologicalSexButton.ButtonPushedFcn = @(~,event) obj.assignBiologicalSexButtonPushed(event); % [cite: 1927]
            obj.BiologicalSexClearButton.ButtonPushedFcn = @(~,event) obj.biologicalSexClearButtonPushed(event); % [cite: 1927]
            obj.AssignSpeciesButton.ButtonPushedFcn = @(~,event) obj.assignSpeciesButtonPushed(event); % [cite: 1927]
            obj.SpeciesClearButton.ButtonPushedFcn = @(~,event) obj.speciesClearButtonPushed(event);  % [cite: 1928]
            obj.AssignStrainButton.ButtonPushedFcn = @(~,event) obj.assignStrainButtonPushed(event); % [cite: 1928]
            obj.StrainClearButton.ButtonPushedFcn = @(~,event) obj.strainClearButtonPushed(event); % [cite: 1928]
            
            obj.AddSpeciesButton.ButtonPushedFcn = @(~,event) obj.addSpeciesButtonPushed(event);  % [cite: 1928]
            obj.AddStrainButton.ButtonPushedFcn = @(~,event) obj.addStrainButtonPushed(event); % [cite: 1928]
            
            obj.loadSpecies(); 

            obj.populateBiologicalSexList(); % [cite: 1928]
            obj.populateSpeciesList();  % [cite: 1929]
            obj.populateStrainList();  % [cite: 1929]

            obj.drawSubjectInfo(); % [cite: 1929]
        end

        function createSubjectInfoUIComponents(obj)
            % This method now uses obj.UIBaseContainer, which is obj.SubjectInfoPanel
            parent = obj.UIBaseContainer; 
            mainGrid = uigridlayout(parent); % [cite: 1930]
            mainGrid.ColumnWidth = {'1x'}; % [cite: 1930]
            mainGrid.RowHeight = {'2x', '3x'}; % [cite: 1930]
            mainGrid.RowSpacing = 20; % [cite: 1931]
            mainGrid.Padding = [10 10 10 10]; % [cite: 1932]

            obj.UITableSubject = uitable(mainGrid, 'ColumnName', {'Subject'; 'Biological Sex'; 'Species'; 'Strain'}, 'RowName', {}); % [cite: 1932]
            obj.UITableSubject.Layout.Row = 1; % [cite: 1932]
            obj.UITableSubject.Layout.Column = 1; % [cite: 1933]

            controlsGrid = uigridlayout(mainGrid); % [cite: 1933]
            controlsGrid.Layout.Row = 2; controlsGrid.Layout.Column = 1; % [cite: 1933]
            controlsGrid.ColumnWidth = {'1x','1x','1x'};  % [cite: 1933]
            controlsGrid.RowHeight = {23,'1x', 'fit', 'fit'}; % [cite: 1933]
            controlsGrid.ColumnSpacing = 20; controlsGrid.RowSpacing = 5; % [cite: 1934]

            obj.BiologicalSexLabel = uilabel(controlsGrid, 'Text', 'Biological Sex');  % [cite: 1934]
            obj.BiologicalSexLabel.Layout.Row=1; obj.BiologicalSexLabel.Layout.Column=1; % [cite: 1934]
            obj.BiologicalSexListBox = uilistbox(controlsGrid); % [cite: 1934]
            obj.BiologicalSexListBox.Layout.Row=2; obj.BiologicalSexListBox.Layout.Column=1; % [cite: 1934]
            sexButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5);  % [cite: 1935]
            sexButtonsGrid.Layout.Row=3; sexButtonsGrid.Layout.Column=1; % [cite: 1935]
            obj.AssignBiologicalSexButton = uibutton(sexButtonsGrid, 'push', 'Text', 'Assign'); % [cite: 1935]
            obj.BiologicalSexClearButton = uibutton(sexButtonsGrid, 'push', 'Text', 'Clear'); % [cite: 1936]

            obj.SpeciesLabel_2 = uilabel(controlsGrid, 'Text', 'Species');  % [cite: 1936]
            obj.SpeciesLabel_2.Layout.Row=1; obj.SpeciesLabel_2.Layout.Column=2; % [cite: 1936]
            obj.SpeciesListBox = uilistbox(controlsGrid); % [cite: 1936]
            obj.SpeciesListBox.Layout.Row=2; obj.SpeciesListBox.Layout.Column=2; % [cite: 1937]
            speciesButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5); % [cite: 1937]
            speciesButtonsGrid.Layout.Row=3; speciesButtonsGrid.Layout.Column=2; % [cite: 1937]
            obj.AssignSpeciesButton = uibutton(speciesButtonsGrid, 'push', 'Text', 'Assign'); % [cite: 1937]
            obj.SpeciesClearButton = uibutton(speciesButtonsGrid, 'push', 'Text', 'Clear'); % [cite: 1938]

            speciesAddGrid = uigridlayout(controlsGrid, [1,2],'ColumnWidth',{'1x',50}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5);  % [cite: 1938]
            speciesAddGrid.Layout.Row=4; speciesAddGrid.Layout.Column=2; % [cite: 1939]
            obj.SpeciesEditField = uieditfield(speciesAddGrid, 'text', 'Placeholder', 'New species name'); % [cite: 1939]
            obj.SpeciesEditField.Layout.Row=1; obj.SpeciesEditField.Layout.Column=1; % [cite: 1939]
            obj.AddSpeciesButton = uibutton(speciesAddGrid, 'push', 'Text', 'Add'); % [cite: 1939]
            obj.AddSpeciesButton.Layout.Row=1; obj.AddSpeciesButton.Layout.Column=2; % [cite: 1939]
            obj.StrainLabel = uilabel(controlsGrid, 'Text', 'Strain');  % [cite: 1940]
            obj.StrainLabel.Layout.Row=1; obj.StrainLabel.Layout.Column=3; % [cite: 1940]
            obj.StrainListBox = uilistbox(controlsGrid); % [cite: 1940]
            obj.StrainListBox.Layout.Row=2; obj.StrainListBox.Layout.Column=3; % [cite: 1941]
            strainButtonsGrid = uigridlayout(controlsGrid, [1,2], 'Padding', [0 0 0 0], 'ColumnSpacing', 5); % [cite: 1941]
            strainButtonsGrid.Layout.Row=3; strainButtonsGrid.Layout.Column=3; % [cite: 1941]
            obj.AssignStrainButton = uibutton(strainButtonsGrid, 'push', 'Text', 'Assign'); % [cite: 1941]
            obj.StrainClearButton = uibutton(strainButtonsGrid, 'push', 'Text', 'Clear'); % [cite: 1942]
            
            strainAddGrid = uigridlayout(controlsGrid,[1,2],'ColumnWidth',{'1x',50}, 'Padding', [0 0 0 0], 'ColumnSpacing', 5);  % [cite: 1942]
            strainAddGrid.Layout.Row=4; strainAddGrid.Layout.Column=3; % [cite: 1943]
            obj.StrainEditField = uieditfield(strainAddGrid, 'text', 'Placeholder', 'New strain name'); % [cite: 1943]
            obj.StrainEditField.Layout.Row=1; obj.StrainEditField.Layout.Column=1; % [cite: 1943]
            obj.AddStrainButton = uibutton(strainAddGrid, 'push', 'Text', 'Add'); % [cite: 1943]
            obj.AddStrainButton.Layout.Row=1; obj.AddStrainButton.Layout.Column=2; % [cite: 1944]
        end

        function drawSubjectInfo(obj)
            fprintf('DEBUG (SubjectInfoGUI): Drawing Subject Info UI (Table).\n'); % [cite: 1944]
            subjectTableData = obj.ParentApp.SubjectData.formatTable(); % [cite: 1945]
            if ~isempty(subjectTableData) || (isstruct(subjectTableData) && numel(fieldnames(subjectTableData)) > 0) % [cite: 1945]
                try
                    obj.UITableSubject.Data = struct2table(subjectTableData, 'AsArray', true); % [cite: 1945]
                catch ME_table %
                     fprintf(2,'Error converting subject data to table: %s\n', ME_table.message); % [cite: 1946]
                     obj.UITableSubject.Data = table(); % [cite: 1947]
                end
            else
                obj.UITableSubject.Data = table(); % [cite: 1948]
            end
        end

        function populateBiologicalSexList(obj)
            [biologicalSexData, biologicalSexDisplay] = ndi.database.metadata_app.fun.getOpenMindsInstances('BiologicalSex'); % [cite: 1948]
            obj.BiologicalSexListBox.Items = biologicalSexDisplay; % [cite: 1949]
            obj.BiologicalSexListBox.ItemsData = biologicalSexData; % [cite: 1949]
            if ~isempty(biologicalSexData) && ~isempty(biologicalSexData{1}) && ~(isstring(biologicalSexData{1}) && ismissing(biologicalSexData{1})) % [cite: 1949]
                obj.BiologicalSexListBox.Value = biologicalSexData{1}; % [cite: 1950]
            else
                obj.BiologicalSexListBox.Items = {'(No sexes available)'}; % [cite: 1950]
                obj.BiologicalSexListBox.ItemsData = {''}; % [cite: 1951]
                obj.BiologicalSexListBox.Value = ''; % [cite: 1951]
            end
        end

        function populateSpeciesList(obj)
            import ndi.database.metadata_app.fun.expandDropDownItems; % [cite: 1951]
            openMindsType = 'Species'; % [cite: 1952]
            speciesCatalog = ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog(openMindsType); % [cite: 1952]
            options_data = string.empty(0,1); names_display = string.empty(0,1); % [cite: 1952]
            if ~isempty(speciesCatalog) % [cite: 1953]
                options_data = string( {speciesCatalog(:).at_id}' ); % [cite: 1953]
                names_display = string( {speciesCatalog(:).name}' ); % [cite: 1954]
                options_data(ismissing(options_data)) = '';  % [cite: 1954]
            end
            [names_display, options_data] = expandDropDownItems(names_display, options_data, openMindsType, "AddSelectOption", true); % [cite: 1954]
            if ~isempty(obj.ParentApp.SpeciesInstancesUser) % [cite: 1955]
                customNames = {obj.ParentApp.SpeciesInstancesUser.name}'; % [cite: 1955]
                customOptions = customNames; customOptions(ismissing(customOptions)) = '';  % [cite: 1956]
                names_display = [names_display; customNames]; options_data = [options_data; customOptions];  % [cite: 1956]
                [names_display, sortIdx] = sort(names_display); % [cite: 1957]
                options_data = options_data(sortIdx); % [cite: 1957]
            end
            obj.SpeciesListBox.Items = names_display; % [cite: 1957]
            obj.SpeciesListBox.ItemsData = cellstr(options_data);  % [cite: 1958]
            if ~isempty(obj.SpeciesListBox.ItemsData) % [cite: 1958]
                firstValidDataIdx = find(~strcmp(obj.SpeciesListBox.ItemsData, '') & ~cellfun(@(x) isstring(x) && ismissing(x), obj.SpeciesListBox.ItemsData), 1, 'first'); % [cite: 1959]
                if ~isempty(firstValidDataIdx), obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{firstValidDataIdx}; % [cite: 1959]
                elseif ~isempty(obj.SpeciesListBox.ItemsData) , obj.SpeciesListBox.Value = obj.SpeciesListBox.ItemsData{1};  % [cite: 1959]
                else, obj.SpeciesListBox.Items = {'(No species available)'}; obj.SpeciesListBox.ItemsData = {''}; % [cite: 1960]
                obj.SpeciesListBox.Value = ''; end % [cite: 1960]
            else, obj.SpeciesListBox.Items = {'(No species available)'}; % [cite: 1960]
            obj.SpeciesListBox.ItemsData = {''}; obj.SpeciesListBox.Value = ''; end % [cite: 1961]
        end

        function populateStrainList(obj)
            items_display = "Select a Species"; % [cite: 1961]
            items_data = {''};  % [cite: 1962]
            if isprop(obj, 'SpeciesListBox') && ~isempty(obj.SpeciesListBox.Value) && ~(isstring(obj.SpeciesListBox.Value) && ismissing(obj.SpeciesListBox.Value)) && ~strcmp(obj.SpeciesListBox.Value,'') % [cite: 1962]
                selectedSpeciesID = obj.SpeciesListBox.Value; % [cite: 1962]
                selectedSpeciesDisplayName = ''; % [cite: 1963]
                idx = find(strcmp(obj.SpeciesListBox.ItemsData, selectedSpeciesID),1); % [cite: 1963]
                if ~isempty(idx) && idx <= numel(obj.SpeciesListBox.Items), selectedSpeciesDisplayName = obj.SpeciesListBox.Items{idx}; end % [cite: 1963]
                
                if ~isempty(selectedSpeciesDisplayName) && ~strcmp(selectedSpeciesDisplayName, '(No species available)') && ~strcmp(selectedSpeciesDisplayName, 'Select a Species') % [cite: 1964]
                    strainCatalog = obj.getStrainInstances(); 
                    if isprop(strainCatalog,'NumItems') && strainCatalog.NumItems == 0 % [cite: 1965]
                        items_display = "No Strains Available"; % [cite: 1965]
                        items_data = {''}; % [cite: 1966]
                    elseif isstruct(strainCatalog) && ~isempty(strainCatalog) % [cite: 1966]
                        speciesMatchIdx = arrayfun(@(x) isfield(x,'species') && strcmp(x.species, selectedSpeciesDisplayName), strainCatalog); % [cite: 1966]
                        if ~any(speciesMatchIdx) % [cite: 1967]
                            items_display = "No Strains for this Species"; % [cite: 1967]
                            items_data = {''}; % [cite: 1968]
                        else
                            filteredStrains = strainCatalog(speciesMatchIdx); % [cite: 1968]
                            if ~isempty(filteredStrains), items_display = string({filteredStrains.name}'); items_data = cellstr(items_display);  % [cite: 1969]
                            else, items_display = "No Strains for this Species"; items_data = {''}; % [cite: 1970]
                            end
                        end
                    elseif isempty(strainCatalog) % [cite: 1971]
                         items_display = "No Strains Available"; % [cite: 1971]
                         items_data = {''}; % [cite: 1971]
                    end
                end
            end
            obj.StrainListBox.Items = items_display; % [cite: 1971]
            obj.StrainListBox.ItemsData = items_data;  % [cite: 1972]
            if ~isempty(items_data) && ~isempty(items_data{1}) && ~(isstring(items_data{1}) && ismissing(items_data{1})) && ~strcmp(items_data{1},'') % [cite: 1972]
                obj.StrainListBox.Value = items_data{1}; % [cite: 1973]
            else, obj.StrainListBox.Value = ''; end % [cite: 1973]
        end

        function updateSubjectTableColumnData(obj, columnName, newValue)
            selectedRows = obj.UITableSubject.Selection; % [cite: 1973]
            if isempty(selectedRows), return; end  % [cite: 1974]

            for i = 1:numel(selectedRows) % [cite: 1974]
                subjectIndexInTable = selectedRows(i); % [cite: 1974]
                subjectNameInTable = obj.UITableSubject.Data{subjectIndexInTable, 'SubjectName'};  % [cite: 1975]
                
                subjectObjIndex = -1; % [cite: 1975]
                for k=1:numel(obj.ParentApp.SubjectData.SubjectList) % [cite: 1975]
                    if strcmp(obj.ParentApp.SubjectData.SubjectList(k).SubjectName, subjectNameInTable) % [cite: 1975]
                        subjectObjIndex = k; % [cite: 1976]
                        break; % [cite: 1976]
                    end
                end

                if subjectObjIndex > 0 % [cite: 1977]
                    currentSubjectObj = obj.ParentApp.SubjectData.SubjectList(subjectObjIndex); % [cite: 1977]
                    switch columnName % [cite: 1977]
                        case 'BiologicalSex' % [cite: 1977]
                            currentSubjectObj.BiologicalSexList = {char(newValue)}; % [cite: 1978]
                        case 'Species' % [cite: 1978]
                            speciesName = char(newValue); % [cite: 1978]
                            speciesObj = obj.ParentApp.SpeciesData.getItem(speciesName);  % [cite: 1979]
                            if ~isempty(speciesObj)  % [cite: 1979]
                                currentSubjectObj.SpeciesList = speciesObj; % [cite: 1980]
                            else 
                                 fprintf('DEBUG (SubjectInfoGUI): Species "%s" not in SpeciesData. Attempting openMINDS lookup.\n', speciesName); % [cite: 1980]
                                 try % [cite: 1981]
                                    omSpecies = openminds.controlledterms.Species('name',speciesName); % [cite: 1981]
                                    currentSubjectObj.SpeciesList = omSpecies;  % [cite: 1982]
                                 catch ME_om % [cite: 1982]
                                     fprintf(2,'Warning: Could not create/assign openminds.controlledterms.Species "%s": %s\n', speciesName, ME_om.message); % [cite: 1982]
                                 end
                            end
                        case 'Strain' % [cite: 1983]
                            currentSubjectObj.addStrain(char(newValue)); % [cite: 1984]
                    end
                else
                    fprintf(2,'Warning: Subject "%s" not found in SubjectData for update.\n', subjectNameInTable); % [cite: 1985]
                end
            end
            obj.drawSubjectInfo(); % [cite: 1985]
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1986]
        end

        function deleteSubjectTableColumnData(obj, columnName)
            selectedRows = obj.UITableSubject.Selection; % [cite: 1986]
            if isempty(selectedRows), return; end % [cite: 1987]

            for i = 1:numel(selectedRows) % [cite: 1987]
                subjectIndexInTable = selectedRows(i); % [cite: 1987]
                subjectNameInTable = obj.UITableSubject.Data{subjectIndexInTable, 'SubjectName'}; % [cite: 1988]
                
                subjectObjIndex = -1; % [cite: 1988]
                for k=1:numel(obj.ParentApp.SubjectData.SubjectList) % [cite: 1988]
                    if strcmp(obj.ParentApp.SubjectData.SubjectList(k).SubjectName, subjectNameInTable) % [cite: 1989]
                        subjectObjIndex = k; % [cite: 1989]
                        break; % [cite: 1989]
                    end
                end

                if subjectObjIndex > 0 % [cite: 1990]
                    currentSubjectObj = obj.ParentApp.SubjectData.SubjectList(subjectObjIndex); % [cite: 1990]
                    switch columnName % [cite: 1990]
                        case 'BiologicalSex', currentSubjectObj.deleteBiologicalSex(); % [cite: 1990]
                        case 'Species' % [cite: 1991]
                            currentSubjectObj.deleteSpeciesList(); % [cite: 1991]
                            currentSubjectObj.deleteStrainList();  % [cite: 1992]
                        case 'Strain', currentSubjectObj.deleteStrainList(); % [cite: 1992]
                    end
                end
            end
            obj.drawSubjectInfo(); % [cite: 1993]
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1993]
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
            [names, ~] = ndi.database.metadata_app.fun.getOpenMindsInstances('Species'); % [cite: 534]
            for i = 1:numel(names) % [cite: 534]
                thisName = char(names(i)); 
                speciesInstance = openminds.internal.getControlledInstance(thisName, 'Species'); % [cite: 535]
                obj.ParentApp.SpeciesData.addItem(speciesInstance.name, speciesInstance.preferredOntologyIdentifier, speciesInstance.synonym); % [cite: 535]
            end
            if ~isempty(obj.ParentApp.SpeciesInstancesUser) % [cite: 535]
                for i = 1:numel(obj.ParentApp.SpeciesInstancesUser) % [cite: 535]
                    speciesInstance = obj.ParentApp.SpeciesInstancesUser(i); % [cite: 535]
                    if isfield(speciesInstance, 'name') && isfield(speciesInstance, 'ontologyIdentifier') && isfield(speciesInstance, 'synonyms') % Modified to check fields
                        obj.ParentApp.SpeciesData.addItem(speciesInstance.name, speciesInstance.ontologyIdentifier, speciesInstance.synonyms); % [cite: 536]
                    else
                        fprintf(2, 'Warning (SubjectInfoGUI/loadSpecies): User species instance missing required fields.\n');
                    end
                end
            end
        end

        function saveSpecies(obj) 
            import ndi.database.metadata_app.fun.saveUserInstances % [cite: 536]
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp) || ~isprop(obj.ParentApp, 'SpeciesInstancesUser')
                fprintf(2, 'Error (SubjectInfoGUI/saveSpecies): ParentApp or ParentApp.SpeciesInstancesUser is not valid.\n');
                return;
            end
            saveUserInstances('species', obj.ParentApp.SpeciesInstancesUser); % [cite: 537]
        end

        function strainInstances = getStrainInstances(obj) 
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog % [cite: 537]
            strainInstances = loadUserInstanceCatalog('Strain'); % [cite: 538]
        end
        
        function S = openSpeciesForm(obj, speciesInfoStruct) 
            if isempty(obj.ParentApp) || ~isvalid(obj.ParentApp) || ~ismethod(obj.ParentApp, 'openForm')
                fprintf(2, 'Error (SubjectInfoGUI/openSpeciesForm): ParentApp is not valid or missing openForm method.\n');
                S = struct.empty;
                return;
            end
            editExisting = (nargin > 1 && ~isempty(speciesInfoStruct)); % [cite: 547]
            S = obj.ParentApp.openForm('Species', speciesInfoStruct, editExisting); %
        end
        
        % --- Callbacks for UI Components ---
        function biologicalSexListBoxValueChanged(obj, event)
            % obj.ParentApp.saveDatasetInformationStruct(); % [cite: 1994]
        end
        function biologicalSexListBoxClicked(obj, event)
            % obj.updateSubjectTableColumnData('BiologicalSex', obj.BiologicalSexListBox.Value); % [cite: 1995]
        end
        function speciesListBoxValueChanged(obj, event)
            obj.populateStrainList(); % [cite: 1996]
        end
        function speciesListBoxClicked(obj, event)
            obj.populateStrainList(); % [cite: 1997]
        end
        function strainListBoxValueChanged(obj, event)
        end
        function strainListBoxClicked(obj, event)
            % obj.updateSubjectTableColumnData('Strain', obj.StrainListBox.Value); % [cite: 1998]
        end
        function strainListBoxDoubleClicked(obj, event)
        end

        function assignBiologicalSexButtonPushed(obj, event)
            obj.updateSubjectTableColumnData('BiologicalSex', obj.BiologicalSexListBox.Value); % [cite: 1999]
        end
        function biologicalSexClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('BiologicalSex'); % [cite: 1999]
        end
        function assignSpeciesButtonPushed(obj, event)
            obj.updateSubjectTableColumnData('Species', obj.SpeciesListBox.Value); % [cite: 2000]
            obj.populateStrainList();  % [cite: 2001]
        end
        function speciesClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('Species'); % [cite: 2001]
            obj.populateStrainList();  % [cite: 2002]
        end
        function assignStrainButtonPushed(obj, event)
             obj.updateSubjectTableColumnData('Strain', obj.StrainListBox.Value); % [cite: 2002]
        end
        function strainClearButtonPushed(obj, event)
            obj.deleteSubjectTableColumnData('Strain'); % [cite: 2003]
        end
        
        function addSpeciesButtonPushed(obj, event)
            speciesName = obj.SpeciesEditField.Value; % [cite: 2004]
            if isempty(strtrim(speciesName)) % [cite: 2005]
                obj.ParentApp.alert('Please enter a species name to add.', 'Species Name Empty'); % [cite: 2005]
                return; % [cite: 2006]
            end
            newSpeciesStruct = struct('name', speciesName, 'ontologyIdentifier', '', 'synonyms', {{}}); % [cite: 2006]
            returnedSpeciesStruct = obj.openSpeciesForm(newSpeciesStruct); 
            
            if ~isempty(returnedSpeciesStruct) && isfield(returnedSpeciesStruct, 'name') && ~isempty(strtrim(returnedSpeciesStruct.name)) % [cite: 2007]
                obj.ParentApp.SpeciesInstancesUser(end+1) = returnedSpeciesStruct; % [cite: 2007]
                obj.ParentApp.SpeciesData.addItem(returnedSpeciesStruct.name, returnedSpeciesStruct.ontologyIdentifier, returnedSpeciesStruct.synonyms); % [cite: 2008]
                obj.saveSpecies(); 
                obj.populateSpeciesList();  % [cite: 2008]
                obj.SpeciesEditField.Value = '';  % [cite: 2008]
                obj.ParentApp.inform(sprintf('Species "%s" added.', returnedSpeciesStruct.name), 'Species Added'); % [cite: 2009]
            else
                obj.ParentApp.inform('Species addition cancelled or failed.', 'Info'); % [cite: 2010]
            end
        end

        function addStrainButtonPushed(obj, event)
            strainName = obj.StrainEditField.Value; % [cite: 2010]
            selectedSpeciesName = ''; % [cite: 2011]
            if ~isempty(obj.SpeciesListBox.Value) % [cite: 2011]
                idx = strcmp(obj.SpeciesListBox.ItemsData, obj.SpeciesListBox.Value); % [cite: 2011]
                if any(idx) % [cite: 2012]
                    selectedSpeciesName = obj.SpeciesListBox.Items{idx}; % [cite: 2012]
                end
            end

            if isempty(strtrim(strainName)) % [cite: 2013]
                obj.ParentApp.alert('Please enter a strain name to add.', 'Strain Name Empty'); % [cite: 2014]
                return; % [cite: 2014]
            end
            if isempty(selectedSpeciesName) || strcmp(selectedSpeciesName, "Select a Species") || strcmp(selectedSpeciesName, "(No species available)") % [cite: 2014]
                 obj.ParentApp.alert('Please select a species before adding a strain.', 'Species Not Selected'); % [cite: 2015]
                 return; % [cite: 2016]
            end
            
            obj.populateStrainList(); % [cite: 2016]
            obj.StrainEditField.Value = ''; % [cite: 2017]
            obj.ParentApp.inform(sprintf('Strain "%s" for species "%s" added (Note: save logic is placeholder).', strainName, selectedSpeciesName), 'Strain Added (Placeholder)'); % [cite: 2017]
            obj.ParentApp.saveDatasetInformationStruct(); % [cite: 2018]
        end
        
        function missingFields = checkRequiredFields(obj)
            missingFields = string.empty(0,1); % [cite: 2019]
            if isempty(obj.ParentApp.SubjectData.SubjectList) % [cite: 2020]
                % missingFields(end+1) = "At least one Subject"; % [cite: 2020]
            end
        end

        function markRequiredFields(obj)
            % Placeholder: Mark labels of required fields in this GUI % [cite: 2021]
            % e.g. % [cite: 2022]
            % obj.UITableSubjectLabel.Text = [obj.UITableSubjectLabel.Text ' *']; % [cite: 2022]
        end

    end
end

% Helper function for conditional assignment (inline if-else)
function result = ifthenelse(condition, trueval, falseval)
    if condition % [cite: 2022]
        result = trueval; % [cite: 2023]
    else
        result = falseval; % [cite: 2023]
    end
end