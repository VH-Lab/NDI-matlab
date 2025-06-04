function finalDsStruct = buildDatasetInformationStructFromApp(app)
%BUILDDATASETINFORMATIONSTRUCTFROMAPP Creates an NDI document-compatible struct from app's current state.
%   finalDsStruct = BUILDDATASETINFORMATIONSTRUCTFROMAPP(app)
%   app: Handle to the MetadataEditorApp instance.
%
%   This function gathers data from the UI components (for fields directly
%   managed by MetadataEditorApp) and from the app's data management objects
%   (AuthorData, SubjectData, ProbeData) and GUI Controllers 
%   (DatasetDetailsGUI, ExperimentalDetailsGUI, SubjectInfoGUI) to construct 
%   an intermediate plain struct. This intermediate struct is then passed to
%   ndi.database.metadata_ds_core.convertDatasetInfoToStruct to perform
%   final conversions (e.g., cell arrays to comma-separated strings,
%   datetime to ISO strings), making the output `finalDsStruct` suitable for
%   creating an ndi.document of type 'ndi.metadata.metadata_editor'.

    fprintf('DEBUG: buildDatasetInformationStructFromApp: Starting to build intermediate struct.\n');
    
    intermediateDsStruct = struct();

    % 1. Populate from simple UI components mapped in FieldComponentMap (those still in MetadataEditorApp)
    if isprop(app, 'FieldComponentMap') && isstruct(app.FieldComponentMap)
        propertyNamesFromMap = fieldnames(app.FieldComponentMap);
        for i = 1:numel(propertyNamesFromMap)
            propertyName = propertyNamesFromMap{i};
            componentName = app.FieldComponentMap.(propertyName);
            
            fprintf('DEBUG: buildDatasetInformationStructFromApp: Processing main app map field: %s, component: %s\n', propertyName, componentName);

            try
                if isprop(app, componentName) && isvalid(app.(componentName))
                    uiComponent = app.(componentName);
                    % This loop now only handles components directly on MetadataEditorApp
                    % (e.g., DatasetOverviewTab components like Description, Comments)
                    if isa(uiComponent, 'matlab.ui.control.TextArea') || isa(uiComponent, 'matlab.ui.control.EditField')
                        intermediateDsStruct.(propertyName) = uiComponent.Value;
                    else
                         fprintf('DEBUG (build): Skipping component %s of type %s in main map processing.\n', componentName, class(uiComponent));
                    end
                    fprintf('DEBUG: buildDatasetInformationStructFromApp: Got value for %s from main app component.\n', propertyName);
                else
                    fprintf(2, 'Warning (buildDatasetInformationStructFromApp): Component %s for property %s not found or invalid.\n', componentName, propertyName);
                    intermediateDsStruct = initializeDefaultField(intermediateDsStruct, propertyName);
                end
            catch ME
                fprintf(2, 'Error getting value for %s from component %s: %s\n', propertyName, componentName, ME.message);
                intermediateDsStruct = initializeDefaultField(intermediateDsStruct, propertyName);
            end
        end
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): FieldComponentMap not found on app object.\n');
    end
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Populated from FieldComponentMap.\n');

    % 2. Populate from data management objects and GUI controllers
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Populating from data objects and GUI controllers.\n');
    
    % Authors (from AuthorData object)
    if isprop(app, 'AuthorData') && isobject(app.AuthorData) && ismethod(app.AuthorData, 'toStructs')
        intermediateDsStruct.Author = app.AuthorData.toStructs();
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Got Authors from AuthorData.toStructs().\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.AuthorData not found or "toStructs" method missing.\n');
        intermediateDsStruct.Author = repmat(ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem(), 0, 1);
    end

    % Dataset Details (from DatasetDetailsGUI_Instance)
    if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance)
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Getting data from DatasetDetailsGUI_Instance.\n');
        intermediateDsStruct.ReleaseDate = app.DatasetDetailsGUI_Instance.getReleaseDate();
        intermediateDsStruct.License = app.DatasetDetailsGUI_Instance.getLicense();
        intermediateDsStruct.FullDocumentation = app.DatasetDetailsGUI_Instance.getFullDocumentation();
        intermediateDsStruct.VersionIdentifier = app.DatasetDetailsGUI_Instance.getVersionIdentifier();
        intermediateDsStruct.VersionInnovation = app.DatasetDetailsGUI_Instance.getVersionInnovation();
        intermediateDsStruct.Funding = app.DatasetDetailsGUI_Instance.getFundingInfo();
        intermediateDsStruct.RelatedPublication = app.DatasetDetailsGUI_Instance.getRelatedPublications();
        fprintf('DEBUG: Got data from DatasetDetailsGUI.\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.DatasetDetailsGUI_Instance not found or invalid.\n');
        % Initialize with defaults if GUI is missing
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'ReleaseDate');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'License');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'FullDocumentation');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'VersionIdentifier');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'VersionInnovation');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'Funding');
        intermediateDsStruct = initializeDefaultField(intermediateDsStruct, 'RelatedPublication');
    end
    
    % Experimental Details (from ExperimentalDetailsGUI_Instance)
    if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance)
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Getting data from ExperimentalDetailsGUI_Instance.\n');
        intermediateDsStruct.DataType = app.ExperimentalDetailsGUI_Instance.getDataType();
        intermediateDsStruct.ExperimentalApproach = app.ExperimentalDetailsGUI_Instance.getExperimentalApproach();
        intermediateDsStruct.TechniquesEmployed = app.ExperimentalDetailsGUI_Instance.getSelectedTechniques();
        fprintf('DEBUG: Got data from ExperimentalDetailsGUI.\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.ExperimentalDetailsGUI_Instance not found or invalid.\n');
        intermediateDsStruct.DataType = {}; intermediateDsStruct.ExperimentalApproach = {}; intermediateDsStruct.TechniquesEmployed = {};
    end

    % Subjects (from SubjectData object - SubjectInfoGUI displays this data)
    if isprop(app, 'SubjectData') && isobject(app.SubjectData) && ismethod(app.SubjectData, 'formatTable')
        subjectStructs = app.SubjectData.formatTable(); 
        if isempty(subjectStructs) && iscell(subjectStructs) 
            defaultSpeciesStruct = struct('name','','preferredOntologyIdentifier','','synonym',{{}});
            emptySubjectBase = struct('SubjectName', '', 'BiologicalSexList', {{}}, 'SpeciesList', defaultSpeciesStruct, 'StrainList', {{}});
            intermediateDsStruct.Subjects = repmat(emptySubjectBase,0,1);
        else
            intermediateDsStruct.Subjects = subjectStructs;
        end
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Got Subjects from SubjectData.formatTable().\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.SubjectData not found or "formatTable" method missing.\n');
        defaultSpeciesStruct = struct('name','','preferredOntologyIdentifier','','synonym',{{}});
        emptySubjectBase = struct('SubjectName', '', 'BiologicalSexList', {{}}, 'SpeciesList', defaultSpeciesStruct, 'StrainList', {{}});
        intermediateDsStruct.Subjects = repmat(emptySubjectBase,0,1);
    end

    % Probes (from ProbeData object - ProbeDataGUI displays this data)
    if isprop(app, 'ProbeData') && isobject(app.ProbeData) && ismethod(app.ProbeData, 'formatTable') 
        probeDataFromObject = app.ProbeData.formatTable(); 
        if iscell(probeDataFromObject)
            intermediateDsStruct.Probe = probeDataFromObject;
        elseif isstruct(probeDataFromObject) 
            intermediateDsStruct.Probe = num2cell(probeDataFromObject); 
        else
            intermediateDsStruct.Probe = {}; 
        end
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Got Probes from ProbeData.formatTable().\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.ProbeData not found or "formatTable" method missing.\n');
        intermediateDsStruct.Probe = {};
    end
    
    % Fallback defaults for fields if not set by GUIs (should be redundant if GUIs are robust)
    if ~isfield(intermediateDsStruct, 'VersionIdentifier') || isempty(intermediateDsStruct.VersionIdentifier)
        intermediateDsStruct.VersionIdentifier = '1.0.0';
    end
    if ~isfield(intermediateDsStruct, 'VersionInnovation') || isempty(intermediateDsStruct.VersionInnovation)
         intermediateDsStruct.VersionInnovation = 'This is the first version of the dataset';
    end
    
    expectedFundingFields = {'funder','awardTitle','awardNumber'};
    if ~isfield(intermediateDsStruct, 'Funding') || ~isstruct(intermediateDsStruct.Funding) || (isempty(intermediateDsStruct.Funding) && isempty(fieldnames(intermediateDsStruct.Funding)))
        emptyF = struct(); for k=1:numel(expectedFundingFields), emptyF.(expectedFundingFields{k})=[]; end
        intermediateDsStruct.Funding = repmat(emptyF,0,1);
    end
    expectedPublicationFields = {'title','doi','pmid','pmcid'};
    if ~isfield(intermediateDsStruct, 'RelatedPublication') || ~isstruct(intermediateDsStruct.RelatedPublication) || (isempty(intermediateDsStruct.RelatedPublication) && isempty(fieldnames(intermediateDsStruct.RelatedPublication)))
        emptyP = struct(); for k=1:numel(expectedPublicationFields), emptyP.(expectedPublicationFields{k})=[]; end
        intermediateDsStruct.RelatedPublication = repmat(emptyP,0,1);
    end
    
    fprintf('DEBUG (build): Intermediate struct built. Calling final conversion.\n');
    % disp(intermediateDsStruct);
    finalDsStruct = ndi.database.metadata_ds_core.convertDatasetInfoToStruct(intermediateDsStruct);
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Conversion complete. Final struct ready.\n');
    % disp(finalDsStruct);

    [b,errorStruct] = ndi.util.isAlphaNumericStruct(finalDsStruct);

    if ~b
        errorStruct(1),
        error(['Output structure has cell arrays in it']);
    end;
end

function S_out = initializeDefaultField(S_in, propertyName)
    fprintf('DEBUG (initializeDefaultField): Initializing missing/error field: %s\n', propertyName);
    if contains(propertyName, {'Tree', 'Approach', 'Type', 'Employed'}, 'IgnoreCase', true)
        S_in.(propertyName) = {}; 
    elseif contains(propertyName, 'Date', 'IgnoreCase', true)
        S_in.(propertyName) = NaT; 
    elseif contains(propertyName, {'Funding', 'Publication'}, 'IgnoreCase', true) 
        S_in.(propertyName) = struct([]); 
    else
        S_in.(propertyName) = ''; 
    end
    S_out = S_in;
end
