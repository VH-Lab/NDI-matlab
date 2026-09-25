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
        if options.Verbose
            fprintf('Checking cloud dataset %s for files already uploaded ...\n', cloudDatasetId);
        end
        [file_manifest, message] = ndi.cloud.sync.internal.filesNotYetUploaded(file_manifest, cloudDatasetId);
        if ~isempty(message)
            success = false;
            % Do not swallow the diagnostic. A caller that inspects only
            % `success` still gets a printed line explaining what failed
            % and where to look next, so the pipeline does not appear to
            % succeed-silently-fail-silently.
            if options.Verbose
                fprintf(['ERROR while checking which files are already ', ...
                    'in the cloud: %s\n', ...
                    'This often means the active NDI_CLOUD_ORGANIZATION_ID ', ...
                    'does not own dataset %s. Pass ndi.cloud.uploadDataset ', ...
                    'the ''organizationName'' or ''organizationID'' the ', ...
                    'dataset was created under. Current active org: %s.\n'], ...
                    message, cloudDatasetId, getenv('NDI_CLOUD_ORGANIZATION_ID'));
            end
            return;
        end
    end

    if options.Verbose
        fprintf('%d files still need to be uploaded.\n', numel(file_manifest));
    end

    if isempty(file_manifest)
        message = 'All files are already on the remote.';
        if options.Verbose
            fprintf('%s\n', message);
        end
        return;
    end

    totalSizeKb = sum([file_manifest.bytes]) / 1e3;

    switch options.FileUploadStrategy
        case "serial"
            app = ndi.gui.component.ProgressBarWindow('NDI tasks');
            uuid = did.ido.unique_id();
            app.addBar('Label','Uploading document-associated binary files','tag',uuid,'Auto',true);
            files_uploaded_count = 0;
            for i=1:numel(file_manifest)
                if file_manifest(i).is_uploaded==false
                    [upload_success, upload_message] = ndi.cloud.uploadSingleFile(cloudDatasetId, ...
                        file_manifest(i).uid, file_manifest(i).file_path);
                    if ~upload_success
                        if success
                            message = ['Failed to upload file ' file_manifest(i).uid ': ' upload_message];
                        end
                        success = false;
                    else
                        files_uploaded_count = files_uploaded_count + 1;
                    end
                end
                app.updateBar(uuid,i/numel(file_manifest));
            end
            if options.Verbose
                fprintf('Uploaded %d of %d files.\n', files_uploaded_count, numel(file_manifest));
            end
        case "batch"
            [batch_success, batch_message] = ndi.cloud.upload.zipForUpload(ndiDataset, file_manifest, totalSizeKb, cloudDatasetId);
            if ~batch_success
                success = false;
                message = batch_message;
                if options.Verbose
                    fprintf('Batch upload failed: %s\n', batch_message);
                end
            elseif options.Verbose
                fprintf('Uploaded %d files in batch mode.\n', numel(file_manifest));
            end
    end
end
