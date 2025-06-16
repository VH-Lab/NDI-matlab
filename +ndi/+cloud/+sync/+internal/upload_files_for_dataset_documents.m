function upload_files_for_dataset_documents(cloudDatasetId, ndiDataset, dataset_documents, options)
% upload_files_for_dataset_documents - Upload a set of files belonging to a set of dataset documents
    arguments
        cloudDatasetId (1,1) string
        ndiDataset (1,1) ndi.dataset
        dataset_documents (1,:) cell
        options.Verbose (1,1) logical = true
    end

    file_manifest = ...
        ndi.database.internal.list_binary_files(...
        ndiDataset, dataset_documents, options.Verbose);
    [file_manifest(:).is_uploaded] = false;

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;
    [~, ~] = ndi.cloud.upload.zip_for_upload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
end
