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
        
        ExperimentDetailsTab          matlab.ui.container.Tab
        ExperimentDetailsGridLayout   matlab.ui.container.GridLayout
        ExperimentDetailsLabel        matlab.ui.control.Label
        ExperimentDetailsPanel        matlab.ui.container.Panel 
        
        SubjectInfoTab                matlab.ui.container.Tab 
        SubjectInfoGridLayout         matlab.ui.container.GridLayout 
        SubjectInfoLabel              matlab.ui.control.Label      
        SubjectInfoPanel              matlab.ui.container.Panel      
        
        ProbeInfoTab                  matlab.ui.container.Tab
        ProbeInfoGridLayout           matlab.ui.container.GridLayout
        ProbeInfoLabel                matlab.ui.control.Label
        ProbeInfoPanel                matlab.ui.container.Panel 
        
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

    properties (Access = public) 
        UIForm (1,1) struct 
        AuthorDataGUI_Instance ndi.database.metadata_app.class.AuthorDataGUI 
        ProbeDataGUI_Instance  ndi.database.metadata_app.class.ProbeDataGUI
        ExperimentalDetailsGUI_Instance ndi.database.metadata_app.class.ExperimentalDetailsGUI
        DatasetDetailsGUI_Instance ndi.database.metadata_app.class.DatasetDetailsGUI
        SubjectInfoGUI_Instance ndi.database.metadata_app.class.SubjectInfoGUI
    end

    properties (Access = public, Constant)
        FieldComponentMap = struct(...
                    'DatasetFullName', 'DatasetBranchTitleEditField', ...
                    'DatasetShortName', 'DatasetShortNameEditField', ...
                            'Description', 'AbstractTextArea', ...
                                'Comments', 'DatasetCommentsTextArea' ... 
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

    methods (Access = public) 
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
            if isempty(treeHandle.Children), treeHandle.CheckedNodes = []; return; end
            if ischar(data) && ~isempty(data), data = {data}; 
            elseif isstring(data), data = cellstr(data); 
            elseif ~iscellstr(data) && ~iscell(data) && ~isempty(data), data = {}; 
            elseif iscell(data) && ~isempty(data) && ~all(cellfun(@ischar, data)) 
                try data = cellfun(@char, data, 'UniformOutput', false); catch; data = {}; end
            end
            if isempty(data), data = {}; end 
            nodeDataArray = {treeHandle.Children.NodeData};
            nodesToSelect = matlab.ui.container.TreeNode.empty(0,1); 
            if ~isempty(data) && ~isempty(nodeDataArray)
                try
                    tf = ismember(nodeDataArray, data);
                    if any(tf), nodesToSelect = treeHandle.Children(tf); end
                catch ME_ismember, fprintf(2, 'Error in setCheckedNodesFromData: %s\n', ME_ismember.message); end
            end
            treeHandle.CheckedNodes = ifthenelse(isempty(nodesToSelect), [], nodesToSelect);
        end
    end
    
    methods (Access = public) % Changed from private for sub-GUI access
        function missingRequiredField = checkRequiredFields(app, tab)
            tabTitleStr = '';
            if isa(tab, 'matlab.ui.container.Tab') && isprop(tab,'Title') && ~isempty(tab.Title)
                tabTitleStr = char(tab.Title);
            elseif ischar(tab) || isstring(tab)
                 tabTitleStr = char(tab);
            end
            fprintf('DEBUG (checkRequiredFields): Called for tab: %s\n', tabTitleStr);
            
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
            missingRequiredField = string.empty(0,1); 
            fieldsToCheck = string.empty(0,1); 

            currentTabName = tabTitleStr;

            switch currentTabName 
                case app.DatasetOverviewTab.Title
                    fieldsToCheck = ["DatasetFullName", "DatasetShortName", "Description", "Comments"];
                case app.DatasetDetailsTab.Title 
                    if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && ismethod(app.DatasetDetailsGUI_Instance, 'checkRequiredFields')
                        missingFromSub = app.DatasetDetailsGUI_Instance.checkRequiredFields();
                        missingRequiredField = [missingRequiredField, missingFromSub];
                    end
                case app.ExperimentDetailsTab.Title 
                    if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance) && ismethod(app.ExperimentalDetailsGUI_Instance, 'checkRequiredFields')
                         missingFromSub = app.ExperimentalDetailsGUI_Instance.checkRequiredFields();
                         missingRequiredField = [missingRequiredField, missingFromSub];
                    end
                case app.SubjectInfoTab.Title
                   if isprop(app, 'SubjectInfoGUI_Instance') && ~isempty(app.SubjectInfoGUI_Instance) && isvalid(app.SubjectInfoGUI_Instance) && ismethod(app.SubjectInfoGUI_Instance, 'checkRequiredFields')
                       missingFromSub = app.SubjectInfoGUI_Instance.checkRequiredFields(); 
                       missingRequiredField = [missingRequiredField, missingFromSub];
                   end
                case {'', app.SaveTab.Title} 
                    fieldsToCheck = string( fieldnames(requiredFields)' ); 
                    if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && ismethod(app.DatasetDetailsGUI_Instance, 'checkRequiredFields')
                        missingFromSub = app.DatasetDetailsGUI_Instance.checkRequiredFields();
                        missingRequiredField = [missingRequiredField, missingFromSub];
                    end
                    if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance) && ismethod(app.ExperimentalDetailsGUI_Instance, 'checkRequiredFields')
                         missingFromSub = app.ExperimentalDetailsGUI_Instance.checkRequiredFields();
                         missingRequiredField = [missingRequiredField, missingFromSub];
                    end
                    if isprop(app, 'SubjectInfoGUI_Instance') && ~isempty(app.SubjectInfoGUI_Instance) && isvalid(app.SubjectInfoGUI_Instance) && ismethod(app.SubjectInfoGUI_Instance, 'checkRequiredFields')
                       missingFromSub = app.SubjectInfoGUI_Instance.checkRequiredFields(); 
                       missingRequiredField = [missingRequiredField, missingFromSub];
                   end
                otherwise
                    fprintf('DEBUG (checkRequiredFields): Tab "%s" has no specific fields in main app switch.\n', currentTabName);
            end    
            
            for iField_str = fieldsToCheck 
                iField = char(iField_str); 
                if ~isfield(app.FieldComponentMap, iField), continue; end

                componentFieldName = app.FieldComponentMap.(iField);
                if isfield(requiredFields, iField) && requiredFields.(iField) 
                    if isprop(app, componentFieldName) 
                        uiComponent = app.(componentFieldName);
                        value = []; 
                        if isa(uiComponent, 'matlab.ui.container.CheckBoxTree')
                            value = uiComponent.CheckedNodes; 
                        elseif isa(uiComponent, 'matlab.ui.control.Table')
                            value = uiComponent.Data;
                             if ~(istable(value) && ~isempty(value)), value = []; end
                        else 
                            value = char(uiComponent.Value); 
                        end
                        if isempty(value)
                            fieldTitle = app.getFieldTitle(iField);
                            missingRequiredField(end+1) = fieldTitle; 
                            app.highlightLabelForRequiredField(componentFieldName);
                        else
                            app.resetLabelForRequiredField(componentFieldName); 
                        end
                    end
                end
            end
            
            if isequal(currentTabName, "") || isequal(currentTabName, app.SaveTab.Title)
                if isempty(app.AuthorData.AuthorList) || ...
                   all(arrayfun(@(x) isempty(strtrim(x.givenName)) && isempty(strtrim(x.familyName)), app.AuthorData.AuthorList))
                    missingRequiredField(end+1) = "At least one Author with a name";
                end
            end
            
            missingRequiredField = unique(missingRequiredField, 'stable'); 

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
                 end
            else 
                switch fieldName 
                    case "DataType", fieldTitle = "Data Type"; 
                    case "License", fieldTitle = "License";
                    case "VersionIdentifier", fieldTitle = "Version Identifier";
                    otherwise, fieldTitle = fieldName; 
                end
            end
        end

        function highlightLabelForRequiredField(app, componentFieldNameOrConcept)
            uiLabelHandle = [];
            if isfield(app.FieldComponentMap, componentFieldNameOrConcept) 
                 labelFieldName = sprintf('%sLabel', app.FieldComponentMap.(componentFieldNameOrConcept));
                 if isprop(app, labelFieldName) && isvalid(app.(labelFieldName))
                    uiLabelHandle = app.(labelFieldName);
                 end
            else 
                switch componentFieldNameOrConcept
                    case 'DataType' 
                        if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance) && isprop(app.ExperimentalDetailsGUI_Instance, 'DataTypeTreeLabel')
                            uiLabelHandle = app.ExperimentalDetailsGUI_Instance.DataTypeTreeLabel;
                        end
                    case 'License'
                        if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && isprop(app.DatasetDetailsGUI_Instance, 'LicenseDropDownLabel')
                            uiLabelHandle = app.DatasetDetailsGUI_Instance.LicenseDropDownLabel;
                        end
                    case 'VersionIdentifier'
                         if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && isprop(app.DatasetDetailsGUI_Instance, 'VersionIdentifierEditFieldLabel')
                            uiLabelHandle = app.DatasetDetailsGUI_Instance.VersionIdentifierEditFieldLabel;
                        end
                end
            end

            if ~isempty(uiLabelHandle) && isvalid(uiLabelHandle)
                uiLabelHandle.FontWeight = 'bold';
                uiLabelHandle.FontColor = [0.7098    0.0902        0]; 
                uiLabelHandle.Tag = 'RequiredValueMissing';
            else
                 fprintf(2, 'Warning (highlightLabel): No label handle found for "%s".\n', componentFieldNameOrConcept);
            end
        end

        function resetLabelForRequiredField(app, componentFieldNameOrConcept)
            labelFieldName = '';
            uiLabelHandle = [];
            if isfield(app.FieldComponentMap, componentFieldNameOrConcept)
                 labelFieldName = sprintf('%sLabel', app.FieldComponentMap.(componentFieldNameOrConcept));
                 if isprop(app, labelFieldName) && isvalid(app.(labelFieldName))
                    uiLabelHandle = app.(labelFieldName);
                 end
            else
                 switch componentFieldNameOrConcept
                    case 'DataType' 
                        if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance) && isprop(app.ExperimentalDetailsGUI_Instance, 'DataTypeTreeLabel')
                            uiLabelHandle = app.ExperimentalDetailsGUI_Instance.DataTypeTreeLabel;
                        end
                     case 'License'
                        if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && isprop(app.DatasetDetailsGUI_Instance, 'LicenseDropDownLabel')
                            uiLabelHandle = app.DatasetDetailsGUI_Instance.LicenseDropDownLabel;
                        end
                    case 'VersionIdentifier'
                         if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && isprop(app.DatasetDetailsGUI_Instance, 'VersionIdentifierEditFieldLabel')
                            uiLabelHandle = app.DatasetDetailsGUI_Instance.VersionIdentifierEditFieldLabel;
                        end
                end
            end

            if ~isempty(uiLabelHandle) && isvalid(uiLabelHandle) && strcmp(uiLabelHandle.Tag, 'RequiredValueMissing')
                uiLabelHandle.FontWeight = 'normal';
                uiLabelHandle.FontColor = [0 0 0]; 
                uiLabelHandle.Tag = '';
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
                    end
                end
            end
            
            if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance) && ismethod(app.ExperimentalDetailsGUI_Instance, 'markRequiredFields')
                app.ExperimentalDetailsGUI_Instance.markRequiredFields();
            end
             if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance) && ismethod(app.DatasetDetailsGUI_Instance, 'markRequiredFields')
                app.DatasetDetailsGUI_Instance.markRequiredFields();
            end
            if isprop(app, 'SubjectInfoGUI_Instance') && ~isempty(app.SubjectInfoGUI_Instance) && isvalid(app.SubjectInfoGUI_Instance) && ismethod(app.SubjectInfoGUI_Instance, 'markRequiredFields')
                app.SubjectInfoGUI_Instance.markRequiredFields(); 
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
            isMatchFound = false; 
            drawnow; 
            pause(0.1); 

            max_attempts = 20; 
            attempt_count = 0;
            
            figName = app.NDIMetadataEditorUIFigure.Name; 
            targetWindow = []; 

            while ~isMatchFound && attempt_count < max_attempts
                windowList = matlab.internal.webwindowmanager.instance.findAllWebwindows();
                if isempty(windowList)
                    attempt_count = attempt_count + 1;
                    pause(0.1);
                    continue;
                end
                
                titles = {windowList.Title};
                matchIndicesByTitle = strcmp(titles, figName);
                if any(matchIndicesByTitle)
                    isMatchFound = true;
                    targetWindow = windowList(find(matchIndicesByTitle,1));
                    break; 
                end
                
                if ~isempty(app.NDIMetadataEditorUIFigure.Tag)
                     tags = arrayfun(@(w) getfieldifexists(w,'Tag'), windowList, 'UniformOutput', false);
                     validTagsIdx = cellfun(@ischar, tags);
                     if any(validTagsIdx)
                        matchIndicesByTag = strcmp(tags(validTagsIdx), app.NDIMetadataEditorUIFigure.Tag);
                        if any(matchIndicesByTag)
                            isMatchFound = true;
                            originalIndices = find(validTagsIdx);
                            targetWindow = windowList(originalIndices(find(matchIndicesByTag,1)));
                            break; 
                        end
                     end
                end

                if ~isMatchFound 
                    attempt_count = attempt_count + 1;
                    pause(0.1);
                end
            end

            if isMatchFound && ~isempty(targetWindow)
                try
                    targetWindow.setMinSize([840 610]);
                catch ME_setMinSize
                     fprintf(2,'Warning: Could not set minimum figure size: %s\n', ME_setMinSize.message);
                end
            else
                fprintf(2,'Warning: Could not find the app window to set minimum size for "%s" after %d attempts.\n', figName, attempt_count);
            end
        end
        
        function centerFigureOnScreen(app) 
            if isprop(app, 'NDIMetadataEditorUIFigure') && isvalid(app.NDIMetadataEditorUIFigure)
                try
                    originalUnits = app.NDIMetadataEditorUIFigure.Units;
                    app.NDIMetadataEditorUIFigure.Units = 'pixels';
                    movegui(app.NDIMetadataEditorUIFigure, 'center');
                    app.NDIMetadataEditorUIFigure.Units = originalUnits; 
                catch ME_center, fprintf(2, 'Warning: Could not center figure on screen: %s\n', ME_center.message); end
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
            
            datasetInformation = app.DatasetInformationStruct; 
            save(tempSaveFile, "datasetInformation"); 
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
            app.loadSpecies();
        end

        function loadSpecies(app)  % needs to move to SubjectInfoGUI
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

        function saveSpecies(app) % needs to move to SubjectInfoGUI
            import ndi.database.metadata_app.fun.saveUserInstances
            saveUserInstances('species', app.SpeciesInstancesUser);
        end
        
        function strainInstances = getStrainInstances(app) % needs to move to SubjectInfoGUI
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog
            strainInstances = loadUserInstanceCatalog('Strain');
        end

        function S = openFundingForm(app, info)  % needs to move to DatasetDetailsGUI.m
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
        
        function success = openProbeForm(app, probeType, probeIndexOrData, probeObjIn) % needs to move to ProbeDataGUI
            success = false;
            formHandle = [];
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
                app.ProbeData.replaceProbe(probeIndexOrData, updatedProbeObjDetails); 
                app.saveDatasetInformationStruct(); 
                success = true; 
            end
            formHandle.reset();
            formHandle.Visible = 'off';
        end
        
        function S = openSpeciesForm(app, speciesInfoStruct)  % needs to move to SubjectInfoGUI
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
        
        function performActualFormReset(app)
            if isprop(app, 'AuthorData') && ismethod(app.AuthorData, 'ClearAll'), app.AuthorData.ClearAll(); app.AuthorData.addDefaultAuthorEntry(); end
            if isprop(app, 'SubjectData') && ismethod(app.SubjectData,'ClearAll'), app.SubjectData.ClearAll(); end
            if isprop(app, 'ProbeData') && ismethod(app.ProbeData,'ClearAll'), app.ProbeData.ClearAll(); end
            
            if ~isempty(app.Dataset)
                app.getInitialMetadataFromSession(); 
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
    end

    % Component initialization
    methods (Access = private)
        function createComponents(app)
            appFileFolder = fileparts(mfilename('fullpath'));
            app.ResourcesPath = fullfile(appFileFolder, 'resources'); 
            if ~isfolder(app.ResourcesPath)
                 fprintf(2, 'Warning (createComponents): ResourcesPath not found: %s.\n', app.ResourcesPath);
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

            app.ExperimentDetailsTab = uitab(app.TabGroup, 'Title', 'Experiment Details');
            app.ExperimentDetailsGridLayout = uigridlayout(app.ExperimentDetailsTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.ExperimentDetailsLabel = uilabel(app.ExperimentDetailsGridLayout, 'Text', 'Experiment Details', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.ExperimentDetailsLabel.Layout.Row=1; app.ExperimentDetailsLabel.Layout.Column=1;
            app.ExperimentDetailsPanel = uipanel(app.ExperimentDetailsGridLayout, 'BorderType', 'none');
            app.ExperimentDetailsPanel.Layout.Row=2; app.ExperimentDetailsPanel.Layout.Column=1;

            app.SubjectInfoTab = uitab(app.TabGroup, 'Title', 'Subject Info');
            app.SubjectInfoGridLayout = uigridlayout(app.SubjectInfoTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.SubjectInfoLabel = uilabel(app.SubjectInfoGridLayout, 'Text', 'Subject Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.SubjectInfoLabel.Layout.Row=1; app.SubjectInfoLabel.Layout.Column=1;
            app.SubjectInfoPanel = uipanel(app.SubjectInfoGridLayout, 'BorderType', 'none');
            app.SubjectInfoPanel.Layout.Row=2; app.SubjectInfoPanel.Layout.Column=1;

            app.ProbeInfoTab = uitab(app.TabGroup, 'Title', 'Probe Info');
            app.ProbeInfoGridLayout = uigridlayout(app.ProbeInfoTab, [2 1], 'RowHeight', {60, '1x'}, 'Padding', [10 20 10 10]);
            app.ProbeInfoLabel = uilabel(app.ProbeInfoGridLayout, 'Text', 'Probe Info', 'HorizontalAlignment', 'center', 'FontSize', 18, 'FontWeight', 'bold');
            app.ProbeInfoLabel.Layout.Row=1; app.ProbeInfoLabel.Layout.Column=1;
            app.ProbeInfoPanel = uipanel(app.ProbeInfoGridLayout, 'BorderType', 'none');
            app.ProbeInfoPanel.Layout.Row=2; app.ProbeInfoPanel.Layout.Column=1;

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

    % STARTUP FUNCTION - ESSENTIAL FOR APP INITIALIZATION
    methods (Access = public) 
        function startupFcn(app, datasetObject, debugMode)
            arguments 
                app (1,1) ndi.database.metadata_app.Apps.MetadataEditorApp
                datasetObject (1,1) {mustBeA(datasetObject, ["ndi.session", "ndi.dataset"])}
                debugMode (1,1) logical = false
            end
            fprintf('DEBUG (startupFcn): MetadataEditorApp startup initiated.\n');

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

            app.ExperimentalDetailsGUI_Instance = ndi.database.metadata_app.class.ExperimentalDetailsGUI(app, app.ExperimentDetailsPanel);
            app.ExperimentalDetailsGUI_Instance.initialize();

            app.DatasetDetailsGUI_Instance = ndi.database.metadata_app.class.DatasetDetailsGUI(app, app.DatasetDetailsPanel);
            app.DatasetDetailsGUI_Instance.initialize();

            app.SubjectInfoGUI_Instance = ndi.database.metadata_app.class.SubjectInfoGUI(app, app.SubjectInfoPanel);
            app.SubjectInfoGUI_Instance.initialize();
            
            app.markRequiredFields(); 

            app.loadUserDefinedMetadata(); 
            app.populateComponentsWithMetadata(); 

            if ~isempty(app.Dataset)
                app.getInitialMetadataFromSession(); 
            end

            app.loadDatasetInformationStruct(); 
            
            fprintf('DEBUG (startupFcn): MetadataEditorApp startup completed.\n');
        end
        
        function populateComponentsWithMetadata(app)
            fprintf('DEBUG (populateComponentsWithMetadata): Called.\n');
            % This method is now minimal as most population is delegated to sub-GUIs.
        end

        function getInitialMetadataFromSession(app)
            fprintf('DEBUG (getInitialMetadataFromSession): Called.\n');
            
            if ~isempty(app.Dataset)
                if isprop(app, 'SubjectData') && isobject(app.SubjectData)
                    subjectDataFromEntity = ndi.database.metadata_app.fun.loadSubjects(app.Dataset);
                    if isa(subjectDataFromEntity, 'ndi.database.metadata_app.class.SubjectData')
                        app.SubjectData = subjectDataFromEntity; 
                        fprintf('DEBUG (getInitialMetadataFromSession): SubjectData loaded from NDI entity.\n');
                    else
                        fprintf(2, 'Warning (getInitialMetadataFromSession): loadSubjects did not return a SubjectData object.\n');
                    end
                else
                    fprintf(2, 'Warning (getInitialMetadataFromSession): app.SubjectData property missing or not an object.\n');
                end
                
                if isprop(app, 'ProbeData') && isobject(app.ProbeData)
                    try
                        probeDataFromEntity = ndi.database.metadata_app.fun.loadProbes(app.Dataset); 
                        if isa(probeDataFromEntity, 'ndi.database.metadata_app.class.ProbeData')
                            app.ProbeData = probeDataFromEntity;
                            fprintf('DEBUG (getInitialMetadataFromSession): ProbeData loaded from NDI entity.\n');
                        else
                            fprintf(2,'Warning (getInitialMetadataFromSession): loadProbes did not return a ProbeData object.\n');
                        end
                    catch ME_loadProbes
                         fprintf(2,'Error loading probes from dataset: %s.\n', ME_loadProbes.message);
                    end
                else
                     fprintf(2, 'Warning (getInitialMetadataFromSession): app.ProbeData property missing or not an object.\n');
                end
            else
                fprintf('DEBUG (getInitialMetadataFromSession): No app.Dataset provided, skipping metadata load from session.\n');
            end
        end
    end
    
    % CLOSE REQUEST FUNCTION - ESSENTIAL FOR CLEANUP
    methods (Access = private)
        function NDIMetadataEditorUIFigureCloseRequest(app, event)
            fprintf('DEBUG (NDIMetadataEditorUIFigureCloseRequest): App close requested.\n');
            errors_for_dialog = {};
            try
                if isprop(app, 'Dataset') && ~isempty(app.Dataset) && isobject(app.Dataset) && isvalid(app.Dataset)
                    try
                        if isprop(app, 'DatasetInformationStruct')
                            app.DatasetInformationStruct = ndi.database.metadata_app.fun.buildDatasetInformationStructFromApp(app);
                            app.Dataset = ndi.database.metadata_ds_core.saveEditor2Doc(app.Dataset, app.DatasetInformationStruct);
                             fprintf('DEBUG (NDIMetadataEditorUIFigureCloseRequest): Dataset saved to NDI document.\n');
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
            fprintf('DEBUG (NDIMetadataEditorUIFigureCloseRequest): App deleted.\n');
        end
    end
end

% Helper function defined outside the classdef
function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval;
    else
        result = falseval;
    end
end
