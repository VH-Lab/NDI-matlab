function file_ids = getUploadedFileIds(dataset_id)
% GETUPLOADEDFILEIDS - Get a list of uploaded file UIDs.
%
% FILE_IDS = GETUPLOADEDFILEIDS(DATASET_ID)
%
% This function retrieves a list of all datasets from the cloud, finds the
% one matching the given DATASET_ID, and then returns the UIDs of all files
% within that dataset that have been successfully uploaded.
%
% The function iterates through the list of all available datasets to find a
% match. If no dataset with the specified ID is found, an error is raised.
%
% Once the correct dataset is identified, it filters the files to include only
% those marked as 'uploaded' and returns their UIDs.
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
% See also: ndi.cloud.datasets.list_datasets

    arguments
        dataset_id (1,:) char
    end

    try
        [~, ~, datasets] = ndi.cloud.datasets.list_datasets();
        dataset_names = {};
        for i=1:numel(datasets)
            dataset_names{i} = datasets{i}.id;
        end
        is_match =  strcmp(dataset_names, dataset_id);
        if any(is_match)
            dataset = datasets{is_match};
        else
            error('No dataset found with id "%s"', dataset_id)
        end
    catch ME
        rethrow(ME)
    end

    if ~isempty(dataset.files)
        is_uploaded = [dataset.files.uploaded];
        file_ids = {dataset.files(is_uploaded).uid};
    else
        file_ids = {};
    end
end
