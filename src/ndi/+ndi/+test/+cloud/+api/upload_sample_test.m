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
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.create_dataset with ndi.cloud.api.datasets.createDataset
        [response, dataset_id] = ndi.cloud.api.datasets.create_dataset(metadata_json);
    catch
        error(['ndi.cloud.api.datasets.create_dataset() failed to create a new dataset' response]);
    end
    if ~ischar(dataset_id) || length(dataset_id) ~= 24
        error('ndi.cloud.api.datasets.create_dataset() failed to return a valid dataset_id');
    end

    %% test getting the dataset
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
        [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
    catch
        error(['ndi.cloud.api.datasets.get_dataset() failed to retrieve the dataset' response]);
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
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.update_dataset with ndi.cloud.api.datasets.updateDataset
        response = ndi.cloud.api.datasets.update_dataset(dataset_id, update_dataset);
    catch
        error(['ndi.cloud.api.datasets.update_dataset() failed to update the dataset' response]);
    end

    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
        [dataset, response] = ndi.cloud.api.datasets.get_dataset(dataset_id);
    catch
        error(['ndi.cloud.api.datasets.get_dataset() failed to retrieve the dataset after updating the metadata' response]);
    end

    if ~isfield(dataset, 'doi')
        error('ndi.cloud.api.datasets.update_dataset failed to update the dataset');
    end

    %% test list_dataset_documents
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.list_dataset_documents with ndi.cloud.api.documents.listDatasetDocuments
        [response, summary] = ndi.cloud.api.documents.list_dataset_documents(dataset_id);
    catch
        error(['ndi.cloud.api.documents.list_dataset_documents() failed to retrieve the documents summary' response]);
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
            % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.list_datasets with ndi.cloud.api.datasets.listDatasets
            [response, datasets] = ndi.cloud.api.datasets.list_datasets();
        catch
            error(['ndi.cloud.api.datasets.list_datasets() failed to retrieve the datasets' response]);
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
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.get_dataset with ndi.cloud.api.datasets.getDataset
        [dataset, response] = ndi.cloud.api.datasets.get_dataset(1);
        error('ndi.cloud.api.datasets.get_dataset did not throw an error after using an invalid dataset id');
    catch
        % do nothing, this is the expected behavior
    end
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.create_dataset with ndi.cloud.api.datasets.createDataset
        response = ndi.cloud.api.datasets.create_dataset(1);
        error('ndi.cloud.api.datasets.create_dataset did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.documents.list_dataset_documents with ndi.cloud.api.documents.listDatasetDocuments
        [response, summary] = ndi.cloud.api.documents.list_dataset_documents(1);
        error('ndi.cloud.api.documents.list_dataset_documents did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.list_datasets with ndi.cloud.api.datasets.listDatasets
        [response, datasets] = ndi.cloud.api.datasets.list_datasets(1);
        error('ndi.cloud.api.datasets.list_datasets did not throw an error after using an invalid input');
    catch
        % do nothing, this is the expected behavior
    end
    try
        % TODO: Update deprecated function call. Replace ndi.cloud.api.datasets.update_dataset with ndi.cloud.api.datasets.updateDataset
        response = ndi.cloud.api.datasets.update_dataset(1, update_dataset);
        error('ndi.cloud.api.datasets.update_dataset did not throw an error after using an invalid input');
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
