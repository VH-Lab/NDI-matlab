function upload_files_for_dataset_documents(cloudDatasetId, ndiDataset, dataset_documents, options)
% upload_files_for_dataset_documents - Upload a set of files belonging to a set of dataset documents
    arguments
        cloudDatasetId (1,1) string
        ndiDataset (1,1) ndi.dataset
        dataset_documents (1,:) cell
        options.Verbose (1,1) logical = true
        options.FileUploadStrategy (1,1) string ...
            {mustBeMember(options.FileUploadStrategy, ["serial", "batch"])} = "batch"
    end

    file_manifest = ...
        ndi.database.internal.list_binary_files(...
        ndiDataset, dataset_documents, options.Verbose);
    [file_manifest(:).is_uploaded] = deal(false);

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;

    switch options.FileUploadStrategy
        case "serial"
            app = ndi.gui.component.ProgressBarWindow('NDI tasks');
            uuid = did.ido.unique_id();
            app.addBar('Label','Uploading document-associated binary files','tag',uuid,'Auto',true);
            for i=1:numel(file_manifest)
                if file_manifest(i).is_uploaded==false
                    [~,uploadURL]=ndi.cloud.api.files.get_file_upload_url(cloudDatasetId,file_manifest(i).uid);
                    ndi.cloud.api.files.put_files(uploadURL,file_manifest(i).file_path);
                end
                app.updateBar(uuid,i/numel(file_manifest));
            end
        case "batch"
            [~, ~] = ndi.cloud.upload.zip_for_upload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
    end
end
