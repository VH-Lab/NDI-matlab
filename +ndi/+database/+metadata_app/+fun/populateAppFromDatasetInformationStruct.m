function populateAppFromDatasetInformationStruct(app, dsStruct)
%POPULATEAPPFROMDATASETINFORMATIONSTRUCT Populates app's data objects and UI from a plain struct.
%   POPULATEAPPFROMDATASETINFORMATIONSTRUCT(app, dsStruct)
%   app: Handle to the MetadataEditorApp instance.
%   dsStruct: The validated plain datasetInformationStruct.

    % Ensure dsStruct is a scalar struct and validated
    if ~isstruct(dsStruct) || ~isscalar(dsStruct)
        warning('populateAppFromDatasetInformationStruct:InvalidInput', 'Input dsStruct must be a scalar structure. Using empty defaults.');
        % Get a default empty one, passing app for context if validator uses it
        dsStruct = ndi.database.metadata_app.fun.validateDatasetInformation(struct(), app); 
    end

    % 1. Populate simple UI components via FieldComponentMap
    %    (These are components directly on MetadataEditorApp)
    if isprop(app, 'FieldComponentMap') && isstruct(app.FieldComponentMap)
        propertyNamesFromMap = fieldnames(app.FieldComponentMap);
        for i = 1:numel(propertyNamesFromMap)
            propertyName = propertyNamesFromMap{i};
            componentName = app.FieldComponentMap.(propertyName);
            
            if isfield(dsStruct, propertyName)
                propertyValue = dsStruct.(propertyName);
                try
                    if isprop(app, componentName) && isvalid(app.(componentName))
                        uiComponent = app.(componentName);
                        if isa(uiComponent, 'matlab.ui.container.CheckBoxTree')
                            app.setCheckedNodesFromData(uiComponent, propertyValue);
                        elseif isa(uiComponent, 'matlab.ui.control.ListBox') % e.g. TechniquesEmployed
                            if iscellstr(propertyValue) || isstring(propertyValue) || isempty(propertyValue) %#ok<ISCLSTR>
                                uiComponent.Items = propertyValue;
                                if ~isempty(propertyValue) && iscell(propertyValue) % Select first item if list is not empty
                                    uiComponent.Value = propertyValue{1};
                                else
                                    uiComponent.Value = {};
                                end
                            else
                                 uiComponent.Items = {}; 
                                 uiComponent.Value = {};
                            end
                        elseif isa(uiComponent, 'matlab.ui.control.Table')
                            % Funding and RelatedPublication tables
                            if isstruct(propertyValue) || isempty(propertyValue)
                                if ~isempty(propertyValue) && isstruct(propertyValue) && ~isvector(propertyValue)
                                    fprintf(2, 'Warning: Table data for "%s" was not a vector struct. Attempting to linearize.\n', propertyName);
                                    try
                                        propertyValue = propertyValue(:);
                                    catch ME_linearize
                                        fprintf(2, 'Error linearizing table data for "%s": %s. Setting to empty table.\n', propertyName, ME_linearize.message);
                                        if ~isempty(propertyValue) && isstruct(propertyValue) && numel(propertyValue)>0 % Check if propertyValue(1) exists
                                             propertyValue = repmat(propertyValue(1),0,1); 
                                             for f = fieldnames(propertyValue)', propertyValue.(f{1})=[]; end % Clear fields of the template
                                        else
                                            propertyValue = struct(); % Fallback to completely empty struct
                                        end
                                    end
                                end
                                if isempty(propertyValue) && isstruct(propertyValue) && isempty(fieldnames(propertyValue))
                                     uiComponent.Data = table();
                                elseif isstruct(propertyValue) && numel(propertyValue)==0 && ~isempty(fieldnames(propertyValue))
                                    uiComponent.Data = struct2table(propertyValue, 'AsArray', true);
                                elseif ~isempty(propertyValue)
                                    uiComponent.Data = struct2table(propertyValue, 'AsArray', true);
                                else
                                    uiComponent.Data = table(); 
                                end
                            else
                                uiComponent.Data = table(); 
                            end
                        elseif isa(uiComponent, 'matlab.ui.control.DatePicker')
                            if isempty(propertyValue) || (isdatetime(propertyValue) && isnat(propertyValue))
                                uiComponent.Value = NaT; % Use NaT for empty/unselected date
                            else
                                uiComponent.Value = propertyValue; % Assumes propertyValue is datetime
                            end
                        else % EditFields, TextAreas, DropDowns
                            uiComponent.Value = propertyValue;
                        end
                    else
                         fprintf(2, 'Warning (populateApp): Component %s for property %s not found on app.\n', componentName, propertyName);
                    end
                catch ME
                    fprintf(2, 'Error setting UI component %s for property %s: %s\n', componentName, propertyName, ME.message);
                    fprintf(2, 'Stack trace for component update error:\n%s\n', ME.getReport('extended', 'hyperlinks', 'off'));
                end
            else
                % If field is missing in dsStruct, set UI component to default/empty
                % validateDatasetInformation should ensure dsStruct has all fields.
                try
                    if isprop(app, componentName) && isvalid(app.(componentName))
                        uiComponent = app.(componentName);
                         if isa(uiComponent, 'matlab.ui.container.CheckBoxTree')
                            app.setCheckedNodesFromData(uiComponent, '');
                        elseif isa(uiComponent, 'matlab.ui.control.ListBox')
                            uiComponent.Items = {};
                            uiComponent.Value = {};
                        elseif isa(uiComponent, 'matlab.ui.control.Table')
                            uiComponent.Data = table();
                        elseif isa(uiComponent, 'matlab.ui.control.DatePicker')
                            uiComponent.Value = NaT; % Use NaT for empty date
                        else 
                            uiComponent.Value = ''; 
                        end
                    end
                catch ME_default
                     fprintf(2, 'Error defaulting UI component %s for missing property %s: %s\n', componentName, propertyName, ME_default.message);
                end
            end
        end
    end

    % 2. Populate app.AuthorData and draw related UI
    if isprop(app, 'AuthorData') && isprop(app, 'AuthorDataGUI_Instance') && isa(app.AuthorDataGUI_Instance, 'ndi.database.metadata_app.class.AuthorDataGUI')
        if isfield(dsStruct, 'Author')
            app.AuthorData.fromStructs(dsStruct.Author); 
        else 
            app.AuthorData.ClearAll(); 
        end
        
        if isempty(app.AuthorData.AuthorList) 
            if ismethod(app.AuthorData, 'addDefaultAuthorEntry')
                app.AuthorData.addDefaultAuthorEntry();
            else
                app.AuthorData.AuthorList = ndi.database.metadata_app.class.AuthorData.getDefaultAuthorItem();
            end
        end
        
        app.AuthorDataGUI_Instance.drawAuthorData(); 
    else
        fprintf(2, 'Warning (populateApp): app.AuthorData or app.AuthorDataGUI_Instance not found or invalid.\n');
    end

    % 3. Populate app.SubjectData and its UI Table
    if isprop(app, 'SubjectData') && isfield(dsStruct, 'Subjects')
        if ismethod(app.SubjectData, 'ClearAll') 
            app.SubjectData.ClearAll();
        elseif ismethod(app.SubjectData, 'clearAllSubjects') 
            app.SubjectData.clearAllSubjects();
        else 
            app.SubjectData.SubjectList = ndi.database.metadata_app.class.Subject.empty(0,1);
        end
        
        subjectsFromStorage_structArray = dsStruct.Subjects;
        finalSubjectList_objectArray = ndi.database.metadata_app.class.Subject.empty(0,1);
        
        subjectsFromNdiEntity_objectArray = [];
        if ~isempty(app.Dataset) && isprop(app.SubjectData, 'SubjectList')
            if ismethod(app.SubjectData,'getSubjectListCopy') 
                 subjectsFromNdiEntity_objectArray = app.SubjectData.getSubjectListCopy(); 
            else
                 subjectsFromNdiEntity_objectArray = app.SubjectData.SubjectList; 
            end
        end
        
        processedSubjectNames = {};

        if ~isempty(subjectsFromStorage_structArray)
            for i = 1:numel(subjectsFromStorage_structArray)
                storedSubStruct = subjectsFromStorage_structArray(i);
                newSubObj = ndi.database.metadata_app.class.Subject(); 
                try
                    if isfield(storedSubStruct, 'SubjectName'), newSubObj.SubjectName = char(storedSubStruct.SubjectName); end
                    if isfield(storedSubStruct, 'BiologicalSexList'), newSubObj.BiologicalSexList = cellstr(storedSubStruct.BiologicalSexList); end
                    
                    % ** CORRECTED SPECIES HANDLING **
                    if isfield(storedSubStruct, 'SpeciesList') && isstruct(storedSubStruct.SpeciesList) && isfield(storedSubStruct.SpeciesList, 'name')
                        % Create an instance of your custom Species class
                        customSpeciesObj = ndi.database.metadata_app.class.Species(); % Assuming this class exists
                        
                        % Populate your Species object from the struct
                        % This assumes your Species class has 'Name' and 'PreferredOntologyIdentifier' properties
                        % or a fromStruct method.
                        if ismethod(customSpeciesObj, 'fromStruct')
                             customSpeciesObj.fromStruct(storedSubStruct.SpeciesList);
                        else % Manual population
                            customSpeciesObj.Name = char(storedSubStruct.SpeciesList.name);
                            if isfield(storedSubStruct.SpeciesList, 'preferredOntologyIdentifier')
                                customSpeciesObj.PreferredOntologyIdentifier = char(storedSubStruct.SpeciesList.preferredOntologyIdentifier);
                            end
                            % Add other relevant fields from storedSubStruct.SpeciesList to customSpeciesObj if they exist in your class
                        end
                        newSubObj.SpeciesList = customSpeciesObj; % Assign your custom Species object
                    else
                        % Assign an empty instance of your custom Species class, or handle as appropriate
                        % This depends on how your Subject class defines an "empty" SpeciesList.
                        % If it can take an empty array of your custom species type:
                        newSubObj.SpeciesList = ndi.database.metadata_app.class.Species.empty(0,1); 
                    end
                    
                    if isfield(storedSubStruct, 'StrainList'), newSubObj.StrainList = cellstr(storedSubStruct.StrainList); end
                    
                    finalSubjectList_objectArray = [finalSubjectList_objectArray, newSubObj]; %#ok<AGROW>
                    if isprop(newSubObj,'SubjectName'), processedSubjectNames{end+1} = newSubObj.SubjectName; end %#ok<AGROW>
                catch ME_subj
                    fprintf(2, 'Error converting subject struct to object at index %d: %s\n', i, ME_subj.message);
                end
            end
        end

        if ~isempty(subjectsFromNdiEntity_objectArray)
            for i = 1:numel(subjectsFromNdiEntity_objectArray)
                entitySubObj = subjectsFromNdiEntity_objectArray(i);
                 if isa(entitySubObj, 'ndi.database.metadata_app.class.Subject') && ...
                   isprop(entitySubObj, 'SubjectName') && ~ismember(entitySubObj.SubjectName, processedSubjectNames)
                    finalSubjectList_objectArray = [finalSubjectList_objectArray, entitySubObj]; %#ok<AGROW>
                end
            end
        end
        try
            app.SubjectData.SubjectList = finalSubjectList_objectArray;
        catch ME_subj_assign
             fprintf(2, 'Error assigning to app.SubjectData.SubjectList: %s\n', ME_subj_assign.message);
        end
        
        subjectTableUITableData = [];
        if ismethod(app.SubjectData, 'formatTable')
            subjectTableUITableData = app.SubjectData.formatTable(); 
        end
        if ~isempty(subjectTableUITableData) || (isstruct(subjectTableUITableData) && numel(subjectTableUITableData)==0)
            app.UITableSubject.Data = struct2table(subjectTableUITableData, 'AsArray', true);
        else
            app.UITableSubject.Data = table(); 
        end
    end


    % 4. Populate app.ProbeData and its UI Table
    if isprop(app, 'ProbeData') && isfield(dsStruct, 'Probe')
        if ismethod(app.ProbeData, 'ClearAll') 
            app.ProbeData.ClearAll();
        elseif ismethod(app.ProbeData, 'clearAllProbes') 
            app.ProbeData.clearAllProbes();
        else 
            app.ProbeData.ProbeList = {}; 
        end
        
        probesFromStorage_structCell = dsStruct.Probe; 

        initialProbesFromEntity_objectCell = {};
        if ~isempty(app.Dataset) && isprop(app.ProbeData,'ProbeList') && iscell(app.ProbeData.ProbeList)
             if ismethod(app.ProbeData, 'getProbeListCopy')
                initialProbesFromEntity_objectCell = app.ProbeData.getProbeListCopy();
             else
                initialProbesFromEntity_objectCell = app.ProbeData.ProbeList; 
             end
        end

        finalProbeList_Cell = {}; 
        processedProbeNames = {};

        if ~isempty(probesFromStorage_structCell)
            for i = 1:numel(probesFromStorage_structCell)
                storedProbeStruct = probesFromStorage_structCell{i};
                probeEntry = []; 
                if isfield(storedProbeStruct,'Name') && isfield(storedProbeStruct,'ClassType')
                    if ismethod(app, 'createProbeObjectFromStruct') 
                         probeEntry = app.createProbeObjectFromStruct(storedProbeStruct);
                    else
                         fprintf(2, 'DEBUG populateApp: createProbeObjectFromStruct method missing in app. Storing Probe as struct.\n');
                         probeEntry = storedProbeStruct; 
                    end
                end
                
                if ~isempty(probeEntry)
                    finalProbeList_Cell{end+1} = probeEntry; %#ok<AGROW>
                    if isstruct(probeEntry) && isfield(probeEntry,'Name')
                         processedProbeNames{end+1} = probeEntry.Name; %#ok<AGROW>
                    elseif isobject(probeEntry) && isprop(probeEntry,'Name')
                         processedProbeNames{end+1} = probeEntry.Name; %#ok<AGROW>
                    end
                end
            end
        end
        
        if ~isempty(initialProbesFromEntity_objectCell)
            for i = 1:numel(initialProbesFromEntity_objectCell)
                entityProbeEntry = initialProbesFromEntity_objectCell{i};
                isNameProp = false; entityName = '';
                if isobject(entityProbeEntry) && isprop(entityProbeEntry,'Name')
                    isNameProp = true;
                    entityName = entityProbeEntry.Name;
                elseif isstruct(entityProbeEntry) && isfield(entityProbeEntry,'Name')
                    isNameProp = true;
                    entityName = entityProbeEntry.Name;
                end

                if isNameProp && ~ismember(entityName, processedProbeNames)
                    finalProbeList_Cell{end+1} = entityProbeEntry; %#ok<AGROW>
                end
            end
        end
        try
            app.ProbeData.ProbeList = finalProbeList_Cell;
        catch ME_probe_assign
            fprintf(2, 'Error assigning to app.ProbeData.ProbeList: %s\n', ME_probe_assign.message);
        end
        
        probeTableData = [];
        if isprop(app, 'ProbeData') && ismethod(app.ProbeData, 'formatTable')
           probeTableData = app.ProbeData.formatTable();
        end

        app.ProbeDataGUI_Instance.drawProbeData();
        
    end

    fprintf('DEBUG: populateAppFromDatasetInformationStruct completed.\n');
end
