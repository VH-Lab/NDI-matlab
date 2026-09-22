function file_ids = getUploadedFileIds(dataset_id)
% GETUPLOADEDFILEIDS - Get a list of uploaded file UIDs.
%
% FILE_IDS = GETUPLOADEDFILEIDS(DATASET_ID)
%
% This function retrieves the file list for the given DATASET_ID and returns
% the UIDs of all files that have been successfully uploaded.
%
% The file list is retrieved with ndi.cloud.api.files.listFilesAll (the dataset
% endpoints no longer return the file list inline), and is filtered to include
% only files marked as 'uploaded'.
%
% Inputs:
%   dataset_id (string) - The unique identifier of the cloud dataset.
%
% Outputs:
%   file_ids (cell array of strings) - A cell array containing the UIDs of
%     all successfully uploaded files in the dataset. Returns an empty cell
%     array if no files have been uploaded.
%
% Example:
%   % Assume 'd-12345' is a valid cloud dataset ID
%   f_ids = ndi.cloud.internal.getUploadedFileIds('d-12345');
%   disp(['Found ' num2str(numel(f_ids)) ' uploaded files.']);
%
% See also: ndi.cloud.api.files.listFilesAll

    arguments
        dataset_id (1,:) char
    end

    [success, datasetFiles] = ndi.cloud.api.files.listFilesAll(dataset_id);
    if ~success
        msg = datasetFiles;
        if isstruct(msg) && isfield(msg, 'message')
            msg = msg.message;
        end
        error('Failed to retrieve file list for dataset "%s": %s', ...
            dataset_id, char(string(msg)));
    end

    if ~isempty(datasetFiles)
        is_uploaded = logical([datasetFiles.uploaded]);
        file_ids = {datasetFiles(is_uploaded).uid};
    else
        file_ids = {};
    end
end
