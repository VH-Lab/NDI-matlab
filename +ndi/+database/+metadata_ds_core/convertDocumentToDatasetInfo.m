function datasetInformation = convertDocumentToDatasetInfo(document)
    %CONVERTDOCUMENTTODATASETINFO function to convert NDI document to datasetInfo
    %   DATASETINFO = ndi.database.metadata_app.fun.CONVERTDOCUMENTTODATASETINFO(DOCUMENT)
    %   Inputs:
    %       DOCUMENT - struct containing the saved dataset information for our app
    %                  Note that this is not a set of saved metadata objects in the dataset,
    %                  but just the saved structure data from the MetaDataEditorApp
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
        v = getfield(datasetInformation, fieldName);
        for j = 1:numel(v)
            if isfield(datasetInformation, fieldName)
                % Check for nested fields and convert if they exist
                if strcmp(fieldName, 'Author') && isfield(datasetInformation.Author(j), 'authorRole')
                    if ischar(datasetInformation.Author(j).authorRole)
                        datasetInformation.Author(j).authorRole = strsplit(datasetInformation.Author(j).authorRole, ', ');
                    end
                elseif strcmp(fieldName, 'Subjects') && isfield(datasetInformation.Subjects(j), 'BiologicalSexList')
                    if ischar(datasetInformation.Subjects(j).BiologicalSexList)
                        datasetInformation.Subjects(j).BiologicalSexList = strsplit(datasetInformation.Subjects(j).BiologicalSexList, ', ');
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
end

