classdef MetadataEditorApp < matlab.apps.AppBase
    %METADATAEDITORAPP App Edit and upload metadata for NDI datasets
    %   
    %   Syntax:
    %       ndi.database.metadata_app.Apps.DatasetUploadApp(ndiSession)
    %           opens the metadata editor for the specified NDI 
    %           session
    %   
    %   Inputs:
    %       Session  : An NDI session object
    %       TempWorkingFile : A pathname for the temporary working 
    %                  metadata file (optional). The default behavior 
    %                  is to use a file in the session folder.

    % Properties that correspond to app components
    properties (Access = public)
        NDIMetadataEditorUIFigure       matlab.ui.Figure
        FooterPanel                     matlab.ui.container.Panel
        FooterGridLayout                matlab.ui.container.GridLayout
        NdiLogoImage                    matlab.ui.control.Image
        NextButton                      matlab.ui.control.Button
        PreviousButton                  matlab.ui.control.Button
        MainGridLayout                  matlab.ui.container.GridLayout
        TabGroup                        matlab.ui.container.TabGroup
        IntroTab                        matlab.ui.container.Tab
        IntroGridLayout                 matlab.ui.container.GridLayout
        GridLayout25                    matlab.ui.container.GridLayout
        NdiLogoIntroImage               matlab.ui.control.Image
        IntroLabel                      matlab.ui.control.Label
        GridLayout_Step0_C2             matlab.ui.container.GridLayout
        IntroductionTextLabel           matlab.ui.control.Label
        GridLayout_Step0_C3             matlab.ui.container.GridLayout
        GetStartedButton                matlab.ui.control.Button
        DatasetOverviewTab              matlab.ui.container.Tab
        DatasetOverviewGridLayout       matlab.ui.container.GridLayout
        DatasetInformationLabel         matlab.ui.control.Label
        DatasetInformationPanel         matlab.ui.container.Panel
        GridLayout                      matlab.ui.container.GridLayout
        GridLayout4                     matlab.ui.container.GridLayout
        DatasetCommentsTextArea         matlab.ui.control.TextArea
        DatasetCommentsTextAreaLabel    matlab.ui.control.Label
        Panel_4                         matlab.ui.container.Panel
        GridLayout3                     matlab.ui.container.GridLayout
        AbstractTextAreaLabel           matlab.ui.control.Label
        AbstractTextArea                matlab.ui.control.TextArea
        Panel_3                         matlab.ui.container.Panel
        GridLayout2                     matlab.ui.container.GridLayout
        DatasetShortNameEditFieldLabel  matlab.ui.control.Label
        DatasetShortNameEditField       matlab.ui.control.EditField
        DatasetBranchTitleEditFieldLabel  matlab.ui.control.Label
        DatasetBranchTitleEditField     matlab.ui.control.EditField
        AuthorsTab                      matlab.ui.container.Tab
        AuthorsGridLayout               matlab.ui.container.GridLayout
        AuthorDetailsLabel              matlab.ui.control.Label
        AuthorMainPanel                 matlab.ui.container.Panel
        AuthorMainPanelGridLayout       matlab.ui.container.GridLayout
        AuthorContentRightGridLayout    matlab.ui.container.GridLayout
        AffiliationListBoxGridLayout    matlab.ui.container.GridLayout
        AffiliationListBox              matlab.ui.control.ListBox
        AffiliationListBoxButtonGridLayout  matlab.ui.container.GridLayout
        RemoveAffiliationButton         matlab.ui.control.Button
        MoveAffiliationUpButton         matlab.ui.control.Button
        MoveAffiliationDownButton       matlab.ui.control.Button
        AffiliationSelectionGridLayout  matlab.ui.container.GridLayout
        OrganizationDropDown            matlab.ui.control.DropDown
        AddAffiliationButton            matlab.ui.control.Button
        AffiliationsListBoxLabel        matlab.ui.control.Label
        AuthorContentCenterGridLayout   matlab.ui.container.GridLayout
        AuthorRoleTree                  matlab.ui.container.CheckBoxTree
        FirstAuthorNode                 matlab.ui.container.TreeNode
        CustodianNode                   matlab.ui.container.TreeNode
        CorrespondingNode               matlab.ui.container.TreeNode
        AuthorRoleLabel                 matlab.ui.control.Label
        AuthorEmailEditFieldLabel       matlab.ui.control.Label
        AuthorEmailEditField            matlab.ui.control.EditField
        AuthorOrcidGridLayout           matlab.ui.container.GridLayout
        SearchOrcidButton               matlab.ui.control.Button
        DigitalIdentifierEditField      matlab.ui.control.EditField
        DigitalIdentifierEditFieldLabel  matlab.ui.control.Label
        FamilyNameEditField             matlab.ui.control.EditField
        FamilyNameEditFieldLabel        matlab.ui.control.Label
        GivenNameEditField              matlab.ui.control.EditField
        GivenNameEditFieldLabel         matlab.ui.control.Label
        AuthorContentLeftGridLayout     matlab.ui.container.GridLayout
        AuthorListBoxLabel              matlab.ui.control.Label
        AuthorListBoxGridLayout         matlab.ui.container.GridLayout
        AuthorListBoxButtonGridLayout   matlab.ui.container.GridLayout
        MoveAuthorDownButton            matlab.ui.control.Button
        MoveAuthorUpButton              matlab.ui.control.Button
        RemoveAuthorButton              matlab.ui.control.Button
        AddAuthorButton                 matlab.ui.control.Button
        AuthorListBox                   matlab.ui.control.ListBox
        DatasetDetailsTab               matlab.ui.container.Tab
        DatasetDetailsGridLayout        matlab.ui.container.GridLayout
        DatasetDetailsLabel             matlab.ui.control.Label
        DatasetDetailsPanel             matlab.ui.container.Panel
        GridLayout18                    matlab.ui.container.GridLayout
        GridLayout20                    matlab.ui.container.GridLayout
        PublicationTableButtonGridLayout  matlab.ui.container.GridLayout
        AddRelatedPublicationButton     matlab.ui.control.Button
        RemovePublicationButton         matlab.ui.control.Button
        MovePublicationUpButton         matlab.ui.control.Button
        MovePublicationDownButton       matlab.ui.control.Button
        RelatedPublicationUITable       matlab.ui.control.Table
        RelatedPublicationUITableLabel  matlab.ui.control.Label
        GridLayout19                    matlab.ui.container.GridLayout
        GridLayout22                    matlab.ui.container.GridLayout
        GridLayout28                    matlab.ui.container.GridLayout
        LicenseHelpButton               matlab.ui.control.Button
        LicenseDropDown                 matlab.ui.control.DropDown
        AccessibilityLabel              matlab.ui.control.Label
        VersionInnovationEditField      matlab.ui.control.EditField
        VersionInnovationEditFieldLabel  matlab.ui.control.Label
        VersionIdentifierEditField      matlab.ui.control.EditField
        VersionIdentifierEditFieldLabel  matlab.ui.control.Label
        FullDocumentationEditField      matlab.ui.control.EditField
        FullDocumentationEditFieldLabel  matlab.ui.control.Label
        LicenseDropDownLabel            matlab.ui.control.Label
        ReleaseDateDatePicker           matlab.ui.control.DatePicker
        ReleaseDateDatePickerLabel      matlab.ui.control.Label
        FundingGridLayout               matlab.ui.container.GridLayout
        FundingTableButtonGridLayout    matlab.ui.container.GridLayout
        AddFundingButton                matlab.ui.control.Button
        RemoveFundingButton             matlab.ui.control.Button
        MoveFundingUpButton             matlab.ui.control.Button
        MoveFundingDownButton           matlab.ui.control.Button
        FundingUITableLabel             matlab.ui.control.Label
        FundingUITable                  matlab.ui.control.Table
        ExperimentDetailsTab            matlab.ui.container.Tab
        ExperimentDetailsGridLayout     matlab.ui.container.GridLayout
        ExperimentDetailsLabel          matlab.ui.control.Label
        ExperimentDetailsPanel          matlab.ui.container.Panel
        GridLayout26                    matlab.ui.container.GridLayout
        SelectedTechniquesListBox       matlab.ui.control.ListBox
        SelectedTechniquesListBoxLabel  matlab.ui.control.Label
        SelectTechniqueDropDownLabel    matlab.ui.control.Label
        SelectTechniqueDropDown         matlab.ui.control.DropDown
        SelectTechniqueCategoryDropDown  matlab.ui.control.DropDown
        SelectTechniqueCategoryDropDownLabel  matlab.ui.control.Label
        AddTechniqueButton              matlab.ui.control.Button
        RemoveTechniqueButton           matlab.ui.control.Button
        ExperimentalApproachTreeLabel   matlab.ui.control.Label
        ExperimentalApproachTree        matlab.ui.container.CheckBoxTree
        DataTypeTree                    matlab.ui.container.CheckBoxTree
        DataTypeTreeLabel               matlab.ui.control.Label
        SubjectInfoTab                  matlab.ui.container.Tab
        SubjectInfoGridLayout           matlab.ui.container.GridLayout
        SubjectInfoLabel                matlab.ui.control.Label
        SubjectInfoPanel                matlab.ui.container.Panel
        GridLayout16                    matlab.ui.container.GridLayout
        UITableSubject                  matlab.ui.control.Table
        GridLayout17                    matlab.ui.container.GridLayout
        GridLayout27                    matlab.ui.container.GridLayout
        AddStrainButton                 matlab.ui.control.Button
        StrainEditField                 matlab.ui.control.EditField
        GridLayout24_4                  matlab.ui.container.GridLayout
        AddSpeciesButton                matlab.ui.control.Button
        SpeciesEditField                matlab.ui.control.EditField
        GridLayout24_3                  matlab.ui.container.GridLayout
        StrainClearButton               matlab.ui.control.Button
        AssignStrainButton              matlab.ui.control.Button
        GridLayout24_2                  matlab.ui.container.GridLayout
        SpeciesClearButton              matlab.ui.control.Button
        AssignSpeciesButton             matlab.ui.control.Button
        GridLayout24                    matlab.ui.container.GridLayout
        BiologicalSexClearButton        matlab.ui.control.Button
        AssignBiologicalSexButton       matlab.ui.control.Button
        StrainListBox                   matlab.ui.control.ListBox
        StrainLabel                     matlab.ui.control.Label
        SpeciesListBox                  matlab.ui.control.ListBox
        SpeciesLabel_2                  matlab.ui.control.Label
        BiologicalSexListBox            matlab.ui.control.ListBox
        BiologicalSexLabel              matlab.ui.control.Label
        ProbeInfoTab                    matlab.ui.container.Tab
        ProbeInfoGridLayout             matlab.ui.container.GridLayout
        ProbeInfoLabel                  matlab.ui.control.Label
        ProbeInfoPanel                  matlab.ui.container.Panel
        GridLayout23                    matlab.ui.container.GridLayout
        UITableProbe                    matlab.ui.control.Table
        SaveTab                         matlab.ui.container.Tab
        SubmitGridLayout                matlab.ui.container.GridLayout
        SubmitLabel                     matlab.ui.control.Label
        SubmitPanelGridLayout           matlab.ui.container.GridLayout
        ErrorTextArea                   matlab.ui.control.TextArea
        ErrorTextAreaLabel              matlab.ui.control.Label
        SubmissionDescriptionLabel      matlab.ui.control.Label
        SubmissionStatusPanel           matlab.ui.container.Panel
        SubmitFooterGridLayout          matlab.ui.container.GridLayout
        ExportDatasetInfoButton         matlab.ui.control.Button
        TestDocumentConversionButton    matlab.ui.control.Button
        SaveButton                      matlab.ui.control.Button
        SaveChangesButton               matlab.ui.control.Button
        FooterpanelLabel                matlab.ui.control.Label
    end

    
    properties (Access = private) % Graphical components
        % UIForm - A struct for storing input form apps, like the Author form. Used
        % to keep external forms/figures in memory, but hidden
        UIForm (1,1) struct
    end

    properties (Access = private, Constant)
        % FieldComponentMap - Mapping between dataset information fields
        % and app components
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
            % 'Subjects', 'UITableSubject', ... % Note: Currently handled individually
            % 'Probes', 'UITableProbe' ...

        FieldComponentPostfix = ["EditField", "TextArea", "DropDown", "UITable", "Tree", "ListBox"]
    end

    properties (Access = private) % Userdata
        % DatasetInformation - Struct holding all the information entered 
        % in the app. This is the data which will be saved and loaded
        DatasetInformation (1,1) struct
        
        % AuthorData - Utility class for keeping track of author
        % information. This is used to manage a list of authors and placing
        % 
        AuthorData (1,1) ndi.database.metadata_app.class.AuthorData
        
        % Organizations - A struct array containing user-defined
        % organizations for author affiliations
        Organizations (1,:) struct % Todo: Save to openminds instances...
        
        %Step 4
        SpeciesInstancesUser (1,:) struct

        SpeciesData (1,1) ndi.database.metadata_app.class.SpeciesData
        SubjectData (1,1) ndi.database.metadata_app.class.SubjectData

        %Step 5
        ProbeData (1,1) ndi.database.metadata_app.class.ProbeData
        
        %Email and password
        LoginInformation

        % An NDI dataset object
        Dataset
        
        % A path to the temporary working file for saving and retrieving 
        % metadata information during an editing session.
        % It is typically under Session/.ndi/NDIMetadataEditorData.mat
        TempWorkingFile
    end

    properties (Access = private)
        Timer
    end

    methods (Access = private) % App utility methods

        % Methods for displaying messages to users:
        
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

        % Methods for getting values from uicomponents

        function selectionIndex = getListBoxSelectionIndex(~, listBoxHandle)
            if isempty(listBoxHandle.Value)
                selectionIndex = [];
            else
                isSelected = strcmp(listBoxHandle.Items, listBoxHandle.Value);
                selectionIndex = find(isSelected);
            end
        end

        function data = getCheckedTreeNodeData(~, checkedNodeHandles)
            
            if ~isempty(checkedNodeHandles)
                data = {checkedNodeHandles.NodeData};
            else
                data = '';
            end
        end

        function setCheckedNodesFromData(~, treeHandle, data)
        % setCheckedNodesFromData - Set checked nodes from reference text
            nodeData = {treeHandle.Children.NodeData};
            
            tf = ismember(nodeData, data);

            if any(tf)
                treeHandle.CheckedNodes = treeHandle.Children(tf);
            else
                treeHandle.CheckedNodes = [];
            end
        end
        
        function missingRequiredField = checkRequiredFields(app, tab)
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();

            missingRequiredField = [];

            switch tab
                case app.DatasetOverviewTab
                    fields = ["DatasetFullName", "DatasetShortName", "Description", "Comments"];
                case app.DatasetDetailsTab
                    fields = ["License", "VersionIdentifier"];
                case app.ExperimentDetailsTab
                    fields = ["DataType"];
                case "" % Final submission step
                    fields = string( fieldnames(requiredFields)' );
                otherwise
                    fields = [];

            end   

            for iField = fields
                componentFieldName = app.FieldComponentMap.(iField);
                if requiredFields.(iField)
                    if isa(app.(componentFieldName), 'matlab.ui.container.CheckBoxTree')
                        value = [app.(componentFieldName).CheckedNodes];
                    else
                        value = char(app.(componentFieldName).Value);
                    end
                    if isempty(value)
                        fieldTitle = app.getFieldTitle(iField);
                        missingRequiredField = [missingRequiredField, fieldTitle]; %#ok<AGROW>
                        app.highlightLabelForRequiredField(componentFieldName)
                    end
                end
            end
        end

        function fieldTitle = getFieldTitle(app, fieldName)
            componentFieldName = app.FieldComponentMap.(fieldName);
            labelFieldName = sprintf('%sLabel', componentFieldName);
            fieldTitle = app.(labelFieldName).Text;
            fieldTitle = string(strrep(fieldTitle, ' *', ''));
        end

        function highlightLabelForRequiredField(app, componentFieldName)
            labelFieldName = sprintf('%sLabel', componentFieldName);

            app.(labelFieldName).FontWeight = 'bold';
            app.(labelFieldName).FontColor = [0.7098    0.0902         0];
            app.(labelFieldName).Tag = 'RequiredValueMissing';
        end

        function resetLabelForRequiredField(app, componentFieldName)
            labelFieldName = sprintf('%sLabel', componentFieldName);
            if strcmp(app.(labelFieldName).Tag, 'RequiredValueMissing')
                app.(labelFieldName).FontWeight = 'normal';
                app.(labelFieldName).FontColor = 'k';
                app.(labelFieldName).Tag = '';
            end
        end
    end

    methods (Access = private) % Load/save user data

        function tempWorkingFile = getTempWorkingFile(app)
        % GETTEMPWORKINGFILE - Determines and returns the full path to the temporary working file.
        % This file is used to save and load metadata during an editing session.

            tempWorkingFile = app.TempWorkingFile; % User-provided path takes precedence

            if isempty(tempWorkingFile) % If no user-provided path, determine the default
                if ~isempty(app.Dataset) && isprop(app.Dataset,'path') && ~isempty(app.Dataset.path)
                    % Use dataset's path if available
                    tempWorkingFile = fullfile(app.Dataset.path, 'NDIMetadataEditorData.mat');
                else
                    % Fallback to original default if dataset or its path is not available
                    tempWorkingFile = fullfile(userpath, 'NDIDatasetUpload', 'dataset.mat'); % Note: This fallback implies a non-temporary storage location if no dataset path
                end
            end
        end

        function saveDatasetInformation(app)
                        
            tempSaveFile = app.getTempWorkingFile();
            datasetInformation = app.DatasetInformation;
            save(tempSaveFile, "datasetInformation")
        end

        function loadDatasetInformation(app)
            tempLoadFile = app.getTempWorkingFile();

            % This function might create/update tempLoadFile if it extracts metadata
            ndi.database.metadata_app.fun.readExistingMetadata(app.Dataset, tempLoadFile);
            if isfile(tempLoadFile)
                S = load(tempLoadFile, "datasetInformation");
                app.DatasetInformation = S.datasetInformation;
            end
            app.updateComponentsFromDatasetInformation();
        end

        function loadSpecies(app)
        % loadSpecies - Load user defined species instances
            import ndi.database.metadata_app.fun.loadUserInstances
            app.SpeciesInstancesUser = loadUserInstances('species');

            % Add openMINDS instances to SpeciesData
            [names, options] = ndi.database.metadata_app.fun.getOpenMindsInstances('Species');

            for i = 1:numel(options)
                thisName = char(names(i));
                speciesInstance = openminds.internal.getControlledInstance(thisName, 'Species');
                app.SpeciesData.addItem(speciesInstance.name, speciesInstance.preferredOntologyIdentifier, speciesInstance.synonym);
            end

            % Add user-defined instances to SpeciesData
            if ~isempty(app.SpeciesInstancesUser)
                for i = 1:numel(app.SpeciesInstancesUser)
                    speciesInstance = app.SpeciesInstancesUser(i);
                    app.SpeciesData.addItem(speciesInstance.name, speciesInstance.ontologyIdentifier, speciesInstance.synonyms);
                end
            end
        end

        function saveSpecies(app)
        % saveSpecies - Save user defined species instances
            import ndi.database.metadata_app.fun.saveUserInstances
            saveUserInstances('species', app.SpeciesInstancesUser);
        end

        function loadOrganizations(app)
            import ndi.database.metadata_app.fun.loadUserInstances
            app.Organizations = loadUserInstances('affiliation_organization');
        end

        function saveOrganizationInstances(app)
            import ndi.database.metadata_app.fun.saveUserInstances
            organizationInstances = app.Organizations;
            saveUserInstances('affiliation_organization', organizationInstances)
        end
    
        function strainInstances = getStrainInstances(app)
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog
            strainInstances = loadUserInstanceCatalog('Strain');
        end
    end

    methods (Access = private) % Validate user inputs

        function tf = assertUniquePublicationEntered(app, S, ignoreRowIdx)
            
            if nargin < 3; ignoreRowIdx = []; end

            rowIND = 1:height(app.RelatedPublicationUITable.Data);
            rowIND = setdiff(rowIND, ignoreRowIdx);

            if isempty(rowIND); tf = true; return; end

            publicationDois = app.RelatedPublicationUITable.Data.DOI{rowIND};
            
            if any(strcmp(publicationDois, S.doi))
                app.alert('A publication with the provided DOI already exists in the table', 'Duplicate Entry', 'Icon', 'info')
                tf = false;
            else
                tf = true;
            end
        end
    end

    methods (Access = private) % Set/get state/values of components
        
        function markRequiredFields(app)
            requiredFields = ndi.database.metadata_app.fun.getRequiredFields();
            
            requiredSymbol = '*'; %char(1805)

            allFieldNames = string( fieldnames(requiredFields) );

            for iFieldName = reshape(allFieldNames, 1, [])

                if requiredFields.(iFieldName)
                
                    componentName = app.FieldComponentMap.(iFieldName);
                    labelComponentName = sprintf("%sLabel", componentName);
                    
                    app.(labelComponentName).Text = sprintf('%s %s', app.(labelComponentName).Text, requiredSymbol);
                    app.(labelComponentName).Tooltip = "Required";
                end
            end
        end

        function updateComponentsFromDatasetInformation(app)
            
            if isfield(app.DatasetInformation, 'Author')
                if numel(app.DatasetInformation.Author) > 0
                    S = app.DatasetInformation.Author(1);
                    app.fillAuthorInputFieldsFromStruct(S)
                    app.AuthorData.AuthorList = app.DatasetInformation.Author;
                    app.updateAuthorListbox()
                end
            end
            
            % Compare subjects data which is loaded with subjects available
            % from session
            if isfield(app.DatasetInformation, 'Subjects')
                app.updateSubjectDataFromSession()
            end

            if isfield(app.DatasetInformation, 'Probe')
                app.updateProbeDataFromSession()
            end

            % See property definition for FieldComponentMap for an overview
            % of which input fields are mapped to respective data fields
            propertyNames = fieldnames(app.FieldComponentMap);
            
            for i = 1:numel(propertyNames)
                propertyName = propertyNames{i};
                componentName = app.FieldComponentMap.(propertyName);

                try
                if isfield(app.DatasetInformation, propertyName)
                    propertyValue = app.DatasetInformation.(propertyName);

                    if isa(app.(componentName), 'matlab.ui.container.CheckBoxTree')
                        app.setCheckedNodesFromData(app.(componentName), propertyValue)
                    elseif isa(app.(componentName), 'matlab.ui.control.ListBox')
                        app.(componentName).Items = propertyValue;
                    elseif isa(app.(componentName), 'matlab.ui.control.Table')
                        tableData = struct2table(propertyValue, 'AsArray', true);
                        app.(componentName).Data = tableData;
                    else
                        app.(componentName).Value = propertyValue;
                    end
                end
                catch ME
                    disp(ME)
                end
            end

        end

        % Get the index for the selected author in the author listbox
        function authorIndex = getSelectedAuthorIndex(app)
            isSelected = strcmp(app.AuthorListBox.Items, app.AuthorListBox.Value);
            authorIndex = find(isSelected);
        end

        function updateCurrentAuthor(app, propertyName, propertyValue, doSave)
        % updateCurrentAuthor - Update details for the current author
        %
        %   This function updates the value of a property for the currently
        %   selected author from the author listbox.

            if nargin < 4 || isempty(doSave)
                doSave = true; 
            end
            
            authorIndex = app.getSelectedAuthorIndex();
            if isempty(authorIndex); authorIndex = 1; end

            app.AuthorData.updateProperty(propertyName, propertyValue, authorIndex)

            if doSave
              app.DatasetInformation.Author = app.AuthorData.AuthorList;
              app.saveDatasetInformation();
            end
        end

        % Validate person property against openMINDS
        function updatePerson(app, propertyName, propertyValue)
        % Try to create an openMINDS Person with given property value and
        %show error if the the information is not valid. Note: requires
        %openMINDS_MATLAB to be on path.
            try
                p = openminds.core.Person(propertyName, propertyValue);
            catch ME
                uialert(app.NDIMetadataEditorUIFigure, ME.message, 'Invalid input')
            end
        end
      
        % Update author input fields based on a struct of author details
        function fillAuthorInputFieldsFromStruct(app, S)
            % Note: Not all fields are handled yet
            
            app.GivenNameEditField.Value = S.givenName;
            app.FamilyNameEditField.Value = S.familyName;
            app.AuthorEmailEditField.Value = S.contactInformation.email;
            app.DigitalIdentifierEditField.Value = S.digitalIdentifier.identifier;
            
            app.AffiliationListBox.Items = {};

            if ~isempty(S.affiliation)
                organizationList = [S.affiliation.memberOf];
                organizationNames = {organizationList.fullName};
                if ~isempty(organizationNames{1})
                    app.AffiliationListBox.Items = organizationNames;
                end
            end

            app.setCheckedNodesFromData(app.AuthorRoleTree, S.authorRole)
        end

        % Update the author listbox with the full names of all existing authors
        function updateAuthorListbox(app)
            S = app.AuthorData.AuthorList;
            fullNames = arrayfun(@(i) app.AuthorData.getAuthorName(i), 1:numel(S), 'UniformOutput', false);
            app.AuthorListBox.Items = fullNames;
            app.AuthorListBox.Value = fullNames{1};
        end

        function updateAuthorPlaceholderLabels(app)
            expression = 'Author \d*';
            authorItems = app.AuthorListBox.Items;

            for i = 1:numel(authorItems)
                
                thisName = authorItems{i};
                isSelected = strcmp(app.AuthorListBox.Value, thisName);

                if ~isempty(regexp(thisName, expression, 'once'))
                    newName = sprintf('Author %d', i);
                    if ~strcmp(newName, thisName)
                        app.AuthorListBox.Items{i} = newName;
                        if isSelected
                            app.AuthorListBox.Value = newName;
                        end
                    end

                end
            end
        end

        function reorderAuthorList(app, newAuthorIndex, oldAuthorIndex)
            
            % Reorder items in author data
            try
                app.AuthorData.reorderItems(newAuthorIndex, oldAuthorIndex)
            catch ME
                oldAuthorName = app.AuthorListBox.Items(oldAuthorIndex);
                
                if ~isempty( regexp(oldAuthorName, 'Author \d*', 'once') )
                    errMessage = 'Can not reorder placeholder author item.';
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid operation')
                    return
                else
                    uialert(app.NDIMetadataEditorUIFigure, ME.message, 'Something went wrong')
                    return
                end
            end
            
            % Reorder listbox items
            app.AuthorListBox.Items([newAuthorIndex, oldAuthorIndex]) = ...
                app.AuthorListBox.Items([oldAuthorIndex, newAuthorIndex]);

            app.updateAuthorPlaceholderLabels()
        end

        function reorderTableRows(app, tableComponent, newRowInd, oldRowInd)
        % reorderTableRows - Reorder the rows of the given table and update
        % data

            tableComponent.Data([newRowInd, oldRowInd], :) = ...
                tableComponent.Data([oldRowInd, newRowInd], :);
            
            tableComponent.Selection = newRowInd;

            if isequal(tableComponent, app.RelatedPublicationUITable)
                fieldName = 'RelatedPublication';
            elseif isequal(tableComponent, app.FundingUITable)
                fieldName = 'Funding';
            else
                error('Unknown table component provided')
            end

            app.DatasetInformation.(fieldName) = table2struct(tableComponent.Data);
            app.saveDatasetInformation()
        end

        function onAuthorNameChanged(app, fieldName, value, mode)
            
            if nargin < 4; mode = 'nontransient'; end

            %app.updatePerson(fieldName, value)
            authorIndex = app.getSelectedAuthorIndex();
            if isempty(authorIndex); authorIndex = 1; end

            app.updateCurrentAuthor(fieldName, value, false)

            fullName = app.AuthorData.getAuthorName(authorIndex);

            app.AuthorListBox.Items{authorIndex} = fullName;
            app.AuthorListBox.Value = fullName;
        
            if strcmp(mode, 'nontransient')
                app.saveDatasetInformation();
            end
        end

        % Check if any ORCID belongs to someone perfectly matching the
        % given name.
        function checkOrcidMatch(app, fullName)

            % Only do this if no orcid is entered already:
            if ~isempty(app.DigitalIdentifierEditField.Value)
                return
            end

            % Also skip this if either given name or family name is empty:
            if isempty(app.GivenNameEditField.Value) || isempty(app.FamilyNameEditField.Value)
                return
            end

            try
                progressdlg = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                    "Indeterminate", "on", "Message", "Searching for ORCID...", ...
                    "Title", "Please Wait");
                orcid = ndi.database.metadata_app.fun.getOrcId(fullName);
                
                if ~isempty(orcid)
                    delete(progressdlg)
                    
                    orcidLink = sprintf("https://orcid.org/%s", orcid);
                    msg = sprintf('The following ORCID <a href="%s">%s</a> was found matching the given author name. Please use the link above to check if the information matches the intended author', orcidLink, orcid);
                    answer = uiconfirm(app.NDIMetadataEditorUIFigure, msg, "Review ORCID", "Options", {'Confirm', 'Reject'}, 'CancelOption', 'Reject', 'Interpreter', 'html');
                    
                    if strcmp( answer, 'Confirm' )
                        app.DigitalIdentifierEditField.Value = orcid;
                        app.updateCurrentAuthor('digitalIdentifier', orcid)
                    end
                else
                    progressdlg.Indeterminate = "off";
                    progressdlg.Message = "No ORCID entry was found for the entered name";
                    pause(1.5)
                    delete(progressdlg)
                end 
            catch ME
                % Todo: Show a uiconfirm if multiple matches are found and
                % provide a search link for the orcid web search. 
            end
        end
           
        function insertOrganization(app, S, insertIndex)

            if nargin < 3 || isempty(insertIndex)
                insertIndex = numel(app.Organizations) + 1;
            end

            if isempty(app.Organizations)
                app.Organizations = S;
            else
                app.Organizations(insertIndex) = S;
            end
            
            % Update organization dropdown
            organizationNames = {app.Organizations.fullName};
            app.OrganizationDropDown.Items = organizationNames;
            app.saveOrganizationInstances()
        end

        function appendUserDefinedSpecies(app, S)

            if isempty(app.SpeciesInstancesUser)
                app.SpeciesInstancesUser = S;
            else
                app.SpeciesInstancesUser(end+1) = S;
            end

            app.saveSpecies()
        end

        % Add author details to the authors table.
        function addAffiliationToTable(app,aff)
            S = struct;
            S.name = aff.memberOf.fullName;
            newRowData = struct2table(S,'AsArray', true);
            app.AffiliationTable.Data = cat(1, app.AffiliationTable.Data, newRowData);
        end

        % function deleteAffiliationInArray(app, authorIndex, affiliationIndex)
        %     app.AuthorData.AuthorList(authorIndex).Affiliation(affiliationIndex) = [];
        % end 

        % Open (external app) form where user can enter author details
        function S = openOrganizationForm(app, organizationInfo, organizationIndex)
        %openOrganizationForm Open Organization form where user can enter organization details
            if ~isfield(app.UIForm, 'Organization')
                app.UIForm.Organization = ndi.database.metadata_app.Apps.OrganizationForm(); % Create the form
            else
                app.UIForm.Organization.Visible = 'on'; % Make the form visible
            end

            if nargin > 1 && ~isempty(organizationInfo)
                % Update form information if we are editing an organization
                app.UIForm.Organization.setOrganizationDetails(organizationInfo);
            end

            app.UIForm.Organization.waitfor(); % Wait for user to proceed
            
            % Get user-inputs from form
            S = app.UIForm.Organization.getOrganizationDetails();
            
            % Update data in table if user pressed save.
            mode = app.UIForm.Organization.FinishState;
            if mode == "Save"
                if nargin > 2 && ~isempty(organizationIndex)
                    app.insertOrganization(S, organizationIndex)
                else
                    app.insertOrganization(S);
                end
            else
                S = struct.empty;
            end

            app.UIForm.Organization.reset()
            app.UIForm.Organization.Visible = 'off'; % Hide the form (for later reuse)

            if ~nargout
                clear S
            end
        end

        function S = openFundingForm(app, info)
        %openFundingForm Open Affiliation form where user can enter Affiliation details
            
            % Todo: Use the general openForm method instead.

            progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                'Message', 'Opening form for entering funder details', ...
                'Title', 'Please wait...', 'Indeterminate', "on");
        
            if ~isfield(app.UIForm, 'Funding')
                app.UIForm.Funding = ndi.database.metadata_app.Apps.FundingForm(); % Create the form
            else
                app.UIForm.Funding.Visible = 'on'; % Make the form visible
            end

            if nargin > 1 && ~isempty(info)
                app.UIForm.Funding.setFunderDetails(info);
            end
                
            ndi.gui.utility.centerFigure(...
                app.UIForm.Funding.UIFigure, app.NDIMetadataEditorUIFigure)
            
            progressDialog.Message = 'Enter funder details:';
            app.UIForm.Funding.waitfor(); % Wait for user to proceed

            % Get user-inputs from form
            S = app.UIForm.Funding.getFunderDetails();
           
            % Update data in table if user pressed save.
            mode = app.UIForm.Funding.FinishState;

            if mode == "Save"
                % pass
            else
                S = struct.empty;
            end

            app.UIForm.Funding.reset()
            app.UIForm.Funding.Visible = 'off'; % Hide the form (for later reuse
            delete(progressDialog)
        end

        function S = openForm(app, formName, S, editExisting)
        %openForm Open form where user can enter details
            
            if nargin < 3; S = struct.empty; end
            if nargin < 4; editExisting = ~isempty(S); end

            progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                'Message', sprintf('Opening form for entering %s details', formName), ...
                'Title', 'Please wait...', 'Indeterminate', "on");
        
            if ~isfield(app.UIForm, formName) || ~isvalid(app.UIForm.(formName))
                appPackage = 'ndi.database.metadata_app.Apps';
                formAppName = sprintf('%s.%sForm', appPackage, formName);
                app.UIForm.(formName) = feval(formAppName); % Create the form
            else
                app.UIForm.(formName).Visible = 'on'; % Make the form visible
            end

            if nargin > 1 && ~isempty(S)
                % Initialize form if details exist and should be edited
                app.UIForm.(formName).setFormData(S, editExisting);
            end
                
            ndi.gui.utility.centerFigure(...
                app.UIForm.(formName).UIFigure, app.NDIMetadataEditorUIFigure)
            
            progressDialog.Message = sprintf('Enter %s details', lower(formName));
            app.UIForm.(formName).waitfor(); % Wait for user to proceed

            % Get user-inputs from form
            S = app.UIForm.(formName).getFormData();
           
            % Update data in table if user pressed save.
            mode = app.UIForm.(formName).FinishState;
            if mode == "Save"
                % pass
            else
                S = struct.empty;
            end

            app.UIForm.(formName).reset()
            app.UIForm.(formName).Visible = 'off'; % Hide the form (for later reuse
            delete(progressDialog)
        end

        % Open (external app) form where user can enter probe details
        function openProbeForm(app, probeType, probeIndex, probe)
        %openProbeForm Open probe form where user can enter probe details
            switch probeType
                case "Electrode"
                    if ~isfield(app.UIForm, 'Electrode')
                        app.UIForm.Electrode = ndi.database.metadata_app.Apps.ElectrodeForm();
                    else
                        app.UIForm.Electrode.Visible = 1;
                    end
                    form = app.UIForm.Electrode;
                case "Pipette"
                    if ~isfield(app.UIForm, 'Pipette')
                        app.UIForm.Pipette = ndi.database.metadata_app.Apps.PipetteForm();
                    else
                        app.UIForm.Pipette.Visible = 1;
                    end
                    form = app.UIForm.Pipette;
                if nargin > 3
                    form.setProbeDetails(probe);
                end
            end

            if nargin > 3 && ~isempty(probe)
                % Update form information if we are editing an probe
                form.setProbeDetails(probe);
            end

            ndi.gui.utility.centerFigure(form.UIFigure, app.NDIMetadataEditorUIFigure)
            
            form.waitfor(); % Wait for user to proceed
            
            % Get user-inputs from form
            newProbe = form.getProbeDetails();

            % Update data in table if user pressed save.
            mode = form.FinishState;
            if mode == "Save"
                app.ProbeData.replaceProbe(probeIndex, newProbe);
                app.replaceProbeInTable(probeIndex, newProbe);
                
                app.DatasetInformation.Probe = app.ProbeData.ProbeList;
                app.saveDatasetInformation();
            end

            form.reset()
            form.Visible = 'off'; % Hide the form (for later reuse)
        end
        
        function S = openSpeciesForm(app, speciesInfo)
            
            if ~isfield(app.UIForm, 'Species') || ~isvalid(app.UIForm.Species)
                app.UIForm.Species = ndi.database.metadata_app.Apps.SpeciesForm(); % Create the form
            else
                app.UIForm.Species.Visible = 'on'; % Make the form visible
            end

            if nargin > 1 && ~isempty(speciesInfo)
                app.UIForm.Species.setInfo(speciesInfo);
            end

            app.UIForm.Species.waitfor(); % Wait for user to proceed
                  
            % Get user-inputs from form
            S = app.UIForm.Species.getInfo();
            
            % Update data in table if user pressed save.
            mode = app.UIForm.Species.FinishState;
            if mode == "Save"
                % Add species to list box
                
                % Add species to DatasetInformation
            else
                S = struct.empty;
            end

            app.UIForm.Species.reset()
            app.UIForm.Species.Visible = 'off'; % Hide the form (for later reuse)
        end

        function S = openLoginForm(app)
        %openOrganizationForm Open Organization form where user can enter organization details
            if ~isfield(app.UIForm, 'Login')
                app.UIForm.Login = ndi.database.metadata_app.Apps.LoginForm(); % Create the form
            else
                app.UIForm.Login.Visible = 'on'; % Make the form visible
            end

            app.UIForm.Login.waitfor(); % Wait for user to proceed
            
            % Get user-inputs from form
            S = app.UIForm.Login.LoginInformation;
            
            % Update data in table if user pressed save.
            mode = app.UIForm.Login.FinishState;
            if mode == "Save"
                app.LoginInformation = S;
            else
                S = struct.empty;
            end

            app.UIForm.Login.reset()
            app.UIForm.Login.Visible = 'off'; % Hide the form (for later reuse)

            if ~nargout
                clear S
            end
        end
       
        % Replace information for specified author in the author table
        function replaceProbeInTable(app, probeIndex, probe)
            newRowData = struct2table(probe.toTableStruct(),'AsArray', true);
            cellData = table2cell(newRowData);
            app.UITableProbe.Data(probeIndex, :) = cellData;
        end

        function populateOrganizationDropdown(app)
            if ~isempty(app.Organizations)
                app.OrganizationDropDown.Items = {app.Organizations.fullName};
            end        
        end

        function populateLicenseDropdown(app)
            [names, shortNames] = ndi.database.metadata_app.fun.getCCByLicences();

            app.LicenseDropDown.Items = ["Select a License"; shortNames];
            app.LicenseDropDown.ItemsData = [""; names];
        end

        function populateTechniqueCategoryDropdown(app)
            allowedTypes = openminds.core.DatasetVersion.LINKED_PROPERTIES.technique;
            allowedTypes = replace(allowedTypes, 'openminds.controlledterms.', '');
            app.SelectTechniqueCategoryDropDown.Items = allowedTypes;
        end
        
        function populateTechniqueDropdown(app, schemaName)
            import ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog
            import ndi.database.metadata_app.fun.expandDropDownItems

            if nargin < 2 || isempty(schemaName)
                schemaName = app.SelectTechniqueCategoryDropDown.Value;
            end
            
            [names, options] = ndi.database.metadata_app.fun.getOpenMindsInstances(schemaName);
            app.SelectTechniqueDropDown.Items = options;
            app.SelectTechniqueDropDown.ItemsData = names;

            % Alternative routine (Todo: implements this instead): 
            % Requires: changes to convertFormDataToDocuments
            % Load openminds instances and extract @ids and names
            % % % catalog = loadOpenMindsInstanceCatalog(schemaName);
            % % % options = string( {catalog(:).at_id}' );
            % % % names = string( {catalog(:).name}' );
            % % % 
            % % % [names, options] = expandDropDownItems(names, options, schemaName, "AddSelectOption", true);
            % % % app.SelectTechniqueDropDown.Items = names;
            % % % app.SelectTechniqueDropDown.ItemsData = options;
        end

        function populateSpeciesList(app)
            import ndi.database.metadata_app.fun.loadUserInstanceCatalog
            import ndi.database.metadata_app.fun.loadOpenMindsInstanceCatalog
            import ndi.database.metadata_app.fun.expandDropDownItems

            openMindsType = 'Species';
            
            speciesCatalog = loadOpenMindsInstanceCatalog(openMindsType);
            
            options = string( {speciesCatalog(:).at_id}' );
            names = string( {speciesCatalog(:).name}' );
            
            % Add some actionable options to the dropdown options
            [names, options] = expandDropDownItems(names, options, openMindsType, "AddSelectOption", true);

            % Combine openMINDS instances and user defined instances.
            if ~isempty(app.SpeciesInstancesUser)
                [customNames, customOptions] = deal({app.SpeciesInstancesUser.name}');
                names = cat(1, names, customNames);
                options = cat(1, options, customOptions);
                [names, sortIdx] = sort(names);
                options = options(sortIdx);
            end

            app.SpeciesListBox.Items = names;
            app.SpeciesListBox.ItemsData = options;
        end

        function populateBiologicalSexList(app)
            [biologicalSex, options] = ndi.database.metadata_app.fun.getOpenMindsInstances('BiologicalSex');
            app.BiologicalSexListBox.Items = options;
            app.BiologicalSexListBox.ItemsData = biologicalSex;
        end

        function populateStrainList(app)
            if isempty(app.SpeciesListBox.Value) || ismissing(app.SpeciesListBox.Value)
                items = "Select a Species";
            else
                species = app.SpeciesListBox.Value;
                strainCatalog = getStrainInstances(app);
                if strainCatalog.NumItems == 0
                    items = "No Strains Available";
                else
                    allStrains = string( {strainCatalog(:).species} );
                    %[~, allStrains] = fileparts(allStrains);
    
                    keep = allStrains == species;
    
                    if ~any(keep)
                        items = "No Strains Available";
                    else
                        items = string( {strainCatalog(keep).name} );
                    end
                end       
            end
            app.StrainListBox.Items = items;
        end
    end

    methods (Access = private) % App initialization/configuration methods
        
        function setFigureMinSize(app)
            isMatch = false;
            drawnow
            app.NDIMetadataEditorUIFigure.Tag = ndi.fun.timestamp;

            while ~any(isMatch)
                windowList = matlab.internal.webwindowmanager.instance.findAllWebwindows();
                isMatch = strcmp({windowList.Title}, app.NDIMetadataEditorUIFigure.Name);
            end
            window = windowList(isMatch);
            window.setMinSize([840 610])
        end

        function centerFigureOnScreen(app)
            ndi.gui.utility.centerFigure(app.NDIMetadataEditorUIFigure)
        end
        
        function hideUnimplementedComponents(app)
%             app.MoveFundingUpButton.Visible = 'off';
%             app.MoveFundingDownButton.Visible = 'off';
%             app.MovePublicationUpButton.Visible = 'off';
%             app.MovePublicationDownButton.Visible = 'off';
            app.MoveAffiliationUpButton.Visible = 'off';
            app.MoveAffiliationDownButton.Visible = 'off';
            app.ErrorTextAreaLabel.Visible = 'off';
            app.ErrorTextArea.Visible = 'off';
            
            % app.FundingEditField.Visible = 'off';
            app.FooterpanelLabel.Visible = 'off';
            % app.SaveChangesButton.Visible = 'off';
            % app.DatasetIdentifierEditField.Visible = 'off';
        end

        function loadUserDefinedMetadata(app)
        % Load user-defined metadata instances. 
        %
        % These are instances that can be re-used across sessions / datasets.
            app.loadOrganizations()
            app.loadSpecies()
        end

        function populateComponentsWithMetadata(app)
            import ndi.database.metadata_app.fun.loadInstancesToTreeCheckbox

            loadInstancesToTreeCheckbox(app.ExperimentalApproachTree, "ExperimentalApproach");
            loadInstancesToTreeCheckbox(app.DataTypeTree, "SemanticDataType");
            
            app.populateLicenseDropdown()
            app.populateTechniqueCategoryDropdown()
            app.populateTechniqueDropdown()
            app.populateSpeciesList()
            app.populateBiologicalSexList()
            app.populateStrainList()
            app.populateOrganizationDropdown()
        end
        
        function getInitialMetadataFromSession(app)
                
            subjectData = ndi.database.metadata_app.fun.loadSubjects(app.Dataset);
            app.SubjectData = subjectData;
            subjectTableData = subjectData.formatTable()
            if ~isempty(subjectTableData)
                app.UITableSubject.Data = struct2table(subjectTableData, 'AsArray', true);
            end

            % probeData = ndi.database.metadata_app.fun.loadProbes(app.Dataset);
            % app.ProbeData = probeData;
            % probeTableData = probeData.formatTable();
            % app.UITableProbe.Data = struct2table(probeTableData, 'AsArray', true);
        end
        
        function updateSubjectDataFromSession(app)
            
            % Note: The app.SubjectData is updated directly from the NDI 
            % session on app construction.

            subjectsLoaded = app.DatasetInformation.Subjects;
            subjectsSession = app.SubjectData.SubjectList;
            
            subjectIdsLoaded = [subjectsLoaded.SubjectName];
            subjectIdsSession = [subjectsSession.SubjectName];

            % Assume only subjects have been added:
            addedSubjectIds = setdiff(subjectIdsSession, subjectIdsLoaded);
            [removedSubjectIds, iA] = setdiff(subjectIdsLoaded, subjectIdsSession);

            if ~isempty(removedSubjectIds)
                %error('Subject has been removed from session, but is still present in metadata. This condition is not handled yet. Please report.')
                subjectsLoaded(iA) = [];
            end

            % Update app's Subject data based on loaded subjects
            app.SubjectData.SubjectList = subjectsLoaded;
            for i = 1:numel(addedSubjectIds)
                newSubject = app.SubjectData.addItem();
                newSubject.SubjectName = addedSubjectIds(i);
            end

            subjectTableData = app.SubjectData.formatTable();
            if ~isempty(subjectTableData)
                app.UITableSubject.Data = struct2table(subjectTableData, 'AsArray', true);
            end
        end

        function updateProbeDataFromSession(app)
            probesLoaded = app.DatasetInformation.Probe;
            probesSession = app.ProbeData.ProbeList;

            probeIdsLoaded = cellfun(@(c) c.Name, probesLoaded, 'UniformOutput', false);
            probeIdsSession = cellfun(@(c) c.Name, probesSession, 'UniformOutput', false);

            % Assume only subjects have been added:
            [addedProbeIds, iA] = setdiff(probeIdsSession, probeIdsLoaded);
            removedProbeIds = setdiff(probeIdsLoaded, probeIdsSession);

            if ~isempty(removedProbeIds)
                error('Probe has been removed from session, but is still present in metadata. This condition is not handled yet. Please report.')
            end

            % Update app's Subject data based on loaded subjects
            app.ProbeData.ProbeList = probesLoaded;
            for i = 1:numel(addedProbeIds)
                newProbe = probesSession{iA(i)};
                app.ProbeData.addNewProbe(newProbe);
            end

            probeTableData = app.ProbeData.formatTable();
            app.UITableProbe.Data = struct2table(probeTableData, 'AsArray', true);
        end

        function resetFigureNameIn(app, name, numSeconds)
        % Use a time to reset figure name
            if ~isempty(app.Timer)
                stop(app.Timer)
                delete(app.Timer)
                app.Timer = [];
            end

            app.Timer = timer();
            app.Timer.TimerFcn = @(s,e)app.updateName(name);
            app.Timer.StartDelay = numSeconds;
            start(app.Timer)
        end

        function updateName(app, name)
        % Update figure name and delete timer.
            app.NDIMetadataEditorUIFigure.Name = name;
            stop(app.Timer)
            delete(app.Timer)
            app.Timer = [];
        end
    
        function changeTab(app, newTab)
            app.TabGroup.SelectedTab = newTab;
            app.onTabChanged()
        end

        function onTabChanged(app, selectedTab)
        % onTabChanged - Callback for when current tab is changed.
            
            if nargin < 2 
                selectedTab = app.TabGroup.SelectedTab;
            end

            if selectedTab == app.TabGroup.Children(1) ...
                    || selectedTab == app.TabGroup.Children(end)
                
                app.FooterPanel.Visible = 'off';
                app.FooterPanel.Parent = app.NDIMetadataEditorUIFigure;

                app.MainGridLayout.RowHeight = {'1x'};
            else
                app.FooterPanel.Visible = 'on';
                app.MainGridLayout.RowHeight = {'1x', 63};
                app.FooterPanel.Parent = app.MainGridLayout;
                app.FooterPanel.Layout.Row = 2;
                app.FooterPanel.Layout.Column = 1;
            end
        end

        function updateSubjectTableColumData(app, columnName, newValue)
                
            % Get the selected row and column in the table
            selectedRows = app.UITableSubject.Selection;
            prevData = app.SubjectData;
            
            for i = 1:numel(selectedRows)

                subjectIndex = selectedRows(i);
                subjectName = app.UITableSubject.Data{selectedRows(i), 'Subject'};

                % subjectIndex = app.SubjectData.getIndex(subjectName); %Question: Would this ever be different from selected row?

                if ~isempty(newValue) && ~isempty(subjectName) && subjectIndex ~= -1          
                    switch columnName
                        case 'BiologicalSex'
                            app.SubjectData.SubjectList(subjectIndex).BiologicalSexList = {newValue};
                            
                        case 'Species'
                            %species_name = app.SpeciesListBox.Value;

                            if ~ismissing(app.SpeciesListBox.Value)
                                selectedIdx = strcmp(app.SpeciesListBox.ItemsData, app.SpeciesListBox.Value);
                                species_name = app.SpeciesListBox.Items{selectedIdx};
                                species = app.SpeciesData.getItem(species_name);
                            else
                                species = openminds.controlledterms.Species;
                            end

                            % % % if ~app.SubjectData.biologicalSexSelected(subjectName) && ~isempty(species) && isa(species, 'ndi.database.metadata_app.class.Species')
                            % % %     app.SubjectData = prevData;
                            % % %     data = app.SubjectData.formatTable();
                            % % %     app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                            % % %     errMessage = sprintf('Please fill the biological sex for the subjects selected.');
                            % % %     uialert(app.NDIMetadataEditorUIFigure, errMessage, 'missing biological sex');
                            % % %     break;
                            % % % else
                            % % %     app.SubjectData.SubjectList(subjectIndex).SpeciesList = species;
                            % % % end

                            app.SubjectData.SubjectList(subjectIndex).SpeciesList = species;


                        case 'Strain'
                            strainName = app.StrainListBox.Value;
                            
                            if isempty(strainName)
                                app.SubjectData = prevData;
                                data = app.SubjectData.formatTable();
                                app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                                errMessage = sprintf('Please select a valid strain.');
                                uialert(app.NDIMetadataEditorUIFigure, errMessage, 'missing strain');
                                break;
                            end

                            if ~app.SubjectData.SpeciesSelected(subjectName)
                                app.SubjectData = prevData;
                                data = app.SubjectData.formatTable();
                                app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                                errMessage = sprintf('Please fill the species for the subjects selected.');
                                uialert(app.NDIMetadataEditorUIFigure, errMessage, 'missing species');
                                break;
                            else
                                app.SubjectData.SubjectList(subjectIndex).addStrain(strainName);
                            end
                    end
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                end
            end
            app.DatasetInformation.Subjects = app.SubjectData.SubjectList;
            app.saveDatasetInformation();
        end

        function deleteSubjectTableColumData(app, columnName)
                
            % Get the selected row and column in the table
            selectedRows = app.UITableSubject.Selection;
            prevData = app.SubjectData;
            
            for i = 1:numel(selectedRows)

                subjectIndex = selectedRows(i);
                subjectName = app.UITableSubject.Data{selectedRows(i), 'Subject'};

                if ~isempty(subjectName) && subjectIndex ~= -1          
                    switch columnName
                        case 'BiologicalSex'
                            app.SubjectData.SubjectList(subjectIndex).deleteBiologicalSex();
                            
                        case 'Species'
                            app.SubjectData.SubjectList(subjectIndex).deleteSpeciesList();

                        case 'Strain'
                            app.SubjectData.SubjectList(subjectIndex).deleteStrainList();
                    end
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                else
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    errMessage = sprintf('Please select a valid subject.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'invalid selection');
                end
            end

            app.DatasetInformation.Subjects = app.SubjectData.SubjectList;
            app.saveDatasetInformation();
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app, datasetObject, tempWorkingFileInput, debugMode)
            
            arguments 
                app (1,1) ndi.database.metadata_app.Apps.MetadataEditorApp
                datasetObject (1,:) ndi.dataset = ndi.dataset.empty % Todo: should be required.
                tempWorkingFileInput (1,:) string = string.empty
                debugMode (1,1) logical = false
            end

            % Check that required addons are present:
            try
                ndi.fun.assertAddonOnPath(...
                    "openMINDS Metadata Models", 'RequiredFor', 'NDI Dataset Uploader')
            catch
                try % was renamed for v0.9.5
                    ndi.fun.assertAddonOnPath(...
                        "openMINDS Metadata Toolbox", 'RequiredFor', 'NDI Dataset Uploader')
                catch ME
                    delete(app); throwAsCaller(ME)
                end
            end
disp('here:startupFcn')
            % Assign input arguments to properties:
            if ~isempty(datasetObject); app.Dataset = datasetObject; end
            if ~isempty(tempWorkingFileInput); app.TempWorkingFile = tempWorkingFileInput; end
            if ~isempty(datasetObject) && (~isempty(tempWorkingFileInput))
                
            end

            % This panel contains the previous and next buttons and should
            % not be visible on the first page:
            app.FooterPanel.Visible = 'off';
                     
            app.hideUnimplementedComponents()
            app.markRequiredFields()

            if not(debugMode)
                app.ExportDatasetInfoButton.Visible = 'off';
                app.TestDocumentConversionButton.Visible = 'off';
            end

            app.setFigureMinSize()
            app.centerFigureOnScreen()

            % Load metadata and populate app components:
            app.loadUserDefinedMetadata()
            app.populateComponentsWithMetadata()

            % Retrieve some data from a session if it was provided:
            if ~isempty(app.Dataset)
                app.getInitialMetadataFromSession()
            end

            app.loadDatasetInformation()

            % Add default value for version identifier if it does not exist
            if ~isfield(app.DatasetInformation, 'VersionIdentifier')
                app.DatasetInformation.VersionIdentifier = app.VersionIdentifierEditField.Value;
            end
            if ~isfield(app.DatasetInformation, 'VersionInnovation')
                app.DatasetInformation.VersionInnovation = "This is the first version of the dataset";
            end
        end

        % Close request function: NDIMetadataEditorUIFigure
        function NDIMetadataEditorUIFigureCloseRequest(app, event)
            if ~isempty(app.Dataset)
                app.Dataset = ndi.database.metadata_ds_core.saveEditor2Doc(app.Dataset,app.DatasetInformation);
            end
            formNames = fieldnames(app.UIForm);
            for i = 1:numel(formNames)
                thisName = formNames{i};
                delete(app.UIForm.(thisName))
            end
            delete(app)
        end

        % Button pushed function: GetStartedButton
        function GetStartedButtonPushed(app, event)
            app.onTabChanged(app.DatasetOverviewTab)
            app.TabGroup.SelectedTab = app.DatasetOverviewTab;
        end

        % Value changed function: DatasetBranchTitleEditField
        function DatasetBranchTitleValueChanged(app, event)
            value = app.DatasetBranchTitleEditField.Value;
            app.DatasetInformation.DatasetFullName = value;
            
            if ~isempty(value)
                app.resetLabelForRequiredField("DatasetBranchTitleEditField")
            end

            % Only update/generate short name if input field is empty
            if isempty(app.DatasetShortNameEditField.Value)
                app.DatasetShortNameEditField.Value = ndi.database.metadata_app.fun.generateShortName(value, 3);
                app.DatasetInformation.DatasetShortName = value;
                if ~isempty(value)
                    app.resetLabelForRequiredField("DatasetShortNameEditField")
                end
            end
            
            app.saveDatasetInformation();
        end

        % Value changed function: DatasetShortNameEditField
        function DatasetShortNameValueChanged(app, event)
            value = event.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("DatasetShortNameEditField")
            end
            app.DatasetInformation.DatasetShortName = value;
            app.saveDatasetInformation();
        end

        % Value changed function: AbstractTextArea
        function AbstractValueChanged(app, event)
            value = event.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("AbstractTextArea")
            end
            app.DatasetInformation.Description = value;
            app.saveDatasetInformation();
        end

        % Value changed function: DatasetCommentsTextArea
        function CommentsDetailsValueChanged(app, event)
            value = event.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("DatasetCommentsTextArea")
            end
            app.DatasetInformation.Comments = value;
            app.saveDatasetInformation();
        end

        % Button pushed function: AddAuthorButton
        function AddAuthorButtonPushed(app, event)
            % Add item to listbox
            numAuthors = numel(app.AuthorListBox.Items);

            app.AuthorListBox.Items{end+1} = sprintf('Author %d', numAuthors+1);
            app.AuthorListBox.Value = app.AuthorListBox.Items{end};
            app.AuthorListBoxValueChanged();

            app.updateAuthorPlaceholderLabels()
        end

        % Button pushed function: RemoveAuthorButton
        function RemoveAuthorButtonPushed(app, event)
            % Remove item from listbox
            isSelected = strcmp(app.AuthorListBox.Items, app.AuthorListBox.Value);
            
            newItems = app.AuthorListBox.Items(~isSelected);
            
            % Remove author from list in author data
            try
                app.AuthorData.removeItem(find(isSelected))
            catch
                % A placeholder author was removed.
            end

            % Update items in listbox
            if ~isempty(newItems)
                app.AuthorListBox.Value = newItems{1};
                app.AuthorListBox.Items = newItems;
            else
                app.AuthorListBox.Value = {};
                app.AuthorListBox.Items = newItems;
            end

            % Update all input fields to reflect new selection 
            S = app.AuthorData.getItem(1);
            app.fillAuthorInputFieldsFromStruct(S)

            app.DatasetInformation.Author = app.AuthorData.AuthorList;
            app.saveDatasetInformation()
        end

        % Button pushed function: MoveAuthorUpButton
        function MoveAuthorUpButtonPushed(app, event)
            oldAuthorIndex = app.getSelectedAuthorIndex();
            if oldAuthorIndex == 1; return; end
            
            newAuthorIndex = oldAuthorIndex - 1;
            app.reorderAuthorList(newAuthorIndex, oldAuthorIndex)
        end

        % Button pushed function: MoveAuthorDownButton
        function MoveAuthorDownButtonPushed(app, event)
            oldAuthorIndex = app.getSelectedAuthorIndex();
            if oldAuthorIndex == numel(app.AuthorListBox.Items); return; end

            newAuthorIndex = oldAuthorIndex + 1; 
            app.reorderAuthorList(newAuthorIndex, oldAuthorIndex)
        end

        % Value changed function: AuthorListBox
        function AuthorListBoxValueChanged(app, event)
            authorIndex = app.getSelectedAuthorIndex();

            S = app.AuthorData.getItem(authorIndex);
            app.fillAuthorInputFieldsFromStruct(S) % Update the author fields
        end

        % Value changed function: GivenNameEditField
        function GivenNameEditFieldValueChanged(app, event)
            newValue = app.GivenNameEditField.Value;
            app.onAuthorNameChanged('givenName', newValue)

            % Use api to search for orcid match for name
            authorIndex = app.getSelectedAuthorIndex();
            fullName = app.AuthorData.getAuthorName(authorIndex);
            app.checkOrcidMatch(fullName) % Only do for value changed
        end

        % Value changing function: GivenNameEditField
        function GivenNameEditFieldValueChanging(app, event)
            changingValue = event.Value;
            app.onAuthorNameChanged('givenName', changingValue, 'transient')
        end

        % Value changed function: FamilyNameEditField
        function FamilyNameEditFieldValueChanged(app, event)
            newValue = app.FamilyNameEditField.Value;
            app.onAuthorNameChanged('familyName', newValue)
            
            % Use api to search for orcid match for name
            authorIndex = app.getSelectedAuthorIndex();
            fullName = app.AuthorData.getAuthorName(authorIndex);
            app.checkOrcidMatch(fullName)
        end

        % Value changing function: FamilyNameEditField
        function FamilyNameEditFieldValueChanging(app, event)
            changingValue = event.Value;
            app.onAuthorNameChanged('familyName', changingValue, 'transient')
        end

        % Value changed function: AuthorEmailEditField
        function AuthorEmailEditFieldValueChanged(app, event)
            value = app.AuthorEmailEditField.Value;
            try
                mustBeValidEmail(value)
            catch ME
                uialert(app.NDIMetadataEditorUIFigure, ME.message, 'Invalid email')
            end
            %app.updatePerson('contactInformation', contactInformation)
            app.updateCurrentAuthor('contactInformation', value, true)
        end

        % Value changed function: DigitalIdentifierEditField
        function DigitalIdentifierEditFieldValueChanged(app, event)
            value = app.DigitalIdentifierEditField.Value;
            if ~isempty(value)
                try
                    if contains(value, 'https://orcid.org/')
                        orcidIRI = value;
                        value = strrep(value, 'https://orcid.org/', '');
                    else
                        orcidIRI = sprintf('https://orcid.org/%s', value);
                    end
                    orcid = openminds.core.ORCID('identifier', orcidIRI);
                    app.updatePerson('digitalIdentifier', orcid)
                    app.DigitalIdentifierEditField.Value = value;
                catch ME
                    errMessage = sprintf('The entered value is not a valid ORCID. For examples of valid ORCID, please see this <a href=https://support.orcid.org/hc/en-us/articles/360006897674-Structure-of-the-ORCID-Identifier#3-some-sample-orcid-ids>link</a>');
                    %uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid ORCID', 'Interpreter', 'html')
                    app.alert(errMessage, 'Invalid ORCID', 'Interpreter', 'html')
                end
            end
            app.updateCurrentAuthor('digitalIdentifier', value)
        end

        % Button pushed function: SearchOrcidButton
        function SearchOrcidButtonPushed(app, event)
            authorIndex = app.getSelectedAuthorIndex();
            
            if isempty(authorIndex)
                app.inform('Please add an author to search for ORCID.')
                return
            end

            try
                fullName = app.AuthorData.getAuthorName(authorIndex);
            catch
                fullName = '';
            end
            
            if isempty(fullName)
                app.inform('Please fill out a name for the selected author to search for ORCID')
                return
            end
            
            apiQueryUrl = ndi.database.metadata_app.fun.getOrcIdSearchUrl(fullName);
            web(apiQueryUrl)
        end

        % Callback function: AuthorRoleTree
        function AuthorRoleTreeCheckedNodesChanged(app, event)
            selectedAuthorRoles = app.getCheckedTreeNodeData(event.CheckedNodes);
            app.updateCurrentAuthor('authorRole', selectedAuthorRoles)
        end

        % Button pushed function: AddAffiliationButton
        function AddAffiliationButtonPushed(app, event)
            
            organizationName = app.OrganizationDropDown.Value;
            
            if ~any(strcmp(organizationName, app.OrganizationDropDown.Items))
%                 progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
%                     'Please wait', 'Opening form for creating new organization')
                S = struct('fullName', organizationName);
                S = app.openOrganizationForm(S);

                if ~isempty(S)
                    organizationName = S.fullName;
                else
                    return
                end
            end
            
            if any(strcmp(app.AffiliationListBox.Items, organizationName))
                message = sprintf('The organization "%s" has already been added to list of affiliations.', organizationName);
                app.inform(message)
                return
            end

            app.AffiliationListBox.Items{end+1} = organizationName;

            % Update authordata % Todo: use update current author?
            idx = app.getSelectedAuthorIndex();
            app.AuthorData.addAffiliation(organizationName, idx)
            
            app.DatasetInformation.Author = app.AuthorData.AuthorList;
            app.saveDatasetInformation()
        end

        % Button pushed function: RemoveAffiliationButton
        function RemoveAffiliationButtonPushed(app, event)
            if ~isempty(app.AffiliationListBox.Items)
                selectedIndices = app.getListBoxSelectionIndex(app.AffiliationListBox);
                app.AffiliationListBox.Items(selectedIndices) = [];

                authorIndex = app.getSelectedAuthorIndex(); 
                if ~isempty(authorIndex)
                    % Todo: use update current author?
                    app.AuthorData.removeAffiliation(authorIndex, selectedIndices);

                    app.DatasetInformation.Author = app.AuthorData.AuthorList;
                    app.saveDatasetInformation()
                end
            end
        end

        % Button pushed function: SaveChangesButton
        function SaveChangesButtonPushed(app, event)
            app.NDIMetadataEditorUIFigure.Name = 'NDI Dataset Wizard (Saving...)';
            app.saveDatasetInformation()
            app.NDIMetadataEditorUIFigure.Name = 'NDI Dataset Wizard (Saved changes)';
            app.resetFigureNameIn('NDI Dataset Wizard', 5)
        end

        % Button pushed function: SaveButton
        function SaveButtonPushed(app, event)
            
            missingRequiredField = app.checkRequiredFields("");
            if ~isempty(missingRequiredField)
                app.alertRequiredFieldsMissing(missingRequiredField)
                return
            end
            ndi.database.metadata_app.fun.save_dataset_docs(app.Dataset, app.Dataset.id(), app.DatasetInformation);
            % app.openLoginForm();
            % ndi.database.fun.dataset_metadata(app.Dataset, 0, 'path', app.TempWorkingFile, 'action', 'submit', 'login', app.LoginInformation);
        end

        % Value changed function: ReleaseDateDatePicker
        function ReleaseDateValueChanged(app, event)
            value = event.Value;
            app.DatasetInformation.ReleaseDate = value;
            app.saveDatasetInformation();
        end

        % Value changed function: LicenseDropDown
        function LicenseDropDownValueChanged(app, event)
            value = event.Value;
            if value ~= ""
                app.resetLabelForRequiredField("LicenseDropDown")
            end
            app.DatasetInformation.License = value;
            app.saveDatasetInformation();
        end

        % Value changed function: FullDocumentationEditField
        function FullDocumentationValueChanged(app, event)
            value = event.Value;

            isValid = true;
            % Verify the value (It should be a DOI or a webresource (i.e URL)):
            try
                doi = openminds.core.DOI('identifier', value);
            catch
                tf = isValidURL(value);
                if ~tf
                    message = sprintf('Full documentation must be a valid DOI or URL');
                    app.alert(message, 'Invalid value')
                    isValid = false;
                end
            end
            if ~isValid
                app.FullDocumentationEditField.Value = event.PreviousValue;
            else
                app.DatasetInformation.FullDocumentation = value;
                app.saveDatasetInformation();
            end

            function isValid = isValidURL(inputString)
                % Define the pattern for a valid IRI
                urlPattern = '^(https?|ftp)://[^\s/$.?#].[^\s]*$';
                % Check if the input string matches the IRI pattern
                isValid = ~isempty(regexp(inputString, urlPattern, 'once'));
            end
        end

        % Value changed function: VersionIdentifierEditField
        function VersionIdentifierValueChanged(app, event)
            value = event.Value;
            app.DatasetInformation.VersionIdentifier = value;
            app.saveDatasetInformation();
        end

        % Value changed function: VersionInnovationEditField
        function VersionInnovationValueChanged(app, event)
            value = event.Value;
            app.DatasetInformation.VersionInnovation = value;
            app.saveDatasetInformation();
        end

        % Button pushed function: AddFundingButton
        function AddFundingButtonPushed(app, event)
            S = app.openFundingForm();

            if isempty(S); return; end

            if isempty(app.FundingUITable.Data)
                app.FundingUITable.Data = struct2table(S, 'AsArray', true);
            else
                app.FundingUITable.Data(end+1,:) = struct2table(S, 'AsArray', true);
            end
            app.DatasetInformation.Funding = table2struct(app.FundingUITable.Data);
            app.saveDatasetInformation();
        end

        % Button pushed function: MoveFundingUpButton
        function MoveFundingUpButtonPushed(app, event)
            currentRowIndex = app.FundingUITable.Selection;
            if isempty(currentRowIndex); return; end
            if currentRowIndex == 1; return; end
            newRowIndex = currentRowIndex - 1;

            app.reorderTableRows(app.FundingUITable, newRowIndex, currentRowIndex)
        end

        % Button pushed function: MoveFundingDownButton
        function MoveFundingDownButtonPushed(app, event)
            currentRowIndex = app.FundingUITable.Selection;
            if isempty(currentRowIndex); return; end
            if currentRowIndex == height(app.FundingUITable.Data); return; end
            newRowIndex = currentRowIndex + 1;

            app.reorderTableRows(app.FundingUITable, newRowIndex, currentRowIndex)
        end

        % Button pushed function: RemoveFundingButton
        function RemoveFundingButtonPushed(app, event)
            rowIdx = app.FundingUITable.Selection;

            if ~isempty(rowIdx)
                app.FundingUITable.Data(rowIdx, :) = [];
                app.DatasetInformation.Funding = table2struct(app.FundingUITable.Data);
                app.saveDatasetInformation()
            end
        end

        % Double-clicked callback: FundingUITable
        function FundingUITableDoubleClicked(app, event)
            displayRow = event.InteractionInformation.DisplayRow;
            
            S = app.FundingUITable.Data(displayRow, :);
            S.Properties.VariableNames = {'funder', 'awardTitle', 'awardNumber'};

            S = app.openFundingForm( table2struct(S) );
            if isempty(S); return; end

            app.FundingUITable.Data{displayRow, :} = struct2cell(S)';
            app.DatasetInformation.Funding = table2struct(app.FundingUITable.Data);
            app.saveDatasetInformation();
        end

        % Button pushed function: AddRelatedPublicationButton
        function AddRelatedPublicationButtonPushed(app, event)
            currentData = app.RelatedPublicationUITable.Data;
            S = openForm(app, "Publication");
            if isempty(S); return; end

            % Make sure the doi does not exist in table from before
            isUnique = app.assertUniquePublicationEntered(S);
            if ~isUnique; return; end

            newRow = struct2cell(S)';
            newRow = cell2table(newRow, "VariableNames", app.RelatedPublicationUITable.ColumnName);

            currentData = [currentData; newRow];
            app.RelatedPublicationUITable.Data = currentData;
            
            % Note: Convert table to struct before adding to dataset information.
            app.DatasetInformation.RelatedPublication = table2struct(currentData);
            app.saveDatasetInformation()
        end

        % Double-clicked callback: RelatedPublicationUITable
        function RelatedPublicationUITableDoubleClicked(app, event)
            displayRow = event.InteractionInformation.DisplayRow;
            %displayColumn = event.InteractionInformation.DisplayColumn;
            
            S = app.RelatedPublicationUITable.Data(displayRow, :);
            S.Properties.VariableNames = {'title', 'doi', 'pmid', 'pmcid'};

            S = app.openForm('Publication', table2struct(S));
            if isempty(S); return; end

            isUnique = app.assertUniquePublicationEntered(S, displayRow);
            if ~isUnique; return; end

            app.RelatedPublicationUITable.Data{displayRow, :} = struct2cell(S)';

            % Note: Convert table to struct before adding to dataset information.
            app.DatasetInformation.RelatedPublication = table2struct(app.RelatedPublicationUITable.Data);
            app.saveDatasetInformation();
        end

        % Button pushed function: RemovePublicationButton
        function RemovePublicationButtonPushed(app, event)
            rowIdx = app.RelatedPublicationUITable.Selection;
            app.RelatedPublicationUITable.Data(rowIdx, :) = [];
            
            currentData = app.RelatedPublicationUITable.Data;
            app.DatasetInformation.RelatedPublication = table2struct(currentData);
            app.saveDatasetInformation();
        end

        % Button pushed function: MovePublicationUpButton
        function MovePublicationUpButtonPushed(app, event)
            currentRowIndex = app.RelatedPublicationUITable.Selection;
            if isempty(currentRowIndex); return; end
            if currentRowIndex == 1; return; end
            newRowIndex = currentRowIndex - 1;

            app.reorderTableRows(app.RelatedPublicationUITable, newRowIndex, currentRowIndex)
        end

        % Button pushed function: MovePublicationDownButton
        function MovePublicationDownButtonPushed(app, event)
            currentRowIndex = app.RelatedPublicationUITable.Selection(:, 1);
            if isempty(currentRowIndex); return; end
            if currentRowIndex == height(app.RelatedPublicationUITable.Data); return; end
            newRowIndex = currentRowIndex + 1;

            app.reorderTableRows(app.RelatedPublicationUITable, newRowIndex, currentRowIndex)
        end

        % Cell edit callback: RelatedPublicationUITable
        function RelatedPublicationCellEdit(app, event)
            % indices = event.Indices;
            % newData = event.NewData;
            currentData = app.RelatedPublicationUITable.Data;
             
            % Note: Convert table to struct before adding to dataset information.
            app.DatasetInformation.RelatedPublication = table2struct(currentData);
            app.saveDatasetInformation();
        end

        % Callback function: DataTypeTree
        function DataTypeTreeCheckedNodesChanged(app, event)
            selectedDataTypes = app.getCheckedTreeNodeData(event.CheckedNodes);
            if ~isempty(selectedDataTypes)
                app.resetLabelForRequiredField("DataTypeTree")
            end
            app.DatasetInformation.DataType = selectedDataTypes;
            app.saveDatasetInformation();
        end

        % Callback function: ExperimentalApproachTree
        function ExperimentTreeCheckedNodesChanged(app, event)
            selectedExperimentalApproach = app.getCheckedTreeNodeData(event.CheckedNodes);
            if ~isempty(selectedExperimentalApproach)
                app.resetLabelForRequiredField("ExperimentalApproachTree")
            end
            app.DatasetInformation.ExperimentalApproach = selectedExperimentalApproach;
            app.saveDatasetInformation();
        end

        % Value changed function: SelectTechniqueCategoryDropDown
        function SelectTechniqueCategoryDropDownValueChanged(app, event)
            value = app.SelectTechniqueCategoryDropDown.Value;
            if ~isempty(value)
                app.resetLabelForRequiredField("SelectTechniqueCategoryDropDown")
            end
            app.populateTechniqueDropdown(value)
        end

        % Button pushed function: AddTechniqueButton
        function AddTechniqueButtonPushed(app, event)
            
            techniqueCategory = app.SelectTechniqueCategoryDropDown.Value;
            techniqueName = app.SelectTechniqueDropDown.Value;

            if ~any(strcmp(techniqueName, app.SelectTechniqueDropDown.ItemsData))
                message = sprintf('Please select one of the techniques from the list');
                app.inform(message)
                return
            end

            technique = sprintf('%s (%s)', techniqueName, techniqueCategory);
            

            if any(strcmp(technique, app.SelectedTechniquesListBox.Items))
                message = sprintf('The technique "%s" has already been added to the list of selected techniques.', techniqueName);
                app.inform(message)
                return
            end

            app.SelectedTechniquesListBox.Items{end+1} = technique;
            %app.SelectedTechniquesListBox.ItemsData{end+1} = technique;

            %todo
            %app.SelectedTechniquesListBox.ItemsData{end+1} = struct('SchemaName', techniqueCategory, 'InstanceName', techniqueName);
            
            % Save changes to datasetInformation
            app.DatasetInformation.TechniquesEmployed = app.SelectedTechniquesListBox.Items;
            %app.DatasetInformation.TechniquesEmployed = app.SelectedTechniquesListBox.ItemsData;
            app.saveDatasetInformation(); 
        end

        % Button pushed function: RemoveTechniqueButton
        function RemoveTechniqueButtonPushed(app, event)
            % Get selected item from the listbox
            selectedIndex = app.getListBoxSelectionIndex(app.SelectedTechniquesListBox);
            
            % Remove the item from the listbox
            app.SelectedTechniquesListBox.Items(selectedIndex) = [];
            app.SelectedTechniquesListBox.Value = {};

            % Update and save changes to datasetInformation
            app.DatasetInformation.TechniquesEmployed = app.SelectedTechniquesListBox.Items;
            app.saveDatasetInformation();
        end

        % Button pushed function: AssignBiologicalSexButton
        function AssignBiologicalSexButtonPushed(app, event)
            
            biologicalSex = app.BiologicalSexListBox.Value;    
            
            % Get the selected row and column in the table
            subjectSelections = app.UITableSubject.Selection;
            prevData = app.SubjectData;
            
            for i = 1:size(subjectSelections,1)
                selectedRow = app.UITableSubject.Selection(i,1);
                %selectedColumn = app.UITableSubject.Selection(i,2);
                subjectName = app.UITableSubject.Data{selectedRow, 'Subject'};
                
                % Check if a biological sex is selected and a valid subject is chosen
                if ~isempty(biologicalSex) && ~isempty(subjectName) && ~(app.SubjectData.getIndex(subjectName) == -1)
                    % Assign the selected biological sex to the corresponding row and "Biological Sex" column
                    index = app.SubjectData.getIndex(subjectName);
                    app.SubjectData.SubjectList(index).BiologicalSexList = {biologicalSex};
                    app.DatasetInformation.Subjects = app.SubjectData.SubjectList;
                    app.saveDatasetInformation();
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                else
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    % Display an error message if the conditions are not met
                    errMessage = sprintf('Please select a valid biological sex and subject.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid biological sex or subject');
                    % msgbox('Please select a valid biological sex and subject.');
                end
            end
        end

        % Value changed function: BiologicalSexListBox
        function BiologicalSexListBoxValueChanged(app, event)
            % value = app.BiologicalSexListBox.Value;
            % app.updateSubjectTableColumData('BiologicalSex', value)
        end

        % Clicked callback: BiologicalSexListBox
        function BiologicalSexListBoxClicked(app, event)
            drawnow;
            value = event.Source.Value;
            app.updateSubjectTableColumData('BiologicalSex', value);
        end

        % Button pushed function: AssignSpeciesButton
        function AssignSpeciesButtonPushed(app, event)
            species = app.SpeciesData.getItem(name);

            subjectSelections = app.UITableSubject.Selection;
            prevData = app.SubjectData;

            for i = 1:size(subjectSelections,1)
                selectedRow = app.UITableSubject.Selection(i,1);
                selectedColumn = app.UITableSubject.Selection(i,2);
                if ~selectedColumn == 1
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    % Display an error message if the conditions are not met
                    errMessage = sprintf('Please select a valid subject.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid subject');
                    break;
                end

                subjectName = app.UITableSubject.Data(selectedRow, selectedColumn).Subject;
                if isempty(subjectName) || (app.SubjectData.getIndex(subjectName) == -1)
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    % Display an error message if the conditions are not met
                    errMessage = sprintf('Please select a valid subject.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid subject');
                    break;
                end
                
                if ~app.SubjectData.biologicalSexSelected(subjectName)
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    % Display an error message if the conditions are not met
                    errMessage = sprintf('Please fill the biological sex for the subjects selected.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'missing biological sex');
                    break;
                end

                if ~isempty(species) && isa(species, 'ndi.database.metadata_app.class.Species')
                    index = app.SubjectData.getIndex(subjectName);
                    app.SubjectData.SubjectList(index).SpeciesList = species;
                    app.DatasetInformation.Subjects = app.SubjectData.SubjectList;
                    app.saveDatasetInformation();

                    % Update subject table
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                else
                    app.SubjectData = prevData;
                    data = app.SubjectData.formatTable();
                    app.UITableSubject.Data = struct2table(data, 'AsArray', true);
                    % Display an error message if the conditions are not met
                    errMessage = sprintf('Please select a valid species.');
                    uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Missing species');
                    % msgbox('Please select a valid biological sex and subject.');
                    break;
                end
            end

        end

        % Value changed function: SpeciesListBox
        function SpeciesListBoxValueChanged(app, event)
            % value = app.SpeciesListBox.Value;
            % app.updateSubjectTableColumData('Species', value);
        end

        % Clicked callback: SpeciesListBox
        function SpeciesListBoxClicked(app, event)
            drawnow;
            value = event.Source.Value;
            if ismissing(value)
                app.deleteSubjectTableColumData("Species")
            else
                app.updateSubjectTableColumData('Species', value);
                app.deleteSubjectTableColumData("Strain")

                % Todo: Clear strain if it is from a different species.
            end
            app.populateStrainList()
        end

        % Button pushed function: AddSpeciesButton
        function AddSpeciesButtonPushed(app, event)
            value = app.SpeciesEditField.Value;

            progressDialog = uiprogressdlg(app.NDIMetadataEditorUIFigure, ...
                "Indeterminate", "on", ...
                'Title','Please Wait!', ...
                "Message", "Searching for species in the NCBI Taxonomy database...");
            [~, uuid] = ndi.database.metadata_app.fun.SearchSpecies(value);
            delete(progressDialog)

            if (uuid == -1)
                errMessage = sprintf('The entered value is not a valid scientific name, common name or synonym.');
                uialert(app.NDIMetadataEditorUIFigure, errMessage, 'Invalid species name');
            else
                [name, ontologyIdentifier, synonym] = ndi.database.metadata_app.fun.getSpeciesInfo(uuid);
                
                speciesInfo = struct;
                speciesInfo.name = name;
                speciesInfo.ontologyIdentifier = ontologyIdentifier;
                speciesInfo.synonyms = synonym;
                speciesInfo.definition = '';
                speciesInfo.description = '';

                % Open species editor
                S = app.openSpeciesForm(speciesInfo);
                if isempty(S); return; end
                
                if ~isempty(app.SpeciesInstancesUser)
                    if any( strcmp({app.SpeciesInstancesUser.name}, S.name) )
                        app.inform(sprintf('Species "%s" already exists in list', S.name))
                        return
                    end
                end

                app.appendUserDefinedSpecies(S);

                app.SpeciesData.addItem(S.name, S.ontologyIdentifier, S.synonyms);
                app.saveDatasetInformation();

                app.populateSpeciesList()
                
                % Set newly added value as current selection
                app.SpeciesListBox.Value = S.name;
            end
        
        end

        % Button pushed function: AddStrainButton
        function AddStrainButtonPushed(app, event)
            SInit = struct('name',  app.StrainEditField.Value);
            if ~ismissing(app.SpeciesListBox.Value)
                SInit.species = app.SpeciesListBox.Value;
            end
            S = app.openForm('Strain', SInit, false); % False because we are not editing existing instance
            if isempty(S); return; end
            
            strainInstances = app.getStrainInstances();
            try
                strainInstances.add(S)
                strainInstances.save()
                
                app.populateStrainList();
                app.StrainListBox.Value = S.name;
            catch ME
                if ME.identifier == "Catalog:NamedItemExists"
                    uialert(app.UIFigure, sprintf("A strain with the name '%s' already exists", S.name), 'Strain Exists')
                else
                    uialert(app.UIFigure, ME.message, 'Aborted')
                end
            end
            
        end

        % Double-clicked callback: StrainListBox
        function StrainListBoxDoubleClicked(app, event)
            strainInstances = app.getStrainInstances();

            strainName = event.Source.Value;
            strainInstance = strainInstances.get(strainName);

            S = app.openForm('Strain', strainInstance);
            if isempty(S); return; end
            S.Uuid = strainInstance.Uuid;

            % Need to reload strain instances because new instances could
            % have been added in the open strain form
            strainInstances = app.getStrainInstances();
            strainInstances.replace(S);
            strainInstances.save()
            
            app.populateStrainList()
            app.StrainListBox.Value = S.name;
        end

        % Value changed function: StrainListBox
        function StrainListBoxValueChanged(app, event)
            % value = app.StrainListBox.Value;
            % app.updateSubjectTableColumData('Strain', value)
        end

        % Clicked callback: StrainListBox
        function StrainListBoxClicked(app, event)
            drawnow;
            value = event.Source.Value;
            
            if value == "Select a Species" || value == "No Strains Available"
                return
            end

            app.updateSubjectTableColumData('Strain', value);
        end

        % Button pushed function: StrainClearButton
        function StrainClearButtonPushed(app, event)
            app.deleteSubjectTableColumData("Strain");
        end

        % Button pushed function: SpeciesClearButton
        function SpeciesClearButtonPushed(app, event)
            app.deleteSubjectTableColumData("Species");
        end

        % Button pushed function: BiologicalSexClearButton
        function BiologicalSexClearButtonPushed(app, event)
            app.deleteSubjectTableColumData("BiologicalSex");
        end

        % Callback function
        function ProbeListBoxValueChanged(app, event)
            value = app.ProbeListBox.Value;
            app.TypeofProbeListBox.Value = {};
        end

        % Callback function
        function UITableProbeCellEdit(app, event)
            indices = event.Indices;
            probeType = event.NewData;
            probeIndex = indices(1);
            if ~app.ProbeData.probeExist(probeIndex)
                app.openProbeForm(probeType,probeIndex);
            else
                message = 'You have already select the probe type. Do you really want to change it?';
                title = 'Confirm selection';
                userResponse = uiconfirm(app.NDIMetadataEditorUIFigure, message, title, 'Options', {'Yes', 'No'}, 'DefaultOption', 'No');
                % Check the user's response
                if strcmp(userResponse, 'Yes')
                    app.openProbeForm(probeType,probeIndex);
                else
                    app.UITableProbe.Data{indices(1),indices(2)} = eventdata.PreviousData;
                end
            end            
        end

        % Double-clicked callback: UITableProbe
        function UITableProbeDoubleClicked(app, event)
            displayRow = event.InteractionInformation.DisplayRow;
            if isempty(displayRow); return; end
            classType = app.ProbeData.ProbeList{displayRow}.ClassType;
            app.openProbeForm(classType,displayRow, app.ProbeData.ProbeList{displayRow});
        end

        % Selection change function: TabGroup
        function TabGroupSelectionChanged(app, event)
            selectedTab = app.TabGroup.SelectedTab;
            app.onTabChanged(selectedTab)
        end

        % Button pushed function: PreviousButton
        function PreviousButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find( ismember( app.TabGroup.Children, currentTab ) );
            newTabIdx = tabIdx - 1;
            newTab = app.TabGroup.Children(newTabIdx);
            
            missingRequiredField = app.checkRequiredFields(currentTab);
            if ~isempty(missingRequiredField)
                app.alertRequiredFieldsMissing(missingRequiredField)
                return
            end

            app.onTabChanged(newTab)
            drawnow
            app.TabGroup.SelectedTab = newTab;
        end

        % Button pushed function: NextButton
        function NextButtonPushed(app, event)
            currentTab = app.TabGroup.SelectedTab;
            tabIdx = find( ismember( app.TabGroup.Children, currentTab ) );
            newTabIdx = tabIdx + 1;
            newTab = app.TabGroup.Children(newTabIdx);
            
            missingRequiredField = app.checkRequiredFields(currentTab);
            if ~isempty(missingRequiredField)
                app.alertRequiredFieldsMissing(missingRequiredField)
                return
            end

            app.onTabChanged(newTab)
            drawnow
            app.TabGroup.SelectedTab = newTab;
        end

        % Button pushed function: TestDocumentConversionButton
        function TestDocumentConversionButtonPushed(app, event)
            import ndi.database.metadata_ds_core.convertFormDataToDocuments

            documentList = convertFormDataToDocuments(app.DatasetInformation, app.Dataset.id);

            %documentsForDisplay = strjoin(documentList, newline);

            for i = 1:numel(documentList)
                %disp(documentList{i}.document_properties)
                disp( jsonencode(documentList{i}.document_properties, 'PrettyPrint', true))
            end
            %disp(documentsForDisplay)
        end

        % Button pushed function: ExportDatasetInfoButton
        function ExportDatasetInfoButtonPushed(app, event)
            assignin('base', 'datasetInfo', app.DatasetInformation)
            datasetInfo = app.DatasetInformation; %#ok<NASGU>
            %disp( app.DatasetInformation )
        end

        % Callback function
        function LicenseHelpImageClicked(app, event)
            web("https://en.wikipedia.org/wiki/Creative_Commons_license#Four_rights")
        end

        % Button pushed function: LicenseHelpButton
        function LicenseHelpButtonPushed(app, event)
            web("https://en.wikipedia.org/wiki/Creative_Commons_license#Six_regularly_used_licenses")
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Get the file path for locating images
            pathToMLAPP = fileparts(mfilename('fullpath'));

            % Create NDIMetadataEditorUIFigure and hide until all components are created
            app.NDIMetadataEditorUIFigure = uifigure('Visible', 'off');
            app.NDIMetadataEditorUIFigure.Position = [100 100 900 610];
            app.NDIMetadataEditorUIFigure.Name = 'NDI Metadata Editor';
            app.NDIMetadataEditorUIFigure.CloseRequestFcn = createCallbackFcn(app, @NDIMetadataEditorUIFigureCloseRequest, true);

            % Create FooterpanelLabel
            app.FooterpanelLabel = uilabel(app.NDIMetadataEditorUIFigure);
            app.FooterpanelLabel.HandleVisibility = 'off';
            app.FooterpanelLabel.Position = [2 -48 509 22];
            app.FooterpanelLabel.Text = 'Footer panel: This will be embedded at the bottom of the tab pages when the app is running';

            % Create SaveChangesButton
            app.SaveChangesButton = uibutton(app.NDIMetadataEditorUIFigure, 'push');
            app.SaveChangesButton.ButtonPushedFcn = createCallbackFcn(app, @SaveChangesButtonPushed, true);
            app.SaveChangesButton.HandleVisibility = 'off';
            app.SaveChangesButton.Position = [800 -27 100 23];
            app.SaveChangesButton.Text = 'Save Changes';

            % Create MainGridLayout
            app.MainGridLayout = uigridlayout(app.NDIMetadataEditorUIFigure);
            app.MainGridLayout.ColumnWidth = {'1x'};
            app.MainGridLayout.RowHeight = {'1x'};
            app.MainGridLayout.RowSpacing = 0;
            app.MainGridLayout.Padding = [0 0 0 0];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.MainGridLayout);
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);
            app.TabGroup.Layout.Row = 1;
            app.TabGroup.Layout.Column = 1;

            % Create IntroTab
            app.IntroTab = uitab(app.TabGroup);
            app.IntroTab.Title = 'Intro';

            % Create IntroGridLayout
            app.IntroGridLayout = uigridlayout(app.IntroTab);
            app.IntroGridLayout.ColumnWidth = {'1x'};
            app.IntroGridLayout.RowHeight = {60, '4x', '1.5x'};

            % Create GridLayout_Step0_C3
            app.GridLayout_Step0_C3 = uigridlayout(app.IntroGridLayout);
            app.GridLayout_Step0_C3.ColumnWidth = {'1x', 150, '1x'};
            app.GridLayout_Step0_C3.RowHeight = {40};
            app.GridLayout_Step0_C3.ColumnSpacing = 20;
            app.GridLayout_Step0_C3.RowSpacing = 20;
            app.GridLayout_Step0_C3.Layout.Row = 3;
            app.GridLayout_Step0_C3.Layout.Column = 1;

            % Create GetStartedButton
            app.GetStartedButton = uibutton(app.GridLayout_Step0_C3, 'push');
            app.GetStartedButton.ButtonPushedFcn = createCallbackFcn(app, @GetStartedButtonPushed, true);
            app.GetStartedButton.Layout.Row = 1;
            app.GetStartedButton.Layout.Column = 2;
            app.GetStartedButton.Text = 'Get Started';

            % Create GridLayout_Step0_C2
            app.GridLayout_Step0_C2 = uigridlayout(app.IntroGridLayout);
            app.GridLayout_Step0_C2.ColumnWidth = {'1x'};
            app.GridLayout_Step0_C2.RowHeight = {'1x'};
            app.GridLayout_Step0_C2.Padding = [50 25 50 25];
            app.GridLayout_Step0_C2.Layout.Row = 2;
            app.GridLayout_Step0_C2.Layout.Column = 1;

            % Create IntroductionTextLabel
            app.IntroductionTextLabel = uilabel(app.GridLayout_Step0_C2);
            app.IntroductionTextLabel.VerticalAlignment = 'top';
            app.IntroductionTextLabel.WordWrap = 'on';
            app.IntroductionTextLabel.FontSize = 14;
            app.IntroductionTextLabel.Layout.Row = 1;
            app.IntroductionTextLabel.Layout.Column = 1;
            app.IntroductionTextLabel.Text = {''; 'We''re excited to have you here. This is your upload form, where you can effortlessly share your data with us. Over the next few pages, we''ll guide you through the process of ingesting your valuable data. Our goal is to make this as seamless as possible, ensuring that your information is accurately processed and ready for analysis. '; ''; 'If you ever need assistance with any of the form elements, simply hover over the respective item to access helpful information. For any further queries, shoot us an email at info@walthamdatascience.com and we''ll get right back to you! Thank you for choosing our app to help you manage your data. Let''s get started on this journey together!'};

            % Create GridLayout25
            app.GridLayout25 = uigridlayout(app.IntroGridLayout);
            app.GridLayout25.ColumnWidth = {25, 100, '1x', 100, 25};
            app.GridLayout25.RowHeight = {'1x'};
            app.GridLayout25.Layout.Row = 1;
            app.GridLayout25.Layout.Column = 1;

            % Create IntroLabel
            app.IntroLabel = uilabel(app.GridLayout25);
            app.IntroLabel.HorizontalAlignment = 'center';
            app.IntroLabel.FontSize = 18;
            app.IntroLabel.FontWeight = 'bold';
            app.IntroLabel.Layout.Row = 1;
            app.IntroLabel.Layout.Column = 3;
            app.IntroLabel.Text = {'Welcome to the NDI Cloud''s core Metadata Editor'; ''};

            % Create NdiLogoIntroImage
            app.NdiLogoIntroImage = uiimage(app.GridLayout25);
            app.NdiLogoIntroImage.Layout.Row = 1;
            app.NdiLogoIntroImage.Layout.Column = 4;
            app.NdiLogoIntroImage.ImageSource = fullfile(pathToMLAPP, 'resources', 'ndi_logo.png');

            % Create DatasetOverviewTab
            app.DatasetOverviewTab = uitab(app.TabGroup);
            app.DatasetOverviewTab.Title = 'Dataset Overview';

            % Create DatasetOverviewGridLayout
            app.DatasetOverviewGridLayout = uigridlayout(app.DatasetOverviewTab);
            app.DatasetOverviewGridLayout.ColumnWidth = {'1x'};
            app.DatasetOverviewGridLayout.RowHeight = {60, '1x'};
            app.DatasetOverviewGridLayout.Padding = [10 20 10 10];

            % Create DatasetInformationPanel
            app.DatasetInformationPanel = uipanel(app.DatasetOverviewGridLayout);
            app.DatasetInformationPanel.BorderType = 'none';
            app.DatasetInformationPanel.Layout.Row = 2;
            app.DatasetInformationPanel.Layout.Column = 1;

            % Create GridLayout
            app.GridLayout = uigridlayout(app.DatasetInformationPanel);
            app.GridLayout.ColumnWidth = {'1x'};
            app.GridLayout.RowHeight = {44, '4x', '2x'};
            app.GridLayout.Padding = [25 25 25 10];

            % Create Panel_3
            app.Panel_3 = uipanel(app.GridLayout);
            app.Panel_3.BorderType = 'none';
            app.Panel_3.Layout.Row = 1;
            app.Panel_3.Layout.Column = 1;

            % Create GridLayout2
            app.GridLayout2 = uigridlayout(app.Panel_3);
            app.GridLayout2.ColumnWidth = {'3x', '1x'};
            app.GridLayout2.ColumnSpacing = 20;
            app.GridLayout2.RowSpacing = 4;
            app.GridLayout2.Padding = [0 0 0 0];

            % Create DatasetBranchTitleEditField
            app.DatasetBranchTitleEditField = uieditfield(app.GridLayout2, 'text');
            app.DatasetBranchTitleEditField.ValueChangedFcn = createCallbackFcn(app, @DatasetBranchTitleValueChanged, true);
            app.DatasetBranchTitleEditField.Layout.Row = 2;
            app.DatasetBranchTitleEditField.Layout.Column = 1;

            % Create DatasetBranchTitleEditFieldLabel
            app.DatasetBranchTitleEditFieldLabel = uilabel(app.GridLayout2);
            app.DatasetBranchTitleEditFieldLabel.Layout.Row = 1;
            app.DatasetBranchTitleEditFieldLabel.Layout.Column = 1;
            app.DatasetBranchTitleEditFieldLabel.Text = 'Dataset Branch Title';

            % Create DatasetShortNameEditField
            app.DatasetShortNameEditField = uieditfield(app.GridLayout2, 'text');
            app.DatasetShortNameEditField.ValueChangedFcn = createCallbackFcn(app, @DatasetShortNameValueChanged, true);
            app.DatasetShortNameEditField.Tooltip = {'If multiple, separate by comma '};
            app.DatasetShortNameEditField.Layout.Row = 2;
            app.DatasetShortNameEditField.Layout.Column = 2;

            % Create DatasetShortNameEditFieldLabel
            app.DatasetShortNameEditFieldLabel = uilabel(app.GridLayout2);
            app.DatasetShortNameEditFieldLabel.Layout.Row = 1;
            app.DatasetShortNameEditFieldLabel.Layout.Column = 2;
            app.DatasetShortNameEditFieldLabel.Text = 'Dataset Short Name';

            % Create Panel_4
            app.Panel_4 = uipanel(app.GridLayout);
            app.Panel_4.BorderType = 'none';
            app.Panel_4.Layout.Row = 2;
            app.Panel_4.Layout.Column = 1;

            % Create GridLayout3
            app.GridLayout3 = uigridlayout(app.Panel_4);
            app.GridLayout3.ColumnWidth = {'1x'};
            app.GridLayout3.RowHeight = {20, '1x'};
            app.GridLayout3.ColumnSpacing = 0;
            app.GridLayout3.RowSpacing = 4;
            app.GridLayout3.Padding = [0 0 0 0];

            % Create AbstractTextArea
            app.AbstractTextArea = uitextarea(app.GridLayout3);
            app.AbstractTextArea.ValueChangedFcn = createCallbackFcn(app, @AbstractValueChanged, true);
            app.AbstractTextArea.Layout.Row = 2;
            app.AbstractTextArea.Layout.Column = 1;

            % Create AbstractTextAreaLabel
            app.AbstractTextAreaLabel = uilabel(app.GridLayout3);
            app.AbstractTextAreaLabel.Layout.Row = 1;
            app.AbstractTextAreaLabel.Layout.Column = 1;
            app.AbstractTextAreaLabel.Text = 'Abstract';

            % Create GridLayout4
            app.GridLayout4 = uigridlayout(app.GridLayout);
            app.GridLayout4.ColumnWidth = {'1x'};
            app.GridLayout4.RowHeight = {20, '1x'};
            app.GridLayout4.ColumnSpacing = 0;
            app.GridLayout4.RowSpacing = 4;
            app.GridLayout4.Padding = [0 0 0 0];
            app.GridLayout4.Layout.Row = 3;
            app.GridLayout4.Layout.Column = 1;

            % Create DatasetCommentsTextAreaLabel
            app.DatasetCommentsTextAreaLabel = uilabel(app.GridLayout4);
            app.DatasetCommentsTextAreaLabel.Layout.Row = 1;
            app.DatasetCommentsTextAreaLabel.Layout.Column = 1;
            app.DatasetCommentsTextAreaLabel.Text = 'Comments/Details';

            % Create DatasetCommentsTextArea
            app.DatasetCommentsTextArea = uitextarea(app.GridLayout4);
            app.DatasetCommentsTextArea.ValueChangedFcn = createCallbackFcn(app, @CommentsDetailsValueChanged, true);
            app.DatasetCommentsTextArea.Tooltip = {'Anything else you''d like us to know about your upload? Note: This field is not public facing.'};
            app.DatasetCommentsTextArea.Layout.Row = 2;
            app.DatasetCommentsTextArea.Layout.Column = 1;

            % Create DatasetInformationLabel
            app.DatasetInformationLabel = uilabel(app.DatasetOverviewGridLayout);
            app.DatasetInformationLabel.HorizontalAlignment = 'center';
            app.DatasetInformationLabel.FontSize = 18;
            app.DatasetInformationLabel.FontWeight = 'bold';
            app.DatasetInformationLabel.Layout.Row = 1;
            app.DatasetInformationLabel.Layout.Column = 1;
            app.DatasetInformationLabel.Text = 'Dataset Information';

            % Create AuthorsTab
            app.AuthorsTab = uitab(app.TabGroup);
            app.AuthorsTab.Title = 'Authors';

            % Create AuthorsGridLayout
            app.AuthorsGridLayout = uigridlayout(app.AuthorsTab);
            app.AuthorsGridLayout.ColumnWidth = {'1x'};
            app.AuthorsGridLayout.RowHeight = {60, '1x'};
            app.AuthorsGridLayout.Padding = [10 20 10 10];

            % Create AuthorMainPanel
            app.AuthorMainPanel = uipanel(app.AuthorsGridLayout);
            app.AuthorMainPanel.BorderType = 'none';
            app.AuthorMainPanel.Layout.Row = 2;
            app.AuthorMainPanel.Layout.Column = 1;

            % Create AuthorMainPanelGridLayout
            app.AuthorMainPanelGridLayout = uigridlayout(app.AuthorMainPanel);
            app.AuthorMainPanelGridLayout.ColumnWidth = {250, '1x', '1x'};
            app.AuthorMainPanelGridLayout.RowHeight = {'1x'};
            app.AuthorMainPanelGridLayout.ColumnSpacing = 40;
            app.AuthorMainPanelGridLayout.Padding = [25 25 25 10];

            % Create AuthorContentLeftGridLayout
            app.AuthorContentLeftGridLayout = uigridlayout(app.AuthorMainPanelGridLayout);
            app.AuthorContentLeftGridLayout.ColumnWidth = {'1x'};
            app.AuthorContentLeftGridLayout.RowHeight = {23, '1x'};
            app.AuthorContentLeftGridLayout.Padding = [0 0 0 0];
            app.AuthorContentLeftGridLayout.Layout.Row = 1;
            app.AuthorContentLeftGridLayout.Layout.Column = 1;

            % Create AuthorListBoxGridLayout
            app.AuthorListBoxGridLayout = uigridlayout(app.AuthorContentLeftGridLayout);
            app.AuthorListBoxGridLayout.ColumnWidth = {'1x', 23};
            app.AuthorListBoxGridLayout.RowHeight = {'1x'};
            app.AuthorListBoxGridLayout.Padding = [0 0 0 0];
            app.AuthorListBoxGridLayout.Layout.Row = 2;
            app.AuthorListBoxGridLayout.Layout.Column = 1;

            % Create AuthorListBox
            app.AuthorListBox = uilistbox(app.AuthorListBoxGridLayout);
            app.AuthorListBox.Items = {};
            app.AuthorListBox.ValueChangedFcn = createCallbackFcn(app, @AuthorListBoxValueChanged, true);
            app.AuthorListBox.Layout.Row = 1;
            app.AuthorListBox.Layout.Column = 1;
            app.AuthorListBox.Value = {};

            % Create AuthorListBoxButtonGridLayout
            app.AuthorListBoxButtonGridLayout = uigridlayout(app.AuthorListBoxGridLayout);
            app.AuthorListBoxButtonGridLayout.ColumnWidth = {'1x'};
            app.AuthorListBoxButtonGridLayout.RowHeight = {23, 23, 23, 23, '1x'};
            app.AuthorListBoxButtonGridLayout.Padding = [0 0 0 0];
            app.AuthorListBoxButtonGridLayout.Layout.Row = 1;
            app.AuthorListBoxButtonGridLayout.Layout.Column = 2;

            % Create AddAuthorButton
            app.AddAuthorButton = uibutton(app.AuthorListBoxButtonGridLayout, 'push');
            app.AddAuthorButton.ButtonPushedFcn = createCallbackFcn(app, @AddAuthorButtonPushed, true);
            app.AddAuthorButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'plus.png');
            app.AddAuthorButton.Layout.Row = 1;
            app.AddAuthorButton.Layout.Column = 1;
            app.AddAuthorButton.Text = '';

            % Create RemoveAuthorButton
            app.RemoveAuthorButton = uibutton(app.AuthorListBoxButtonGridLayout, 'push');
            app.RemoveAuthorButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveAuthorButtonPushed, true);
            app.RemoveAuthorButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'minus.png');
            app.RemoveAuthorButton.Layout.Row = 2;
            app.RemoveAuthorButton.Layout.Column = 1;
            app.RemoveAuthorButton.Text = '';

            % Create MoveAuthorUpButton
            app.MoveAuthorUpButton = uibutton(app.AuthorListBoxButtonGridLayout, 'push');
            app.MoveAuthorUpButton.ButtonPushedFcn = createCallbackFcn(app, @MoveAuthorUpButtonPushed, true);
            app.MoveAuthorUpButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'up.png');
            app.MoveAuthorUpButton.Layout.Row = 3;
            app.MoveAuthorUpButton.Layout.Column = 1;
            app.MoveAuthorUpButton.Text = '';

            % Create MoveAuthorDownButton
            app.MoveAuthorDownButton = uibutton(app.AuthorListBoxButtonGridLayout, 'push');
            app.MoveAuthorDownButton.ButtonPushedFcn = createCallbackFcn(app, @MoveAuthorDownButtonPushed, true);
            app.MoveAuthorDownButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'down.png');
            app.MoveAuthorDownButton.Layout.Row = 4;
            app.MoveAuthorDownButton.Layout.Column = 1;
            app.MoveAuthorDownButton.Text = '';

            % Create AuthorListBoxLabel
            app.AuthorListBoxLabel = uilabel(app.AuthorContentLeftGridLayout);
            app.AuthorListBoxLabel.WordWrap = 'on';
            app.AuthorListBoxLabel.Layout.Row = 1;
            app.AuthorListBoxLabel.Layout.Column = 1;
            app.AuthorListBoxLabel.Text = 'Create authors and fill out their details';

            % Create AuthorContentCenterGridLayout
            app.AuthorContentCenterGridLayout = uigridlayout(app.AuthorMainPanelGridLayout);
            app.AuthorContentCenterGridLayout.ColumnWidth = {'1x'};
            app.AuthorContentCenterGridLayout.RowHeight = {23, 23, 23, 23, 23, 23, 23, 23, 23, '1x'};
            app.AuthorContentCenterGridLayout.Padding = [0 0 0 0];
            app.AuthorContentCenterGridLayout.Layout.Row = 1;
            app.AuthorContentCenterGridLayout.Layout.Column = 2;

            % Create GivenNameEditFieldLabel
            app.GivenNameEditFieldLabel = uilabel(app.AuthorContentCenterGridLayout);
            app.GivenNameEditFieldLabel.Layout.Row = 1;
            app.GivenNameEditFieldLabel.Layout.Column = 1;
            app.GivenNameEditFieldLabel.Text = 'Given Name';

            % Create GivenNameEditField
            app.GivenNameEditField = uieditfield(app.AuthorContentCenterGridLayout, 'text');
            app.GivenNameEditField.ValueChangedFcn = createCallbackFcn(app, @GivenNameEditFieldValueChanged, true);
            app.GivenNameEditField.ValueChangingFcn = createCallbackFcn(app, @GivenNameEditFieldValueChanging, true);
            app.GivenNameEditField.Layout.Row = 2;
            app.GivenNameEditField.Layout.Column = 1;

            % Create FamilyNameEditFieldLabel
            app.FamilyNameEditFieldLabel = uilabel(app.AuthorContentCenterGridLayout);
            app.FamilyNameEditFieldLabel.Layout.Row = 3;
            app.FamilyNameEditFieldLabel.Layout.Column = 1;
            app.FamilyNameEditFieldLabel.Text = 'Family Name';

            % Create FamilyNameEditField
            app.FamilyNameEditField = uieditfield(app.AuthorContentCenterGridLayout, 'text');
            app.FamilyNameEditField.ValueChangedFcn = createCallbackFcn(app, @FamilyNameEditFieldValueChanged, true);
            app.FamilyNameEditField.ValueChangingFcn = createCallbackFcn(app, @FamilyNameEditFieldValueChanging, true);
            app.FamilyNameEditField.Layout.Row = 4;
            app.FamilyNameEditField.Layout.Column = 1;

            % Create DigitalIdentifierEditFieldLabel
            app.DigitalIdentifierEditFieldLabel = uilabel(app.AuthorContentCenterGridLayout);
            app.DigitalIdentifierEditFieldLabel.Layout.Row = 5;
            app.DigitalIdentifierEditFieldLabel.Layout.Column = 1;
            app.DigitalIdentifierEditFieldLabel.Text = 'Digital Identifier (ORCID)';

            % Create AuthorOrcidGridLayout
            app.AuthorOrcidGridLayout = uigridlayout(app.AuthorContentCenterGridLayout);
            app.AuthorOrcidGridLayout.ColumnWidth = {'1x', 23};
            app.AuthorOrcidGridLayout.RowHeight = {'1x'};
            app.AuthorOrcidGridLayout.Padding = [0 0 0 0];
            app.AuthorOrcidGridLayout.Layout.Row = 6;
            app.AuthorOrcidGridLayout.Layout.Column = 1;

            % Create DigitalIdentifierEditField
            app.DigitalIdentifierEditField = uieditfield(app.AuthorOrcidGridLayout, 'text');
            app.DigitalIdentifierEditField.ValueChangedFcn = createCallbackFcn(app, @DigitalIdentifierEditFieldValueChanged, true);
            app.DigitalIdentifierEditField.Placeholder = 'Example: 0000-0002-1825-0097';
            app.DigitalIdentifierEditField.Layout.Row = 1;
            app.DigitalIdentifierEditField.Layout.Column = 1;

            % Create SearchOrcidButton
            app.SearchOrcidButton = uibutton(app.AuthorOrcidGridLayout, 'push');
            app.SearchOrcidButton.ButtonPushedFcn = createCallbackFcn(app, @SearchOrcidButtonPushed, true);
            app.SearchOrcidButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'search.png');
            app.SearchOrcidButton.Layout.Row = 1;
            app.SearchOrcidButton.Layout.Column = 2;
            app.SearchOrcidButton.Text = '';

            % Create AuthorEmailEditField
            app.AuthorEmailEditField = uieditfield(app.AuthorContentCenterGridLayout, 'text');
            app.AuthorEmailEditField.ValueChangedFcn = createCallbackFcn(app, @AuthorEmailEditFieldValueChanged, true);
            app.AuthorEmailEditField.Layout.Row = 8;
            app.AuthorEmailEditField.Layout.Column = 1;

            % Create AuthorEmailEditFieldLabel
            app.AuthorEmailEditFieldLabel = uilabel(app.AuthorContentCenterGridLayout);
            app.AuthorEmailEditFieldLabel.Layout.Row = 7;
            app.AuthorEmailEditFieldLabel.Layout.Column = 1;
            app.AuthorEmailEditFieldLabel.Text = 'Author Email';

            % Create AuthorRoleLabel
            app.AuthorRoleLabel = uilabel(app.AuthorContentCenterGridLayout);
            app.AuthorRoleLabel.Layout.Row = 9;
            app.AuthorRoleLabel.Layout.Column = 1;
            app.AuthorRoleLabel.Text = 'Author Role';

            % Create AuthorRoleTree
            app.AuthorRoleTree = uitree(app.AuthorContentCenterGridLayout, 'checkbox');
            app.AuthorRoleTree.Tooltip = {'An author can have multiple roles'};
            app.AuthorRoleTree.Layout.Row = 10;
            app.AuthorRoleTree.Layout.Column = 1;

            % Create FirstAuthorNode
            app.FirstAuthorNode = uitreenode(app.AuthorRoleTree);
            app.FirstAuthorNode.NodeData = '1st Author';
            app.FirstAuthorNode.Text = '1st Author';

            % Create CustodianNode
            app.CustodianNode = uitreenode(app.AuthorRoleTree);
            app.CustodianNode.NodeData = 'Custodian';
            app.CustodianNode.Text = 'Custodian';

            % Create CorrespondingNode
            app.CorrespondingNode = uitreenode(app.AuthorRoleTree);
            app.CorrespondingNode.NodeData = 'Corresponding';
            app.CorrespondingNode.Text = 'Corresponding';

            % Assign Checked Nodes
            app.AuthorRoleTree.CheckedNodesChangedFcn = createCallbackFcn(app, @AuthorRoleTreeCheckedNodesChanged, true);

            % Create AuthorContentRightGridLayout
            app.AuthorContentRightGridLayout = uigridlayout(app.AuthorMainPanelGridLayout);
            app.AuthorContentRightGridLayout.ColumnWidth = {'1x'};
            app.AuthorContentRightGridLayout.RowHeight = {23, 23, '1x'};
            app.AuthorContentRightGridLayout.Padding = [0 0 0 0];
            app.AuthorContentRightGridLayout.Layout.Row = 1;
            app.AuthorContentRightGridLayout.Layout.Column = 3;

            % Create AffiliationsListBoxLabel
            app.AffiliationsListBoxLabel = uilabel(app.AuthorContentRightGridLayout);
            app.AffiliationsListBoxLabel.Layout.Row = 1;
            app.AffiliationsListBoxLabel.Layout.Column = 1;
            app.AffiliationsListBoxLabel.Text = 'Affiliations/Institutes';

            % Create AffiliationSelectionGridLayout
            app.AffiliationSelectionGridLayout = uigridlayout(app.AuthorContentRightGridLayout);
            app.AffiliationSelectionGridLayout.ColumnWidth = {'1x', 23};
            app.AffiliationSelectionGridLayout.RowHeight = {'1x'};
            app.AffiliationSelectionGridLayout.Padding = [0 0 0 0];
            app.AffiliationSelectionGridLayout.Layout.Row = 2;
            app.AffiliationSelectionGridLayout.Layout.Column = 1;

            % Create AddAffiliationButton
            app.AddAffiliationButton = uibutton(app.AffiliationSelectionGridLayout, 'push');
            app.AddAffiliationButton.ButtonPushedFcn = createCallbackFcn(app, @AddAffiliationButtonPushed, true);
            app.AddAffiliationButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'plus.png');
            app.AddAffiliationButton.Tooltip = {'Add an affilitation to the list'};
            app.AddAffiliationButton.Layout.Row = 1;
            app.AddAffiliationButton.Layout.Column = 2;
            app.AddAffiliationButton.Text = '';

            % Create OrganizationDropDown
            app.OrganizationDropDown = uidropdown(app.AffiliationSelectionGridLayout);
            app.OrganizationDropDown.Items = {};
            app.OrganizationDropDown.Editable = 'on';
            app.OrganizationDropDown.Tooltip = {'Select name of an organization'};
            app.OrganizationDropDown.Placeholder = 'Select or enter name';
            app.OrganizationDropDown.Layout.Row = 1;
            app.OrganizationDropDown.Layout.Column = 1;
            app.OrganizationDropDown.Value = {};

            % Create AffiliationListBoxGridLayout
            app.AffiliationListBoxGridLayout = uigridlayout(app.AuthorContentRightGridLayout);
            app.AffiliationListBoxGridLayout.ColumnWidth = {'1x', 23};
            app.AffiliationListBoxGridLayout.RowHeight = {'1x'};
            app.AffiliationListBoxGridLayout.Padding = [0 0 0 0];
            app.AffiliationListBoxGridLayout.Layout.Row = 3;
            app.AffiliationListBoxGridLayout.Layout.Column = 1;

            % Create AffiliationListBoxButtonGridLayout
            app.AffiliationListBoxButtonGridLayout = uigridlayout(app.AffiliationListBoxGridLayout);
            app.AffiliationListBoxButtonGridLayout.ColumnWidth = {'1x'};
            app.AffiliationListBoxButtonGridLayout.RowHeight = {23, 23, 23, 23, '1x'};
            app.AffiliationListBoxButtonGridLayout.Padding = [0 0 0 0];
            app.AffiliationListBoxButtonGridLayout.Layout.Row = 1;
            app.AffiliationListBoxButtonGridLayout.Layout.Column = 2;

            % Create MoveAffiliationDownButton
            app.MoveAffiliationDownButton = uibutton(app.AffiliationListBoxButtonGridLayout, 'push');
            app.MoveAffiliationDownButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'up.png');
            app.MoveAffiliationDownButton.Layout.Row = 2;
            app.MoveAffiliationDownButton.Layout.Column = 1;
            app.MoveAffiliationDownButton.Text = '';

            % Create MoveAffiliationUpButton
            app.MoveAffiliationUpButton = uibutton(app.AffiliationListBoxButtonGridLayout, 'push');
            app.MoveAffiliationUpButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'down.png');
            app.MoveAffiliationUpButton.Layout.Row = 3;
            app.MoveAffiliationUpButton.Layout.Column = 1;
            app.MoveAffiliationUpButton.Text = '';

            % Create RemoveAffiliationButton
            app.RemoveAffiliationButton = uibutton(app.AffiliationListBoxButtonGridLayout, 'push');
            app.RemoveAffiliationButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveAffiliationButtonPushed, true);
            app.RemoveAffiliationButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'minus.png');
            app.RemoveAffiliationButton.Layout.Row = 1;
            app.RemoveAffiliationButton.Layout.Column = 1;
            app.RemoveAffiliationButton.Text = '';

            % Create AffiliationListBox
            app.AffiliationListBox = uilistbox(app.AffiliationListBoxGridLayout);
            app.AffiliationListBox.Items = {};
            app.AffiliationListBox.Layout.Row = 1;
            app.AffiliationListBox.Layout.Column = 1;
            app.AffiliationListBox.Value = {};

            % Create AuthorDetailsLabel
            app.AuthorDetailsLabel = uilabel(app.AuthorsGridLayout);
            app.AuthorDetailsLabel.HorizontalAlignment = 'center';
            app.AuthorDetailsLabel.FontSize = 18;
            app.AuthorDetailsLabel.FontWeight = 'bold';
            app.AuthorDetailsLabel.Layout.Row = 1;
            app.AuthorDetailsLabel.Layout.Column = 1;
            app.AuthorDetailsLabel.Text = 'Author Details';

            % Create DatasetDetailsTab
            app.DatasetDetailsTab = uitab(app.TabGroup);
            app.DatasetDetailsTab.Title = 'Dataset Details';

            % Create DatasetDetailsGridLayout
            app.DatasetDetailsGridLayout = uigridlayout(app.DatasetDetailsTab);
            app.DatasetDetailsGridLayout.ColumnWidth = {'1x'};
            app.DatasetDetailsGridLayout.RowHeight = {60, '1x'};
            app.DatasetDetailsGridLayout.Padding = [10 20 10 10];

            % Create DatasetDetailsPanel
            app.DatasetDetailsPanel = uipanel(app.DatasetDetailsGridLayout);
            app.DatasetDetailsPanel.BorderType = 'none';
            app.DatasetDetailsPanel.Layout.Row = 2;
            app.DatasetDetailsPanel.Layout.Column = 1;

            % Create GridLayout18
            app.GridLayout18 = uigridlayout(app.DatasetDetailsPanel);
            app.GridLayout18.ColumnWidth = {'1x'};
            app.GridLayout18.RowHeight = {188, '1x'};
            app.GridLayout18.Padding = [25 25 25 10];

            % Create GridLayout19
            app.GridLayout19 = uigridlayout(app.GridLayout18);
            app.GridLayout19.RowHeight = {'1x'};
            app.GridLayout19.ColumnSpacing = 45;
            app.GridLayout19.Padding = [0 0 0 0];
            app.GridLayout19.Layout.Row = 1;
            app.GridLayout19.Layout.Column = 1;

            % Create FundingGridLayout
            app.FundingGridLayout = uigridlayout(app.GridLayout19);
            app.FundingGridLayout.ColumnWidth = {'1x', 23};
            app.FundingGridLayout.RowHeight = {23, '1x'};
            app.FundingGridLayout.Padding = [0 0 0 0];
            app.FundingGridLayout.Layout.Row = 1;
            app.FundingGridLayout.Layout.Column = 2;

            % Create FundingUITable
            app.FundingUITable = uitable(app.FundingGridLayout);
            app.FundingUITable.ColumnName = {'Funder'; 'Award Title'; 'Award Number'};
            app.FundingUITable.RowName = {};
            app.FundingUITable.SelectionType = 'row';
            app.FundingUITable.DoubleClickedFcn = createCallbackFcn(app, @FundingUITableDoubleClicked, true);
            app.FundingUITable.Multiselect = 'off';
            app.FundingUITable.Layout.Row = 2;
            app.FundingUITable.Layout.Column = 1;

            % Create FundingUITableLabel
            app.FundingUITableLabel = uilabel(app.FundingGridLayout);
            app.FundingUITableLabel.FontWeight = 'bold';
            app.FundingUITableLabel.Layout.Row = 1;
            app.FundingUITableLabel.Layout.Column = 1;
            app.FundingUITableLabel.Text = 'Funding';

            % Create FundingTableButtonGridLayout
            app.FundingTableButtonGridLayout = uigridlayout(app.FundingGridLayout);
            app.FundingTableButtonGridLayout.ColumnWidth = {'1x'};
            app.FundingTableButtonGridLayout.RowHeight = {23, 23, 23, 23, '1x'};
            app.FundingTableButtonGridLayout.Padding = [0 0 0 0];
            app.FundingTableButtonGridLayout.Layout.Row = 2;
            app.FundingTableButtonGridLayout.Layout.Column = 2;

            % Create MoveFundingDownButton
            app.MoveFundingDownButton = uibutton(app.FundingTableButtonGridLayout, 'push');
            app.MoveFundingDownButton.ButtonPushedFcn = createCallbackFcn(app, @MoveFundingDownButtonPushed, true);
            app.MoveFundingDownButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'down.png');
            app.MoveFundingDownButton.Layout.Row = 4;
            app.MoveFundingDownButton.Layout.Column = 1;
            app.MoveFundingDownButton.Text = '';

            % Create MoveFundingUpButton
            app.MoveFundingUpButton = uibutton(app.FundingTableButtonGridLayout, 'push');
            app.MoveFundingUpButton.ButtonPushedFcn = createCallbackFcn(app, @MoveFundingUpButtonPushed, true);
            app.MoveFundingUpButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'up.png');
            app.MoveFundingUpButton.Layout.Row = 3;
            app.MoveFundingUpButton.Layout.Column = 1;
            app.MoveFundingUpButton.Text = '';

            % Create RemoveFundingButton
            app.RemoveFundingButton = uibutton(app.FundingTableButtonGridLayout, 'push');
            app.RemoveFundingButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveFundingButtonPushed, true);
            app.RemoveFundingButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'minus.png');
            app.RemoveFundingButton.Layout.Row = 2;
            app.RemoveFundingButton.Layout.Column = 1;
            app.RemoveFundingButton.Text = '';

            % Create AddFundingButton
            app.AddFundingButton = uibutton(app.FundingTableButtonGridLayout, 'push');
            app.AddFundingButton.ButtonPushedFcn = createCallbackFcn(app, @AddFundingButtonPushed, true);
            app.AddFundingButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'plus.png');
            app.AddFundingButton.Layout.Row = 1;
            app.AddFundingButton.Layout.Column = 1;
            app.AddFundingButton.Text = '';

            % Create GridLayout22
            app.GridLayout22 = uigridlayout(app.GridLayout19);
            app.GridLayout22.ColumnWidth = {'1x', '1.5x'};
            app.GridLayout22.RowHeight = {23, 23, 23, 23, 23, 23};
            app.GridLayout22.Padding = [0 0 0 0];
            app.GridLayout22.Layout.Row = 1;
            app.GridLayout22.Layout.Column = 1;

            % Create ReleaseDateDatePickerLabel
            app.ReleaseDateDatePickerLabel = uilabel(app.GridLayout22);
            app.ReleaseDateDatePickerLabel.HorizontalAlignment = 'right';
            app.ReleaseDateDatePickerLabel.Layout.Row = 2;
            app.ReleaseDateDatePickerLabel.Layout.Column = 1;
            app.ReleaseDateDatePickerLabel.Text = 'Release Date';

            % Create ReleaseDateDatePicker
            app.ReleaseDateDatePicker = uidatepicker(app.GridLayout22);
            app.ReleaseDateDatePicker.ValueChangedFcn = createCallbackFcn(app, @ReleaseDateValueChanged, true);
            app.ReleaseDateDatePicker.Layout.Row = 2;
            app.ReleaseDateDatePicker.Layout.Column = 2;

            % Create LicenseDropDownLabel
            app.LicenseDropDownLabel = uilabel(app.GridLayout22);
            app.LicenseDropDownLabel.HorizontalAlignment = 'right';
            app.LicenseDropDownLabel.Layout.Row = 3;
            app.LicenseDropDownLabel.Layout.Column = 1;
            app.LicenseDropDownLabel.Text = 'License';

            % Create FullDocumentationEditFieldLabel
            app.FullDocumentationEditFieldLabel = uilabel(app.GridLayout22);
            app.FullDocumentationEditFieldLabel.HorizontalAlignment = 'right';
            app.FullDocumentationEditFieldLabel.Layout.Row = 4;
            app.FullDocumentationEditFieldLabel.Layout.Column = 1;
            app.FullDocumentationEditFieldLabel.Text = 'Full Documentation';

            % Create FullDocumentationEditField
            app.FullDocumentationEditField = uieditfield(app.GridLayout22, 'text');
            app.FullDocumentationEditField.ValueChangedFcn = createCallbackFcn(app, @FullDocumentationValueChanged, true);
            app.FullDocumentationEditField.Tooltip = {'Enter URL(s); separate multiple entries with commas'};
            app.FullDocumentationEditField.Layout.Row = 4;
            app.FullDocumentationEditField.Layout.Column = 2;

            % Create VersionIdentifierEditFieldLabel
            app.VersionIdentifierEditFieldLabel = uilabel(app.GridLayout22);
            app.VersionIdentifierEditFieldLabel.HorizontalAlignment = 'right';
            app.VersionIdentifierEditFieldLabel.Layout.Row = 5;
            app.VersionIdentifierEditFieldLabel.Layout.Column = 1;
            app.VersionIdentifierEditFieldLabel.Text = 'Version Identifier';

            % Create VersionIdentifierEditField
            app.VersionIdentifierEditField = uieditfield(app.GridLayout22, 'text');
            app.VersionIdentifierEditField.ValueChangedFcn = createCallbackFcn(app, @VersionIdentifierValueChanged, true);
            app.VersionIdentifierEditField.Tooltip = {'Enter a string like 1.0.0; separate multiple entries with commas'};
            app.VersionIdentifierEditField.Layout.Row = 5;
            app.VersionIdentifierEditField.Layout.Column = 2;
            app.VersionIdentifierEditField.Value = '1.0.0';

            % Create VersionInnovationEditFieldLabel
            app.VersionInnovationEditFieldLabel = uilabel(app.GridLayout22);
            app.VersionInnovationEditFieldLabel.HorizontalAlignment = 'right';
            app.VersionInnovationEditFieldLabel.Layout.Row = 6;
            app.VersionInnovationEditFieldLabel.Layout.Column = 1;
            app.VersionInnovationEditFieldLabel.Text = 'Version Innovation';

            % Create VersionInnovationEditField
            app.VersionInnovationEditField = uieditfield(app.GridLayout22, 'text');
            app.VersionInnovationEditField.ValueChangedFcn = createCallbackFcn(app, @VersionInnovationValueChanged, true);
            app.VersionInnovationEditField.Tooltip = {'Enter a comment on what this version adds to previous versions; can be blank; separate multiple entries with commas'};
            app.VersionInnovationEditField.Layout.Row = 6;
            app.VersionInnovationEditField.Layout.Column = 2;
            app.VersionInnovationEditField.Value = 'This is the first version of the dataset';

            % Create AccessibilityLabel
            app.AccessibilityLabel = uilabel(app.GridLayout22);
            app.AccessibilityLabel.FontWeight = 'bold';
            app.AccessibilityLabel.Layout.Row = 1;
            app.AccessibilityLabel.Layout.Column = 1;
            app.AccessibilityLabel.Text = 'Accessibility';

            % Create GridLayout28
            app.GridLayout28 = uigridlayout(app.GridLayout22);
            app.GridLayout28.ColumnWidth = {'1x', 23};
            app.GridLayout28.RowHeight = {'1x'};
            app.GridLayout28.Padding = [0 0 0 0];
            app.GridLayout28.Layout.Row = 3;
            app.GridLayout28.Layout.Column = 2;

            % Create LicenseDropDown
            app.LicenseDropDown = uidropdown(app.GridLayout28);
            app.LicenseDropDown.Items = {'CC BY 4.0', 'CC BY-SA 4.0', 'CC BY-NC 4.0', 'CC BY-NC-SA 4.0', 'CC BY-ND 4.0', 'CC BY-NC-ND 4.0'};
            app.LicenseDropDown.ValueChangedFcn = createCallbackFcn(app, @LicenseDropDownValueChanged, true);
            app.LicenseDropDown.Tooltip = {'Choose from one of our approved licenses'};
            app.LicenseDropDown.Layout.Row = 1;
            app.LicenseDropDown.Layout.Column = 1;
            app.LicenseDropDown.Value = 'CC BY 4.0';

            % Create LicenseHelpButton
            app.LicenseHelpButton = uibutton(app.GridLayout28, 'push');
            app.LicenseHelpButton.ButtonPushedFcn = createCallbackFcn(app, @LicenseHelpButtonPushed, true);
            app.LicenseHelpButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'help.png');
            app.LicenseHelpButton.Layout.Row = 1;
            app.LicenseHelpButton.Layout.Column = 2;
            app.LicenseHelpButton.Text = '';

            % Create GridLayout20
            app.GridLayout20 = uigridlayout(app.GridLayout18);
            app.GridLayout20.ColumnWidth = {'1x', 23};
            app.GridLayout20.RowHeight = {23, '1x'};
            app.GridLayout20.Padding = [0 0 0 0];
            app.GridLayout20.Layout.Row = 2;
            app.GridLayout20.Layout.Column = 1;

            % Create RelatedPublicationUITableLabel
            app.RelatedPublicationUITableLabel = uilabel(app.GridLayout20);
            app.RelatedPublicationUITableLabel.FontWeight = 'bold';
            app.RelatedPublicationUITableLabel.Layout.Row = 1;
            app.RelatedPublicationUITableLabel.Layout.Column = 1;
            app.RelatedPublicationUITableLabel.Text = 'Related Publications';

            % Create RelatedPublicationUITable
            app.RelatedPublicationUITable = uitable(app.GridLayout20);
            app.RelatedPublicationUITable.ColumnName = {'Publication'; 'DOI'; 'PMID'; 'PMCID'};
            app.RelatedPublicationUITable.RowName = {};
            app.RelatedPublicationUITable.SelectionType = 'row';
            app.RelatedPublicationUITable.CellEditCallback = createCallbackFcn(app, @RelatedPublicationCellEdit, true);
            app.RelatedPublicationUITable.DoubleClickedFcn = createCallbackFcn(app, @RelatedPublicationUITableDoubleClicked, true);
            app.RelatedPublicationUITable.Multiselect = 'off';
            app.RelatedPublicationUITable.Layout.Row = 2;
            app.RelatedPublicationUITable.Layout.Column = 1;

            % Create PublicationTableButtonGridLayout
            app.PublicationTableButtonGridLayout = uigridlayout(app.GridLayout20);
            app.PublicationTableButtonGridLayout.ColumnWidth = {'1x'};
            app.PublicationTableButtonGridLayout.RowHeight = {23, 23, 23, 23, '1x'};
            app.PublicationTableButtonGridLayout.Padding = [0 0 0 0];
            app.PublicationTableButtonGridLayout.Layout.Row = 2;
            app.PublicationTableButtonGridLayout.Layout.Column = 2;

            % Create MovePublicationDownButton
            app.MovePublicationDownButton = uibutton(app.PublicationTableButtonGridLayout, 'push');
            app.MovePublicationDownButton.ButtonPushedFcn = createCallbackFcn(app, @MovePublicationDownButtonPushed, true);
            app.MovePublicationDownButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'down.png');
            app.MovePublicationDownButton.Layout.Row = 4;
            app.MovePublicationDownButton.Layout.Column = 1;
            app.MovePublicationDownButton.Text = '';

            % Create MovePublicationUpButton
            app.MovePublicationUpButton = uibutton(app.PublicationTableButtonGridLayout, 'push');
            app.MovePublicationUpButton.ButtonPushedFcn = createCallbackFcn(app, @MovePublicationUpButtonPushed, true);
            app.MovePublicationUpButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'up.png');
            app.MovePublicationUpButton.Layout.Row = 3;
            app.MovePublicationUpButton.Layout.Column = 1;
            app.MovePublicationUpButton.Text = '';

            % Create RemovePublicationButton
            app.RemovePublicationButton = uibutton(app.PublicationTableButtonGridLayout, 'push');
            app.RemovePublicationButton.ButtonPushedFcn = createCallbackFcn(app, @RemovePublicationButtonPushed, true);
            app.RemovePublicationButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'minus.png');
            app.RemovePublicationButton.Layout.Row = 2;
            app.RemovePublicationButton.Layout.Column = 1;
            app.RemovePublicationButton.Text = '';

            % Create AddRelatedPublicationButton
            app.AddRelatedPublicationButton = uibutton(app.PublicationTableButtonGridLayout, 'push');
            app.AddRelatedPublicationButton.ButtonPushedFcn = createCallbackFcn(app, @AddRelatedPublicationButtonPushed, true);
            app.AddRelatedPublicationButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'plus.png');
            app.AddRelatedPublicationButton.Layout.Row = 1;
            app.AddRelatedPublicationButton.Layout.Column = 1;
            app.AddRelatedPublicationButton.Text = '';

            % Create DatasetDetailsLabel
            app.DatasetDetailsLabel = uilabel(app.DatasetDetailsGridLayout);
            app.DatasetDetailsLabel.HorizontalAlignment = 'center';
            app.DatasetDetailsLabel.FontSize = 18;
            app.DatasetDetailsLabel.FontWeight = 'bold';
            app.DatasetDetailsLabel.Layout.Row = 1;
            app.DatasetDetailsLabel.Layout.Column = 1;
            app.DatasetDetailsLabel.Text = 'Dataset Details';

            % Create ExperimentDetailsTab
            app.ExperimentDetailsTab = uitab(app.TabGroup);
            app.ExperimentDetailsTab.Title = 'Experiment Details';

            % Create ExperimentDetailsGridLayout
            app.ExperimentDetailsGridLayout = uigridlayout(app.ExperimentDetailsTab);
            app.ExperimentDetailsGridLayout.ColumnWidth = {'1x'};
            app.ExperimentDetailsGridLayout.RowHeight = {60, '1x'};
            app.ExperimentDetailsGridLayout.Padding = [10 20 10 10];

            % Create ExperimentDetailsPanel
            app.ExperimentDetailsPanel = uipanel(app.ExperimentDetailsGridLayout);
            app.ExperimentDetailsPanel.BorderType = 'none';
            app.ExperimentDetailsPanel.Layout.Row = 2;
            app.ExperimentDetailsPanel.Layout.Column = 1;

            % Create GridLayout26
            app.GridLayout26 = uigridlayout(app.ExperimentDetailsPanel);
            app.GridLayout26.ColumnWidth = {180, 45, '1.25x', 45, '1x', 25};
            app.GridLayout26.RowHeight = {22, 22, 22, 23, '1x', 22, 23, '5.3x', '5.13x'};
            app.GridLayout26.Padding = [25 25 25 10];

            % Create DataTypeTreeLabel
            app.DataTypeTreeLabel = uilabel(app.GridLayout26);
            app.DataTypeTreeLabel.Layout.Row = 1;
            app.DataTypeTreeLabel.Layout.Column = 1;
            app.DataTypeTreeLabel.Text = 'Data Type';

            % Create DataTypeTree
            app.DataTypeTree = uitree(app.GridLayout26, 'checkbox');
            app.DataTypeTree.Tooltip = {''};
            app.DataTypeTree.Layout.Row = [2 6];
            app.DataTypeTree.Layout.Column = 1;

            % Assign Checked Nodes
            app.DataTypeTree.CheckedNodesChangedFcn = createCallbackFcn(app, @DataTypeTreeCheckedNodesChanged, true);

            % Create ExperimentalApproachTree
            app.ExperimentalApproachTree = uitree(app.GridLayout26, 'checkbox');
            app.ExperimentalApproachTree.Tooltip = {''};
            app.ExperimentalApproachTree.Layout.Row = [2 9];
            app.ExperimentalApproachTree.Layout.Column = 3;

            % Assign Checked Nodes
            app.ExperimentalApproachTree.CheckedNodesChangedFcn = createCallbackFcn(app, @ExperimentTreeCheckedNodesChanged, true);

            % Create ExperimentalApproachTreeLabel
            app.ExperimentalApproachTreeLabel = uilabel(app.GridLayout26);
            app.ExperimentalApproachTreeLabel.Layout.Row = 1;
            app.ExperimentalApproachTreeLabel.Layout.Column = 3;
            app.ExperimentalApproachTreeLabel.Text = 'Experimental Approach';

            % Create RemoveTechniqueButton
            app.RemoveTechniqueButton = uibutton(app.GridLayout26, 'push');
            app.RemoveTechniqueButton.ButtonPushedFcn = createCallbackFcn(app, @RemoveTechniqueButtonPushed, true);
            app.RemoveTechniqueButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'minus.png');
            app.RemoveTechniqueButton.Tooltip = {'Remove technique from list of selected techniques'};
            app.RemoveTechniqueButton.Layout.Row = 7;
            app.RemoveTechniqueButton.Layout.Column = 6;
            app.RemoveTechniqueButton.Text = '';

            % Create AddTechniqueButton
            app.AddTechniqueButton = uibutton(app.GridLayout26, 'push');
            app.AddTechniqueButton.ButtonPushedFcn = createCallbackFcn(app, @AddTechniqueButtonPushed, true);
            app.AddTechniqueButton.Icon = fullfile(pathToMLAPP, 'resources', 'icons', 'plus.png');
            app.AddTechniqueButton.Tooltip = {'Add technique to list of selected techniques'};
            app.AddTechniqueButton.Layout.Row = 4;
            app.AddTechniqueButton.Layout.Column = 6;
            app.AddTechniqueButton.Text = '';

            % Create SelectTechniqueCategoryDropDownLabel
            app.SelectTechniqueCategoryDropDownLabel = uilabel(app.GridLayout26);
            app.SelectTechniqueCategoryDropDownLabel.Layout.Row = 1;
            app.SelectTechniqueCategoryDropDownLabel.Layout.Column = 5;
            app.SelectTechniqueCategoryDropDownLabel.Text = 'Select Technique Category';

            % Create SelectTechniqueCategoryDropDown
            app.SelectTechniqueCategoryDropDown = uidropdown(app.GridLayout26);
            app.SelectTechniqueCategoryDropDown.ValueChangedFcn = createCallbackFcn(app, @SelectTechniqueCategoryDropDownValueChanged, true);
            app.SelectTechniqueCategoryDropDown.Layout.Row = 2;
            app.SelectTechniqueCategoryDropDown.Layout.Column = 5;

            % Create SelectTechniqueDropDown
            app.SelectTechniqueDropDown = uidropdown(app.GridLayout26);
            app.SelectTechniqueDropDown.Editable = 'on';
            app.SelectTechniqueDropDown.Layout.Row = 4;
            app.SelectTechniqueDropDown.Layout.Column = 5;

            % Create SelectTechniqueDropDownLabel
            app.SelectTechniqueDropDownLabel = uilabel(app.GridLayout26);
            app.SelectTechniqueDropDownLabel.Layout.Row = 3;
            app.SelectTechniqueDropDownLabel.Layout.Column = 5;
            app.SelectTechniqueDropDownLabel.Text = 'Select Technique';

            % Create SelectedTechniquesListBoxLabel
            app.SelectedTechniquesListBoxLabel = uilabel(app.GridLayout26);
            app.SelectedTechniquesListBoxLabel.Layout.Row = 6;
            app.SelectedTechniquesListBoxLabel.Layout.Column = 5;
            app.SelectedTechniquesListBoxLabel.Text = 'Selected Techniques';

            % Create SelectedTechniquesListBox
            app.SelectedTechniquesListBox = uilistbox(app.GridLayout26);
            app.SelectedTechniquesListBox.Items = {};
            app.SelectedTechniquesListBox.Layout.Row = [7 9];
            app.SelectedTechniquesListBox.Layout.Column = 5;
            app.SelectedTechniquesListBox.Value = {};

            % Create ExperimentDetailsLabel
            app.ExperimentDetailsLabel = uilabel(app.ExperimentDetailsGridLayout);
            app.ExperimentDetailsLabel.HorizontalAlignment = 'center';
            app.ExperimentDetailsLabel.FontSize = 18;
            app.ExperimentDetailsLabel.FontWeight = 'bold';
            app.ExperimentDetailsLabel.Layout.Row = 1;
            app.ExperimentDetailsLabel.Layout.Column = 1;
            app.ExperimentDetailsLabel.Text = 'Experiment Details';

            % Create SubjectInfoTab
            app.SubjectInfoTab = uitab(app.TabGroup);
            app.SubjectInfoTab.Title = 'Subject Info';

            % Create SubjectInfoGridLayout
            app.SubjectInfoGridLayout = uigridlayout(app.SubjectInfoTab);
            app.SubjectInfoGridLayout.ColumnWidth = {'1x'};
            app.SubjectInfoGridLayout.RowHeight = {60, '1x'};
            app.SubjectInfoGridLayout.Padding = [10 20 10 10];

            % Create SubjectInfoPanel
            app.SubjectInfoPanel = uipanel(app.SubjectInfoGridLayout);
            app.SubjectInfoPanel.BorderType = 'none';
            app.SubjectInfoPanel.Layout.Row = 2;
            app.SubjectInfoPanel.Layout.Column = 1;

            % Create GridLayout16
            app.GridLayout16 = uigridlayout(app.SubjectInfoPanel);
            app.GridLayout16.ColumnWidth = {'1x'};
            app.GridLayout16.RowHeight = {150, '1x'};
            app.GridLayout16.RowSpacing = 30;
            app.GridLayout16.Padding = [25 25 25 10];

            % Create GridLayout17
            app.GridLayout17 = uigridlayout(app.GridLayout16);
            app.GridLayout17.ColumnWidth = {'1x', '1x', '1x'};
            app.GridLayout17.RowHeight = {23, '1x', 23, 23};
            app.GridLayout17.ColumnSpacing = 30;
            app.GridLayout17.Padding = [0 0 0 0];
            app.GridLayout17.Layout.Row = 2;
            app.GridLayout17.Layout.Column = 1;

            % Create BiologicalSexLabel
            app.BiologicalSexLabel = uilabel(app.GridLayout17);
            app.BiologicalSexLabel.Layout.Row = 1;
            app.BiologicalSexLabel.Layout.Column = 1;
            app.BiologicalSexLabel.Text = 'Biological Sex';

            % Create BiologicalSexListBox
            app.BiologicalSexListBox = uilistbox(app.GridLayout17);
            app.BiologicalSexListBox.Items = {'asexual multicellular organism', 'female organism', 'male organism', 'hermaphroditic organism'};
            app.BiologicalSexListBox.ValueChangedFcn = createCallbackFcn(app, @BiologicalSexListBoxValueChanged, true);
            app.BiologicalSexListBox.Layout.Row = 2;
            app.BiologicalSexListBox.Layout.Column = 1;
            app.BiologicalSexListBox.ClickedFcn = createCallbackFcn(app, @BiologicalSexListBoxClicked, true);
            app.BiologicalSexListBox.Value = 'asexual multicellular organism';

            % Create SpeciesLabel_2
            app.SpeciesLabel_2 = uilabel(app.GridLayout17);
            app.SpeciesLabel_2.Layout.Row = 1;
            app.SpeciesLabel_2.Layout.Column = 2;
            app.SpeciesLabel_2.Text = 'Species';

            % Create SpeciesListBox
            app.SpeciesListBox = uilistbox(app.GridLayout17);
            app.SpeciesListBox.Items = {};
            app.SpeciesListBox.ValueChangedFcn = createCallbackFcn(app, @SpeciesListBoxValueChanged, true);
            app.SpeciesListBox.Layout.Row = 2;
            app.SpeciesListBox.Layout.Column = 2;
            app.SpeciesListBox.ClickedFcn = createCallbackFcn(app, @SpeciesListBoxClicked, true);
            app.SpeciesListBox.Value = {};

            % Create StrainLabel
            app.StrainLabel = uilabel(app.GridLayout17);
            app.StrainLabel.Layout.Row = 1;
            app.StrainLabel.Layout.Column = 3;
            app.StrainLabel.Text = 'Strain';

            % Create StrainListBox
            app.StrainListBox = uilistbox(app.GridLayout17);
            app.StrainListBox.Items = {};
            app.StrainListBox.ValueChangedFcn = createCallbackFcn(app, @StrainListBoxValueChanged, true);
            app.StrainListBox.Tag = 'Strain';
            app.StrainListBox.Layout.Row = 2;
            app.StrainListBox.Layout.Column = 3;
            app.StrainListBox.ClickedFcn = createCallbackFcn(app, @StrainListBoxClicked, true);
            app.StrainListBox.DoubleClickedFcn = createCallbackFcn(app, @StrainListBoxDoubleClicked, true);
            app.StrainListBox.Value = {};

            % Create GridLayout24
            app.GridLayout24 = uigridlayout(app.GridLayout17);
            app.GridLayout24.RowHeight = {'1x'};
            app.GridLayout24.Padding = [0 0 0 0];
            app.GridLayout24.Layout.Row = 3;
            app.GridLayout24.Layout.Column = 1;

            % Create AssignBiologicalSexButton
            app.AssignBiologicalSexButton = uibutton(app.GridLayout24, 'push');
            app.AssignBiologicalSexButton.ButtonPushedFcn = createCallbackFcn(app, @AssignBiologicalSexButtonPushed, true);
            app.AssignBiologicalSexButton.Layout.Row = 1;
            app.AssignBiologicalSexButton.Layout.Column = 1;
            app.AssignBiologicalSexButton.Text = 'Assign';

            % Create BiologicalSexClearButton
            app.BiologicalSexClearButton = uibutton(app.GridLayout24, 'push');
            app.BiologicalSexClearButton.ButtonPushedFcn = createCallbackFcn(app, @BiologicalSexClearButtonPushed, true);
            app.BiologicalSexClearButton.Layout.Row = 1;
            app.BiologicalSexClearButton.Layout.Column = 2;
            app.BiologicalSexClearButton.Text = 'CLEAR';

            % Create GridLayout24_2
            app.GridLayout24_2 = uigridlayout(app.GridLayout17);
            app.GridLayout24_2.RowHeight = {'1x'};
            app.GridLayout24_2.Padding = [0 0 0 0];
            app.GridLayout24_2.Layout.Row = 3;
            app.GridLayout24_2.Layout.Column = 2;

            % Create AssignSpeciesButton
            app.AssignSpeciesButton = uibutton(app.GridLayout24_2, 'push');
            app.AssignSpeciesButton.ButtonPushedFcn = createCallbackFcn(app, @AssignSpeciesButtonPushed, true);
            app.AssignSpeciesButton.Layout.Row = 1;
            app.AssignSpeciesButton.Layout.Column = 1;
            app.AssignSpeciesButton.Text = 'Assign';

            % Create SpeciesClearButton
            app.SpeciesClearButton = uibutton(app.GridLayout24_2, 'push');
            app.SpeciesClearButton.ButtonPushedFcn = createCallbackFcn(app, @SpeciesClearButtonPushed, true);
            app.SpeciesClearButton.Layout.Row = 1;
            app.SpeciesClearButton.Layout.Column = 2;
            app.SpeciesClearButton.Text = 'CLEAR';

            % Create GridLayout24_3
            app.GridLayout24_3 = uigridlayout(app.GridLayout17);
            app.GridLayout24_3.RowHeight = {'1x'};
            app.GridLayout24_3.Padding = [0 0 0 0];
            app.GridLayout24_3.Layout.Row = 3;
            app.GridLayout24_3.Layout.Column = 3;

            % Create AssignStrainButton
            app.AssignStrainButton = uibutton(app.GridLayout24_3, 'push');
            app.AssignStrainButton.Layout.Row = 1;
            app.AssignStrainButton.Layout.Column = 1;
            app.AssignStrainButton.Text = 'Assign';

            % Create StrainClearButton
            app.StrainClearButton = uibutton(app.GridLayout24_3, 'push');
            app.StrainClearButton.ButtonPushedFcn = createCallbackFcn(app, @StrainClearButtonPushed, true);
            app.StrainClearButton.Layout.Row = 1;
            app.StrainClearButton.Layout.Column = 2;
            app.StrainClearButton.Text = 'CLEAR';

            % Create GridLayout24_4
            app.GridLayout24_4 = uigridlayout(app.GridLayout17);
            app.GridLayout24_4.ColumnWidth = {'1x', 50};
            app.GridLayout24_4.RowHeight = {'1x'};
            app.GridLayout24_4.Padding = [0 0 0 0];
            app.GridLayout24_4.Layout.Row = 4;
            app.GridLayout24_4.Layout.Column = 2;

            % Create SpeciesEditField
            app.SpeciesEditField = uieditfield(app.GridLayout24_4, 'text');
            app.SpeciesEditField.Placeholder = 'Enter name of species to add';
            app.SpeciesEditField.Layout.Row = 1;
            app.SpeciesEditField.Layout.Column = 1;

            % Create AddSpeciesButton
            app.AddSpeciesButton = uibutton(app.GridLayout24_4, 'push');
            app.AddSpeciesButton.ButtonPushedFcn = createCallbackFcn(app, @AddSpeciesButtonPushed, true);
            app.AddSpeciesButton.Layout.Row = 1;
            app.AddSpeciesButton.Layout.Column = 2;
            app.AddSpeciesButton.Text = 'Add';

            % Create GridLayout27
            app.GridLayout27 = uigridlayout(app.GridLayout17);
            app.GridLayout27.ColumnWidth = {'1x', 50};
            app.GridLayout27.RowHeight = {'1x'};
            app.GridLayout27.Padding = [0 0 0 0];
            app.GridLayout27.Layout.Row = 4;
            app.GridLayout27.Layout.Column = 3;

            % Create StrainEditField
            app.StrainEditField = uieditfield(app.GridLayout27, 'text');
            app.StrainEditField.Placeholder = 'Enter name of strain to add';
            app.StrainEditField.Layout.Row = 1;
            app.StrainEditField.Layout.Column = 1;

            % Create AddStrainButton
            app.AddStrainButton = uibutton(app.GridLayout27, 'push');
            app.AddStrainButton.ButtonPushedFcn = createCallbackFcn(app, @AddStrainButtonPushed, true);
            app.AddStrainButton.Layout.Row = 1;
            app.AddStrainButton.Layout.Column = 2;
            app.AddStrainButton.Text = 'Add';

            % Create UITableSubject
            app.UITableSubject = uitable(app.GridLayout16);
            app.UITableSubject.ColumnName = {'Subject'; 'Biological Sex'; 'Species'; 'Strain'};
            app.UITableSubject.RowName = {};
            app.UITableSubject.SelectionType = 'row';
            app.UITableSubject.Layout.Row = 1;
            app.UITableSubject.Layout.Column = 1;

            % Create SubjectInfoLabel
            app.SubjectInfoLabel = uilabel(app.SubjectInfoGridLayout);
            app.SubjectInfoLabel.HorizontalAlignment = 'center';
            app.SubjectInfoLabel.FontSize = 18;
            app.SubjectInfoLabel.FontWeight = 'bold';
            app.SubjectInfoLabel.Layout.Row = 1;
            app.SubjectInfoLabel.Layout.Column = 1;
            app.SubjectInfoLabel.Text = 'Subject Info';

            % Create ProbeInfoTab
            app.ProbeInfoTab = uitab(app.TabGroup);
            app.ProbeInfoTab.Title = 'Probe Info';

            % Create ProbeInfoGridLayout
            app.ProbeInfoGridLayout = uigridlayout(app.ProbeInfoTab);
            app.ProbeInfoGridLayout.ColumnWidth = {'1x'};
            app.ProbeInfoGridLayout.RowHeight = {60, '1x'};
            app.ProbeInfoGridLayout.Padding = [10 20 10 10];

            % Create ProbeInfoPanel
            app.ProbeInfoPanel = uipanel(app.ProbeInfoGridLayout);
            app.ProbeInfoPanel.BorderType = 'none';
            app.ProbeInfoPanel.Layout.Row = 2;
            app.ProbeInfoPanel.Layout.Column = 1;

            % Create GridLayout23
            app.GridLayout23 = uigridlayout(app.ProbeInfoPanel);
            app.GridLayout23.ColumnWidth = {'1x'};
            app.GridLayout23.RowHeight = {'2x', '1x'};
            app.GridLayout23.Padding = [25 25 25 10];

            % Create UITableProbe
            app.UITableProbe = uitable(app.GridLayout23);
            app.UITableProbe.ColumnName = {'Probe Name'; 'Probe type'; 'Status'};
            app.UITableProbe.RowName = {};
            app.UITableProbe.SelectionType = 'row';
            app.UITableProbe.ColumnEditable = [false false false];
            app.UITableProbe.DoubleClickedFcn = createCallbackFcn(app, @UITableProbeDoubleClicked, true);
            app.UITableProbe.Multiselect = 'off';
            app.UITableProbe.Layout.Row = 1;
            app.UITableProbe.Layout.Column = 1;

            % Create ProbeInfoLabel
            app.ProbeInfoLabel = uilabel(app.ProbeInfoGridLayout);
            app.ProbeInfoLabel.HorizontalAlignment = 'center';
            app.ProbeInfoLabel.FontSize = 18;
            app.ProbeInfoLabel.FontWeight = 'bold';
            app.ProbeInfoLabel.Layout.Row = 1;
            app.ProbeInfoLabel.Layout.Column = 1;
            app.ProbeInfoLabel.Text = 'Probe Info';

            % Create SaveTab
            app.SaveTab = uitab(app.TabGroup);
            app.SaveTab.Title = 'Save';

            % Create SubmitGridLayout
            app.SubmitGridLayout = uigridlayout(app.SaveTab);
            app.SubmitGridLayout.ColumnWidth = {'1x'};
            app.SubmitGridLayout.RowHeight = {60, '4x', '1.5x'};

            % Create SubmitFooterGridLayout
            app.SubmitFooterGridLayout = uigridlayout(app.SubmitGridLayout);
            app.SubmitFooterGridLayout.ColumnWidth = {'1x', 150, '1x'};
            app.SubmitFooterGridLayout.RowHeight = {40};
            app.SubmitFooterGridLayout.ColumnSpacing = 20;
            app.SubmitFooterGridLayout.RowSpacing = 20;
            app.SubmitFooterGridLayout.Layout.Row = 3;
            app.SubmitFooterGridLayout.Layout.Column = 1;

            % Create SaveButton
            app.SaveButton = uibutton(app.SubmitFooterGridLayout, 'push');
            app.SaveButton.ButtonPushedFcn = createCallbackFcn(app, @SaveButtonPushed, true);
            app.SaveButton.Layout.Row = 1;
            app.SaveButton.Layout.Column = 2;
            app.SaveButton.Text = 'Save';

            % Create TestDocumentConversionButton
            app.TestDocumentConversionButton = uibutton(app.SubmitFooterGridLayout, 'push');
            app.TestDocumentConversionButton.ButtonPushedFcn = createCallbackFcn(app, @TestDocumentConversionButtonPushed, true);
            app.TestDocumentConversionButton.Layout.Row = 1;
            app.TestDocumentConversionButton.Layout.Column = 1;
            app.TestDocumentConversionButton.Text = 'Test Document Conversion';

            % Create ExportDatasetInfoButton
            app.ExportDatasetInfoButton = uibutton(app.SubmitFooterGridLayout, 'push');
            app.ExportDatasetInfoButton.ButtonPushedFcn = createCallbackFcn(app, @ExportDatasetInfoButtonPushed, true);
            app.ExportDatasetInfoButton.Layout.Row = 1;
            app.ExportDatasetInfoButton.Layout.Column = 3;
            app.ExportDatasetInfoButton.Text = 'Export Dataset Info to Workspace';

            % Create SubmitPanelGridLayout
            app.SubmitPanelGridLayout = uigridlayout(app.SubmitGridLayout);
            app.SubmitPanelGridLayout.ColumnWidth = {'1x'};
            app.SubmitPanelGridLayout.RowHeight = {'1x', 23, '1x'};
            app.SubmitPanelGridLayout.Padding = [50 25 50 25];
            app.SubmitPanelGridLayout.Layout.Row = 2;
            app.SubmitPanelGridLayout.Layout.Column = 1;

            % Create SubmissionStatusPanel
            app.SubmissionStatusPanel = uipanel(app.SubmitPanelGridLayout);
            app.SubmissionStatusPanel.BorderType = 'none';
            app.SubmissionStatusPanel.Layout.Row = 2;
            app.SubmissionStatusPanel.Layout.Column = 1;

            % Create SubmissionDescriptionLabel
            app.SubmissionDescriptionLabel = uilabel(app.SubmitPanelGridLayout);
            app.SubmissionDescriptionLabel.VerticalAlignment = 'top';
            app.SubmissionDescriptionLabel.WordWrap = 'on';
            app.SubmissionDescriptionLabel.FontSize = 14;
            app.SubmissionDescriptionLabel.Layout.Row = 1;
            app.SubmissionDescriptionLabel.Layout.Column = 1;
            app.SubmissionDescriptionLabel.Text = 'If you have filled out all the information for this dataset, please go ahead with the submission. If you want to review your information one last time, feel free to look through each of the pages again';

            % Create ErrorTextAreaLabel
            app.ErrorTextAreaLabel = uilabel(app.SubmitPanelGridLayout);
            app.ErrorTextAreaLabel.Layout.Row = 2;
            app.ErrorTextAreaLabel.Layout.Column = 1;
            app.ErrorTextAreaLabel.Text = 'Status';

            % Create ErrorTextArea
            app.ErrorTextArea = uitextarea(app.SubmitPanelGridLayout);
            app.ErrorTextArea.Layout.Row = 3;
            app.ErrorTextArea.Layout.Column = 1;

            % Create SubmitLabel
            app.SubmitLabel = uilabel(app.SubmitGridLayout);
            app.SubmitLabel.HorizontalAlignment = 'center';
            app.SubmitLabel.FontSize = 18;
            app.SubmitLabel.FontWeight = 'bold';
            app.SubmitLabel.Layout.Row = 1;
            app.SubmitLabel.Layout.Column = 1;
            app.SubmitLabel.Text = 'Review and Save Data';

            % Create FooterPanel
            app.FooterPanel = uipanel(app.NDIMetadataEditorUIFigure);
            app.FooterPanel.BorderType = 'none';
            app.FooterPanel.Position = [-6 -122 900 63];

            % Create FooterGridLayout
            app.FooterGridLayout = uigridlayout(app.FooterPanel);
            app.FooterGridLayout.ColumnWidth = {100, '1x', 100, 50, 100, '1x', 100};
            app.FooterGridLayout.RowHeight = {23};
            app.FooterGridLayout.Padding = [25 10 25 20];
            app.FooterGridLayout.BackgroundColor = [0.902 0.902 0.902];

            % Create PreviousButton
            app.PreviousButton = uibutton(app.FooterGridLayout, 'push');
            app.PreviousButton.ButtonPushedFcn = createCallbackFcn(app, @PreviousButtonPushed, true);
            app.PreviousButton.Layout.Row = 1;
            app.PreviousButton.Layout.Column = 3;
            app.PreviousButton.Text = 'Previous';

            % Create NextButton
            app.NextButton = uibutton(app.FooterGridLayout, 'push');
            app.NextButton.ButtonPushedFcn = createCallbackFcn(app, @NextButtonPushed, true);
            app.NextButton.Layout.Row = 1;
            app.NextButton.Layout.Column = 5;
            app.NextButton.Text = 'Next';

            % Create NdiLogoImage
            app.NdiLogoImage = uiimage(app.FooterGridLayout);
            app.NdiLogoImage.Layout.Row = 1;
            app.NdiLogoImage.Layout.Column = 7;
            app.NdiLogoImage.ImageSource = fullfile(pathToMLAPP, 'resources', 'ndi_logo.png');

            % Show the figure after all components are created
            app.NDIMetadataEditorUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = MetadataEditorApp(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.NDIMetadataEditorUIFigure)

                % Execute the startup function
                runStartupFcn(app, @(app)startupFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.NDIMetadataEditorUIFigure)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.NDIMetadataEditorUIFigure)
        end
    end
end
