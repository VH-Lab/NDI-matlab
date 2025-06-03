function populateAppFromDatasetInformationStruct(app, dsStruct)
%POPULATEAPPFROMDATASETINFORMATIONSTRUCT Populates app's data objects and UI from a plain struct.
%   POPULATEAPPFROMDATASETINFORMATIONSTRUCT(app, dsStruct)
%   app: Handle to the MetadataEditorApp instance.
%   dsStruct: The validated plain datasetInformationStruct. This struct is
%             expected to be app.DatasetInformationStruct after validation.

    fprintf('DEBUG (populateApp): Starting population from dsStruct.\n');
    if ~isstruct(dsStruct) || ~isscalar(dsStruct)
        warning('populateAppFromDatasetInformationStruct:InvalidInput', 'Input dsStruct must be a scalar structure. Using empty defaults.');
        dsStruct = ndi.database.metadata_app.fun.validateDatasetInformation(struct(), app); 
    end
    % At this point, dsStruct is assumed to be the validated app.DatasetInformationStruct

    % 1. Populate simple UI components still directly managed by MetadataEditorApp via FieldComponentMap
    %    (e.g., DatasetOverviewTab components)
    if isprop(app, 'FieldComponentMap') && isstruct(app.FieldComponentMap)
        propertyNamesFromMap = fieldnames(app.FieldComponentMap);
        for i = 1:numel(propertyNamesFromMap)
            propertyName = propertyNamesFromMap{i};
            componentName = app.FieldComponentMap.(propertyName);
            
            fprintf('DEBUG (populateApp): Processing main app mapped UI field: %s, component: %s\n', propertyName, componentName);
            if isfield(dsStruct, propertyName)
                propertyValue = dsStruct.(propertyName);
                try
                    if isprop(app, componentName) && isvalid(app.(componentName))
                        uiComponent = app.(componentName);
                        % Only handle components that are NOT tables or trees here,
                        % as those are now managed by sub-GUIs or need special handling.
                        if isa(uiComponent, 'matlab.ui.control.DatePicker') 
                            if isempty(propertyValue) || (isdatetime(propertyValue) && isnat(propertyValue))
                                uiComponent.Value = NaT; 
                            else
                                uiComponent.Value = propertyValue; 
                            end
                        elseif isa(uiComponent, 'matlab.ui.control.TextArea') || isa(uiComponent, 'matlab.ui.control.EditField') || isa(uiComponent, 'matlab.ui.control.DropDown')
                            uiComponent.Value = propertyValue;
                        else
                             fprintf('DEBUG (populateApp): Skipping component %s of type %s in main map population.\n', componentName, class(uiComponent));
                        end
                    else
                         fprintf(2, 'Warning (populateApp): Component %s for property %s not found on app.\n', componentName, propertyName);
                    end
                catch ME
                    fprintf(2, 'Error setting UI component %s for property %s: %s\n', componentName, propertyName, ME.message);
                end
            else % Defaulting if field is missing from dsStruct
                 try
                    if isprop(app, componentName) && isvalid(app.(componentName))
                        uiComponent = app.(componentName);
                        if isa(uiComponent, 'matlab.ui.control.DatePicker'), uiComponent.Value = NaT; 
                        else, uiComponent.Value = ''; end
                    end
                catch ME_default, fprintf(2, 'Error defaulting UI component %s: %s\n', componentName, ME_default.message); end
            end
        end
    end
    fprintf('DEBUG (populateApp): Finished populating from FieldComponentMap.\n');

    % 2. Populate AuthorData object and tell AuthorDataGUI_Instance to draw
    if isprop(app, 'AuthorDataGUI_Instance') && ~isempty(app.AuthorDataGUI_Instance) && isvalid(app.AuthorDataGUI_Instance)
        if isfield(dsStruct, 'Author')
            app.AuthorData.fromStructs(dsStruct.Author); 
        else 
            app.AuthorData.ClearAll(); 
        end
        if isempty(app.AuthorData.AuthorList), app.AuthorData.addDefaultAuthorEntry(); end
        app.AuthorDataGUI_Instance.drawAuthorData(); 
        fprintf('DEBUG (populateApp): AuthorData object populated and AuthorDataGUI drawn.\n');
    else
        fprintf(2, 'Warning (populateApp): app.AuthorDataGUI_Instance not found or invalid.\n');
    end

    % 3. Tell DatasetDetailsGUI_Instance to draw (it will read from app.DatasetInformationStruct)
    if isprop(app, 'DatasetDetailsGUI_Instance') && ~isempty(app.DatasetDetailsGUI_Instance) && isvalid(app.DatasetDetailsGUI_Instance)
        app.DatasetDetailsGUI_Instance.drawDatasetDetails();
        fprintf('DEBUG (populateApp): DatasetDetailsGUI drawn.\n');
    else
        fprintf(2, 'Warning (populateApp): app.DatasetDetailsGUI_Instance not found or invalid.\n');
    end

    % 4. Tell ExperimentalDetailsGUI_Instance to draw
    if isprop(app, 'ExperimentalDetailsGUI_Instance') && ~isempty(app.ExperimentalDetailsGUI_Instance) && isvalid(app.ExperimentalDetailsGUI_Instance)
        app.ExperimentalDetailsGUI_Instance.drawExperimentalDetails();
        fprintf('DEBUG (populateApp): ExperimentalDetailsGUI drawn.\n');
    else
        fprintf(2, 'Warning (populateApp): app.ExperimentalDetailsGUI_Instance not found or invalid.\n');
    end
    
    % 5. Populate SubjectData object and tell SubjectInfoGUI_Instance to draw
    if isprop(app, 'SubjectInfoGUI_Instance') && ~isempty(app.SubjectInfoGUI_Instance) && isvalid(app.SubjectInfoGUI_Instance)
        if isfield(dsStruct, 'Subjects')
            if ismethod(app.SubjectData, 'fromStructs')
                 app.SubjectData.fromStructs(dsStruct.Subjects); 
            else 
                app.SubjectData.clearAllSubjects(); 
                if isstruct(dsStruct.Subjects)
                    for k_sub = 1:numel(dsStruct.Subjects)
                        try
                            subObj = ndi.database.metadata_app.class.Subject.fromStruct(dsStruct.Subjects(k_sub));
                            app.SubjectData.SubjectList(end+1) = subObj;
                        catch ME_sub_create, fprintf(2, 'Error creating Subject object from struct: %s\n', ME_sub_create.message); end
                    end
                end
            end
        else
            app.SubjectData.clearAllSubjects();
        end
        app.SubjectInfoGUI_Instance.drawSubjectInfo(); 
        fprintf('DEBUG (populateApp): SubjectData object populated and SubjectInfoGUI drawn.\n');
    else
         fprintf(2, 'Warning (populateApp): app.SubjectInfoGUI_Instance not found or invalid.\n');
    end

    % 6. Populate ProbeData object and tell ProbeDataGUI_Instance to draw
    if isprop(app, 'ProbeDataGUI_Instance') && ~isempty(app.ProbeDataGUI_Instance) && isvalid(app.ProbeDataGUI_Instance)
        if isfield(dsStruct, 'Probe')
            if ismethod(app.ProbeData, 'fromStructs') 
                app.ProbeData.fromStructs(dsStruct.Probe); 
            else 
                app.ProbeData.clearAllProbes(); 
                if iscell(dsStruct.Probe)
                    for k_probe = 1:numel(dsStruct.Probe)
                        try
                            probeEntry = app.createProbeObjectFromStruct(dsStruct.Probe{k_probe}); 
                            if ~isempty(probeEntry), app.ProbeData.addProbe(probeEntry); end 
                        catch ME_probe_create, fprintf(2, 'Error creating Probe object from struct: %s\n', ME_probe_create.message); end
                    end
                end
            end
        else
            app.ProbeData.clearAllProbes();
        end
        app.ProbeDataGUI_Instance.drawProbeData(); 
        fprintf('DEBUG (populateApp): ProbeData object populated and ProbeDataGUI drawn.\n');
    else
        fprintf(2, 'Warning (populateApp): app.ProbeDataGUI_Instance not found or invalid.\n');
    end

    fprintf('DEBUG (populateApp): populateAppFromDatasetInformationStruct completed.\n');
end
