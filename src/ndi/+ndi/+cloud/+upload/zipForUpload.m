function [b, msg] = zipForUpload(D, doc_file_struct, total_size, dataset_id, options)
% ZIPFORUPLOAD - Create and upload zip files in batches to the NDI cloud.
%
%   [B, MSG] = ndi.cloud.upload.zipForUpload(D, DOC_FILE_STRUCT, TOTAL_SIZE, DATASET_ID, 'Verbose', true, 'DebugLog', true)
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
    options.numberRetries (1,1) {mustBeNumeric, mustBeInteger, mustBeNonnegative} = 3
end
% --- Initial Setup ---
msg = '';
b = 1;
files_to_process = doc_file_struct(~[doc_file_struct.is_uploaded]);
files_left = numel(files_to_process);
files_uploaded_count = 0;
processed_bytes = 0;
base_dir = fullfile(D.path, '.ndi', 'files'); %#ok<NASGU>

if options.Verbose
    fprintf('Beginning upload process. %d files to upload.\n', files_left);
end

% --- Log File Initialization ---
if options.DebugLog
    log_folder = ndi.common.PathConstants.LogFolder;
    if ~isfolder(log_folder), mkdir(log_folder); end
    
    % Erase previous logs by opening in write mode 'wt' and writing headers.
    % skipped_log.csv is no longer written: the pre-zip isfile() check was
    % removed as redundant with list_binary_files' manifest, so there is no
    % "missing at zip time" bookkeeping to log.
    log_files_to_clear = {'zip_log.csv', 'processed_log.csv'};
    headers = {'ZipFile,ZippedFile,UncompressedBytes', 'TotalProcessedBytes'};
    
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
% Standard NDI progress bar, same "NDI tasks" window the serial upload
% branch uses so bars stack in one place. Auto=true removes it at 1.0.
progressApp = ndi.gui.component.ProgressBarWindow('NDI tasks');
uploadBarId = did.ido.unique_id();
progressApp.addBar( ...
    'Label', sprintf('Uploading document-associated binary files (0 of %d)', files_left), ...
    'tag', uploadBarId, ...
    'Auto', true);

size_limit = options.SizeLimit;
n_files = numel(files_to_process);
file_bytes_all = [files_to_process.bytes]; % scalar array, indexed below

% NOTE: no per-file isfile() check here. list_binary_files already
% resolved each entry through database_existbinarydoc + dir() when the
% manifest was built moments ago, so a redundant stat per file (four
% total per file with the zip/log dir() calls below) costs real time on
% a slow drive and adds nothing. If a file vanishes between manifest
% and zip time, MATLAB's zip() raises inside zipAndUploadBatch's
% try/catch and the batch is reported as failed rather than silently
% skipped -- the guard against issue #805 that isfile+skipped_files
% used to enforce.

% --- Main Loop: Single pass through the file list --------------------
% Cursor-based, greedy pack in the input order. Each file is examined
% exactly once across all batches, so the total work is O(N_files)
% instead of the O(N_batches * N_files) the previous restart-from-top
% design imposed -- at 160k files and batches of ~50 MB, that mattered.
% A file too large for the remaining budget of the current batch closes
% the batch and starts the next one at that file; a single file bigger
% than size_limit still goes up alone (the first file in a batch is
% always accepted).
cursor = 1;
files_processed_so_far = 0;
while cursor <= n_files
    batch_start = cursor;
    batch_end = cursor;      % inclusive; grown below
    current_batch_size = file_bytes_all(cursor);
    cursor = cursor + 1;
    while cursor <= n_files
        fb = file_bytes_all(cursor);
        if current_batch_size + fb > size_limit
            break;
        end
        current_batch_size = current_batch_size + fb;
        batch_end = cursor;
        cursor = cursor + 1;
        if current_batch_size >= size_limit
            break;
        end
    end

    % Slice out just this batch's paths (no cell growth in a loop).
    batch_indices = batch_start:batch_end;
    files_for_current_batch = {files_to_process(batch_indices).file_path};

    [success, batch_msg, uploaded_count] = zipAndUploadBatch( ...
        files_for_current_batch, dataset_id, options.numberRetries, options);
    files_uploaded_count = files_uploaded_count + uploaded_count;

    if ~success
        b = 0;
        files_not_uploaded = files_left - files_processed_so_far;
        msg = sprintf('%s\n%d files were successfully uploaded. %d files were not uploaded.', ...
            batch_msg, files_uploaded_count, files_not_uploaded);
        return;
    end

    files_processed_so_far = files_processed_so_far + numel(batch_indices);
    progressApp.updateBar(uploadBarId, files_processed_so_far / files_left);
end

progressApp.updateBar(uploadBarId, 1); % Auto=true removes it

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
end

if options.Verbose
    fprintf('Upload process finished. %d files were included in upload batches.\n', files_uploaded_count);
end
end

% --- Helper Function for Zipped Batches ---
function [success, msg, file_count] = zipAndUploadBatch(files_to_zip, dataset_id, numberRetries, options)
    success = 1;
    msg = '';
    file_count = numel(files_to_zip);
    tempFile = tempname;
    [parentDir,zip_file_unique_part] = fileparts(tempFile);
    zip_file = fullfile(parentDir,[dataset_id '.' zip_file_unique_part '.zip']);
    
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

        upload_url = '';
        upload_jobId = "";
        for r=1:numberRetries
            [success, upload_info_or_err] = ndi.cloud.api.files.getFileCollectionUploadURL(dataset_id);
            if success
                upload_url = upload_info_or_err.url;
                upload_jobId = upload_info_or_err.jobId;
                break;
            else
                if options.Verbose
                    fprintf('Attempt %d of %d to get upload URL failed. Retrying in 5s...\n', r, numberRetries);
                end
                pause(5);
            end
        end

        if ~success
            msg = sprintf('Failed to get upload URL after %d attempts: %s', numberRetries, upload_info_or_err.message);
            error(msg);
        end

        if options.Verbose, disp('Uploading zip archive...'); end
        for r=1:numberRetries
            [success, err] = ndi.cloud.api.files.putFiles(upload_url, zip_file, ...
                'jobId', upload_jobId);
            if success
                break;
            else
                if options.Verbose
                    fprintf('Attempt %d of %d to upload file failed. Retrying in 5s...\n', r, numberRetries);
                end
                pause(5);
            end
        end

        if ~success
            msg = sprintf('Failed to upload file after %d attempts: %s', numberRetries, err.message);
            error(msg);
        end
        
    catch e
        success = 0;
        msg = sprintf('An error occurred during the zip/upload process: %s', e.message);
    end
    
    if isfile(zip_file), delete(zip_file); end
    if options.Verbose && success, disp('Batch upload successful.'); end
end