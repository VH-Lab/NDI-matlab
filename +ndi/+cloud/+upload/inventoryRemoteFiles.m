function inventoryRemoteFiles(cloudDatasetId, options)
% INVENTORYREMOTEFILES - Verifies the presence and contents of zipped files on the remote server.
%
%   inventoryRemoteFiles(CLOUDDATASETID)
%   inventoryRemoteFiles(CLOUDDATASETID, 'VerifyContents', true)
%
%   This function reads 'zip_log.csv' and, for each file, queries the NDI
%   server to see if a file with the corresponding UID exists.
%
%   It generates 'zipFileInventory.csv' which is a copy of 'zip_log.csv'
%   plus an additional column, 'PresentOnRemote' (true/false).
%
%   Name-Value Options:
%    'VerifyContents' - A logical (true/false) to control whether the function
%                       should download the remote file and perform a byte-by-byte
%                       comparison with the local file. Defaults to false. If true,
%                       an additional 'ContentsMatch' column is added to the report.
%
%   Inputs:
%    cloudDatasetId - The character string ID of the dataset on the NDI server.
%
arguments
    cloudDatasetId (1,:) char {mustBeTextScalar}
    options.VerifyContents (1,1) logical = false
end

    log_folder = ndi.common.PathConstants.LogFolder;
    zip_log_path = fullfile(log_folder, 'zip_log.csv');
    inventory_output_path = fullfile(log_folder, 'zipFileInventory.csv');

    if ~isfile(zip_log_path)
        error('The zip log file "%s" does not exist. Please run the upload function with DebugLog enabled first.', zip_log_path);
    end

    fprintf('Reading zip log file...\n');
    % Use specific import options to read the log file reliably
    opts = delimitedTextImportOptions("NumVariables", 3);
    opts.DataLines = [2, Inf];
    opts.Delimiter = ",";
    opts.VariableNames = ["ZipFile", "ZippedFile", "UncompressedBytes"];
    opts.VariableTypes = ["string", "string", "double"];
    zipLogTable = readtable(zip_log_path, opts);
    
    numFiles = height(zipLogTable);
    fprintf('Found %d file entries to verify...\n', numFiles);
    
    % Add the new columns for our results
    zipLogTable.PresentOnRemote = false(numFiles, 1);
    if options.VerifyContents
        zipLogTable.ContentsMatch = false(numFiles, 1);
    end
    
    h_wait = waitbar(0, 'Verifying files on remote server...');
    cleanupObj = onCleanup(@() delete(h_wait(ishandle(h_wait))));

    for i = 1:numFiles
        waitbar(i/numFiles, h_wait, sprintf('Verifying file %d of %d...', i, numFiles));
        
        [~, filename_uid, ~] = fileparts(zipLogTable.ZippedFile{i});
        
        if numel(filename_uid) == 33 && filename_uid(17) == '_'
            uid_to_check = filename_uid;
            
            try
                % Check for file existence by getting its details
                [~, downloadURL, ~] = ndi.cloud.api.datasets.get_file_details(cloudDatasetId, uid_to_check);
                zipLogTable.PresentOnRemote(i) = true;

                % --- CONTENT VERIFICATION LOGIC ---
                if options.VerifyContents
                    waitbar(i/numFiles, h_wait, sprintf('Downloading file %d of %d for verification...', i, numFiles));
                    
                    % Download remote file to a temporary location
                    temp_remote_file = [tempname, '.bin'];
                    websave(temp_remote_file, downloadURL);

                    % Read local and downloaded files as binary data
                    fid_local = fopen(zipLogTable.ZippedFile{i}, 'rb');
                    local_bytes = fread(fid_local, '*uint8');
                    fclose(fid_local);

                    fid_remote = fopen(temp_remote_file, 'rb');
                    remote_bytes = fread(fid_remote, '*uint8');
                    fclose(fid_remote);

                    % Cleanup the temporary file
                    delete(temp_remote_file);
                    
                    % Perform byte-for-byte comparison
                    if isequal(local_bytes, remote_bytes)
                        zipLogTable.ContentsMatch(i) = true;
                    end
                end

            catch e
                fprintf('File with UID %s not found or could not be verified on remote. Error: %s\n', uid_to_check, e.message);
            end
        else
            warning('Row %d in zip log does not appear to contain a valid UID in the ZippedFile column: %s', i, zipLogTable.ZippedFile{i});
        end
    end

    fprintf('Verification complete. Writing inventory report to %s...\n', inventory_output_path);
    writetable(zipLogTable, inventory_output_path);
    fprintf('Done.\n');
end