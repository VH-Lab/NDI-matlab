function finalDsStruct = buildDatasetInformationStructFromApp(app)
%BUILDDATASETINFORMATIONSTRUCTFROMAPP Creates an NDI document-compatible struct from app's current state.
%   finalDsStruct = BUILDDATASETINFORMATIONSTRUCTFROMAPP(app)
%   app: Handle to the MetadataEditorApp instance.
%
%   This function gathers data from the UI components (for fields directly
%   managed by MetadataEditorApp) and from the app's data management objects
%   (AuthorData, SubjectData, ProbeData, ExperimentalDetailsGUI) to construct
%   an intermediate plain struct. This intermediate struct is then passed to
%   ndi.database.metadata_ds_core.convertDatasetInfoToStruct to perform
%   final conversions (e.g., cell arrays to comma-separated strings,
%   datetime to ISO strings), making the output `finalDsStruct` suitable for
%   creating an ndi.document of type 'ndi.metadata.metadata_editor'.

    fprintf('DEBUG: buildDatasetInformationStructFromApp: Starting to build intermediate struct.\n');
    
    intermediateDsStruct = struct();

    % 1. Populate from simple UI components mapped in FieldComponentMap
    %    (This will skip fields now managed by sub-GUIs if FieldComponentMap is updated)
    if isprop(app, 'FieldComponentMap') && isstruct(app.FieldComponentMap)
        propertyNamesFromMap = fieldnames(app.FieldComponentMap);
        for i = 1:numel(propertyNamesFromMap)
            propertyName = propertyNamesFromMap{i};
            componentName = app.FieldComponentMap.(propertyName);
            
            fprintf('DEBUG: buildDatasetInformationStructFromApp: Processing map field: %s, component: %s\n', propertyName, componentName);

            try
                if isprop(app, componentName) && isvalid(app.(componentName))
                    uiComponent = app.(componentName);
                    if isa(uiComponent, 'matlab.ui.container.CheckBoxTree')
                        intermediateDsStruct.(propertyName) = app.getCheckedTreeNodeData(uiComponent.CheckedNodes);
                    elseif isa(uiComponent, 'matlab.ui.control.ListBox') 
                        intermediateDsStruct.(propertyName) = uiComponent.Items; 
                    elseif isa(uiComponent, 'matlab.ui.control.Table')
                        if ~isempty(uiComponent.Data)
                            intermediateDsStruct.(propertyName) = table2struct(uiComponent.Data);
                        else
                            switch propertyName 
                                case 'Funding'
                                    intermediateDsStruct.Funding = repmat(struct('funder','','awardTitle','','awardNumber',''),0,1);
                                case 'RelatedPublication'
                                    intermediateDsStruct.RelatedPublication = repmat(struct('title','','doi','','pmid','','pmcid',''),0,1);
                                otherwise
                                    intermediateDsStruct.(propertyName) = struct([]);
                            end
                        end
                    else 
                        intermediateDsStruct.(propertyName) = uiComponent.Value;
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
    % disp(intermediateDsStruct);


    % 2. Populate from data management objects and GUI controllers
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Populating from data objects and GUI controllers.\n');
    
    % Authors (from AuthorData object via AuthorDataGUI if needed, or directly from AuthorData)
    if isprop(app, 'AuthorData') && isobject(app.AuthorData) && ismethod(app.AuthorData, 'toStructs')
        intermediateDsStruct.Author = app.AuthorData.toStructs();
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Got Authors from AuthorData.toStructs().\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.AuthorData not found or "toStructs" method missing. Author data will be empty struct array.\n');
        emptyAuthorBase = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
        intermediateDsStruct.Author = repmat(emptyAuthorBase, 0, 1);
    end

    % Subjects (from SubjectData object)
    if isprop(app, 'SubjectData') && isobject(app.SubjectData) && ismethod(app.SubjectData, 'formatTable') % or toStructs if implemented
        subjectStructs = app.SubjectData.formatTable(); % This should return plain structs
        if isempty(subjectStructs) && iscell(subjectStructs) % formatTable might return {} for empty
            defaultSpeciesStruct = struct('name','','preferredOntologyIdentifier','','synonym',{{}});
            emptySubjectBase = struct('SubjectName', '', 'BiologicalSexList', {{}}, 'SpeciesList', defaultSpeciesStruct, 'StrainList', {{}});
            intermediateDsStruct.Subjects = repmat(emptySubjectBase,0,1);
        else
            intermediateDsStruct.Subjects = subjectStructs;
        end
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Got Subjects from SubjectData.formatTable().\n');
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.SubjectData not found or "formatTable" method missing. Subjects data will be empty struct array.\n');
        defaultSpeciesStruct = struct('name','','preferredOntologyIdentifier','','synonym',{{}});
        emptySubjectBase = struct('SubjectName', '', 'BiologicalSexList', {{}}, 'SpeciesList', defaultSpeciesStruct, 'StrainList', {{}});
        intermediateDsStruct.Subjects = repmat(emptySubjectBase,0,1);
    end

    % Probes (from ProbeData object via ProbeDataGUI if needed, or directly from ProbeData)
    if isprop(app, 'ProbeData') && isobject(app.ProbeData) && ismethod(app.ProbeData, 'formatTable') % or toStructs
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
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.ProbeData not found or "formatTable" method missing. Probe data will be empty cell array.\n');
        intermediateDsStruct.Probe = {};
    end

    % Experimental Details (from ExperimentalDetailsGUI_Instance)
    if isprop(app, 'ExperimentalDetailsGUI_Instance') && isvalid(app.ExperimentalDetailsGUI_Instance)
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Getting data from ExperimentalDetailsGUI_Instance.\n');
        if ismethod(app.ExperimentalDetailsGUI_Instance, 'getDataType')
            intermediateDsStruct.DataType = app.ExperimentalDetailsGUI_Instance.getDataType();
            fprintf('DEBUG: Got DataType from ExperimentalDetailsGUI.\n');
        else
            fprintf(2, 'Warning: ExperimentalDetailsGUI_Instance missing getDataType method.\n');
            intermediateDsStruct.DataType = {};
        end

        if ismethod(app.ExperimentalDetailsGUI_Instance, 'getExperimentalApproach')
            intermediateDsStruct.ExperimentalApproach = app.ExperimentalDetailsGUI_Instance.getExperimentalApproach();
            fprintf('DEBUG: Got ExperimentalApproach from ExperimentalDetailsGUI.\n');
        else
            fprintf(2, 'Warning: ExperimentalDetailsGUI_Instance missing getExperimentalApproach method.\n');
            intermediateDsStruct.ExperimentalApproach = {};
        end

        if ismethod(app.ExperimentalDetailsGUI_Instance, 'getSelectedTechniques')
            intermediateDsStruct.TechniquesEmployed = app.ExperimentalDetailsGUI_Instance.getSelectedTechniques();
            fprintf('DEBUG: Got TechniquesEmployed from ExperimentalDetailsGUI.\n');
        else
            fprintf(2, 'Warning: ExperimentalDetailsGUI_Instance missing getSelectedTechniques method.\n');
            intermediateDsStruct.TechniquesEmployed = {};
        end
    else
        fprintf(2, 'Warning (buildDatasetInformationStructFromApp): app.ExperimentalDetailsGUI_Instance not found or invalid.\n');
        intermediateDsStruct.DataType = {};
        intermediateDsStruct.ExperimentalApproach = {};
        intermediateDsStruct.TechniquesEmployed = {};
    end
    % disp(intermediateDsStruct);
    
    % Ensure specific defaults for fields not directly from UI map, if they weren't set
    if ~isfield(intermediateDsStruct, 'VersionIdentifier') || isempty(intermediateDsStruct.VersionIdentifier)
        if isprop(app, 'VersionIdentifierEditField') && isvalid(app.VersionIdentifierEditField)
            intermediateDsStruct.VersionIdentifier = app.VersionIdentifierEditField.Value;
        else
            intermediateDsStruct.VersionIdentifier = '1.0.0';
        end
    end
    if ~isfield(intermediateDsStruct, 'VersionInnovation') || isempty(intermediateDsStruct.VersionInnovation)
         if isprop(app, 'VersionInnovationEditField') && isvalid(app.VersionInnovationEditField)
            intermediateDsStruct.VersionInnovation = app.VersionInnovationEditField.Value;
         else
            intermediateDsStruct.VersionInnovation = 'This is the first version of the dataset';
         end
    end
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Ensured fallback defaults for Version fields.\n');

    expectedFundingFields = {'funder','awardTitle','awardNumber'};
    if ~isfield(intermediateDsStruct, 'Funding') || ~isstruct(intermediateDsStruct.Funding) || (isempty(intermediateDsStruct.Funding) && isempty(fieldnames(intermediateDsStruct.Funding)))
        emptyF = struct(); 
        for k=1:numel(expectedFundingFields), emptyF.(expectedFundingFields{k})=[]; end
        intermediateDsStruct.Funding = repmat(emptyF,0,1);
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Initialized empty Funding field.\n');
    end
    expectedPublicationFields = {'title','doi','pmid','pmcid'};
    if ~isfield(intermediateDsStruct, 'RelatedPublication') || ~isstruct(intermediateDsStruct.RelatedPublication) || (isempty(intermediateDsStruct.RelatedPublication) && isempty(fieldnames(intermediateDsStruct.RelatedPublication)))
        emptyP = struct();
        for k=1:numel(expectedPublicationFields), emptyP.(expectedPublicationFields{k})=[]; end
        intermediateDsStruct.RelatedPublication = repmat(emptyP,0,1);
        fprintf('DEBUG: buildDatasetInformationStructFromApp: Initialized empty RelatedPublication field.\n');
    end
    % disp(intermediateDsStruct);

    % --- Final Conversion Step ---
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Calling ndi.database.metadata_ds_core.convertDatasetInfoToStruct.\n');
    % disp(intermediateDsStruct); % Display struct before final conversion
    finalDsStruct = ndi.database.metadata_ds_core.convertDatasetInfoToStruct(intermediateDsStruct);
    fprintf('DEBUG: buildDatasetInformationStructFromApp: Conversion complete. Final struct ready.\n');
    % disp(finalDsStruct);

end

function S_out = initializeDefaultField(S_in, propertyName)
    % Helper to initialize a field with a sensible empty default
    fprintf('DEBUG (initializeDefaultField): Initializing missing/error field: %s\n', propertyName);
    if contains(propertyName, {'Tree', 'Approach', 'Type', 'Employed'}, 'IgnoreCase', true)
        S_in.(propertyName) = {}; % Cell for list-like or tree data
    elseif contains(propertyName, 'Date', 'IgnoreCase', true)
        S_in.(propertyName) = NaT; % Use NaT for DatePicker
    elseif contains(propertyName, {'Funding', 'Publication'}, 'IgnoreCase', true) % For table data
        S_in.(propertyName) = struct([]); % Empty struct array for tables
    else
        S_in.(propertyName) = ''; % Default for edit fields, dropdowns
    end
    S_out = S_in;
end
