function datasetInformation = convertDocumentToDatasetInfo(document)
%CONVERTDOCUMENTTODATASETINFO function to convert NDI document to datasetInfo
%   DATASETINFO = ndi.database.metadata_app.fun.CONVERTDOCUMENTTODATASETINFO(DOCUMENT)
%   Inputs:
%       DOCUMENT - struct containing the dataset information
%
%   Outputs:
%       DATASETINFO - struct containing the dataset information

datasetInformation = document; % Initialize datasetInfo with the same structure
datasetInformation.ReleaseDate = datetime(datasetInformation.ReleaseDate);
Subjects = ndi.database.metadata_app.class.Subject.fromStruct(datasetInformation.Subjects);
datasetInformation.Subjects = Subjects;
fieldsToConvert = {'Description', 'DataType', 'ExperimentalApproach', 'TechniquesEmployed', 'Author', 'Subjects'};
    
    for i = 1:numel(fieldsToConvert)
        fieldName = fieldsToConvert{i};
        if isfield(datasetInformation, fieldName)
            % Check for nested fields and convert if they exist
            if strcmp(fieldName, 'Author') && isfield(datasetInformation.Author, 'authorRole')
                if ischar(datasetInformation.Author.authorRole)
                    datasetInformation.Author.authorRole = strsplit(datasetInformation.Author.authorRole, ', ');
                end
            elseif strcmp(fieldName, 'Subjects') && isfield(datasetInformation.Subjects, 'BiologicalSexList')
                if ischar(datasetInformation.Subjects.BiologicalSexList)
                    datasetInformation.Subjects.BiologicalSexList = strsplit(datasetInformation.Subjects.BiologicalSexList, ', ');
                end
            else
                % Convert top-level fields
                if ischar(datasetInformation.(fieldName))
                    datasetInformation.(fieldName) = strsplit(datasetInformation.(fieldName), ', ');
                end
            end
        end
    end
end

