function dataset_id = upload_sample_test()
    % UPLOAD_SAMPLE_TEST - tests the api commands used to upload a sample dataset
    %
    % UPLOAD_SAMPLE_TEST()
    %
    % Tests the following api commands:
    %
    %    datasets/get_datasetid
    %    datasets/create_dataset
    %    documents/list_dataset_documents
    %    datasets/list_datasets
    %    datasets/update_dataset
    %
    % Tests the following functions:
    %
    %    ndi.cloud.upload.upload_to_NDI_cloud
    %    ndi.database.metadata_app.fun.metadata_to_json

    dirname = [ndi.common.PathConstants.ExampleDataFolder filesep '..' filesep 'example_datasets' filesep 'sample_test'];

    D = ndi.dataset.dir(dirname);

    metadatafile = [ndi.common.PathConstants.ExampleDataFolder filesep '..' filesep 'example_datasets' filesep 'NDIDatasetUpload' filesep 'metadata.mat'];
    metadata = load(metadatafile);
    datasetInformation = metadata.datasetInformation;
    metadata_json = ndi.database.metadata_ds_core.metadata_to_json(datasetInformation);
    %% test posting a dataset
    try
        [success, answer] = ndi.cloud.api.datasets.createDataset(metadata_json);
        if ~success, error(answer.message); end
        dataset_id = answer.dataset_id;
    catch ME
        error(['ndi.cloud.api.datasets.createDataset() failed to create a new dataset: ' ME.message]);
    end
    if ~ischar(dataset_id) || length(dataset_id) ~= 24
        error('ndi.cloud.api.datasets.createDataset() failed to return a valid dataset_id');
    end

    %% test getting the dataset
    try
        [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
        if ~success, error(dataset.message); end
    catch ME
        error(['ndi.cloud.api.datasets.getDataset() failed to retrieve the dataset: ' ME.message]);
    end

    if ~isfield(dataset, 'x_id')
        error('Does not return a dataset struct');
    end

    if ~strcmp(dataset.x_id, dataset_id)
        error('Dataset id does not match the input dataset id');
    end

    if ~isempty(dataset.documents)
        error('Dataset documents should be empty');
    end

    if ~isempty(dataset.files)
        error('Dataset files should be empty');
    end

    %% test updating the dataset
    update_dataset.doi = "https://doi.org://10.1000/123456789";
    try
        [success, ~] = ndi.cloud.api.datasets.updateDataset(dataset_id, update_dataset);
        if ~success, error("update failed"); end
    catch ME
        error(['ndi.cloud.api.datasets.updateDataset() failed to update the dataset: ' ME.message]);
    end
    
    try
        [success, dataset] = ndi.cloud.api.datasets.getDataset(dataset_id);
        if ~success, error(dataset.message); end
    catch ME
        error(['ndi.cloud.api.datasets.getDataset() failed to retrieve the dataset after updating the metadata: ' ME.message]);
    end

    if ~isfield(dataset, 'doi')
        error('ndi.cloud.api.datasets.updateDataset failed to update the dataset');
    end

    %% test list_dataset_documents
    try
        [success, summary] = ndi.cloud.api.documents.listDatasetDocuments(dataset_id);
        if ~success, error(summary.message); end
    catch ME
        error(['ndi.cloud.api.documents.listDatasetDocuments() failed to retrieve the documents summary: ' ME.message]);
    end
    if ~isfield(summary, 'documents')
        error('Does not return a documents summary struct');
    end

    if ~isempty(summary.documents)
        error('Documents summary should be empty');
    end
    %% test list_datasets
    if 0
        try
            [success, datasets] = ndi.cloud.api.datasets.listDatasets();
            if ~success, error(datasets.message); end
        catch ME
            error(['ndi.cloud.api.datasets.listDatasets() failed to retrieve the datasets: ' ME.message]);
        end

        match = 0;
        for i = 1:numel(datasets)
            if strcmp(datasets{i}.id, dataset_id)
                match = 1;
                break;
            end
        end
        if ~match
            error('Dataset id not found in the list of datasets');
        end
    end

    %% test invalid inputs
    try
        [~,~] = ndi.cloud.api.datasets.getDataset(1);
        error('ndi.cloud.api.datasets.getDataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.createDataset(1);
        error('ndi.cloud.api.datasets.createDataset did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.documents.listDatasetDocuments(1);
        error('ndi.cloud.api.documents.listDatasetDocuments did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.listDatasets(1);
        error('ndi.cloud.api.datasets.listDatasets did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        [~,~] = ndi.cloud.api.datasets.updateDataset(1, update_dataset);
        error('ndi.cloud.api.datasets.updateDataset did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
end

function status = check_dataset_metadata(datasetInformation, dataset)
    % CHECK_DATASET_METADATA - checks if the dataset matches the metadata
    %
    % STATUS = CHECK_DATASET_METADATA(DATASETINFORMATION, DATASET)
    %
    % Inputs:
    %   DATASETINFORMATION - a struct with the metadata to check
    %   DATASET - a struct with the dataset information
    %
    % Outputs:
    %   STATUS - 0 if the dataset matches the metadata, 1 otherwise
    %
    if (isfield(datasetInformation, 'name') && isfield(dataset, 'name') && ~strcmp(datasetInformation.name, dataset.name))
        status = 1;
        error(['Dataset: ' dataset.x_id 'name does not match metadata input']);
    elseif (isfield(datasetInformation, 'name') && ~isfield(dataset, 'name'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'name field missing']);
    end

    if (isfield(datasetInformation, 'branchName') && isfield(dataset, 'branchName') && ~strcmp(datasetInformation.branchName, dataset.branchName))
        status = 1;
        error(['Dataset: ' dataset.x_id 'branchName does not match metadata input']);
    elseif (isfield(datasetInformation, 'branchName') && ~isfield(dataset, 'branchName'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'branchName field missing']);
    end

    if (isfield(datasetInformation, 'contributors') && isfield(dataset, 'contributors') && ~isequal(datasetInformation.contributors, dataset.contributors))
        status = 1;
        error(['Dataset: ' dataset.x_id 'contributors does not match metadata input']);
    elseif (isfield(datasetInformation, 'contributors') && ~isfield(dataset, 'contributors'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'contributors field missing']);
    end

    % if (isfield(datasetInformation, 'doi') && isfield(dataset, 'doi') && ~strcmp(datasetInformation.doi, dataset.doi))
    %     status = 1;
    %     error(['Dataset: ' dataset.x_id 'doi does not match metadata input']);
    % elseif (isfield(datasetInformation, 'doi') && ~isfield(dataset, 'doi'))
    %     status = 1;
    %     error(['Dataset: ' dataset.x_id 'doi field missing']);
    % end

    if (isfield(datasetInformation, 'funding') && isfield(dataset, 'funding') && ~strcmp(datasetInformation.funding, dataset.funding))
        status = 1;
        error(['Dataset: ' dataset.x_id 'funding does not match metadata input']);
    elseif (isfield(datasetInformation, 'funding') && ~isfield(dataset, 'funding'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'funding field missing']);
    end

    if (isfield(datasetInformation, 'abstract') && isfield(dataset, 'abstract') && ~strcmp(datasetInformation.abstract, dataset.abstract))
        status = 1;
        error(['Dataset: ' dataset.x_id 'abstract does not match metadata input']);
    elseif (isfield(datasetInformation, 'abstract') && ~isfield(dataset, 'abstract'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'abstract field missing']);
    end

    if (isfield(datasetInformation, 'license') && isfield(dataset, 'license') && ~strcmp(datasetInformation.license, dataset.license))
        status = 1;
        error(['Dataset: ' dataset.x_id 'license does not match metadata input']);
    elseif (isfield(datasetInformation, 'license') && ~isfield(dataset, 'license'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'license field missing']);
    end

    if (isfield(datasetInformation, 'species') && isfield(dataset, 'species') && ~strcmp(datasetInformation.species, dataset.species))
        status = 1;
        error(['Dataset: ' dataset.x_id 'species does not match metadata input']);
    elseif (isfield(datasetInformation, 'species') && ~isfield(dataset, 'species'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'species field missing']);
    end

    if (isfield(datasetInformation, 'relatedPublications') && isfield(dataset, 'relatedPublications') && ~isequal(datasetInformation.relatedPublications, dataset.relatedPublications))
        status = 1;
        error(['Dataset: ' dataset.x_id 'relatedPublications does not match metadata input']);
    elseif (isfield(datasetInformation, 'relatedPublications') && ~isfield(dataset, 'relatedPublications'))
        status = 1;
        error(['Dataset: ' dataset.x_id 'relatedPublications field missing']);
    end
end
