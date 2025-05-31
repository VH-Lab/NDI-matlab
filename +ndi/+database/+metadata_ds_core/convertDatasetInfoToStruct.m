function datasetInfoStruct = convertDatasetInfoToStruct(datasetInfo)
    % CONVERTDATASETINFOSTRUCT function to convert datasetInfo to a structure
    %   DATASETINFOSTRUCT = ndi.database.metadata_ds_core.convertDatasetInfoToStruct(DATASETINFO)
    %   This function takes a datasetInfo structure and prepares it as a 
    %   structure (datasetInfoStruct) that can be used to create an ndi.document
    %   of type 'ndi.metadata.metadata_editor'.
    %
    %   Inputs:
    %       DATASETINFO - struct containing the dataset information
    %
    %   Outputs:
    %       DATASETINFOSTRUCT - struct containing the dataset information, formatted
    %                           for an ndi.document of type 'ndi.metadata.metadata_editor'.

    if isfield(datasetInfo, 'Subjects')
        Subjects = datasetInfo.Subjects.toStruct();
        if isfield(Subjects, 'StrainMap')
            Subjects = rmfield(Subjects, 'StrainMap');
        end
        datasetInfo.Subjects = Subjects;
    end
    if isfield(datasetInfo, 'ReleaseDate')
        datasetInfo.ReleaseDate = string(datasetInfo.ReleaseDate);
    end
    datasetInfoStruct = datasetInfo;
    fieldsToConvert = {'Description', 'DataType', 'ExperimentalApproach', 'TechniquesEmployed', 'Author', 'Subjects'};

    for i = 1:numel(fieldsToConvert)
        fieldName = fieldsToConvert{i};
        if isfield(datasetInfo, fieldName)
            value = datasetInfo.(fieldName);
            for j = 1:numel(value)
                if isfield(datasetInfoStruct, fieldName)
                    % Check for nested fields and convert if they exist
                    if strcmp(fieldName, 'Author') && isfield(datasetInfoStruct.Author(j), 'authorRole')
                        if iscell(datasetInfoStruct.Author(j).authorRole) || isstring(datasetInfoStruct.Author(j).authorRole)
                            datasetInfoStruct.Author(j).authorRole=cellfun(@char, datasetInfoStruct.Author(j).authorRole, 'UniformOutput', false);
                            datasetInfoStruct.Author(j).authorRole = strjoin(datasetInfoStruct.Author(j).authorRole, ', ');
                        end
                    elseif strcmp(fieldName, 'Subjects') && isfield(datasetInfoStruct.Subjects(j), 'BiologicalSexList')
                        if iscell(datasetInfoStruct.Subjects(j).BiologicalSexList) || isstring(datasetInfoStruct.Subjects(j).BiologicalSexList)
                            datasetInfoStruct.Subjects(j).BiologicalSexList=cellfun(@char, Subjects(j).BiologicalSexList, 'UniformOutput', false);
                            datasetInfoStruct.Subjects(j).BiologicalSexList = strjoin(datasetInfoStruct.Subjects(j).BiologicalSexList, ', ');
                        end
                    else
                        % Convert top-level fields
                        if iscell(datasetInfoStruct.(fieldName)) || isstring(datasetInfoStruct.(fieldName))
                            datasetInfoStruct.(fieldName) = strjoin(datasetInfoStruct.(fieldName), ', ');
                        end
                    end
                end
            end
        end
    end

    fields = fieldnames(datasetInfoStruct);
    for i = 1:numel(fields)
        fieldName = fields{i};
        value = getfield(datasetInfoStruct, fieldName);
        if ischar(value) || isstring(value)
            datasetInfoStruct.(fields{i}) = char(value);
        elseif isstruct(value)
            for j = 1:numel(value)
                data = value(j);
                subfields = fieldnames(data);
                for k = 1:numel(subfields)
                    subfieldName = subfields{k};
                    if ischar(data.(subfieldName)) || isstring(data.(subfieldName))
                        datasetInfoStruct.(fields{i})(j).(subfields{k}) = char(data.(subfieldName));
                    end
                end
            end
        end
    end
end
