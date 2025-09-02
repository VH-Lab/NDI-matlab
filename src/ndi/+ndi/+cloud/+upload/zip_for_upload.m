function [b, msg] = zip_for_upload(D, doc_file_struct, total_size, dataset_id, options)
% ZIP_FOR_UPLOAD - Create and upload zip files in batches to the NDI cloud.
%
%   [B, MSG] = ndi.cloud.upload.zip_for_upload(D, DOC_FILE_STRUCT, TOTAL_SIZE, DATASET_ID, 'Verbose', true, 'DebugLog', true)
%
% Inputs:
%  D - The ndi.database object.
%  DOC_FILE_STRUCT - A structure array with file information.
%  TOTAL_SIZE - The total size of all files to be uploaded (in bytes). (Note: This is no longer used for the progress bar).
%  DATASET_ID - The dataset ID for the upload.
%
% Name-Value Options:
%  'Verbose'   - A logical (true/false) to control whether detailed
%                information is printed to the console. Defaults to false.
%  'SizeLimit' - The maximum size of each zip file batch in bytes.
%                Defaults to 25 MB (25e6).
%  'DebugLog'  - A logical (true/false) to enable logging of zipped files.
%                Defaults to false.
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
    options.SizeLimit (1,1) {mustBeNumeric, mustBePositive} = 50e6
    options.DebugLog (1,1) logical = true
end
% --- Initial Setup ---
msg = '';
b = 1;
files_to_process = doc_file_struct(~[doc_file_struct.is_uploaded]);
files_left = numel(files_to_process);
files_uploaded_count = 0;
processed_bytes = 0;
base_dir = fullfile(D.path, '.ndi', 'files');
skipped_files = {};

if options.Verbose
    fprintf('Beginning upload process. %d files to upload.\n', files_left);
end

% --- Log File Initialization ---
if options.DebugLog
    log_folder = ndi.common.PathConstants.LogFolder;
    if ~isfolder(log_folder), mkdir(log_folder); end
    
    % Erase previous logs by opening in write mode 'wt' and writing headers
    log_files_to_clear = {'zip_log.csv', 'processed_log.csv', 'skipped_log.csv'};
    % **Updated header for zip_log.csv**
    headers = {'ZipFile,ZippedFile,UncompressedBytes', 'TotalProcessedBytes', 'SkippedFile,UID'};
    
    for k = 1:numel(log_files_to_clear)
        fid = fopen(fullfile(log_folder, log_files_to_clear{k}), 'wt');
        if fid ~= -1
            fprintf(fid, '%s\n', headers{k});
            fclose(fid);
        else
            warning('Could not create log file: %s', log_files_to_clear{k});
        end
    end
end

% --- Progress Bar Setup ---
h = waitbar(0, 'Preparing to upload files...');
cleanupObj = onCleanup(@() delete(h(ishandle(h))));
size_limit = options.SizeLimit;
current_batch_size = 0;
files_for_current_batch = {};

% --- Main Loop: Iterate through files and create batches ---
for i = 1:numel(files_to_process)
    
    current_file = files_to_process(i);
    file_path = fullfile(base_dir, current_file.uid);
    file_bytes = current_file.bytes;
    
    % --- Update Progress based on file count ---
    processed_bytes = processed_bytes + file_bytes;
    try
        progress = i / files_left;
        message = sprintf('Processing file %d of %d...', i, files_left);
        waitbar(progress, h, message);
    catch
        b = 0; msg = 'Upload cancelled by user.'; return;
    end
    
    % --- Logic Check: Ensure file exists on disk ---
    if ~isfile(file_path)
        if options.Verbose
            warning('File %s (UID: %s) not found on disk. Skipping.', current_file.name, current_file.uid);
        end
        skipped_files{end+1} = current_file;
        continue;
    end
    
    % --- Batching Logic ---
    if ~isempty(files_for_current_batch) && (current_batch_size + file_bytes > size_limit)
        [success, batch_msg, uploaded_count] = zipAndUploadBatch(files_for_current_batch, dataset_id, options);
        files_uploaded_count = files_uploaded_count + uploaded_count;
        if ~success, b = 0; msg = batch_msg; return; end
        files_for_current_batch = {};
        current_batch_size = 0;
    end
    
    % Add the current file to the new/current batch
    files_for_current_batch{end+1} = file_path;
    current_batch_size = current_batch_size + file_bytes;
    
end % for

% --- Final Upload: Upload any remaining files ---
if ~isempty(files_for_current_batch)
    [success, batch_msg, uploaded_count] = zipAndUploadBatch(files_for_current_batch, dataset_id, options);
    files_uploaded_count = files_uploaded_count + uploaded_count;
    if ~success, b = 0; msg = batch_msg; return; end
end

% --- Final Logging ---
if options.DebugLog
    log_folder = ndi.common.PathConstants.LogFolder;
    
    % Log processed files summary
    processed_log_file = fullfile(log_folder, 'processed_log.csv');
    fid = fopen(processed_log_file, 'at'); % Append total size
    if fid ~= -1
        fprintf(fid, '%d\n', processed_bytes);
        fclose(fid);
    end
    
    % Log skipped files
    if ~isempty(skipped_files)
        skipped_log_file = fullfile(log_folder, 'skipped_log.csv');
        fid = fopen(skipped_log_file, 'at'); % Append skipped files
        if fid ~= -1
            for k = 1:numel(skipped_files)
                fprintf(fid, '"%s","%s"\n', skipped_files{k}.name, skipped_files{k}.uid);
            end
            fclose(fid);
        end
    end
end

if options.Verbose
    fprintf('Upload process finished. %d files were included in upload batches.\n', files_uploaded_count);
end
end

% --- Helper Function for Zipped Batches ---
function [success, msg, file_count] = zipAndUploadBatch(files_to_zip, dataset_id, options)
    success = 1;
    msg = '';
    file_count = numel(files_to_zip);
    zip_file = [tempname, '.zip'];
    
    try
        if options.Verbose
            batch_size_bytes = 0;
            for i=1:numel(files_to_zip), s = dir(files_to_zip{i}); batch_size_bytes = batch_size_bytes + s.bytes; end
            fprintf('Zipping %d files (%.2f MB) for upload...\n', file_count, batch_size_bytes / 1e6);
        end
        
        zip(zip_file, files_to_zip);
        
        if options.DebugLog
            log_file = fullfile(ndi.common.PathConstants.LogFolder, 'zip_log.csv');
            fid = fopen(log_file, 'at');
            if fid ~= -1
                [~, zip_name, zip_ext] = fileparts(zip_file);
                zip_filename_str = [zip_name zip_ext];
                
                % **Get and log the size of each file**
                for i = 1:numel(files_to_zip)
                    file_info = dir(files_to_zip{i});
                    file_size_bytes = file_info.bytes;
                    fprintf(fid, '"%s","%s",%d\n', zip_filename_str, files_to_zip{i}, file_size_bytes);
                end
                fclose(fid);
            end
        end
        
        if options.Verbose, disp('Getting upload URL for zipped batch...'); end
        [~, upload_url] = ndi.cloud.api.datasets.get_file_collection_upload_url(dataset_id);
        
        if options.Verbose, disp('Uploading zip archive...'); end
        ndi.cloud.api.files.put_files(upload_url, zip_file);
        
    catch e
        success = 0;
        msg = sprintf('An error occurred during the zip/upload process: %s', e.message);
    end
    
    if isfile(zip_file), delete(zip_file); end
    if options.Verbose && success, disp('Batch upload successful.'); end
end