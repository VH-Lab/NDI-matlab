classdef MetadataEditorApp < matlab.apps.AppBase
    %METADATAEDITORAPP App Edit and upload metadata for NDI datasets
    %   (Syntax and Inputs documentation remains the same)

    % Properties that correspond to app components
    properties (Access = public)
        NDIMetadataEditorUIFigure       matlab.ui.Figure
        FooterPanel                   matlab.ui.container.Panel
        FooterGridLayout              matlab.ui.container.GridLayout
        NdiLogoImage                  matlab.ui.control.Image
        NextButton                    matlab.ui.control.Button
        PreviousButton                matlab.ui.control.Button
        MainGridLayout                matlab.ui.container.GridLayout
        TabGroup                      matlab.ui.container.TabGroup
        
        IntroTab                      matlab.ui.container.Tab
        IntroGridLayout               matlab.ui.container.GridLayout
        GridLayout25                  matlab.ui.container.GridLayout % For Intro Tab
        NdiLogoIntroImage             matlab.ui.control.Image      % For Intro Tab
        IntroLabel                    matlab.ui.control.Label      % For Intro Tab
        GridLayout_Step0_C2           matlab.ui.container.GridLayout % For Intro Tab
        IntroductionTextLabel         matlab.ui.control.Label      % For Intro Tab
        GridLayout_Step0_C3           matlab.ui.container.GridLayout % For Intro Tab
        GetStartedButton              matlab.ui.control.Button     % For Intro Tab
        
        DatasetOverviewTab            matlab.ui.container.Tab
        DatasetOverviewGridLayout     matlab.ui.container.GridLayout
        DatasetInformationLabel       matlab.ui.control.Label
        DatasetInformationPanel       matlab.ui.container.Panel
        GridLayout                    matlab.ui.container.GridLayout % Inside DatasetInformationPanel
        GridLayout4                   matlab.ui.container.GridLayout % For Comments
        DatasetCommentsTextArea       matlab.ui.control.TextArea
        DatasetCommentsTextAreaLabel  matlab.ui.control.Label
        Panel_4                       matlab.ui.container.Panel      % For Abstract
        GridLayout3                   matlab.ui.container.GridLayout % For Abstract
        AbstractTextAreaLabel         matlab.ui.control.Label
        AbstractTextArea              matlab.ui.control.TextArea
        Panel_3                       matlab.ui.container.Panel      % For Titles
        GridLayout2                   matlab.ui.container.GridLayout % For Titles
        DatasetShortNameEditFieldLabel matlab.ui.control.Label
        DatasetShortNameEditField     matlab.ui.control.EditField
        DatasetBranchTitleEditFieldLabel matlab.ui.control.Label
        DatasetBranchTitleEditField   matlab.ui.control.EditField
        
        AuthorsTab                    matlab.ui.container.Tab
        AuthorsGridLayout             matlab.ui.container.GridLayout % Main grid for Authors Tab
        AuthorDetailsLabel            matlab.ui.control.Label      % Title for Authors Tab
        AuthorMainPanel               matlab.ui.container.Panel      % Panel that will contain AuthorDataGUI's UI
        
        DatasetDetailsTab             matlab.ui.container.Tab
        DatasetDetailsGridLayout      matlab.ui.container.GridLayout
        DatasetDetailsLabel           matlab.ui.control.Label
        DatasetDetailsPanel           matlab.ui.container.Panel
        GridLayout18                  matlab.ui.container.GridLayout % Main grid in DatasetDetailsPanel
        GridLayout20                  matlab.ui.container.GridLayout % For Publication Table
        PublicationTableButtonGridLayout matlab.ui.container.GridLayout
        AddRelatedPublicationButton   matlab.ui.control.Button
        RemovePublicationButton       matlab.ui.control.Button
        MovePublicationUpButton       matlab.ui.control.Button
        MovePublicationDownButton     matlab.ui.control.Button
        RelatedPublicationUITable     matlab.ui.control.Table
        RelatedPublicationUITableLabel matlab.ui.control.Label
        GridLayout19                  matlab.ui.container.GridLayout % For Accessibility and Funding
        GridLayout22                  matlab.ui.container.GridLayout % For Accessibility section
        GridLayout28                  matlab.ui.container.GridLayout % For License Dropdown + Help
        LicenseHelpButton             matlab.ui.control.Button
        LicenseDropDown               matlab.ui.control.DropDown
        AccessibilityLabel            matlab.ui.control.Label
        VersionInnovationEditField    matlab.ui.control.EditField
        VersionInnovationEditFieldLabel matlab.ui.control.Label
        VersionIdentifierEditField    matlab.ui.control.EditField
        VersionIdentifierEditFieldLabel matlab.ui.control.Label
        FullDocumentationEditField    matlab.ui.control.EditField
        FullDocumentationEditFieldLabel matlab.ui.control.Label
        LicenseDropDownLabel          matlab.ui.control.Label
        ReleaseDateDatePicker         matlab.ui.control.DatePicker
        ReleaseDateDatePickerLabel    matlab.ui.control.Label
        FundingGridLayout             matlab.ui.container.GridLayout % For Funding Table
        FundingTableButtonGridLayout  matlab.ui.container.GridLayout
        AddFundingButton              matlab.ui.control.Button
        RemoveFundingButton           matlab.ui.control.Button
        MoveFundingUpButton           matlab.ui.control.Button
        MoveFundingDownButton         matlab.ui.control.Button
        FundingUITableLabel           matlab.ui.control.Label
        FundingUITable                matlab.ui.control.Table
        
        ExperimentDetailsTab          matlab.ui.container.Tab
        ExperimentDetailsGridLayout   matlab.ui.container.GridLayout
        ExperimentDetailsLabel        matlab.ui.control.Label
        ExperimentDetailsPanel        matlab.ui.container.Panel
        GridLayout26                  matlab.ui.container.GridLayout % Main grid in ExperimentDetailsPanel
        SelectedTechniquesListBox     matlab.ui.control.ListBox
        SelectedTechniquesListBoxLabel matlab.ui.control.Label
        SelectTechniqueDropDownLabel  matlab.ui.control.Label
        SelectTechniqueDropDown       matlab.ui.control.DropDown
        SelectTechniqueCategoryDropDown matlab.ui.control.DropDown
        SelectTechniqueCategoryDropDownLabel matlab.ui.control.Label
        AddTechniqueButton            matlab.ui.control.Button
        RemoveTechniqueButton         matlab.ui.control.Button
        ExperimentalApproachTreeLabel matlab.ui.control.Label
        ExperimentalApproachTree      matlab.ui.container.CheckBoxTree
        DataTypeTree                  matlab.ui.container.CheckBoxTree
        DataTypeTreeLabel             matlab.ui.control.Label
        
        SubjectInfoTab                matlab.ui.container.Tab
        SubjectInfoGridLayout         matlab.ui.container.GridLayout
        SubjectInfoLabel              matlab.ui.control.Label
        SubjectInfoPanel              matlab.ui.container.Panel
        GridLayout16                  matlab.ui.container.GridLayout % Main grid in SubjectInfoPanel
        UITableSubject                matlab.ui.control.Table
        GridLayout17                  matlab.ui.container.GridLayout % For dropdowns/edits below subject table
        GridLayout27                  matlab.ui.container.GridLayout % For Strain add
        AddStrainButton               matlab.ui.control.Button
        StrainEditField               matlab.ui.control.EditField
        GridLayout24_4                matlab.ui.container.GridLayout % For Species add
        AddSpeciesButton              matlab.ui.control.Button
        SpeciesEditField              matlab.ui.control.EditField
        GridLayout24_3                matlab.ui.container.GridLayout % For Strain assign/clear
        StrainClearButton             matlab.ui.control.Button
        AssignStrainButton            matlab.ui.control.Button
        GridLayout24_2                matlab.ui.container.GridLayout % For Species assign/clear
        SpeciesClearButton            matlab.ui.control.Button
        AssignSpeciesButton           matlab.ui.control.Button
        GridLayout24                  matlab.ui.container.GridLayout % For Sex assign/clear
        BiologicalSexClearButton      matlab.ui.control.Button
        AssignBiologicalSexButton     matlab.ui.control.Button
        StrainListBox                 matlab.ui.control.ListBox
        StrainLabel                   matlab.ui.control.Label
        SpeciesListBox                matlab.ui.control.ListBox
        SpeciesLabel_2                matlab.ui.control.Label
        BiologicalSexListBox          matlab.ui.control.ListBox
        BiologicalSexLabel            matlab.ui.control.Label
        
        ProbeInfoTab                  matlab.ui.container.Tab
        ProbeInfoGridLayout           matlab.ui.container.GridLayout
        ProbeInfoLabel                matlab.ui.control.Label
        ProbeInfoPanel                matlab.ui.container.Panel % This panel will be parent for ProbeDataGUI
        % UITableProbe will be created by ProbeDataGUI
        
        SaveTab                       matlab.ui.container.Tab
        SubmitGridLayout              matlab.ui.container.GridLayout
        SubmitLabel                   matlab.ui.control.Label
        SubmitPanelGridLayout         matlab.ui.container.GridLayout
        ErrorTextArea                 matlab.ui.control.TextArea
        ErrorTextAreaLabel            matlab.ui.control.Label
        SubmissionDescriptionLabel    matlab.ui.control.Label
        SubmissionStatusPanel         matlab.ui.container.Panel
        SubmitFooterGridLayout        matlab.ui.container.GridLayout
        ExportDatasetInfoButton       matlab.ui.control.Button
        TestDocumentConversionButton  matlab.ui.control.Button
        SaveButton                    matlab.ui.control.Button
        SaveChangesButton             matlab.ui.control.Button 
        FooterpanelLabel              matlab.ui.control.Label
        ResetFormButton               matlab.ui.control.Button 
        RevertToSavedButton           matlab.ui.control.Button 
    end

    properties (Access = public) % Changed from private for GUI_Instances
        UIForm (1,1) struct 
        AuthorDataGUI_Instance ndi.database.metadata_app.class.AuthorDataGUI 
        ProbeDataGUI_Instance  ndi.database.metadata_app.class.ProbeDataGUI % Added
        % SubjectDataGUI_Instance % Placeholder for future Subject GUI controller
    end

    properties (Access = public, Constant)
        FieldComponentMap = struct(...
                    'DatasetFullName', 'DatasetBranchTitleEditField', ...
                    'DatasetShortName', 'DatasetShortNameEditField', ...
                            'Description', 'AbstractTextArea', ...
                                'Comments', 'DatasetCommentsTextArea', ...
                            'ReleaseDate', 'ReleaseDateDatePicker', ...
                                'License', 'LicenseDropDown', ...
                    'FullDocumentation', 'FullDocumentationEditField', ...
                    'VersionIdentifier', 'VersionIdentifierEditField', ...
                    'VersionInnovation', 'VersionInnovationEditField', ...
                                'Funding', 'FundingUITable', ... 
                    'RelatedPublication', 'RelatedPublicationUITable', ... 
                    'ExperimentalApproach', 'ExperimentalApproachTree', ...
                    'TechniquesEmployed', 'SelectedTechniquesListBox', ...
                                'DataType', 'DataTypeTree' ...
                    );
        FieldComponentPostfix = ["EditField", "TextArea", "DropDown", "UITable", "Tree", "ListBox"]
    end

    properties (Access = public) 
        DatasetInformationStruct (1,1) struct 
        
        AuthorData (1,1) ndi.database.metadata_app.class.AuthorData
        Organizations (1,:) struct 
        
        SpeciesInstancesUser (1,:) struct
        SpeciesData (1,1) ndi.database.metadata_app.class.SpeciesData
        SubjectData (1,1) ndi.database.metadata_app.class.SubjectData
        ProbeData (1,1) ndi.database.metadata_app.class.ProbeData
        
        LoginInformation 
        Dataset          
        TempWorkingFile  
        Timer            
        ResourcesPath 
    end

    methods (Access = public) % App utility methods (alert, inform, etc.) - Changed to public for external access
        
        function alert(app, message, title, varargin)
            if nargin < 3 || isempty(title); title = 'Error'; end
            uialert(app.NDIMetadataEditorUIFigure, message, title, varargin{:})
        end

        function inform(app, message, title, varargin)
            if nargin < 3 || isempty(title);title = 'Info'; end
            uialert(app.NDIMetadataEditorUIFigure, message, title, varargin{:}, 'Icon', 'info')
        end

        function alertRequiredFieldsMissing(app, missingFields)
            msg = sprintf("The following required field(s) are missing:\n%s", strjoin(" - "+missingFields, newline));
            uialert(app.NDIMetadataEditorUIFigure, msg, 'Required Field(s) Missing')
        end
    end
    
    methods (Access = public) % UI Helper methods - made public for external .fun access
        function selectionIndex = getListBoxSelectionIndex(app, listBoxHandle)
            if isempty(listBoxHandle.Value)
                selectionIndex = [];
            else
                if iscell(listBoxHandle.Value) && ~isempty(listBoxHandle.Value)
                    isSelected = ismember(listBoxHandle.Items, listBoxHandle.Value);
                else 
                    isSelected = strcmp(listBoxHandle.Items, listBoxHandle.Value);
                end
                selectionIndex = find(isSelected);
            end
        end

        function data = getCheckedTreeNodeData(app, checkedNodeHandles)
            if ~isempty(checkedNodeHandles)
                data = {checkedNodeHandles.NodeData};
            else
                data = {}; 
            end
        end

        function setCheckedNodesFromData(app, treeHandle, data)
            if isempty(treeHandle.Children)
                treeHandle.CheckedNodes = []; 
                return; 
            end
            
            if ischar(data) && ~isempty(data)
                data = {data}; 
            elseif isstring(data)
                data = cellstr(data); 
            elseif ~iscellstr(data) && ~iscell(data) && ~isempty(data) 
                data = {}; 
            elseif iscell(data) && ~isempty(data) && ~all(cellfun(@ischar, data)) 
                try 
                    data = cellfun(@char, data, 'UniformOutput', false); 
                catch
                    data = {};
                end
            end
            if isempty(data), data = {}; end 

            nodeDataArray = {treeHandle.Children.NodeData};
            nodesToSelect = matlab.ui.container.TreeNode.empty(0,1); 
            if ~isempty(data) && ~isempty(nodeDataArray)
                try
                    tf = ismember(nodeDataArray, data);
                    if any(tf)
                        nodesToSelect = treeHandle.Children(tf);
                    end
                catch ME_ismember
                    fprintf(2, 'Error in setCheckedNodesFromData during ismember: %s\n', ME_ismember.message);
                end
            end
            if isempty(nodesToSelect)
                treeHandle.CheckedNodes = []; 
            else
                treeHandle.CheckedNodes = nodesToSelect;
            end
        end
    end
    
    methods (Access = private) % UI Checks and Highlighting (and other private app logic)
        function missingRequiredField = checkRequiredFields(app, tab)
            tabTitleStr = '';
            if isa(tab, 'matlab.ui.container.Tab') && isprop(tab,'Title') && ~isempty(tab.Title)
                tabTitleStr = char(tab.Title);
            elseif ischar(tab) || isstring(tab)
                 tabTitleStr = char(tab);
            end
            fprintf('DEBUG (checkRequiredFields): Called for tab: %s\n', tabTitleStr);
            
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
            missingRequiredField = string.empty(0,1); % Initialize as empty string array
            fieldsToCheck = string.empty(0,1); 

            currentTabName = tabTitleStr;
            fprintf('DEBUG (checkRequiredFields): currentTabName determined as: "%s"\n', currentTabName);

            switch currentTabName 
                case app.DatasetOverviewTab.Title
                    fieldsToCheck = ["DatasetFullName", "DatasetShortName", "Description", "Comments"];
                case app.DatasetDetailsTab.Title
                    fieldsToCheck = ["License", "VersionIdentifier"];
                case app.ExperimentDetailsTab.Title
                    fieldsToCheck = ["DataType"]; % Example, add more if needed
                case {'', app.SaveTab.Title} % Final submission step or SaveTab
                    fieldsToCheck = string( fieldnames(requiredFields)' );
                otherwise
                    fprintf('DEBUG (checkRequiredFields): Tab "%s" not explicitly handled for required fields check, no specific fields added to fieldsToCheck.\n', currentTabName);
            end    
            
            if isempty(fieldsToCheck)
                fprintf('DEBUG (checkRequiredFields): No fields to check for this tab based on switch case.\n');
            else
                fprintf('DEBUG (checkRequiredFields): Fields to check for this tab: %s\n', strjoin(fieldsToCheck,', '));
            end

            for iField_str = fieldsToCheck % Iterate using string for safety
                iField = char(iField_str); % Convert to char for struct field access
                fprintf('DEBUG (checkRequiredFields): Checking field: %s\n', iField);

                if ~isfield(app.FieldComponentMap, iField)
                    fprintf('DEBUG (checkRequiredFields): Field "%s" not in FieldComponentMap. Skipping.\n', iField);
                    continue; 
                end

                componentFieldName = app.FieldComponentMap.(iField);
                fprintf('DEBUG (checkRequiredFields): Mapped component: %s\n', componentFieldName);

                if isfield(requiredFields, iField) && requiredFields.(iField) 
                    fprintf('DEBUG (checkRequiredFields): Field "%s" is required.\n', iField);
                    if isprop(app, componentFieldName) 
                        uiComponent = app.(componentFieldName);
                        fprintf('DEBUG (checkRequiredFields): Component "%s" exists.\n', componentFieldName);
                        value = []; % Initialize value
                        if isa(uiComponent, 'matlab.ui.container.CheckBoxTree')
                            value = uiComponent.CheckedNodes; 
                            fprintf('DEBUG (checkRequiredFields): Value from CheckBoxTree "%s": %d nodes checked.\n', componentFieldName, numel(value));
                        elseif isa(uiComponent, 'matlab.ui.control.Table')
                            value = uiComponent.Data;
                             if istable(value) && ~isempty(value)
                                fprintf('DEBUG (checkRequiredFields): Value from Table "%s": Table with %d rows.\n', componentFieldName, height(value));
                             else
                                 fprintf('DEBUG (checkRequiredFields): Value from Table "%s": Empty or not a table.\n', componentFieldName);
                                 value = []; % Treat empty table as empty for check
                             end
                        else % EditField, TextArea, DropDown, ListBox
                            value = char(uiComponent.Value); % Convert to char for isempty check
                            fprintf('DEBUG (checkRequiredFields): Value from "%s" ("%s"): "%s"\n', class(uiComponent), componentFieldName, value);
                        end

                        if isempty(value)
                            fieldTitle = app.getFieldTitle(iField);
                            missingRequiredField(end+1) = fieldTitle; % Append to string array
                            app.highlightLabelForRequiredField(componentFieldName);
                            fprintf('DEBUG (checkRequiredFields): Field "%s" (Title: "%s") IS MISSING.\n', iField, fieldTitle);
                        else
                            app.resetLabelForRequiredField(componentFieldName); 
                            fprintf('DEBUG (checkRequiredFields): Field "%s" is PRESENT.\n', iField);
                        end
                    else
                         fprintf(2, 'Warning (checkRequiredFields): Component "%s" for required field "%s" not found on app.\n', componentFieldName, iField);
                    end
                else
                     fprintf('DEBUG (checkRequiredFields): Field "%s" is NOT required or not in requiredFields struct.\n', iField);
                end
            end
            
            if isequal(currentTabName, "") || isequal(currentTabName, app.SaveTab.Title)
                fprintf('DEBUG (checkRequiredFields): Performing final checks for SaveTab or empty tab name.\n');
                if isempty(app.AuthorData.AuthorList) || ...
                   all(arrayfun(@(x) isempty(strtrim(x.givenName)) && isempty(strtrim(x.familyName)), app.AuthorData.AuthorList))
                    missingRequiredField(end+1) = "At least one Author with a name";
                    fprintf('DEBUG (checkRequiredFields): MISSING: At least one Author with a name.\n');
                end
            end

            if isempty(missingRequiredField)
                fprintf('DEBUG (checkRequiredFields): Final missing fields: None\n');
            else
                fprintf('DEBUG (checkRequiredFields): Final missing fields: %s\n', strjoin(missingRequiredField,', '));
            end
        end

        function fieldTitle = getFieldTitle(app, fieldName)
            if isfield(app.FieldComponentMap, fieldName)
                componentFieldName = app.FieldComponentMap.(fieldName);
                labelFieldName = sprintf('%sLabel', componentFieldName);
                 if isprop(app, labelFieldName) && isvalid(app.(labelFieldName))
                    fieldTitle = app.(labelFieldName).Text;
                    fieldTitle = string(strrep(fieldTitle, ' *', ''));
                 else
                    fieldTitle = fieldName; 
                    fprintf(2, 'Warning: Label for component %s (field %s) not found.\n', componentFieldName, fieldName);
                 end
            else
                fieldTitle = fieldName; 
                 fprintf(2, 'Warning: Field %s not found in FieldComponentMap for getFieldTitle.\n', fieldName);
            end
        end

        function highlightLabelForRequiredField(app, componentFieldName)
            labelFieldName = sprintf('%sLabel', componentFieldName);
            if isprop(app, labelFieldName) && isvalid(app.(labelFieldName))
                app.(labelFieldName).FontWeight = 'bold';
                app.(labelFieldName).FontColor = [0.7098    0.0902        0]; 
                app.(labelFieldName).Tag = 'RequiredValueMissing';
            end
        end

        function resetLabelForRequiredField(app, componentFieldName)
            labelFieldName = sprintf('%sLabel', componentFieldName);
            if isprop(app, labelFieldName) && isvalid(app.(labelFieldName)) && strcmp(app.(labelFieldName).Tag, 'RequiredValueMissing')
                app.(labelFieldName).FontWeight = 'normal';
                app.(labelFieldName).FontColor = [0 0 0]; 
                app.(labelFieldName).Tag = '';
            end
        end
        
        function markRequiredFields(app) 
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
            requiredSymbol = '*'; 

            allFieldNamesInMap = string(fieldnames(app.FieldComponentMap));

            for iFieldName = reshape(allFieldNamesInMap, 1, [])
                if isfield(requiredFields, iFieldName) && requiredFields.(iFieldName)
                    componentName = app.FieldComponentMap.(iFieldName);
                    labelComponentName = sprintf("%sLabel", componentName);
                    
                    if isprop(app, labelComponentName) && isvalid(app.(labelComponentName))
                        if ~contains(app.(labelComponentName).Text, requiredSymbol)
                            app.(labelComponentName).Text = sprintf('%s %s', app.(labelComponentName).Text, requiredSymbol);
                        end
                        app.(labelComponentName).Tooltip = "Required";
                    else
                        fprintf(2, 'Warning (markRequiredFields): Label component "%s" not found for required field "%s".\n', labelComponentName, iFieldName);
                    end
                end
            end
        end

        function hideUnimplementedComponents(app) 
            if isprop(app, 'ErrorTextAreaLabel') && isvalid(app.ErrorTextAreaLabel)
                app.ErrorTextAreaLabel.Visible = 'off';
            end
            if isprop(app, 'ErrorTextArea') && isvalid(app.ErrorTextArea)
                app.ErrorTextArea.Visible = 'off';
            end
            if isprop(app, 'FooterpanelLabel') && isvalid(app.FooterpanelLabel)
                app.FooterpanelLabel.Visible = 'off';
            end
        end
        
        function setFigureMinSize(app) 
            isMatch = false;
            drawnow 
            pause(0.1); 

            max_attempts = 20; 
            attempt_count = 0;
            
            figName = app.NDIMetadataEditorUIFigure.Name; 

            while ~isMatch && attempt_count < max_attempts
                windowList = matlab.internal.webwindowmanager.instance.findAllWebwindows();
                if isempty(windowList)
                    attempt_count = attempt_count + 1;
                    pause(0.1);
                    continue;
                end
                titles = {windowList.Title};
                isMatch = strcmp(titles, figName);
                
                if ~any(isMatch)
                    if ~isempty(app.NDIMetadataEditorUIFigure.Tag)
                         tags = arrayfun(@(w) getfieldifexists(w,'Tag'), windowList, 'UniformOutput', false);
                         validTags = cellfun(@ischar, tags);
                         if any(validTags)
                            isMatch = strcmp(tags(validTags), app.NDIMetadataEditorUIFigure.Tag);
                         else
                            isMatch = false(1,0); 
                         end
                    end
                end

                if ~any(isMatch)
                    attempt_count = attempt_count + 1;
                    pause(0.1);
                end
            end

            if any(isMatch)
                window = windowList(find(isMatch,1)); 
                try
                    window.setMinSize([840 610]);
                catch ME_setMinSize
                     fprintf(2,'Warning: Could not set minimum figure size: %s\n', ME_setMinSize.message);
                end
            else
                fprintf(2,'Warning: Could not find the app window to set minimum size for "%s".\n', figName);
            end
        end
        
        function centerFigureOnScreen(app) 
            if isprop(app, 'NDIMetadataEditorUIFigure') && isvalid(app.NDIMetadataEditorUIFigure)
                try
                    originalUnits = app.NDIMetadataEditorUIFigure.Units;
                    app.NDIMetadataEditorUIFigure.Units = 'pixels';
                    movegui(app.NDIMetadataEditorUIFigure, 'center');
                    app.NDIMetadataEditorUIFigure.Units = originalUnits; 
                catch ME_center
                    fprintf(2, 'Warning: Could not center figure on screen: %s\n', ME_center.message);
                end
            end
        end
    end

    methods (Access = public) % Load/save and data object interaction 
        function tempWorkingFile = getTempWorkingFile(app)
            if isempty(app.TempWorkingFile) || app.TempWorkingFile == ""
                entityPath = app.Dataset.path();
                ndiFolderPath = fullfile(entityPath, '.ndi');
                app.TempWorkingFile = fullfile(ndiFolderPath, 'NDIMetadataEditorData.mat');
            end
            tempWorkingFile = app.TempWorkingFile;
        end

        function saveDatasetInformationStruct(app) 
            tempSaveFile = app.getTempWorkingFile();
            app.DatasetInformationStruct = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
            
            datasetInformationToSave = app.DatasetInformationStruct; 
            save(tempSaveFile, "datasetInformation", datasetInformationToSave); 
            fprintf('DEBUG: DatasetInformationStruct saved to %s\n', tempSaveFile);
        end

        function loadDatasetInformationStruct(app) 
            tempLoadFile = app.getTempWorkingFile();
            loadedDataStruct = struct(); 

            if ~isempty(app.Dataset) 
                ndi.database.metadata_app.fun.readExistingMetadata(app.Dataset, tempLoadFile);
            end

            if isfile(tempLoadFile)
                S_loaded = [];
                try
                    S_loaded = load(tempLoadFile, "datasetInformation");
                    if isfield(S_loaded, 'datasetInformation')
                        loadedDataStruct = S_loaded.datasetInformation;
                    else
                        fprintf(2, 'Warning: NDIMetadataEditorData.mat "datasetInformation" variable missing. Initializing defaults.\n');
                    end
                catch ME_load
                    warning('MATLAB:MetadataEditorApp:TempFileLoadError', ...
                            'Could not load temporary metadata file "%s". Error: %s. Initializing default structure.', tempLoadFile, ME_load.message);
                end
            else
                fprintf(1, 'Temporary metadata file not found. Initializing default structure.\n');
            end
            
            validatedStruct = ndi.database.metadata_app.fun.validateDatasetInformation(loadedDataStruct, app);
            app.DatasetInformationStruct = validatedStruct;
            
            ndi.database.metadata_app.fun.populateAppFromDatasetInformationStruct(app, app.DatasetInformationStruct);
        end

        function loadUserDefinedMetadata(app) 
            app.loadOrganizations();
            app.loadSpecies();
        end

        function loadSpecies(app)
            import ndi.database.metadata_app.fun.loadUserInstances
            app.SpeciesInstancesUser = loadUserInstances('species');
            [names, ~] = ndi.database.metadata_app.fun.getOpenMindsInstances('Species');
            for i = 1:numel(names)
                thisName = char(names(i));
                speciesInstance = openminds.internal.getControlledInstance(thisName, 'Species');
                app.SpeciesData.addItem(speciesInstance.name, speciesInstance.preferredOntologyIdentifier, speciesInstance.synonym);
            end
            if ~isempty(app.SpeciesInstancesUser)
                for i = 1:numel(app.SpeciesInstancesUser)
                    speciesInstance = app.SpeciesInstancesUser(i);
                    app.SpeciesData.addItem(speciesInstance.name, speciesInstance.ontologyIdentifier, speciesInstance.synonyms);
                end
            end
        end

        function saveSpecies(app)
            import ndi.database.metadata_app.fun.saveUserInstances
            saveUserInstances('species', app.SpeciesInstancesUser);
        end

        function loadOrganizations(app)
            import ndi.database.metadata_app.fun.loadUserInstances
            app.Organizations = loadUserInstances('affiliation_organization');
            if ~isempty(app.AuthorDataGUI_Instance) && isvalid(app.AuthorDataGUI_Instance)
                app.AuthorDataGUI_Instance.populateOrganizationDropdownInternal();
            end
        end

        function saveOrganizationInstances(app)
            import ndi.database.metadata_app.fun.saveUserInstances
            saveUserInstances('affiliation_organization', app.Organizations);
        end
        
        function strainInstances = getStrainInstances(app)
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog
            strainInstances = loadUserInstanceCatalog('Strain');
        end

        function S = openOrganizationForm(app, organizationInfo, organizationIndex)
            if ~isfield(app.UIForm, 'Organization') || ~isvalid(app.UIForm.Organization)
                app.UIForm.Organization = ndi.database.metadata_app.Apps.OrganizationForm();
            else
                app.UIForm.Organization.Visible = 'on';
            end
            if nargin > 1 && ~isempty(organizationInfo)
                app.UIForm.Organization.setOrganizationDetails(organizationInfo);
            end
            app.UIForm.Organization.waitfor();
            S = app.UIForm.Organization.getOrganizationDetails();
            mode = app.UIForm.Organization.FinishState;
            if mode == "Save"
                if nargin > 2 && ~isempty(organizationIndex)
                    app.insertOrganization(S, organizationIndex);
                else
                    app.insertOrganization(S);
                end
                if ~isempty(app.AuthorDataGUI_Instance) && isvalid(app.AuthorDataGUI_Instance)
                    app.AuthorDataGUI_Instance.populateOrganizationDropdownInternal();
                end
            else
                S = struct.empty;
            end
            app.UIForm.Organization.reset();
            app.UIForm.Organization.Visible = 'off';
            if ~nargout, clear S; end
        end
        
        function insertOrganization(app, S_org, insertIndex) 
            if nargin < 3 || isempty(insertIndex)
                insertIndex = numel(app.Organizations) + 1;
            end
            if isempty(app.Organizations)
                app.Organizations = S_org;
            else
                app.Organizations(insertIndex) = S_org;
            end
            app.saveOrganizationInstances();
        end

        function S = openFundingForm(app, info)
            progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                'Message', 'Opening form for entering funder details', ...
                'Title', 'Please wait...', 'Indeterminate', "on");
            if ~isfield(app.UIForm, 'Funding') || ~isvalid(app.UIForm.Funding)
                app.UIForm.Funding = ndi.database.metadata_app.Apps.FundingForm();
            else
                app.UIForm.Funding.Visible = 'on';
            end
            if nargin > 1 && ~isempty(info)
                app.UIForm.Funding.setFunderDetails(info);
            end
            ndi.gui.utility.centerFigure(app.UIForm.Funding.UIFigure, app.NDIMetadataEditorUIFigure);
            progressDialog.Message = 'Enter funder details:';
            app.UIForm.Funding.waitfor(); 
            S = app.UIForm.Funding.getFunderDetails();
            mode = app.UIForm.Funding.FinishState;
            if mode ~= "Save", S = struct.empty; end
            app.UIForm.Funding.reset();
            app.UIForm.Funding.Visible = 'off';
            delete(progressDialog);
        end

        function S = openForm(app, formName, S_in, editExisting) 
            if nargin < 3; S_in = struct.empty; end
            if nargin < 4; editExisting = ~isempty(S_in); end

            progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                'Message', sprintf('Opening form for entering %s details', formName), ...
                'Title', 'Please wait...', 'Indeterminate', "on");
        
            if ~isfield(app.UIForm, formName) || ~isvalid(app.UIForm.(formName))
                appPackage = 'ndi.database.metadata_app.Apps';
                formAppName = sprintf('%s.%sForm', appPackage, formName);
                app.UIForm.(formName) = feval(formAppName); 
            else
                app.UIForm.(formName).Visible = 'on'; 
            end

            if ~isempty(S_in)
                app.UIForm.(formName).setFormData(S_in, editExisting);
            end
                
            ndi.gui.utility.centerFigure(app.UIForm.(formName).UIFigure, app.NDIMetadataEditorUIFigure);
            
            progressDialog.Message = sprintf('Enter %s details', lower(formName));
            app.UIForm.(formName).waitfor(); 

            S = app.UIForm.(formName).getFormData();
            mode = app.UIForm.(formName).FinishState;
            if mode ~= "Save", S = struct.empty; end

            app.UIForm.(formName).reset();
            app.UIForm.(formName).Visible = 'off'; 
            delete(progressDialog);
        end
        
        % MODIFIED openProbeForm
        function success = openProbeForm(app, probeType, probeIndexOrData, probeObjIn)
            % Returns true if form was saved, false otherwise.
            % Updates app.ProbeData directly if saved.
            success = false;
            formHandle = [];
            % ... (switch statement for formHandle remains the same) ...
            switch probeType
                case "Electrode"
                    if ~isfield(app.UIForm, 'Electrode') || ~isvalid(app.UIForm.Electrode)
                        app.UIForm.Electrode = ndi.database.metadata_app.Apps.ElectrodeForm();
                    end
                    formHandle = app.UIForm.Electrode;
                case "Pipette"
                    if ~isfield(app.UIForm, 'Pipette') || ~isvalid(app.UIForm.Pipette)
                        app.UIForm.Pipette = ndi.database.metadata_app.Apps.PipetteForm();
                    end
                    formHandle = app.UIForm.Pipette;
                otherwise
                    app.alert(['Probe form for type "' probeType '" not implemented.'], 'Error');
                    return;
            end
            
            formHandle.Visible = 'on';
            if nargin > 3 && ~isempty(probeObjIn) 
                formHandle.setProbeDetails(probeObjIn); 
            end
            ndi.gui.utility.centerFigure(formHandle.UIFigure, app.NDIMetadataEditorUIFigure);
            formHandle.waitfor();
            
            if strcmp(formHandle.FinishState, "Save")
                updatedProbeObjDetails = formHandle.getProbeDetails(); 
                app.ProbeData.replaceProbe(probeIndexOrData, updatedProbeObjDetails); % Use probeIndexOrData
                app.saveDatasetInformationStruct(); 
                success = true; 
            end
            formHandle.reset();
            formHandle.Visible = 'off';
        end
        
        function S = openSpeciesForm(app, speciesInfoStruct) 
             if ~isfield(app.UIForm, 'Species') || ~isvalid(app.UIForm.Species)
                app.UIForm.Species = ndi.database.metadata_app.Apps.SpeciesForm(); 
            else
                app.UIForm.Species.Visible = 'on'; 
            end
            if nargin > 1 && ~isempty(speciesInfoStruct)
                app.UIForm.Species.setInfo(speciesInfoStruct); 
            end
            app.UIForm.Species.waitfor(); 
            S = app.UIForm.Species.getInfo(); 
            mode = app.UIForm.Species.FinishState;
            if mode ~= "Save", S = struct.empty; end
            app.UIForm.Species.reset();
            app.UIForm.Species.Visible = 'off';
        end

        function S = openLoginForm(app)
             if ~isfield(app.UIForm, 'Login') || ~isvalid(app.UIForm.Login)
                app.UIForm.Login = ndi.database.metadata_app.Apps.LoginForm();
            else
                app.UIForm.Login.Visible = 'on';
            end
            app.UIForm.Login.waitfor();
            S = app.UIForm.Login.LoginInformation;
            mode = app.UIForm.Login.FinishState;
            if mode == "Save"
                app.LoginInformation = S; 
            else
                S = struct.empty;
            end
            app.UIForm.Login.reset();
            app.UIForm.Login.Visible = 'off';
            if ~nargout, clear S; end
        end

        function resetFigureNameIn(app, name, numSeconds)
            if ~isempty(app.Timer) && isvalid(app.Timer), stop(app.Timer); delete(app.Timer); app.Timer = []; end
            app.Timer = timer('TimerFcn', @(~,~)app.updateFigureName(name), 'StartDelay', numSeconds, 'ExecutionMode', 'singleShot');
            start(app.Timer);
        end

        function updateFigureName(app, name) 
            if isvalid(app.NDIMetadataEditorUIFigure)
                app.NDIMetadataEditorUIFigure.Name = name;
            end
            if ~isempty(app.Timer) && isvalid(app.Timer), stop(app.Timer); delete(app.Timer); app.Timer = []; end
        end
        
        function changeTab(app, newTab)
            app.TabGroup.SelectedTab = newTab;
            app.onTabChanged(); 
        end

        function onTabChanged(app, ~) 
            selectedTab = app.TabGroup.SelectedTab;
            isIntroOrSaveTab = selectedTab == app.IntroTab || selectedTab == app.SaveTab;

            if isIntroOrSaveTab
                app.FooterPanel.Visible = 'off';
                if isvalid(app.FooterPanel.Parent) && ~isequal(app.FooterPanel.Parent, app.NDIMetadataEditorUIFigure)
                    app.FooterPanel.Parent = app.NDIMetadataEditorUIFigure; 
                end
                app.MainGridLayout.RowHeight = {'1x'};
            else
                app.FooterPanel.Visible = 'on';
                if isvalid(app.FooterPanel.Parent) && ~isequal(app.FooterPanel.Parent, app.MainGridLayout)
                    app.FooterPanel.Parent = app.MainGridLayout; 
                end
                app.FooterPanel.Layout.Row = 2;
                app.FooterPanel.Layout.Column = 1;
                app.MainGridLayout.RowHeight = {'1x', 63};
            end
        end

        function updateSubjectTableColumData(app, columnName, newValue)
            selectedRows = app.UITableSubject.Selection;
            if isempty(selectedRows), return; end 

            for i = 1:numel(selectedRows)
                subjectIndexInTable = selectedRows(i);
                subjectNameInTable = app.UITableSubject.Data{subjectIndexInTable, 'Subject'};
                subjectObjIndex = find(strcmp({app.SubjectData.SubjectList.SubjectName}, subjectNameInTable), 1);

                if ~isempty(subjectObjIndex)
                    currentSubjectObj = app.SubjectData.SubjectList(subjectObjIndex);
                    switch columnName
                        case 'BiologicalSex'
                            currentSubjectObj.BiologicalSexList = {char(newValue)};
                        case 'Species'
                            speciesName = char(newValue);
                            speciesObj = app.SpeciesData.getItem(speciesName); 
                            if ~isempty(speciesObj) 
                                currentSubjectObj.SpeciesList = speciesObj;
                            else
                                fprintf(2,'Warning: Species "%s" not found in SpeciesData.\n', speciesName);
                            end
                        case 'Strain'
                            currentSubjectObj.addStrain(char(newValue)); 
                    end
                else
                    fprintf(2,'Warning: Subject "%s" not found in SubjectData for update.\n', subjectNameInTable);
                end
            end
            app.UITableSubject.Data = struct2table(app.SubjectData.formatTable(), 'AsArray', true);
            app.saveDatasetInformationStruct();
        end

        function deleteSubjectTableColumData(app, columnName)
            selectedRows = app.UITableSubject.Selection;
            if isempty(selectedRows), return; end

            for i = 1:numel(selectedRows)
                subjectIndexInTable = selectedRows(i);
                subjectNameInTable = app.UITableSubject.Data{subjectIndexInTable, 'Subject'};
                subjectObjIndex = find(strcmp({app.SubjectData.SubjectList.SubjectName}, subjectNameInTable), 1);

                if ~isempty(subjectObjIndex)
                    currentSubjectObj = app.SubjectData.SubjectList(subjectObjIndex);
                    switch columnName
                        case 'BiologicalSex'
                            currentSubjectObj.deleteBiologicalSex();
                        case 'Species'
                            currentSubjectObj.deleteSpeciesList();
                            currentSubjectObj.deleteStrainList(); 
                        case 'Strain'
                            currentSubjectObj.deleteStrainList();
                    end
                end
            end
            app.UITableSubject.Data = struct2table(app.SubjectData.formatTable(), 'AsArray', true);
            app.saveDatasetInformationStruct();
        end
        
        function probeObj = createProbeObjectFromStruct(app, probeStruct)
            probeObj = []; 
            if ~isstruct(probeStruct) || ~isfield(probeStruct, 'ClassType') || ~isfield(probeStruct, 'Name')
                fprintf(2, 'Warning (createProbeObjectFromStruct): Invalid probeStruct provided.\n');
                return;
            end
            className = probeStruct.ClassType;
            probeName = probeStruct.Name;
            try
                switch className
                    case {'Electrode', 'ElectrodeArray', 'ndi.daq.metadatabundle.EphysProbe'} 
                        fprintf(1, 'DEBUG (createProbeObjectFromStruct): Placeholder for creating %s object "%s". Returning struct.\n', className, probeName);
                        probeObj = probeStruct; % PLACEHOLDER - MUST INSTANTIATE ACTUAL OBJECT
                    case {'Pipette', 'ndi.daq.metadatabundle.Pipette'}
                        fprintf(1, 'DEBUG (createProbeObjectFromStruct): Placeholder for creating %s object "%s". Returning struct.\n', className, probeName);
                        probeObj = probeStruct; % PLACEHOLDER
                    otherwise
                        fprintf(2, 'Warning (createProbeObjectFromStruct): Unknown probe ClassType "%s" for probe "%s". Returning struct.\n', className, probeName);
                        probeObj = probeStruct; 
                end
            catch ME_probeCreate
                 fprintf(2, 'Error creating probe object for "%s" of type "%s": %s\n', probeName, className, ME_probeCreate.message);
                 probeObj = probeStruct; 
            end
        end
    end

    % Callbacks that handle component events (non-author related)
    methods (Access = public) % Changed from private for callbacks

        % Code that executes after component creation
        function startupFcn(app, datasetObject, debugMode)
            arguments 
                app (1,1) ndi.database.metadata_app.Apps.MetadataEditorApp
                datasetObject (1,1) {mustBeA(datasetObject, ["ndi.session", "ndi.dataset"])}
                debugMode (1,1) logical = false
            end

            appFileFolder = fileparts(mfilename('fullpath'));
            app.ResourcesPath = fullfile(appFileFolder, 'resources'); 
            if ~isfolder(app.ResourcesPath)
                 fprintf(2, 'Warning (startupFcn): ResourcesPath not found: %s. Icon paths might be incorrect.\n', app.ResourcesPath);
            end

            try
                ndi.fun.assertAddonOnPath("openMINDS Metadata Models", 'RequiredFor', 'NDI Dataset Uploader');
            catch
                try 
                    ndi.fun.assertAddonOnPath("openMINDS Metadata Toolbox", 'RequiredFor', 'NDI Dataset Uploader');
                catch ME
                    delete(app); throwAsCaller(ME);
                end
            end

            app.Dataset = datasetObject;
            app.TempWorkingFile = app.getTempWorkingFile();
            
            app.FooterPanel.Visible = 'off';
            app.hideUnimplementedComponents(); 
            app.markRequiredFields(); 

            if not(debugMode)
                app.ExportDatasetInfoButton.Visible = 'off';
                app.TestDocumentConversionButton.Visible = 'off';
            end

            app.setFigureMinSize();
            app.centerFigureOnScreen(); 

            app.AuthorData = ndi.database.metadata_app.class.AuthorData();
            app.SubjectData = ndi.database.metadata_app.class.SubjectData();
            app.ProbeData = ndi.database.metadata_app.class.ProbeData();
            app.SpeciesData = ndi.database.metadata_app.class.SpeciesData();

            app.AuthorDataGUI_Instance = ndi.database.metadata_app.class.AuthorDataGUI(app, app.AuthorMainPanel);
            app.AuthorDataGUI_Instance.initialize();
            
            app.ProbeDataGUI_Instance = ndi.database.metadata_app.class.ProbeDataGUI(app, app.ProbeInfoPanel); 
            app.ProbeDataGUI_Instance.initialize(); 


            app.loadUserDefinedMetadata(); 
            app.populateComponentsWithMetadata(); 

            if ~isempty(app.Dataset)
                app.getInitialMetadataFromSession(); 
            end

            app.loadDatasetInformationStruct(); 

            if ~isfield(app.DatasetInformationStruct, 'VersionIdentifier') || isempty(app.DatasetInformationStruct.VersionIdentifier)
                app.DatasetInformationStruct.VersionIdentifier = app.VersionIdentifierEditField.Value;
            end
            if ~isfield(app.DatasetInformationStruct, 'VersionInnovation') || isempty(app.DatasetInformationStruct.VersionInnovation)
                app.DatasetInformationStruct.VersionInnovation = 'This is the first version of the dataset';
            end
        end

        function populateComponentsWithMetadata(app)
            import ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox

            loadInstancesToTreeCheckbox(app.ExperimentalApproachTree, "ExperimentalApproach");
            loadInstancesToTreeCheckbox(app.DataTypeTree, "SemanticDataType");
            
            app.populateLicenseDropdown(); 
            app.populateTechniqueCategoryDropdown(); 
            app.populateTechniqueDropdown(); 
            
            app.populateSpeciesList();
            app.populateBiologicalSexList();
            app.populateStrainList();
        end
        
        function populateLicenseDropdown(app)
            [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences();
            app.LicenseDropDown.Items = ["Select a License"; shortNames];
            app.LicenseDropDown.ItemsData = [""; names];
        end
        
        function populateTechniqueCategoryDropdown(app)
            allowedTypes = openminds.core.DatasetVersion.LINKED_PROPERTIES.technique;
            allowedTypes = replace(allowedTypes, 'openminds.controlledterms.', '');
            if ~iscolumn(allowedTypes) && ~isempty(allowedTypes)
                allowedTypes = allowedTypes(:);
            elseif isempty(allowedTypes)
                allowedTypes = cell(0,1); 
            end
            app.SelectTechniqueCategoryDropDown.Items = ["Select Category"; allowedTypes]; 
            app.SelectTechniqueCategoryDropDown.Value = "Select Category"; 
        end
        
        function populateTechniqueDropdown(app, schemaName)
            if nargin < 2 || isempty(schemaName) || strcmp(schemaName, "Select Category")
                app.SelectTechniqueDropDown.Items = {'Select a category first'};
                app.SelectTechniqueDropDown.ItemsData = {''}; 
                app.SelectTechniqueDropDown.Value = ''; 
                return; 
            end
            
            [names, options] = ndi.database.metadata_app.fun.getOpenMindsInstances(schemaName); 
            
            if isempty(names) 
                app.SelectTechniqueDropDown.Items = {'No techniques for this category'};
                app.SelectTechniqueDropDown.ItemsData = {''};
                app.SelectTechniqueDropDown.Value = '';
            else
                if ~iscolumn(options), options = options(:); end 
                if ~iscolumn(names), names = names(:); end     

                app.SelectTechniqueDropDown.Items = ["Select Technique"; options];
                app.SelectTechniqueDropDown.ItemsData = [""; names]; 
                app.SelectTechniqueDropDown.Value = ""; 
            end
        end
        
        function populateSpeciesList(app)
            import ndi.database.metadata_app.fun.expandDropDownItems

            openMindsType = 'Species';
            speciesCatalog = ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog(openMindsType);
            
            options_data = string.empty(0,1); 
            names_display = string.empty(0,1);   

            if ~isempty(speciesCatalog)
                options_data = string( {speciesCatalog(:).at_id}' );
                names_display = string( {speciesCatalog(:).name}' );
                options_data(ismissing(options_data)) = ''; 
            end
            
            [names_display, options_data] = expandDropDownItems(names_display, options_data, openMindsType, "AddSelectOption", true);

            if ~isempty(app.SpeciesInstancesUser)
                customNames = {app.SpeciesInstancesUser.name}'; 
                customOptions = customNames; 
                customOptions(ismissing(customOptions)) = ''; 
                
                names_display = [names_display; customNames];
                options_data = [options_data; customOptions]; 
                
                [names_display, sortIdx] = sort(names_display);
                options_data = options_data(sortIdx);
            end

            app.SpeciesListBox.Items = names_display;
            app.SpeciesListBox.ItemsData = cellstr(options_data); 
            
            if ~isempty(app.SpeciesListBox.ItemsData)
                firstValidDataIdx = find(~strcmp(app.SpeciesListBox.ItemsData, '') & ~cellfun(@(x) isstring(x) && ismissing(x), app.SpeciesListBox.ItemsData), 1, 'first');
                if ~isempty(firstValidDataIdx)
                    app.SpeciesListBox.Value = app.SpeciesListBox.ItemsData{firstValidDataIdx};
                elseif ~isempty(app.SpeciesListBox.ItemsData) 
                    app.SpeciesListBox.Value = app.SpeciesListBox.ItemsData{1}; 
                else 
                    app.SpeciesListBox.Items = {'(No species available)'}; 
                    app.SpeciesListBox.ItemsData = {''}; 
                    app.SpeciesListBox.Value = ''; 
                end
            else
                app.SpeciesListBox.Items = {'(No species available)'}; 
                app.SpeciesListBox.ItemsData = {''}; 
                app.SpeciesListBox.Value = ''; 
            end
        end

        function populateBiologicalSexList(app)
            [biologicalSexData, biologicalSexDisplay] = ndi.database.metadata_app.fun.getOpenMindsInstances('BiologicalSex');
            app.BiologicalSexListBox.Items = biologicalSexDisplay;
            app.BiologicalSexListBox.ItemsData = biologicalSexData;
            if ~isempty(biologicalSexData) && ~isempty(biologicalSexData{1}) && ~(isstring(biologicalSexData{1}) && ismissing(biologicalSexData{1}))
                app.BiologicalSexListBox.Value = biologicalSexData{1}; 
            else
                app.BiologicalSexListBox.Items = {'(No sexes available)'};
                app.BiologicalSexListBox.ItemsData = {''};
                app.BiologicalSexListBox.Value = '';
            end
        end

        function populateStrainList(app)
            items_display = "Select a Species"; 
            items_data = {''}; 

            if isprop(app, 'SpeciesListBox') && ~isempty(app.SpeciesListBox.Value) && ~(isstring(app.SpeciesListBox.Value) && ismissing(app.SpeciesListBox.Value)) && ~strcmp(app.SpeciesListBox.Value,'')
                selectedSpeciesID = app.SpeciesListBox.Value; 
                
                selectedSpeciesDisplayName = '';
                idx = find(strcmp(app.SpeciesListBox.ItemsData, selectedSpeciesID),1);
                if ~isempty(idx) && idx <= numel(app.SpeciesListBox.Items) 
                    selectedSpeciesDisplayName = app.SpeciesListBox.Items{idx};
                end
                
                if ~isempty(selectedSpeciesDisplayName) && ~strcmp(selectedSpeciesDisplayName, '(No species available)') && ~strcmp(selectedSpeciesDisplayName, 'Select a Species')
                    strainCatalog = app.getStrainInstances(); 
                    
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
                            if ~isempty(filteredStrains)
                                items_display = string({filteredStrains.name}');
                                items_data = cellstr(items_display); 
                            else
                                items_display = "No Strains for this Species";
                                items_data = {''};
                            end
                        end
                    elseif isempty(strainCatalog)
                         items_display = "No Strains Available";
                         items_data = {''};
                    end
                end
            end
            app.StrainListBox.Items = items_display;
            app.StrainListBox.ItemsData = items_data; 
            
            if ~isempty(items_data) && ~isempty(items_data{1}) && ~(isstring(items_data{1}) && ismissing(items_data{1})) && ~strcmp(items_data{1},'')
                app.StrainListBox.Value = items_data{1}; 
            else
                app.StrainListBox.Value = ''; 
            end
        end

        function getInitialMetadataFromSession(app)
            subjectDataFromEntity = ndi.database.metadata_app.fun.loadSubjects(app.Dataset);
            app.SubjectData = subjectDataFromEntity; 
            
            try
                probeDataFromEntity = ndi.database.metadata_app.fun.loadProbes(app.Dataset); 
                if isa(probeDataFromEntity, 'ndi.database.metadata_app.class.ProbeData')
                    app.ProbeData = probeDataFromEntity;
                else
                    fprintf(2,'Warning: loadProbes did not return a ProbeData object. Using default empty ProbeData.\n');
                    app.ProbeData = ndi.database.metadata_app.class.ProbeData();
                end
            catch ME_loadProbes
                 fprintf(2,'Error loading probes from dataset: %s. Using default empty ProbeData.\n', ME_loadProbes.message);
                 app.ProbeData = ndi.database.metadata_app.class.ProbeData();
            end
        end

        % Close request function: NDIMetadataEditorUIFigure
        function NDIMetadataEditorUIFigureCloseRequest(app, event)
            errors_for_dialog = {};
            try
                if isprop(app, 'Dataset') && ~isempty(app.Dataset) && isobject(app.Dataset) && isvalid(app.Dataset)
                    try
                        if isprop(app, 'DatasetInformationStruct')
                            app.DatasetInformationStruct = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
                            app.Dataset = ndi.database.metadata_ds_core.saveEditor2Doc(app.Dataset, app.DatasetInformationStruct);
                        else
                            msg_info = 'DatasetInformationStruct property not found, cannot save dataset state.';
                            fprintf(2, 'INFO during app close: %s\n', msg_info);
                        end
                    catch ME_save
                        full_msg = sprintf('ERROR saving dataset during app close: %s (ID: %s)', ME_save.message, ME_save.identifier);
                        errors_for_dialog{end+1} = ME_save.message; 
                        fprintf(2, '%s\nFull report for ME_save:\n%s\n', full_msg, ME_save.getReport('extended', 'hyperlinks', 'off'));
                    end
                end
                if isprop(app, 'UIForm') && ~isempty(app.UIForm) && isstruct(app.UIForm)
                    formNames = fieldnames(app.UIForm);
                    for i = 1:numel(formNames)
                        thisName = formNames{i};
                        try
                            if isfield(app.UIForm, thisName) && ...
                               ~isempty(app.UIForm.(thisName)) && isobject(app.UIForm.(thisName)) && isvalid(app.UIForm.(thisName))
                                delete(app.UIForm.(thisName));
                            end
                        catch ME_form
                            full_msg = sprintf('ERROR deleting UIForm element "%s" during app close: %s (ID: %s)', thisName, ME_form.message, ME_form.identifier);
                            errors_for_dialog{end+1} = sprintf('Deleting form "%s": %s', thisName, ME_form.message);
                            fprintf(2, '%s\nFull report for ME_form ("%s"):\n%s\n', full_msg, thisName, ME_form.getReport('extended', 'hyperlinks', 'off'));
                        end
                    end
                end
            catch ME_general_cleanup
                full_msg = sprintf('UNEXPECTED ERROR during app close preparation: %s (ID: %s)', ME_general_cleanup.message, ME_general_cleanup.identifier);
                errors_for_dialog{end+1} = ME_general_cleanup.message; 
                fprintf(2, '%s\nFull report for ME_general_cleanup:\n%s\n', full_msg, ME_general_cleanup.getReport('extended', 'hyperlinks', 'off'));
            end
            
            if ~isempty(errors_for_dialog)
                try
                    dialog_message_lines = {'Errors occurred while closing the NDI Metadata Editor.', ...
                                            'The application window will close, but these issues were noted:', ''};
                    for k_err = 1:min(numel(errors_for_dialog), 5) 
                        concise_msg = errors_for_dialog{k_err};
                        if length(concise_msg) > 150, concise_msg = [concise_msg(1:147), '...']; end
                        dialog_message_lines{end+1} = ['- ', concise_msg];
                    end
                    if numel(errors_for_dialog) > 5
                        dialog_message_lines{end+1} = sprintf('- ... and %d more error(s).', numel(errors_for_dialog)-5);
                    end
                    dialog_message_lines{end+1} = ''; 
                    dialog_message_lines{end+1} = 'Please check the MATLAB Command Window for full technical details.';
                    errordlg(dialog_message_lines, 'Application Closing Errors', 'non-modal');
                catch ME_dialog_display
                    fprintf(2, 'CRITICAL: Could not display graphical error dialog for closing errors: %s\n', ME_dialog_display.message);
                end
            end
            delete(app); 
        end
        
        function GetStartedButtonPushed(app, event)
            app.changeTab(app.DatasetOverviewTab);
        end

        function DatasetBranchTitleValueChanged(app, event)
            value = app.DatasetBranchTitleEditField.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("DatasetBranchTitleEditField");
            end
            if isempty(app.DatasetShortNameEditField.Value)
                generatedShortName = ndi.database.metadata_app.fun.generateShortName(value, 3);
                app.DatasetShortNameEditField.Value = generatedShortName;
                if ~isempty(generatedShortName)
                    app.resetLabelForRequiredField("DatasetShortNameEditField");
                end
            end
            app.saveDatasetInformationStruct();
        end

        function DatasetShortNameValueChanged(app, event)
            value = app.DatasetShortNameEditField.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("DatasetShortNameEditField");
            end
            app.saveDatasetInformationStruct();
        end

        function AbstractValueChanged(app, event)
            value = app.AbstractTextArea.Value;
            if ~isempty(value) 
                 if iscell(value) && ~isempty(value{1})
                    app.resetLabelForRequiredField("AbstractTextArea");
                 elseif ischar(value) && ~isempty(strtrim(value))
                    app.resetLabelForRequiredField("AbstractTextArea");
                 end
            end
            app.saveDatasetInformationStruct();
        end

        function CommentsDetailsValueChanged(app, event)
            value = app.DatasetCommentsTextArea.Value;
             if ~isempty(value) 
                 if iscell(value) && ~isempty(value{1})
                    app.resetLabelForRequiredField("DatasetCommentsTextArea");
                 elseif ischar(value) && ~isempty(strtrim(value))
                    app.resetLabelForRequiredField("DatasetCommentsTextArea");
                 end
            end
            app.saveDatasetInformationStruct();
        end
        
        function SaveChangesButtonPushed(app, event) 
            app.NDIMetadataEditorUIFigure.Name = 'NDI Dataset Wizard (Saving temporary data...)';
            app.saveDatasetInformationStruct();
            app.NDIMetadataEditorUIFigure.Name = 'NDI Dataset Wizard (Temporary data saved)';
            app.resetFigureNameIn('NDI Metadata Editor', 5);
        end

        function SaveButtonPushed(app, event) 
            missingRequiredField = app.checkRequiredFields(""); 
            if ~isempty(missingRequiredField)
                app.alertRequiredFieldsMissing(missingRequiredField);
                return;
            end
            currentDatasetInfoStruct = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
            ndi.database.metadata_app.fun.save_dataset_docs(app.Dataset, app.Dataset.id(), currentDatasetInfoStruct);
            app.inform('Dataset metadata successfully saved to NDI documents.', 'Save Successful');
        end

        function ReleaseDateValueChanged(app, event)
            app.saveDatasetInformationStruct();
        end

        function LicenseDropDownValueChanged(app, event)
            value = event.Value;
            if value ~= "" 
                app.resetLabelForRequiredField("LicenseDropDown");
            end
            app.saveDatasetInformationStruct();
        end
        
        function FullDocumentationValueChanged(app, event)
            value = event.Value;
            isValid = true;
            try 
                if ~isempty(value) && ~(startsWith(value, 'http') || contains(value, 'doi.org') || regexp(value, '^\d{2}\.\d{4,9}/[-._;()/:A-Z0-9]+$','ignorecase'))
                end
            catch
                isValid = false;
            end
            if ~isValid
                 app.alert('Full documentation should be a valid URL or DOI.', 'Invalid Input');
            else
                app.saveDatasetInformationStruct();
            end
        end
        
        function VersionIdentifierValueChanged(app, event)
            if ~isempty(event.Value), app.resetLabelForRequiredField('VersionIdentifierEditField'); end
            app.saveDatasetInformationStruct();
        end

        function VersionInnovationValueChanged(app, event)
            app.saveDatasetInformationStruct();
        end
        
        function AddFundingButtonPushed(app, event)
            S = app.openFundingForm();
            if isempty(S); return; end
            if ~isfield(app.DatasetInformationStruct, 'Funding') || isempty(app.DatasetInformationStruct.Funding)
                app.DatasetInformationStruct.Funding = S;
            else
                app.DatasetInformationStruct.Funding(end+1) = S;
            end
            app.FundingUITable.Data = struct2table(app.DatasetInformationStruct.Funding, 'AsArray', true);
            app.saveDatasetInformationStruct();
        end

        function RemoveFundingButtonPushed(app, event)
            rowIdx = app.FundingUITable.Selection;
            if ~isempty(rowIdx) && isfield(app.DatasetInformationStruct, 'Funding') && ~isempty(app.DatasetInformationStruct.Funding)
                app.DatasetInformationStruct.Funding(rowIdx) = [];
                if isempty(app.DatasetInformationStruct.Funding) 
                    expectedFields = {'funder','awardTitle','awardNumber'};
                    emptyStructWithFields = struct();
                    for k=1:numel(expectedFields)
                        emptyStructWithFields.(expectedFields{k}) = []; 
                    end
                    if numel(expectedFields) > 0
                        app.DatasetInformationStruct.Funding = repmat(emptyStructWithFields,0,1);
                    else
                        app.DatasetInformationStruct.Funding = struct([]); 
                    end
                end
                app.FundingUITable.Data = struct2table(app.DatasetInformationStruct.Funding, 'AsArray', true);
                app.saveDatasetInformationStruct();
            end
        end
        
        function AddRelatedPublicationButtonPushed(app,event)
            S = app.openForm("Publication");
            if isempty(S); return; end
            
            if ~isfield(app.DatasetInformationStruct, 'RelatedPublication') || isempty(app.DatasetInformationStruct.RelatedPublication)
                app.DatasetInformationStruct.RelatedPublication = S;
            else
                app.DatasetInformationStruct.RelatedPublication(end+1) = S;
            end
            app.RelatedPublicationUITable.Data = struct2table(app.DatasetInformationStruct.RelatedPublication, 'AsArray', true);
            app.saveDatasetInformationStruct();
        end

        function DataTypeTreeCheckedNodesChanged(app, event)
            selectedDataTypes = app.getCheckedTreeNodeData(event.CheckedNodes);
            if ~isempty(selectedDataTypes)
                app.resetLabelForRequiredField("DataTypeTree");
            end
            app.saveDatasetInformationStruct();
        end

        function ExperimentTreeCheckedNodesChanged(app, event)
            selectedExperimentalApproach = app.getCheckedTreeNodeData(event.CheckedNodes);
            if ~isempty(selectedExperimentalApproach)
                app.resetLabelForRequiredField("ExperimentalApproachTree");
            end
            app.saveDatasetInformationStruct();
        end
        
        function SelectTechniqueCategoryDropDownValueChanged(app, event)
            value = app.SelectTechniqueCategoryDropDown.Value;
            app.populateTechniqueDropdown(value); 
        end

        function AddTechniqueButtonPushed(app, event)
            techniqueCategory = app.SelectTechniqueCategoryDropDown.Value;
            techniqueName = app.SelectTechniqueDropDown.Value;
            if ~any(strcmp(techniqueName, app.SelectTechniqueDropDown.ItemsData))
                app.inform('Please select one of the techniques from the list'); return;
            end
            technique = sprintf('%s (%s)', techniqueName, techniqueCategory);
            if any(strcmp(technique, app.SelectedTechniquesListBox.Items))
                app.inform(sprintf('The technique "%s" has already been added.', techniqueName)); return;
            end
            app.SelectedTechniquesListBox.Items{end+1} = technique;
            app.saveDatasetInformationStruct();
        end

        function RemoveTechniqueButtonPushed(app, event)
            selectedIndex = app.getListBoxSelectionIndex(app.SelectedTechniquesListBox);
            if ~isempty(selectedIndex)
                app.SelectedTechniquesListBox.Items(selectedIndex) = [];
                app.SelectedTechniquesListBox.Value = {};
                app.saveDatasetInformationStruct();
            end
        end
        
        function AssignBiologicalSexButtonPushed(app, event)
            app.updateSubjectTableColumData('BiologicalSex', app.BiologicalSexListBox.Value);
        end
        function BiologicalSexListBoxClicked(app, event)
            drawnow; 
            app.updateSubjectTableColumData('BiologicalSex', event.Source.Value);
        end
        function AssignSpeciesButtonPushed(app, event)
            app.updateSubjectTableColumData('Species', app.SpeciesListBox.Value);
        end
        function SpeciesListBoxClicked(app, event)
            drawnow;
            value = event.Source.Value;
            if ismissing(value) || strcmp(value,'') % Check for missing or empty string (placeholder)
                app.deleteSubjectTableColumData("Species");
                app.deleteSubjectTableColumData("Strain"); 
            else
                app.updateSubjectTableColumData('Species', value);
                app.deleteSubjectTableColumData("Strain"); 
            end
            app.populateStrainList(); 
        end
        
        function TabGroupSelectionChanged(app, event)
            app.onTabChanged(); 
        end
        function PreviousButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find(app.TabGroup.Children == currentTab);
            if tabIdx > 1
                missingRequiredField = app.checkRequiredFields(currentTab);
                if ~isempty(missingRequiredField)
                    app.alertRequiredFieldsMissing(missingRequiredField); return;
                end
                app.changeTab(app.TabGroup.Children(tabIdx - 1));
            end
        end
        function NextButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find(app.TabGroup.Children == currentTab);
            if tabIdx < numel(app.TabGroup.Children)
                missingRequiredField = app.checkRequiredFields(currentTab);
                if ~isempty(missingRequiredField)
                    app.alertRequiredFieldsMissing(missingRequiredField); return;
                end
                app.changeTab(app.TabGroup.Children(tabIdx + 1));
            end
        end

        function TestDocumentConversionButtonPushed(app, event)
            currentStructToConvert = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
            documentList = ndi.database.metadata_ds_core.convertFormDataToDocuments(currentStructToConvert, app.Dataset.id());
            for i = 1:numel(documentList)
                disp( jsonencode(documentList{i}.document_properties, 'PrettyPrint', true));
            end
        end
        function ExportDatasetInfoButtonPushed(app, event)
            currentStructToExport = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
            assignin('base', 'datasetInfoStruct', currentStructToExport);
            disp('DatasetInformationStruct exported to base workspace as "datasetInfoStruct".');
        end
        function LicenseHelpImageClicked(app, event) 
            web("https://en.wikipedia.org/wiki/Creative_Commons_license#Four_rights");
        end
        function LicenseHelpButtonPushed(app, event)
            web("https://en.wikipedia.org/wiki/Creative_Commons_license#Six_regularly_used_licenses");
        end
        
        function performActualFormReset(app)
            % Clear data objects
            if isprop(app, 'AuthorData') && ismethod(app.AuthorData, 'ClearAll'), app.AuthorData.ClearAll(); end
            if isprop(app, 'AuthorData') && ismethod(app.AuthorData, 'addDefaultAuthorEntry'), app.AuthorData.addDefaultAuthorEntry(); end
            
            if ~isempty(app.Dataset)
                app.getInitialMetadataFromSession(); 
            else 
                if isprop(app, 'SubjectData') && ismethod(app.SubjectData,'ClearAll'), app.SubjectData.ClearAll(); else, if isprop(app,'SubjectData'), app.SubjectData.SubjectList = ndi.database.metadata_app.class.Subject.empty(0,1); end; end
                if isprop(app,'UITableSubject'), app.UITableSubject.Data = table(); end
                if isprop(app, 'ProbeData') && ismethod(app.ProbeData,'ClearAll'), app.ProbeData.ClearAll(); else, if isprop(app,'ProbeData'), app.ProbeData.ProbeList = {}; end; end
                % Check if ProbeDataGUI_Instance and its UITableProbe are valid before accessing
                if isprop(app, 'ProbeDataGUI_Instance') && isvalid(app.ProbeDataGUI_Instance) && ...
                   isprop(app.ProbeDataGUI_Instance, 'UITableProbe') && isvalid(app.ProbeDataGUI_Instance.UITableProbe)
                    app.ProbeDataGUI_Instance.UITableProbe.Data = table();
                end
            end
            
            app.DatasetInformationStruct = ndi.database.metadata_app.fun.validateDatasetInformation(struct(), app); 
            ndi.database.metadata_app.fun.populateAppFromDatasetInformationStruct(app, app.DatasetInformationStruct);
            app.saveDatasetInformationStruct();
            app.inform('Form has been reset.', 'Form Reset');
        end
        
        function ResetFormButtonPushed(app, event)
            answer = uiconfirm(app.NDIMetadataEditorUIFigure, ...
                ['Are you sure you want to reset the form? All unsaved changes will be lost ' ...
                 'and the form will be repopulated with initial data from the NDI entity or to a blank state.'], ...
                'Confirm Reset', ...
                'Options', {'Yes, Reset', 'Cancel'}, 'DefaultOption', 'Cancel', 'Icon', 'warning');
            if strcmp(answer, 'Yes, Reset'), app.performActualFormReset(); end
        end
        
        function RevertToSavedButtonPushed(app, event)
            answer = uiconfirm(app.NDIMetadataEditorUIFigure, ...
                'Are you sure you want to revert to the last saved version? All current unsaved changes will be lost.', ...
                'Confirm Revert', ...
                'Options', {'Yes, Revert', 'Cancel'}, 'DefaultOption', 'Cancel');
            if strcmp(answer, 'Yes, Revert')
                app.loadDatasetInformationStruct(); 
                app.inform('Form has been reverted to the last saved version.', 'Reverted to Saved');
            end
        end
        
        % Callbacks for specific list boxes in Subject Info tab
        function BiologicalSexListBoxValueChanged(app, event)
            % This might trigger updates or just be for selection
            app.saveDatasetInformationStruct(); % Save if selection implies data change
        end

        function SpeciesListBoxValueChanged(app, event)
            app.populateStrainList(); % Populate strains based on selected species
            app.saveDatasetInformationStruct();
        end

        function StrainListBoxValueChanged(app, event)
            app.saveDatasetInformationStruct(); % Save if selection implies data change
        end
        
        function StrainListBoxClicked(app, event)
            % This callback might be used if double-click is too slow or for other interactions
            drawnow;
            app.updateSubjectTableColumData('Strain', event.Source.Value);
        end

        function StrainListBoxDoubleClicked(app, event)
            % Could be used to edit a selected strain, if such functionality is added
        end

        function AddSpeciesButtonPushed(app, event)
            speciesName = app.SpeciesEditField.Value;
            if isempty(strtrim(speciesName))
                app.alert('Please enter a species name to add.', 'Species Name Empty');
                return;
            end
            % Create a basic struct for the new species
            newSpeciesStruct = struct('name', speciesName, 'ontologyIdentifier', '', 'synonyms', {{}});
            
            % Open the SpeciesForm to allow user to fill details
            returnedSpeciesStruct = app.openSpeciesForm(newSpeciesStruct);
            
            if ~isempty(returnedSpeciesStruct) && isfield(returnedSpeciesStruct, 'name') && ~isempty(strtrim(returnedSpeciesStruct.name))
                % Add to app.SpeciesInstancesUser and app.SpeciesData
                app.SpeciesInstancesUser(end+1) = returnedSpeciesStruct;
                app.SpeciesData.addItem(returnedSpeciesStruct.name, returnedSpeciesStruct.ontologyIdentifier, returnedSpeciesStruct.synonyms);
                app.saveSpecies(); % Save the updated user instances
                app.populateSpeciesList(); % Refresh the listbox
                app.SpeciesEditField.Value = ''; % Clear the edit field
                app.inform(sprintf('Species "%s" added.', returnedSpeciesStruct.name), 'Species Added');
            else
                app.inform('Species addition cancelled or failed.', 'Info');
            end
        end

        function AddStrainButtonPushed(app, event)
            % Similar to AddSpecies, but for strains. This needs a StrainForm or direct add.
            % For now, let's assume direct add to a catalog if no form exists.
            strainName = app.StrainEditField.Value;
            if isempty(strtrim(strainName))
                app.alert('Please enter a strain name to add.', 'Strain Name Empty');
                return;
            end
            
            % This part needs to be fleshed out: how are new strains stored?
            % Are they associated with the currently selected species?
            % For now, let's just refresh the strain list (it won't show new one unless getStrainInstances is updated)
            app.populateStrainList(); 
            app.StrainEditField.Value = '';
            app.inform(sprintf('Strain "%s" added (placeholder logic). Implement saving and catalog update.', strainName), 'Strain Added (Placeholder)');
        end
        
        function BiologicalSexClearButtonPushed(app, event)
            app.deleteSubjectTableColumData('BiologicalSex');
        end
        function SpeciesClearButtonPushed(app, event)
            app.deleteSubjectTableColumData('Species');
            app.populateStrainList(); % Strains depend on species
        end
        function StrainClearButtonPushed(app, event)
            app.deleteSubjectTableColumData('Strain');
        end

    end

    % Component initialization
    methods (Access = private)
        function createComponents(app)
            % Get the file path for locating images relative to this app file
            appFileFolder = fileparts(mfilename('fullpath'));
            % Define ResourcesPath based on the app's location
            app.ResourcesPath = fullfile(appFileFolder, 'resources'); 
            if ~isfolder(app.ResourcesPath)
                 fprintf(2, 'Warning (createComponents): ResourcesPath not found: %s. Icon paths might be incorrect.\n', app.ResourcesPath);
            end

            app.NDIMetadataEditorUIFigure = uifigure('Visible', 'off', ...
                'Position', [100 100 900 610], 'Name', 'NDI Metadata Editor', ...
                'CloseRequestFcn', createCallbackFcn(app, @NDIMetadataEditorUIFigureCloseRequest, true));

            app.MainGridLayout = uigridlayout(app.NDIMetadataEditorUIFigure, [2 1], ...
                'RowHeight', {'1x', 'fit'}, 'RowSpacing', 0, 'Padding', [0 0 0 0]);
            app.MainGridLayout.RowHeight = {'1x'}; 

            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.Layout.Row = 1; app.TabGroup.Layout.Column = 1;
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            app.IntroTab = uitab(app.TabGroup, 'Title', 'Intro');
            app.IntroGridLayout = uigridlayout(app.IntroTab, [3 1], 'RowHeight', {60, '4x', '1.5x'});
            app.IntroGridLayout.Padding = [10 10 10 10]; 
                app.GridLayout25 = uigridlayout(app.IntroGridLayout); 
                app.GridLayout25.Layout.Row=1; app.GridLayout25.Layout.Column=1;
                app.GridLayout25.ColumnWidth = {25, 100, '1x', 100, 25}; app.GridLayout25.RowHeight = {'1x'};
                    app.IntroLabel = uilabel(app.GridLayout25, 'Text', {'Welcome to the NDI Cloud''s core Metadata Editor'; ''}, ...
                        'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
                    app.IntroLabel.Layout.Row = 1; app.IntroLabel.Layout.Column = 3;
                    app.NdiLogoIntroImage = uiimage(app.GridLayout25, 'ImageSource', fullfile(app.ResourcesPath, 'ndi_logo.png')); 
                    app.NdiLogoIntroImage.Layout.Row = 1; app.NdiLogoIntroImage.Layout.Column = 4;
                app.GridLayout_Step0_C2 = uigridlayout(app.IntroGridLayout); 
                app.GridLayout_Step0_C2.Layout.Row=2; app.GridLayout_Step0_C2.Layout.Column=1;
                app.GridLayout_Step0_C2.Padding = [10 25 10 25]; 
                app.GridLayout_Step0_C2.ColumnWidth = {'1x'}; 
                app.GridLayout_Step0_C2.RowHeight = {'1x'}; 
                    app.IntroductionTextLabel = uilabel(app.GridLayout_Step0_C2, 'Text', ...
                        {''; 'We''re excited to have you here. This is your upload form, where you can effortlessly share your data with us. Over the next few pages, we''ll guide you through the process of ingesting your valuable data. Our goal is to make this as seamless as possible, ensuring that your information is accurately processed and ready for analysis. '; ''; 'If you ever need assistance with any of the form elements, simply hover over the respective item to access helpful information. For any further queries, shoot us an email at info@walthamdatascience.com and we''ll get right back to you! Thank you for choosing our app to help you manage your data. Let''s get started on this journey together!'}, ...
                        'VerticalAlignment', 'top', 'WordWrap', 'on', 'FontSize', 14);
                    app.IntroductionTextLabel.Layout.Row = 1; app.IntroductionTextLabel.Layout.Column = 1; 
            app.GridLayout_Step0_C3 = uigridlayout(app.IntroGridLayout); 
            app.GridLayout_Step0_C3.Layout.Row=3; app.GridLayout_Step0_C3.Layout.Column=1;
            app.GridLayout_Step0_C3.ColumnWidth = {'1x', 150, '1x'}; app.GridLayout_Step0_C3.RowHeight = {40};
                app.GetStartedButton = uibutton(app.GridLayout_Step0_C3, 'push', 'Text', 'Get Started', ...
                    'ButtonPushedFcn', createCallbackFcn(app, @GetStartedButtonPushed, true));
                app.GetStartedButton.Layout.Row = 1; app.GetStartedButton.Layout.Column = 2;
            
            app.DatasetOverviewTab = uitab(app.TabGroup, 'Title', 'Dataset Overview');
            app.DatasetOverviewGridLayout = uigridlayout(app.DatasetOverviewTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
                app.DatasetInformationLabel = uilabel(app.DatasetOverviewGridLayout, 'Text', 'Dataset Information', ...
                    'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
                app.DatasetInformationLabel.Layout.Row=1; app.DatasetInformationLabel.Layout.Column=1;
                app.DatasetInformationPanel = uipanel(app.DatasetOverviewGridLayout, 'BorderType', 'none');
                app.DatasetInformationPanel.Layout.Row=2; app.DatasetInformationPanel.Layout.Column=1;
                    app.GridLayout = uigridlayout(app.DatasetInformationPanel, [3 1], 'RowHeight', {'fit', '4x', '2x'}, 'Padding', [25 25 25 10]); 
                        app.Panel_3 = uipanel(app.GridLayout, 'BorderType', 'none'); 
                        app.Panel_3.Layout.Row=1; app.Panel_3.Layout.Column=1;
                            app.GridLayout2 = uigridlayout(app.Panel_3, [2 2], 'ColumnWidth', {'2.5x','1x'}, 'ColumnSpacing', 15, 'RowSpacing', 4); 
                                app.DatasetBranchTitleEditFieldLabel = uilabel(app.GridLayout2, 'Text', 'Dataset Branch Title');
                                app.DatasetBranchTitleEditFieldLabel.Layout.Row=1; app.DatasetBranchTitleEditFieldLabel.Layout.Column=1;
                                app.DatasetBranchTitleEditField = uieditfield(app.GridLayout2, 'text', 'ValueChangedFcn', createCallbackFcn(app, @DatasetBranchTitleValueChanged, true));
                                app.DatasetBranchTitleEditField.Layout.Row=2; app.DatasetBranchTitleEditField.Layout.Column=1;
                                app.DatasetShortNameEditFieldLabel = uilabel(app.GridLayout2, 'Text', 'Dataset Short Name');
                                app.DatasetShortNameEditFieldLabel.Layout.Row=1; app.DatasetShortNameEditFieldLabel.Layout.Column=2;
                                app.DatasetShortNameEditField = uieditfield(app.GridLayout2, 'text', 'ValueChangedFcn', createCallbackFcn(app, @DatasetShortNameValueChanged, true));
                                app.DatasetShortNameEditField.Layout.Row=2; app.DatasetShortNameEditField.Layout.Column=2;
                        app.Panel_4 = uipanel(app.GridLayout, 'BorderType', 'none'); 
                        app.Panel_4.Layout.Row=2; app.Panel_4.Layout.Column=1;
                            app.GridLayout3 = uigridlayout(app.Panel_4, [2 1], 'RowHeight', {20, '1x'}, 'RowSpacing', 4);
                                app.AbstractTextAreaLabel = uilabel(app.GridLayout3, 'Text', 'Abstract');
                                app.AbstractTextAreaLabel.Layout.Row=1; app.AbstractTextAreaLabel.Layout.Column=1;
                                app.AbstractTextArea = uitextarea(app.GridLayout3, 'ValueChangedFcn', createCallbackFcn(app, @AbstractValueChanged, true));
                                app.AbstractTextArea.Layout.Row=2; app.AbstractTextArea.Layout.Column=1;
                        app.GridLayout4 = uigridlayout(app.GridLayout); 
                        app.GridLayout4.Layout.Row=3; app.GridLayout4.Layout.Column=1;
                        app.GridLayout4.RowHeight = {20, '1x'}; app.GridLayout4.RowSpacing = 4;
                            app.DatasetCommentsTextAreaLabel = uilabel(app.GridLayout4, 'Text', 'Comments/Details');
                            app.DatasetCommentsTextAreaLabel.Layout.Row=1; app.DatasetCommentsTextAreaLabel.Layout.Column=1;
                            app.DatasetCommentsTextArea = uitextarea(app.GridLayout4, 'ValueChangedFcn', createCallbackFcn(app, @CommentsDetailsValueChanged, true));
                            app.DatasetCommentsTextArea.Layout.Row=2; app.DatasetCommentsTextArea.Layout.Column=1;

            app.AuthorsTab = uitab(app.TabGroup, 'Title', 'Authors');
            app.AuthorsGridLayout = uigridlayout(app.AuthorsTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
                app.AuthorDetailsLabel = uilabel(app.AuthorsGridLayout, 'Text', 'Author Details', ...
                    'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
                app.AuthorDetailsLabel.Layout.Row = 1; app.AuthorDetailsLabel.Layout.Column = 1;
                app.AuthorMainPanel = uipanel(app.AuthorsGridLayout, 'BorderType', 'none', 'Scrollable','on');
                app.AuthorMainPanel.Layout.Row = 2; app.AuthorMainPanel.Layout.Column = 1;
            
            app.DatasetDetailsTab = uitab(app.TabGroup, 'Title', 'Dataset Details');
            app.DatasetDetailsGridLayout = uigridlayout(app.DatasetDetailsTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
                app.DatasetDetailsLabel = uilabel(app.DatasetDetailsGridLayout, 'Text', 'Dataset Details', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
                app.DatasetDetailsLabel.Layout.Row=1; app.DatasetDetailsLabel.Layout.Column=1;
                app.DatasetDetailsPanel = uipanel(app.DatasetDetailsGridLayout, 'BorderType', 'none');
                app.DatasetDetailsPanel.Layout.Row=2; app.DatasetDetailsPanel.Layout.Column=1;
                    app.GridLayout18 = uigridlayout(app.DatasetDetailsPanel, [2 1], 'RowHeight', {'fit', '1x'}, 'Padding', [25 25 25 10]); 
                        app.GridLayout19 = uigridlayout(app.GridLayout18, [1 2], 'ColumnSpacing', 25, 'ColumnWidth', {'1x', '1x'}); 
                        app.GridLayout19.Layout.Row=1; app.GridLayout19.Layout.Column=1;
                            app.GridLayout22 = uigridlayout(app.GridLayout19); 
                            app.GridLayout22.Layout.Row=1; app.GridLayout22.Layout.Column=1;
                            app.GridLayout22.ColumnWidth = {'0.8x', '1.2x'}; app.GridLayout22.RowHeight = {23, 23, 23, 23, 23, 23}; 
                                app.AccessibilityLabel = uilabel(app.GridLayout22, 'Text', 'Accessibility', 'FontWeight', 'bold');
                                app.AccessibilityLabel.Layout.Row=1; app.AccessibilityLabel.Layout.Column=1;
                                app.ReleaseDateDatePickerLabel = uilabel(app.GridLayout22, 'Text', 'Release Date', 'HorizontalAlignment', 'right');
                                app.ReleaseDateDatePickerLabel.Layout.Row=2; app.ReleaseDateDatePickerLabel.Layout.Column=1;
                                app.ReleaseDateDatePicker = uidatepicker(app.GridLayout22, 'ValueChangedFcn', createCallbackFcn(app, @ReleaseDateValueChanged, true));
                                app.ReleaseDateDatePicker.Layout.Row=2; app.ReleaseDateDatePicker.Layout.Column=2;
                                app.LicenseDropDownLabel = uilabel(app.GridLayout22, 'Text', 'License', 'HorizontalAlignment', 'right');
                                app.LicenseDropDownLabel.Layout.Row=3; app.LicenseDropDownLabel.Layout.Column=1;
                                app.GridLayout28 = uigridlayout(app.GridLayout22); 
                                app.GridLayout28.Layout.Row=3; app.GridLayout28.Layout.Column=2;
                                app.GridLayout28.ColumnWidth = {'1x',23}; app.GridLayout28.Padding = [0 0 0 0]; app.GridLayout28.RowHeight = {'fit'}; 
                                    app.LicenseDropDown = uidropdown(app.GridLayout28, 'ValueChangedFcn', createCallbackFcn(app, @LicenseDropDownValueChanged, true));
                                    app.LicenseDropDown.Layout.Row=1; app.LicenseDropDown.Layout.Column=1;
                                    app.LicenseHelpButton = uibutton(app.GridLayout28, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'help.png'), 'ButtonPushedFcn', createCallbackFcn(app, @LicenseHelpButtonPushed, true));
                                    app.LicenseHelpButton.Layout.Row=1; app.LicenseHelpButton.Layout.Column=2;
                                app.FullDocumentationEditFieldLabel = uilabel(app.GridLayout22, 'Text', 'Full Documentation', 'HorizontalAlignment', 'right');
                                app.FullDocumentationEditFieldLabel.Layout.Row=4; app.FullDocumentationEditFieldLabel.Layout.Column=1;
                                app.FullDocumentationEditField = uieditfield(app.GridLayout22, 'text', 'ValueChangedFcn', createCallbackFcn(app, @FullDocumentationValueChanged, true));
                                app.FullDocumentationEditField.Layout.Row=4; app.FullDocumentationEditField.Layout.Column=2;
                                app.VersionIdentifierEditFieldLabel = uilabel(app.GridLayout22, 'Text', 'Version Identifier', 'HorizontalAlignment', 'right');
                                app.VersionIdentifierEditFieldLabel.Layout.Row=5; app.VersionIdentifierEditFieldLabel.Layout.Column=1;
                                app.VersionIdentifierEditField = uieditfield(app.GridLayout22, 'text', 'Value', '1.0.0', 'ValueChangedFcn', createCallbackFcn(app, @VersionIdentifierValueChanged, true));
                                app.VersionIdentifierEditField.Layout.Row=5; app.VersionIdentifierEditField.Layout.Column=2;
                                app.VersionInnovationEditFieldLabel = uilabel(app.GridLayout22, 'Text', 'Version Innovation', 'HorizontalAlignment', 'right');
                                app.VersionInnovationEditFieldLabel.Layout.Row=6; app.VersionInnovationEditFieldLabel.Layout.Column=1;
                                app.VersionInnovationEditField = uieditfield(app.GridLayout22, 'text', 'Value', 'This is the first version of the dataset', 'ValueChangedFcn', createCallbackFcn(app, @VersionInnovationValueChanged, true));
                                app.VersionInnovationEditField.Layout.Row=6; app.VersionInnovationEditField.Layout.Column=2;
                            app.FundingGridLayout = uigridlayout(app.GridLayout19); 
                            app.FundingGridLayout.Layout.Row=1; app.FundingGridLayout.Layout.Column=2;
                            app.FundingGridLayout.ColumnWidth = {'1x', 45}; 
                            app.FundingGridLayout.RowHeight = {23, '1x'};
                                app.FundingUITableLabel = uilabel(app.FundingGridLayout, 'Text', 'Funding', 'FontWeight', 'bold');
                                app.FundingUITableLabel.Layout.Row=1; app.FundingUITableLabel.Layout.Column=1;
                                app.FundingUITable = uitable(app.FundingGridLayout, 'ColumnName', {'Funder'; 'Award Title'; 'Award Number'}, 'RowName', {}, 'SelectionType', 'row', 'Multiselect', 'off', 'DoubleClickedFcn', createCallbackFcn(app, @FundingUITableDoubleClicked, true));
                                app.FundingUITable.Layout.Row=2; app.FundingUITable.Layout.Column=1;
                                app.FundingTableButtonGridLayout = uigridlayout(app.FundingGridLayout);
                                app.FundingTableButtonGridLayout.Layout.Row=2; app.FundingTableButtonGridLayout.Layout.Column=2;
                                app.FundingTableButtonGridLayout.RowHeight={23,23,10,23,23,'1x'}; app.FundingTableButtonGridLayout.ColumnWidth={'1x'}; app.FundingTableButtonGridLayout.Padding = [0 0 0 0];
                                    app.AddFundingButton = uibutton(app.FundingTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'plus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @AddFundingButtonPushed, true));
                                    app.AddFundingButton.Layout.Row=1; app.AddFundingButton.Layout.Column=1;
                                    app.RemoveFundingButton = uibutton(app.FundingTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'minus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @RemoveFundingButtonPushed, true));
                                    app.RemoveFundingButton.Layout.Row=2; app.RemoveFundingButton.Layout.Column=1;
                                    app.MoveFundingUpButton = uibutton(app.FundingTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'up.png'), 'ButtonPushedFcn', createCallbackFcn(app, @MoveFundingUpButtonPushed, true));
                                    app.MoveFundingUpButton.Layout.Row=4; app.MoveFundingUpButton.Layout.Column=1; 
                                    app.MoveFundingDownButton = uibutton(app.FundingTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'down.png'), 'ButtonPushedFcn', createCallbackFcn(app, @MoveFundingDownButtonPushed, true));
                                    app.MoveFundingDownButton.Layout.Row=5; app.MoveFundingDownButton.Layout.Column=1;
                        app.GridLayout20 = uigridlayout(app.GridLayout18); 
                        app.GridLayout20.Layout.Row=2; app.GridLayout20.Layout.Column=1;
                        app.GridLayout20.ColumnWidth = {'1x', 45}; 
                        app.GridLayout20.RowHeight = {23, '1x'};
                            app.RelatedPublicationUITableLabel = uilabel(app.GridLayout20, 'Text', 'Related Publications', 'FontWeight', 'bold');
                            app.RelatedPublicationUITableLabel.Layout.Row=1; app.RelatedPublicationUITableLabel.Layout.Column=1;
                            app.RelatedPublicationUITable = uitable(app.GridLayout20, 'ColumnName', {'Publication'; 'DOI'; 'PMID'; 'PMCID'}, 'RowName', {}, 'SelectionType', 'row', 'Multiselect', 'off', 'CellEditCallback', createCallbackFcn(app, @RelatedPublicationCellEdit, true), 'DoubleClickedFcn', createCallbackFcn(app, @RelatedPublicationUITableDoubleClicked, true));
                            app.RelatedPublicationUITable.Layout.Row=2; app.RelatedPublicationUITable.Layout.Column=1;
                            app.PublicationTableButtonGridLayout = uigridlayout(app.GridLayout20);
                            app.PublicationTableButtonGridLayout.Layout.Row=2; app.PublicationTableButtonGridLayout.Layout.Column=2;
                            app.PublicationTableButtonGridLayout.RowHeight={23,23,10,23,23,'1x'}; app.PublicationTableButtonGridLayout.ColumnWidth={'1x'}; app.PublicationTableButtonGridLayout.Padding = [0 0 0 0];
                                app.AddRelatedPublicationButton = uibutton(app.PublicationTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'plus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @AddRelatedPublicationButtonPushed, true));
                                app.AddRelatedPublicationButton.Layout.Row=1; app.AddRelatedPublicationButton.Layout.Column=1;
                                app.RemovePublicationButton = uibutton(app.PublicationTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'minus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @RemovePublicationButtonPushed, true));
                                app.RemovePublicationButton.Layout.Row=2; app.RemovePublicationButton.Layout.Column=1;
                                app.MovePublicationUpButton = uibutton(app.PublicationTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'up.png'), 'ButtonPushedFcn', createCallbackFcn(app, @MovePublicationUpButtonPushed, true));
                                app.MovePublicationUpButton.Layout.Row=4; app.MovePublicationUpButton.Layout.Column=1; 
                                app.MovePublicationDownButton = uibutton(app.PublicationTableButtonGridLayout, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'down.png'), 'ButtonPushedFcn', createCallbackFcn(app, @MovePublicationDownButtonPushed, true));
                                app.MovePublicationDownButton.Layout.Row=5; app.MovePublicationDownButton.Layout.Column=1;

            app.ExperimentDetailsTab = uitab(app.TabGroup, 'Title', 'Experiment Details');
            app.ExperimentDetailsGridLayout = uigridlayout(app.ExperimentDetailsTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.ExperimentDetailsLabel = uilabel(app.ExperimentDetailsGridLayout, 'Text', 'Experiment Details', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.ExperimentDetailsLabel.Layout.Row=1; app.ExperimentDetailsLabel.Layout.Column=1;
            app.ExperimentDetailsPanel = uipanel(app.ExperimentDetailsGridLayout, 'BorderType', 'none');
            app.ExperimentDetailsPanel.Layout.Row=2; app.ExperimentDetailsPanel.Layout.Column=1;
            app.GridLayout26 = uigridlayout(app.ExperimentDetailsPanel, [9 6], ...
                'ColumnWidth', {180, 45, '1.25x', 45, '1x', 25}, ...
                'RowHeight', {22, 22, 22, 23, '1x', 22, 23, '5.3x', '5.13x'}, ... 
                'Padding', [25 25 25 10]);
                app.DataTypeTreeLabel = uilabel(app.GridLayout26, 'Text', 'Data Type');
                app.DataTypeTreeLabel.Layout.Row = 1; app.DataTypeTreeLabel.Layout.Column = 1;
                app.DataTypeTree = uitree(app.GridLayout26, 'checkbox', 'CheckedNodesChangedFcn', createCallbackFcn(app, @DataTypeTreeCheckedNodesChanged, true));
                app.DataTypeTree.Layout.Row = [2 5]; app.DataTypeTree.Layout.Column = 1; 
                app.ExperimentalApproachTreeLabel = uilabel(app.GridLayout26, 'Text', 'Experimental Approach');
                app.ExperimentalApproachTreeLabel.Layout.Row = 1; app.ExperimentalApproachTreeLabel.Layout.Column = 3;
                app.ExperimentalApproachTree = uitree(app.GridLayout26, 'checkbox', 'CheckedNodesChangedFcn', createCallbackFcn(app, @ExperimentTreeCheckedNodesChanged, true));
                app.ExperimentalApproachTree.Layout.Row = [2 9]; app.ExperimentalApproachTree.Layout.Column = 3; 
                app.SelectTechniqueCategoryDropDownLabel = uilabel(app.GridLayout26, 'Text', 'Select Technique Category');
                app.SelectTechniqueCategoryDropDownLabel.Layout.Row = 1; app.SelectTechniqueCategoryDropDownLabel.Layout.Column = 5;
                app.SelectTechniqueCategoryDropDown = uidropdown(app.GridLayout26, 'ValueChangedFcn', createCallbackFcn(app, @SelectTechniqueCategoryDropDownValueChanged, true));
                app.SelectTechniqueCategoryDropDown.Layout.Row = 2; app.SelectTechniqueCategoryDropDown.Layout.Column = 5;
                app.SelectTechniqueDropDownLabel = uilabel(app.GridLayout26, 'Text', 'Select Technique');
                app.SelectTechniqueDropDownLabel.Layout.Row = 3; app.SelectTechniqueDropDownLabel.Layout.Column = 5;
                app.SelectTechniqueDropDown = uidropdown(app.GridLayout26, 'Editable', 'on');
                app.SelectTechniqueDropDown.Layout.Row = 4; app.SelectTechniqueDropDown.Layout.Column = 5;
                app.AddTechniqueButton = uibutton(app.GridLayout26, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'plus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @AddTechniqueButtonPushed, true));
                app.AddTechniqueButton.Layout.Row = 4; app.AddTechniqueButton.Layout.Column = 6;
                app.SelectedTechniquesListBoxLabel = uilabel(app.GridLayout26, 'Text', 'Selected Techniques');
                app.SelectedTechniquesListBoxLabel.Layout.Row = 6; app.SelectedTechniquesListBoxLabel.Layout.Column = 5;
                app.SelectedTechniquesListBox = uilistbox(app.GridLayout26);
                app.SelectedTechniquesListBox.Layout.Row = [7 9]; app.SelectedTechniquesListBox.Layout.Column = 5; 
                app.RemoveTechniqueButton = uibutton(app.GridLayout26, 'push', 'Text', '', 'Icon', fullfile(app.ResourcesPath, 'icons', 'minus.png'), 'ButtonPushedFcn', createCallbackFcn(app, @RemoveTechniqueButtonPushed, true));
                app.RemoveTechniqueButton.Layout.Row = 7; app.RemoveTechniqueButton.Layout.Column = 6;

            app.SubjectInfoTab = uitab(app.TabGroup, 'Title', 'Subject Info');
            app.SubjectInfoGridLayout = uigridlayout(app.SubjectInfoTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.SubjectInfoLabel = uilabel(app.SubjectInfoGridLayout, 'Text', 'Subject Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.SubjectInfoLabel.Layout.Row=1; app.SubjectInfoLabel.Layout.Column=1;
            app.SubjectInfoPanel = uipanel(app.SubjectInfoGridLayout, 'BorderType', 'none');
            app.SubjectInfoPanel.Layout.Row=2; app.SubjectInfoPanel.Layout.Column=1;
                app.GridLayout16 = uigridlayout(app.SubjectInfoPanel, [2 1], 'RowHeight', {150, '1x'}, 'RowSpacing', 30, 'Padding', [25 25 25 10]);
                    app.UITableSubject = uitable(app.GridLayout16, 'ColumnName', {'Subject'; 'Biological Sex'; 'Species'; 'Strain'}, 'RowName', {}, 'SelectionType', 'row');
                    app.UITableSubject.Layout.Row=1; app.UITableSubject.Layout.Column=1;
                    app.GridLayout17 = uigridlayout(app.GridLayout16, [4 3], 'ColumnWidth', {'1x','1x','1x'}, 'RowHeight', {23,'1x',23,23}, 'ColumnSpacing',30);
                    app.GridLayout17.Layout.Row=2; app.GridLayout17.Layout.Column=1;
                        app.BiologicalSexLabel = uilabel(app.GridLayout17, 'Text', 'Biological Sex'); app.BiologicalSexLabel.Layout.Row=1; app.BiologicalSexLabel.Layout.Column=1;
                        app.BiologicalSexListBox = uilistbox(app.GridLayout17, 'Items', {'asexual multicellular organism', 'female organism', 'male organism', 'hermaphroditic organism'}, 'Value', 'asexual multicellular organism', 'ValueChangedFcn', createCallbackFcn(app, @BiologicalSexListBoxValueChanged, true), 'ClickedFcn', createCallbackFcn(app, @BiologicalSexListBoxClicked, true));
                        app.BiologicalSexListBox.Layout.Row=2; app.BiologicalSexListBox.Layout.Column=1;
                        app.SpeciesLabel_2 = uilabel(app.GridLayout17, 'Text', 'Species'); app.SpeciesLabel_2.Layout.Row=1; app.SpeciesLabel_2.Layout.Column=2;
                        app.SpeciesListBox = uilistbox(app.GridLayout17, 'ValueChangedFcn', createCallbackFcn(app, @SpeciesListBoxValueChanged, true), 'ClickedFcn', createCallbackFcn(app, @SpeciesListBoxClicked, true));
                        app.SpeciesListBox.Layout.Row=2; app.SpeciesListBox.Layout.Column=2;
                        app.StrainLabel = uilabel(app.GridLayout17, 'Text', 'Strain'); app.StrainLabel.Layout.Row=1; app.StrainLabel.Layout.Column=3;
                        app.StrainListBox = uilistbox(app.GridLayout17, 'Tag', 'Strain', 'ValueChangedFcn', createCallbackFcn(app, @StrainListBoxValueChanged, true), 'ClickedFcn', createCallbackFcn(app, @StrainListBoxClicked, true), 'DoubleClickedFcn', createCallbackFcn(app, @StrainListBoxDoubleClicked, true));
                        app.StrainListBox.Layout.Row=2; app.StrainListBox.Layout.Column=3;
                        app.GridLayout24 = uigridlayout(app.GridLayout17,[1,2]); app.GridLayout24.Layout.Row=3; app.GridLayout24.Layout.Column=1; app.GridLayout24.Padding=[0 0 0 0];
                            app.AssignBiologicalSexButton = uibutton(app.GridLayout24, 'push', 'Text', 'Assign', 'ButtonPushedFcn', createCallbackFcn(app, @AssignBiologicalSexButtonPushed, true));
                            app.BiologicalSexClearButton = uibutton(app.GridLayout24, 'push', 'Text', 'CLEAR', 'ButtonPushedFcn', createCallbackFcn(app, @BiologicalSexClearButtonPushed, true));
                        app.GridLayout24_2 = uigridlayout(app.GridLayout17,[1,2]); app.GridLayout24_2.Layout.Row=3; app.GridLayout24_2.Layout.Column=2; app.GridLayout24_2.Padding=[0 0 0 0];
                            app.AssignSpeciesButton = uibutton(app.GridLayout24_2, 'push', 'Text', 'Assign', 'ButtonPushedFcn', createCallbackFcn(app, @AssignSpeciesButtonPushed, true));
                            app.SpeciesClearButton = uibutton(app.GridLayout24_2, 'push', 'Text', 'CLEAR', 'ButtonPushedFcn', createCallbackFcn(app, @SpeciesClearButtonPushed, true));
                        app.GridLayout24_3 = uigridlayout(app.GridLayout17,[1,2]); app.GridLayout24_3.Layout.Row=3; app.GridLayout24_3.Layout.Column=3; app.GridLayout24_3.Padding=[0 0 0 0];
                            app.AssignStrainButton = uibutton(app.GridLayout24_3, 'push', 'Text', 'Assign'); 
                            app.StrainClearButton = uibutton(app.GridLayout24_3, 'push', 'Text', 'CLEAR', 'ButtonPushedFcn', createCallbackFcn(app, @StrainClearButtonPushed, true));
                        app.GridLayout24_4 = uigridlayout(app.GridLayout17,[1,2],'ColumnWidth',{'1x',50}); app.GridLayout24_4.Layout.Row=4; app.GridLayout24_4.Layout.Column=2; app.GridLayout24_4.Padding=[0 0 0 0];
                            app.SpeciesEditField = uieditfield(app.GridLayout24_4, 'text', 'Placeholder', 'Enter name of species to add');
                            app.AddSpeciesButton = uibutton(app.GridLayout24_4, 'push', 'Text', 'Add', 'ButtonPushedFcn', createCallbackFcn(app, @AddSpeciesButtonPushed, true));
                        app.GridLayout27 = uigridlayout(app.GridLayout17,[1,2],'ColumnWidth',{'1x',50}); app.GridLayout27.Layout.Row=4; app.GridLayout27.Layout.Column=3; app.GridLayout27.Padding=[0 0 0 0];
                            app.StrainEditField = uieditfield(app.GridLayout27, 'text', 'Placeholder', 'Enter name of strain to add');
                            app.AddStrainButton = uibutton(app.GridLayout27, 'push', 'Text', 'Add', 'ButtonPushedFcn', createCallbackFcn(app, @AddStrainButtonPushed, true));

            app.ProbeInfoTab = uitab(app.TabGroup, 'Title', 'Probe Info');
            app.ProbeInfoGridLayout = uigridlayout(app.ProbeInfoTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.ProbeInfoLabel = uilabel(app.ProbeInfoGridLayout, 'Text', 'Probe Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.ProbeInfoLabel.Layout.Row=1; app.ProbeInfoLabel.Layout.Column=1;
            app.ProbeInfoPanel = uipanel(app.ProbeInfoGridLayout, 'BorderType', 'none');
            app.ProbeInfoPanel.Layout.Row=2; app.ProbeInfoPanel.Layout.Column=1;
            % UITableProbe will be created by ProbeDataGUI inside ProbeInfoPanel

            app.SaveTab = uitab(app.TabGroup, 'Title', 'Save');
            app.SubmitGridLayout = uigridlayout(app.SaveTab, [3 1], 'RowHeight', {60, '4x', 'fit'}); 
                app.SubmitLabel = uilabel(app.SubmitGridLayout, 'Text', 'Review and Save Data', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
                app.SubmitLabel.Layout.Row=1; app.SubmitLabel.Layout.Column=1;
                app.SubmitPanelGridLayout = uigridlayout(app.SubmitGridLayout, [3 1], 'RowHeight', {'1x', 23, '1x'}, 'Padding', [50 25 50 25]);
                app.SubmitPanelGridLayout.Layout.Row=2; app.SubmitPanelGridLayout.Layout.Column=1;
                    app.SubmissionDescriptionLabel = uilabel(app.SubmitPanelGridLayout, 'Text', 'If you have filled out all the information for this dataset, please SAVE TO DATASET. If you are still working, simply close the form and it will save your progress.', 'VerticalAlignment', 'top', 'WordWrap', 'on', 'FontSize', 14);
                    app.SubmissionDescriptionLabel.Layout.Row=1; app.SubmissionDescriptionLabel.Layout.Column=1;
                    app.ErrorTextAreaLabel = uilabel(app.SubmitPanelGridLayout, 'Text', 'Status');
                    app.ErrorTextAreaLabel.Layout.Row=2; app.ErrorTextAreaLabel.Layout.Column=1;
                    app.ErrorTextArea = uitextarea(app.SubmitPanelGridLayout);
                    app.ErrorTextArea.Layout.Row=3; app.ErrorTextArea.Layout.Column=1;
                app.SubmitFooterGridLayout = uigridlayout(app.SubmitGridLayout, [2 3], 'ColumnWidth', {'1x', '1x', '1x'}, 'RowHeight', {40, 40}, 'ColumnSpacing', 20, 'RowSpacing', 10, 'Padding', [10 10 10 10]);
                app.SubmitFooterGridLayout.Layout.Row=3; app.SubmitFooterGridLayout.Layout.Column=1;
                    app.SaveButton = uibutton(app.SubmitFooterGridLayout, 'push', 'Text', 'Save to Dataset', 'FontWeight', 'bold', 'ButtonPushedFcn', createCallbackFcn(app, @SaveButtonPushed, true));
                    app.SaveButton.Layout.Row=1; app.SaveButton.Layout.Column=1;
                    app.ResetFormButton = uibutton(app.SubmitFooterGridLayout, 'push', 'Text', 'Reset Form', 'ButtonPushedFcn', createCallbackFcn(app, @ResetFormButtonPushed, true));
                    app.ResetFormButton.Layout.Row=1; app.ResetFormButton.Layout.Column=2;
                    app.RevertToSavedButton = uibutton(app.SubmitFooterGridLayout, 'push', 'Text', 'Revert to Saved', 'ButtonPushedFcn', createCallbackFcn(app, @RevertToSavedButtonPushed, true));
                    app.RevertToSavedButton.Layout.Row=1; app.RevertToSavedButton.Layout.Column=3;
                    app.TestDocumentConversionButton = uibutton(app.SubmitFooterGridLayout, 'push', 'Text', 'Test Document Conversion', 'ButtonPushedFcn', createCallbackFcn(app, @TestDocumentConversionButtonPushed, true));
                    app.TestDocumentConversionButton.Layout.Row=2; app.TestDocumentConversionButton.Layout.Column=1;
                    app.ExportDatasetInfoButton = uibutton(app.SubmitFooterGridLayout, 'push', 'Text', 'Export Dataset Info to Workspace', 'ButtonPushedFcn', createCallbackFcn(app, @ExportDatasetInfoButtonPushed, true));
                    app.ExportDatasetInfoButton.Layout.Row=2; app.ExportDatasetInfoButton.Layout.Column=2;
            
            app.FooterPanel = uipanel(app.NDIMetadataEditorUIFigure, 'BorderType', 'none'); 
            app.FooterPanel.Position = [1 1 900 63]; 
            app.FooterGridLayout = uigridlayout(app.FooterPanel, [1 7], 'ColumnWidth', {100, '1x', 100, 50, 100, '1x', 100}, 'RowHeight', {23}, 'Padding', [25 10 25 20], 'BackgroundColor', [0.902 0.902 0.902]);
                app.PreviousButton = uibutton(app.FooterGridLayout, 'push', 'Text', 'Previous', 'ButtonPushedFcn', createCallbackFcn(app, @PreviousButtonPushed, true));
                app.PreviousButton.Layout.Row=1; app.PreviousButton.Layout.Column=3;
                app.NextButton = uibutton(app.FooterGridLayout, 'push', 'Text', 'Next', 'ButtonPushedFcn', createCallbackFcn(app, @NextButtonPushed, true));
                app.NextButton.Layout.Row=1; app.NextButton.Layout.Column=5;
                app.NdiLogoImage = uiimage(app.FooterGridLayout, 'ImageSource', fullfile(app.ResourcesPath, 'ndi_logo.png')); 
                app.NdiLogoImage.Layout.Row=1; app.NdiLogoImage.Layout.Column=7;

            app.FooterpanelLabel = uilabel(app.NDIMetadataEditorUIFigure, 'Text', 'Footer panel description', 'Visible','off', 'Position', [2 -48 509 22]);
            app.SaveChangesButton = uibutton(app.NDIMetadataEditorUIFigure, 'push', 'Text', 'Save Changes (Temp)', 'Visible','off', 'ButtonPushedFcn', createCallbackFcn(app, @SaveChangesButtonPushed, true), 'Position', [800 -27 100 23]);

            app.NDIMetadataEditorUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)
        function app = MetadataEditorApp(varargin)
            runningApp = getRunningApp(app);
            if isempty(runningApp)
                createComponents(app)
                registerApp(app, app.NDIMetadataEditorUIFigure)
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else
                figure(runningApp.NDIMetadataEditorUIFigure)
                app = runningApp;
            end
            if nargout == 0, clear app; end
        end

        function delete(app)
            if ~isempty(app.Timer) && isvalid(app.Timer)
                stop(app.Timer);
                delete(app.Timer);
            end
            if ishandle(app.NDIMetadataEditorUIFigure) && isvalid(app.NDIMetadataEditorUIFigure)
                delete(app.NDIMetadataEditorUIFigure);
            end
        end
    end
end
