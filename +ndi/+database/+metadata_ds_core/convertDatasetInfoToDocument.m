function document = convertDatasetInfoToDocument(datasetInfo)
    % CONVERTDATASETINFOTODOCUMENT function to convert datasetInfo to NDI document
    %   DOCUMENT = ndi.database.metadata_app.fun.CONVERTDATASETINFOTODOCUMENT(DATASETINFO)
    %   Inputs:
    %       DATASETINFO - struct containing the dataset information
    %
    %   Outputs:
    %       DOCUMENT - struct containing the dataset information

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
    document = datasetInfo;
    fieldsToConvert = {'Description', 'DataType', 'ExperimentalApproach', 'TechniquesEmployed', 'Author', 'Subjects'};

    for i = 1:numel(fieldsToConvert)
        fieldName = fieldsToConvert{i};
        v = getfield(datasetInfo, fieldName);
        for j = 1:numel(v)
            if isfield(document, fieldName)
                % Check for nested fields and convert if they exist
                if strcmp(fieldName, 'Author') && isfield(document.Author(j), 'authorRole')
                    if iscell(document.Author(j).authorRole) || isstring(document.Author(j).authorRole)
                        document.Author(j).authorRole=cellfun(@char, document.Author(j).authorRole, 'UniformOutput', false);
                        document.Author(j).authorRole = strjoin(document.Author(j).authorRole, ', ');
                    end
                elseif strcmp(fieldName, 'Subjects') && isfield(document.Subjects(j), 'BiologicalSexList')
                    if iscell(document.Subjects(j).BiologicalSexList) || isstring(document.Subjects(j).BiologicalSexList)
                        document.Subjects(j).BiologicalSexList=cellfun(@char, Subjects(j).BiologicalSexList, 'UniformOutput', false);
                        document.Subjects(j).BiologicalSexList = strjoin(document.Subjects(j).BiologicalSexList, ', ');
                    end
                else
                    % Convert top-level fields
                    if iscell(document.(fieldName)) || isstring(document.(fieldName))
                        document.(fieldName) = strjoin(document.(fieldName), ', ');
                    end
                end
            end
        end
    end

    fields = fieldnames(document);
    for i = 1:numel(fields)
        fieldName = fields{i};
        v = getfield(document, fieldName);
        if ischar(v) || isstring(v)
            document.(fields{i}) = char(v);
        elseif isstruct(v)
            for j = 1:numel(v)
                data = v(j);
                subfields = fieldnames(data);
                for k = 1:numel(subfields)
                    subfieldName = subfields{k};
                    if ischar(data.(subfieldName)) || isstring(data.(subfieldName))
                        document.(fields{i})(j).(subfields{k}) = char(data.(subfieldName));
                    end
                end
            end
        end
    end
end

