function [success, message] = uploadFilesForDatasetDocuments(cloudDatasetId, ndiDataset, dataset_documents, options)
% UPLOADFILESFORDATASETDOCUMENTS - Upload a set of files belonging to a set of dataset documents
%
% [SUCCESS, MESSAGE] = UPLOADFILESFORDATASETDOCUMENTS(CLOUD_DATASET_ID, NDIDATASET, ...
%    DATASET_DOCUMENTS, NAME/VALUE PAIRS)
%
% Uploads a set of files that are associated with a given list of NDI_DOCUMENTS.
%
% This function takes a list of NDI_DOCUMENTS, finds all the associated binary data files
% that are stored in the NDIDATASET, and uploads them to the remote dataset identified
% by CLOUD_DATASET_ID.
%
% It can be configured with the following NAME/VALUE pairs:
% | Name                  | Description                               |
% |-----------------------|-------------------------------------------|
% | 'Verbose'             | (logical) Display verbose output (default true) |
% | 'FileUploadStrategy'  | ('serial' or 'batch') Upload strategy (default 'batch') |
% | 'onlyMissing'         | (logical) Only upload missing files (default true) |
%
% Outputs:
% | Name                  | Description                               |
% |-----------------------|-------------------------------------------|
% | SUCCESS               | (logical) True if all files were uploaded successfully. |
% | MESSAGE               | (char) An error message if SUCCESS is false. |
%
% See also: ndi.cloud.uploadDataset
%
    arguments
        cloudDatasetId (1,1) string
        ndiDataset (1,1) ndi.dataset
        dataset_documents (1,:) cell
        options.Verbose (1,1) logical = true
        options.FileUploadStrategy (1,1) string ...
            {mustBeMember(options.FileUploadStrategy, ["serial", "batch"])} = "batch"
        options.onlyMissing (1,1) logical = true
    end

    success = true;
    message = '';

    file_manifest = ...
        ndi.database.internal.list_binary_files(...
        ndiDataset, dataset_documents, options.Verbose);
    [file_manifest(:).is_uploaded] = deal(false);

    if options.onlyMissing
        [b, file_list] = ndi.cloud.api.files.listFiles(cloudDatasetId, "checkForUpdates", true);
        if b
            remote_files = containers.Map();
            for i=1:numel(file_list)
                remote_files(file_list(i).uid) = 1;
            end

            files_to_upload = struct('uid',{},'bytes',{},'file_path',{},'is_uploaded',{});
            for i=1:numel(file_manifest)
                if ~isKey(remote_files, file_manifest(i).uid)
                    new_struct.uid = file_manifest(i).uid;
                    new_struct.bytes = file_manifest(i).bytes;
                    new_struct.file_path = file_manifest(i).file_path;
                    new_struct.is_uploaded = file_manifest(i).is_uploaded;
                    files_to_upload(end+1) = new_struct;
                end
            end
            file_manifest = files_to_upload;
        else
            success = false;
            message = 'Could not retrieve remote dataset file list.';
            return;
        end
    end

    if isempty(file_manifest)
        message = 'All files are already on the remote.';
        return;
    end

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;

    switch options.FileUploadStrategy
        case "serial"
            app = ndi.gui.component.ProgressBarWindow('NDI tasks');
            uuid = did.ido.unique_id();
            app.addBar('Label','Uploading document-associated binary files','tag',uuid,'Auto',true);
            for i=1:numel(file_manifest)
                if file_manifest(i).is_uploaded==false
                    [url_success,uploadURL]=ndi.cloud.api.files.getFileUploadURL(cloudDatasetId,file_manifest(i).uid);
                    if ~url_success
                        warning('Failed to get upload URL');
                        if success
                           message = ['Failed to get upload URL for ' file_manifest(i).uid];
                        end
                        success = false;
                        continue;
                    end
                    [put_success] = ndi.cloud.api.files.putFiles(uploadURL,file_manifest(i).file_path);
                    if ~put_success
                        if success
                            message = ['Failed to upload file ' file_manifest(i).uid];
                        end
                        success = false;
                    end
                end
                app.updateBar(uuid,i/numel(file_manifest));
            end
        case "batch"
            [batch_success, batch_message] = ndi.cloud.upload.zipForUpload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
            if ~batch_success
                success = false;
                message = batch_message;
            end
    end
end
