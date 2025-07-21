function inventoryRemoteFiles(cloudDatasetId)
% INVENTORYREMOTEFILES - Verifies the presence of zipped files on the remote server.
%
%   INVENTORYREMOTEFILES(CLOUDDATASETID)
%
%   This function reads the 'zip_log.csv' file created by the upload process.
%   For each file listed in the log, it queries the NDI cloud server to see if
%   a file with the corresponding UID exists for the given CLOUDDATASETID.
%
%   It then generates a new log file, 'zipFileInventory.csv', in the same
%   log folder. This new file is a copy of 'zip_log.csv' but includes an
%   additional column, 'PresentOnRemote', which is marked as true or false.
%
%   This provides a clear report of which specific files are missing from the
%   remote dataset after an upload.
%
%   Inputs:
%    cloudDatasetId - The character string ID of the dataset on the NDI cloud server.
%

    log_folder = ndi.common.PathConstants.LogFolder;
    zip_log_path = fullfile(log_folder, 'zip_log.csv');
    inventory_output_path = fullfile(log_folder, 'zipFileInventory.csv');

    if ~isfile(zip_log_path)
        error('The zip log file "%s" does not exist. Please run the upload function with DebugLog enabled first.', zip_log_path);
    end

    fprintf('Reading zip log file...\n');
    % Explicitly set delimiter and tell it the first row is the header
    opts = detectImportOptions(zip_log_path);
    opts.Delimiter = ',';
    opts.DataLines = [2, Inf]; % Data is on line 2 onwards
    opts.VariableNamesLine = 1;
    zipLogTable = readtable(zip_log_path, opts);
    
    numFiles = height(zipLogTable);
    fprintf('Found %d file entries to verify...\n', numFiles);
    
    % Add the new column for our results
    zipLogTable.PresentOnRemote = false(numFiles, 1);
    
    h_wait = waitbar(0, 'Verifying files on remote server...');

    for i = 1:numFiles
        % Update progress
        waitbar(i/numFiles, h_wait, sprintf('Verifying file %d of %d...', i, numFiles));
        
        % Extract the UID from the full file path
        [~, filename_uid, ~] = fileparts(zipLogTable.ZippedFile{i});
        
        % The UID should be a 33-character string with an underscore at position 17
        if numel(filename_uid) == 33 && filename_uid(17) == '_'
            uid_to_check = filename_uid;
            
            try
                % Attempt to get file details. If this succeeds, the file exists.
                ndi.cloud.api.datasets.get_file_details(cloudDatasetId, uid_to_check);
                zipLogTable.PresentOnRemote(i) = true;
            catch e
                % If an error is thrown, the file does not exist.
                % The 'PresentOnRemote' value remains false.
                fprintf('File with UID %s not found on remote. Error: %s\n', uid_to_check, e.message);
            end
        else
            warning('Row %d in zip log does not appear to contain a valid UID in the ZippedFile column: %s', i, zipLogTable.ZippedFile{i});
        end
    end
    
    delete(h_wait); % Close the waitbar

    fprintf('Verification complete. Writing inventory report to %s...\n', inventory_output_path);
    
    % Write the new table with the verification column
    writetable(zipLogTable, inventory_output_path);
    
    fprintf('Done.\n');
end