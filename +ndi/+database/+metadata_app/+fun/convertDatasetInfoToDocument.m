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
    if isfield(document, fieldName)
        % Check for nested fields and convert if they exist
        if strcmp(fieldName, 'Author') && isfield(document.Author, 'authorRole')
            if iscell(document.Author.authorRole) || isstring(document.Author.authorRole)
                document.Author.authorRole = strjoin(document.Author.authorRole, ', ');
            end
        elseif strcmp(fieldName, 'Subjects') && isfield(document.Subjects, 'BiologicalSexList')
            if iscell(document.Subjects.BiologicalSexList) || isstring(document.Subjects.BiologicalSexList)
                document.Subjects.BiologicalSexList = strjoin(document.Subjects.BiologicalSexList, ', ');
            end
        else
            % Convert top-level fields
            if iscell(document.(fieldName)) || isstring(document.(fieldName))
                document.(fieldName) = strjoin(document.(fieldName), ', ');
            end
        end
    end
end
fields = fieldnames(document);
for i = 1:numel(fields)
    if ischar(document.(fields{i})) || isstring(document.(fields{i}))
        document.(fields{i}) = char(document.(fields{i}));
    elseif isstruct(document.(fields{i}))
        subfields = fieldnames(document.(fields{i}));
        for j = 1:numel(subfields)
            if ischar(document.(fields{i}).(subfields{j})) || isstring(document.(fields{i}).(subfields{j}))
                document.(fields{i}).(subfields{j}) = char(document.(fields{i}).(subfields{j}));
            end
        end
    end
end

end

