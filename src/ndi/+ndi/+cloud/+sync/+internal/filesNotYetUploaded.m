function [files_to_upload, message] = filesNotYetUploaded(fileManifest, cloudDatasetId)
% FILESNOTYETUPLOADED - Identify files that have not yet been uploaded to a cloud dataset
%
% [FILES_TO_UPLOAD, MESSAGE] = filesNotYetUploaded(FILE_MANIFEST, CLOUD_DATASET_ID)
%
% Given a file manifest (a struct array with fields 'uid', 'bytes', 'file_path', 'is_uploaded'),
% and a cloud dataset ID, this function returns a new struct array containing only those
% files that need to be uploaded.
%
% A file is considered to need uploading if it is not present in the remote dataset's file list,
% or if it is present but its 'uploaded' status is false.
%
% Outputs:
% | Name              | Description                                   |
% |-------------------|-----------------------------------------------|
% | FILES_TO_UPLOAD   | A struct array of files to be uploaded.       |
% | MESSAGE           | An error message if the operation fails.      |
%
    files_to_upload = struct('uid',{},'bytes',{},'file_path',{},'is_uploaded',{});
    message = '';

    [b, file_list] = ndi.cloud.api.files.listFiles(cloudDatasetId, "checkForUpdates", true);
    if b
        remote_files = containers.Map();
        for i=1:numel(file_list)
            remote_files(file_list(i).uid) = file_list(i);
        end

        for i=1:numel(fileManifest)
            if ~isKey(remote_files, fileManifest(i).uid) || ...
               (isKey(remote_files, fileManifest(i).uid) && ...
                isfield(remote_files(fileManifest(i).uid), 'uploaded') && ...
                remote_files(fileManifest(i).uid).uploaded == false)

                new_struct.uid = fileManifest(i).uid;
                new_struct.bytes = fileManifest(i).bytes;
                new_struct.file_path = fileManifest(i).file_path;
                new_struct.is_uploaded = fileManifest(i).is_uploaded;
                files_to_upload(end+1) = new_struct;
            end
        end
    else
        message = 'Could not retrieve remote dataset file list.';
    end
end
