function populateAppFromDatasetInformationStruct(app, dsStruct)
%POPULATEAPPFROMDATASETINFORMATIONSTRUCT Populates app's data objects and UI from a plain struct.
%   POPULATEAPPFROMDATASETINFORMATIONSTRUCT(app, dsStruct)
%   app: Handle to the MetadataEditorApp instance.
%   dsStruct: The validated plain datasetInformationStruct.

    fprintf('DEBUG (populateApp): Starting population from dsStruct.\n');
    % Ensure dsStruct is a scalar struct and validated
    if ~isstruct(dsStruct) || ~isscalar(dsStruct)
        warning('populateAppFromDatasetInformationStruct:InvalidInput', 'Input dsStruct must be a scalar structure. Using empty defaults.');
        dsStruct = ndi.database.metadata_app.fun.validateDatasetInformation(struct(), app); 
    end
    % disp(dsStruct);

    % 1. Populate simple UI components via FieldComponentMap
    if isprop(app, 'FieldComponentMap') && isstruct(app.FieldComponentMap)
        propertyNamesFromMap = fieldnames(app.FieldComponentMap);
        for i = 1:numel(propertyNamesFromMap)
            propertyName = propertyNamesFromMap{i};
            componentName = app.FieldComponentMap.(propertyName);
            
            fprintf('DEBUG (populateApp): Processing mapped UI field: %s, component: %s\n', propertyName, componentName);
            if isfield(dsStruct, propertyName)
                propertyValue = dsStruct.(propertyName);
                try
                    if isprop(app, componentName) && isvalid(app.(componentName))
                        uiComponent = app.(componentName);
                        if isa(uiComponent, 'matlab.ui.container.CheckBoxTree') % Should not be hit if trees moved to sub-GUIs
                            app.setCheckedNodesFromData(uiComponent, propertyValue);
                        elseif isa(uiComponent, 'matlab.ui.control.ListBox') % e.g. TechniquesEmployed (if it were still here)
                            if iscellstr(propertyValue) || isstring(propertyValue) || isempty(propertyValue) %#ok<ISCLSTR>
                                uiComponent.Items = propertyValue;
                                if ~isempty(propertyValue) && iscell(propertyValue) 
                                    uiComponent.Value = propertyValue{1};
                                else
                                    uiComponent.Value = {};
                                end
                            else
                                 uiComponent.Items = {}; 
                                 uiComponent.Value = {};
                            end
                        elseif isa(uiComponent, 'matlab.ui.control.Table')
                            if isstruct(propertyValue) || isempty(propertyValue)
                                if ~isempty(propertyValue) && isstruct(propertyValue) && ~isvector(propertyValue)
                                    fprintf(2, 'Warning: Table data for "%s" was not a vector struct. Attempting to linearize.\n', propertyName);
                                    try
                                        propertyValue = propertyValue(:);
                                    catch ME_linearize
                                        fprintf(2, 'Error linearizing table data for "%s": %s. Setting to empty table.\n', propertyName, ME_linearize.message);
                                        if ~isempty(propertyValue) && isstruct(propertyValue) && numel(propertyValue)>0 
                                             propertyValue = repmat(propertyValue(1),0,1); 
                                             for f = fieldnames(propertyValue)', propertyValue.(f{1})=[]; end 
                                        else
                                            propertyValue = struct(); 
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
                                uiComponent.Value = NaT; 
                            else
                                uiComponent.Value = propertyValue; 
                            end
                        else 
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
                            uiComponent.Value = NaT; 
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
    fprintf('DEBUG (populateApp): Finished populating from FieldComponentMap.\n');

    % 2. Populate app.AuthorData and draw related UI
    if isprop(app, 'AuthorDataGUI_Instance') && isvalid(app.AuthorDataGUI_Instance)
        if isfield(dsStruct, 'Author')
            app.AuthorData.fromStructs(dsStruct.Author); 
        else 
            app.AuthorData.ClearAll(); 
        end
        if isempty(app.AuthorData.AuthorList) 
            app.AuthorData.addDefaultAuthorEntry();
        end
        app.AuthorDataGUI_Instance.drawAuthorData(); 
        fprintf('DEBUG (populateApp): AuthorData and GUI updated.\n');
    else
        fprintf(2, 'Warning (populateApp): app.AuthorDataGUI_Instance not found or invalid.\n');
    end

    % 3. Populate app.SubjectData and its UI Table
    if isprop(app, 'SubjectData') && isprop(app,'UITableSubject') && isvalid(app.UITableSubject)
        if isfield(dsStruct, 'Subjects')
            % This assumes dsStruct.Subjects is an array of plain structs.
            % app.SubjectData needs a fromStructs or similar method.
            % For now, directly assign to SubjectList if it's compatible, or convert.
            if ismethod(app.SubjectData, 'fromStructs')
                 app.SubjectData.fromStructs(dsStruct.Subjects);
            else % Manual conversion loop if fromStructs is not available
                app.SubjectData.SubjectList = ndi.database.metadata_app.class.Subject.empty(0,1);
                if isstruct(dsStruct.Subjects)
                    for k_sub = 1:numel(dsStruct.Subjects)
                        try
                            subObj = ndi.database.metadata_app.class.Subject.fromStruct(dsStruct.Subjects(k_sub));
                            app.SubjectData.SubjectList(end+1) = subObj;
                        catch ME_sub_create
                             fprintf(2, 'Error creating Subject object from struct: %s\n', ME_sub_create.message);
                        end
                    end
                end
            end
        else
            app.SubjectData.clearAllSubjects();
        end
        
        % Update Subject UI Table
        subjectTableDataForUI = app.SubjectData.formatTable(); 
        if ~isempty(subjectTableDataForUI) || (isstruct(subjectTableDataForUI) && numel(subjectTableDataForUI)==0)
            app.UITableSubject.Data = struct2table(subjectTableDataForUI, 'AsArray', true);
        else
            app.UITableSubject.Data = table(); 
        end
        fprintf('DEBUG (populateApp): SubjectData and UI table updated.\n');
    else
         fprintf(2, 'Warning (populateApp): app.SubjectData or app.UITableSubject not found/invalid.\n');
    end

    % 4. Populate app.ProbeData and its UI Table (via ProbeDataGUI)
    if isprop(app, 'ProbeDataGUI_Instance') && isvalid(app.ProbeDataGUI_Instance)
        if isfield(dsStruct, 'Probe')
            % This assumes dsStruct.Probe is a cell array of structs/objects
            % app.ProbeData needs a fromStructs or similar method.
            if ismethod(app.ProbeData, 'fromStructs') % Ideal
                app.ProbeData.fromStructs(dsStruct.Probe);
            else % Manual conversion if fromStructs is not available
                app.ProbeData.clearAllProbes(); % Or app.ProbeData.ProbeList = {};
                if iscell(dsStruct.Probe)
                    for k_probe = 1:numel(dsStruct.Probe)
                        try
                            probeEntry = app.createProbeObjectFromStruct(dsStruct.Probe{k_probe});
                            if ~isempty(probeEntry)
                                app.ProbeData.addProbe(probeEntry); % Assuming addProbe exists
                            end
                        catch ME_probe_create
                            fprintf(2, 'Error creating Probe object from struct: %s\n', ME_probe_create.message);
                        end
                    end
                end
            end
        else
            app.ProbeData.clearAllProbes();
        end
        app.ProbeDataGUI_Instance.drawProbeData();
        fprintf('DEBUG (populateApp): ProbeData and GUI updated via ProbeDataGUI_Instance.\n');
    else
        fprintf(2, 'Warning (populateApp): app.ProbeDataGUI_Instance not found or invalid.\n');
    end
    
    % 5. Populate ExperimentalDetailsGUI
    if isprop(app, 'ExperimentalDetailsGUI_Instance') && isvalid(app.ExperimentalDetailsGUI_Instance)
        fprintf('DEBUG (populateApp): Populating ExperimentalDetailsGUI.\n');
        % Pass the relevant parts of dsStruct to ExperimentalDetailsGUI
        % The GUI's drawExperimentalDetails or individual setters will handle UI updates.
        
        % DataType
        if isfield(dsStruct, 'DataType')
            app.ExperimentalDetailsGUI_Instance.setDataType(dsStruct.DataType);
        else
            app.ExperimentalDetailsGUI_Instance.setDataType({}); % Default to empty
        end

        % ExperimentalApproach
        if isfield(dsStruct, 'ExperimentalApproach')
            app.ExperimentalDetailsGUI_Instance.setExperimentalApproach(dsStruct.ExperimentalApproach);
        else
            app.ExperimentalDetailsGUI_Instance.setExperimentalApproach({}); % Default to empty
        end
        
        % TechniquesEmployed
        if isfield(dsStruct, 'TechniquesEmployed')
            % setSelectedTechniques in GUI should handle converting IDs to display strings if needed
            app.ExperimentalDetailsGUI_Instance.setSelectedTechniques(dsStruct.TechniquesEmployed);
        else
            app.ExperimentalDetailsGUI_Instance.setSelectedTechniques({}); % Default to empty
        end
        
        % After setting data, explicitly tell the GUI to refresh its display elements
        app.ExperimentalDetailsGUI_Instance.drawExperimentalDetails();
        fprintf('DEBUG (populateApp): ExperimentalDetailsGUI data set and UI drawn.\n');
    else
        fprintf(2, 'Warning (populateApp): app.ExperimentalDetailsGUI_Instance not found or invalid.\n');
    end

    fprintf('DEBUG (populateApp): populateAppFromDatasetInformationStruct completed.\n');
end
