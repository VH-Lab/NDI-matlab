function datasetInformation = readExistingMetadata(D, tempWorkingFile)
    %READEXISTINGMETADATA - retrieves metadata from an existing NDI entity or a temporary file.
    %
    % DATASETINFORMATION = ndi.database.metadata_app.fun.READEXISTINGMETADATA(D, TEMPWORKINGFILE)
    %
    % This function retrieves metadata.
    % If D is an ndi.dataset or ndi.session object, it reads metadata from the object.
    % If D is empty, it attempts to load metadata from a temporary working file specified
    % by TEMPWORKINGFILE, after confirming with the user via askResumeTempFile.
    %
    % Inputs:
    %   D - An ndi.dataset or ndi.session object, or empty.
    %   TEMPWORKINGFILE - The path to a temporary file that may contain saved metadata.
    %
    % Outputs:
    %   DATASETINFORMATION - The metadata structure, or empty if not found/loaded.
    %
    datasetInformation = {}; % Initialize to empty

    if isa(D, 'ndi.dataset') || isa(D, 'ndi.session')
        % Original flow for ndi.dataset or ndi.session
        metadata_editor_docs = D.database_search(ndi.query('','isa','metadata_editor'));
        if (numel(metadata_editor_docs) > 0)
            datasetInformation = read_metadata_editor(metadata_editor_docs);
        else
            datasetInformation = ndi.database.metadata_ds_core.ndidataset2metadataeditorstruct(D);
        end
        if ~isempty(datasetInformation) && nargin > 1 && ~isempty(tempWorkingFile)
            save(tempWorkingFile, "datasetInformation");
        end
    elseif isempty(D)
        if nargin > 1 && ~isempty(tempWorkingFile)
            % Attempt to resume from temporary file
            [useFile, existingData] = ndi.database.metadata_app.fun.askResumeTempFile(tempWorkingFile);
            if useFile && ~isempty(existingData)
                datasetInformation = existingData;
            end
        end
    else
        error('Input D must be an ndi.dataset, ndi.session, or empty.');
    end
end

function datasetInformation = read_metadata_editor(metadata_editor_docs)
    document = metadata_editor_docs{1}.document_properties.metadata_editor.metadata_structure;
    datasetInformation = ndi.database.metadata_ds_core.convertDocumentToDatasetInfo(document);
end
