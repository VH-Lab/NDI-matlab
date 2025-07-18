function [b, msg] = zip_for_upload(D, doc_file_struct, total_size, dataset_id, options)
% ZIP_FOR_UPLOAD - Create and upload zip files in batches to the NDI cloud.
%
%   [B, MSG] = ndi.cloud.upload.zip_for_upload(D, DOC_FILE_STRUCT, TOTAL_SIZE, DATASET_ID, 'Verbose', true)
%
% Inputs:
%  D - The ndi.database object.
%  DOC_FILE_STRUCT - A structure array with file information.
%  TOTAL_SIZE - The total size of all files to be uploaded (in bytes).
%  DATASET_ID - The dataset ID for the upload.
%
% Name-Value Options:
%  'Verbose'   - A logical (true/false) to control whether detailed
%                information is printed to the console. Defaults to false.
%  'SizeLimit' - The maximum size of each zip file batch in bytes.
%                Defaults to 50 MB (50e6).
%
% Outputs:
%   B - A boolean indicating success (1) or failure (0).
%   MSG - An error message if the operation failed; otherwise empty.
%
arguments
    D
    doc_file_struct (1,:) struct
    total_size (1,1) {mustBeNumeric}
    dataset_id (1,:) char {mustBeTextScalar}
    options.Verbose (1,1) logical = true
    options.SizeLimit (1,1) {mustBeNumeric, mustBePositive} = 25e6
end

% --- Initial Setup ---
msg = '';
b = 1;
files_to_process = doc_file_struct(~[doc_file_struct.is_uploaded]);
files_left = numel(files_to_process);
files_uploaded_count = 0;
processed_bytes = 0;
base_dir = fullfile(D.path, '.ndi', 'files');

if options.Verbose
    fprintf('Beginning upload process. %d files to upload.\n', files_left);
end

% --- Progress Bar Setup ---
h = waitbar(0, 'Preparing to upload files...');
% Use onCleanup to ensure the waitbar is always deleted, even on error
cleanupObj = onCleanup(@() delete(h(ishandle(h))));


% Set the maximum size of each zip file from options
size_limit = options.SizeLimit;
current_batch_size = 0;
files_for_current_batch = {};

% --- Main Loop: Iterate through files and create batches ---
for i = 1:numel(files_to_process)
    
    current_file = files_to_process(i);
    file_path = fullfile(base_dir, current_file.uid);
    file_bytes = current_file.bytes;
    
    % --- Update Progress ---
    processed_bytes = processed_bytes + file_bytes;
    try
        progress = processed_bytes / total_size;
        message = sprintf('Processing file %d of %d (%.2f / %.2f GB)...', ...
                          i, files_left, processed_bytes/1e9, total_size/1e9);
        waitbar(progress, h, message);
    catch
        % Handle cases where the waitbar was closed by the user
        b = 0; msg = 'Upload cancelled by user.'; return;
    end

    % --- Logic Check: Ensure file exists on disk ---
    if ~isfile(file_path)
        if options.Verbose
            warning('File %s (UID: %s) not found on disk. Skipping.', current_file.name, current_file.uid);
        end
        continue; % Skip this missing file
    end
    
    % --- Batching Logic for all files ---
    % If the current batch is not empty and adding the next file would exceed the limit,
    % then upload the current batch first.
    if ~isempty(files_for_current_batch) && (current_batch_size + file_bytes > size_limit)
        
        [success, batch_msg, uploaded_count] = zipAndUploadBatch(files_for_current_batch, dataset_id, options.Verbose);
        files_uploaded_count = files_uploaded_count + uploaded_count;
        
        if ~success, b = 0; msg = batch_msg; return; end
        
        % Reset for the next batch
        files_for_current_batch = {};
        current_batch_size = 0;
    end
    
    % Add the current file to the new/current batch
    files_for_current_batch{end+1} = file_path;
    current_batch_size = current_batch_size + file_bytes;
    
end % for

% --- Final Upload: Upload any remaining files in the last batch ---
if ~isempty(files_for_current_batch)
    [success, batch_msg, uploaded_count] = zipAndUploadBatch(files_for_current_batch, dataset_id, options.Verbose);
    files_uploaded_count = files_uploaded_count + uploaded_count;
    
    if ~success, b = 0; msg = batch_msg; return; end
end

if options.Verbose
    fprintf('Upload process finished. %d files were included in upload batches.\n', files_uploaded_count);
end

end


% --- Helper Function for Zipped Batches ---
function [success, msg, file_count] = zipAndUploadBatch(files_to_zip, dataset_id, is_verbose)
    % This helper function zips a list of files, uploads the archive, and cleans up.
    
    success = 1;
    msg = '';
    file_count = numel(files_to_zip);
    
    % Use a temporary name for the zip file to avoid collisions
    zip_file = [tempname, '.zip'];
    
    try
        if is_verbose
            batch_size_bytes = 0;
            for i=1:numel(files_to_zip)
                s = dir(files_to_zip{i});
                batch_size_bytes = batch_size_bytes + s.bytes;
            end
            fprintf('Zipping %d files (%.2f GB) for upload...\n', file_count, batch_size_bytes / 1e9);
        end
        
        % --- Zip, Upload, Cleanup ---
        zip(zip_file, files_to_zip);
        
        if is_verbose, disp('Getting upload URL for zipped batch...'); end
        [~, upload_url] = ndi.cloud.api.datasets.get_file_collection_upload_url(dataset_id);
        
        if is_verbose, disp('Uploading zip archive...'); end
        ndi.cloud.api.files.put_files(upload_url, zip_file);
        
    catch e
        success = 0;
        msg = sprintf('An error occurred during the zip/upload process: %s', e.message);
    end
    
    % --- Cleanup ---
    if isfile(zip_file)
        delete(zip_file);
    end
    
    if is_verbose && success
        disp('Batch upload successful.');
    end
end
