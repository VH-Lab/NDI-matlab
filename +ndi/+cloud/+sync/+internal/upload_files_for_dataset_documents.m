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
    [file_manifest(:).is_uploaded] = deal(false);

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;
    ndiCloudUploadNoZipEnvironment = getenv('NDI_CLOUD_UPLOAD_NO_ZIP');
    if isempty(ndiCloudUploadNoZipEnvironment)
       ndiCloudUploadNoZipEnvironment = "false";
    end

    if strcmp(char(ndiCloudUploadNoZipEnvironment),'true')
        app = ndi.gui.component.ProgressBarWindow('NDI tasks');
        uuid = did.ido.unique_id();
        app.addBar('Label','Uploading document-associated binary files','tag',uuid,'Auto',true);
        for i=1:numel(file_manifest)
            if file_manifest(i).is_uploaded==false
                [r,uploadURL]=ndi.cloud.api.files.get_file_upload_url(cloudDatasetId,file_manifest(i).uid);
                r=ndi.cloud.api.files.put_files(uploadURL,file_manifest(i).file_path);
            end
            app.updateBar(uuid,i/numel(file_manifest));
        end
    else
        [~, ~] = ndi.cloud.upload.zip_for_upload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
    end
end
