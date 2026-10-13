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

    if options.Verbose
        fprintf('%d files in the manifest.\n', numel(file_manifest));
    end

    if options.onlyMissing
        [file_manifest, message] = ndi.cloud.sync.internal.filesNotYetUploaded(file_manifest, cloudDatasetId);
        if ~isempty(message)
            success = false;
            return;
        end
    end

    if options.Verbose
        fprintf('%d files still need to be uploaded.\n', numel(file_manifest));
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
            sentUids = strings(1, 0);
            for i=1:numel(file_manifest)
                if file_manifest(i).is_uploaded==false
                    % Wait for the server to record the uploads once, below,
                    % rather than after every file.
                    [upload_success, upload_message] = ndi.cloud.uploadSingleFile(cloudDatasetId, ...
                        file_manifest(i).uid, file_manifest(i).file_path, 'waitForUpload', false);
                    if ~upload_success
                        if success
                            message = ['Failed to upload file ' file_manifest(i).uid ': ' upload_message];
                        end
                        success = false;
                    else
                        sentUids(end+1) = string(file_manifest(i).uid); %#ok<AGROW>
                    end
                end
                app.updateBar(uuid,i/numel(file_manifest));
            end
            if ~isempty(sentUids)
                [wait_success, wait_answer] = ndi.cloud.api.files.waitForFileUpload(cloudDatasetId, sentUids);
                if ~wait_success
                    if success
                        message = sprintf(['%d of %d uploaded files were not recorded by NDI Cloud ' ...
                            'within %.0f s (first: %s).'], numel(wait_answer.pending), numel(sentUids), ...
                            wait_answer.elapsed, wait_answer.pending(1));
                    end
                    success = false;
                end
            end
        case "batch"
            [batch_success, batch_message] = ndi.cloud.upload.zipForUpload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
            if ~batch_success
                success = false;
                message = batch_message;
            end
    end
end
