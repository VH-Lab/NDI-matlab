function recreateZipFile(zipfilename)
% RECREATEZIPFILE - Re-creates a specific zip file from the zip_log.csv.
%
%   recreateZipFile(ZIPFILENAME)
%
%   This function reads the 'zip_log.csv' file to find all the files that
%   were included in a specific zip archive named ZIPFILENAME. It then
%   gathers those original files and creates a new zip archive with the
%   same name in the NDI log folder.
%
%   This is a debugging tool to allow inspection of the exact contents of any
%   given zip file that was generated during the upload process.
%
%   If an existing file with the same name is found in the log folder, it
%   will be overwritten.
%
%   Inputs:
%    zipfilename - The character string filename of the zip file to recreate
%                  (e.g., 'tmpABC123.zip').
%

    log_folder = ndi.common.PathConstants.LogFolder;
    zip_log_path = fullfile(log_folder, 'zip_log.csv');

    if ~isfile(zip_log_path)
        error('The zip log file "%s" does not exist. Please run the upload function with DebugLog enabled first.', zip_log_path);
    end

    fprintf('Reading zip log file: %s\n', zip_log_path);

    % Use specific import options to read the log file reliably
    opts = delimitedTextImportOptions("NumVariables", 3);
    opts.DataLines = [2, Inf];
    opts.Delimiter = ",";
    opts.VariableNames = ["ZipFile", "ZippedFile", "UncompressedBytes"];
    opts.VariableTypes = ["string", "string", "double"];
    zipLogTable = readtable(zip_log_path, opts);

    % Find all entries for the requested zip file
    matching_rows = zipLogTable(strcmp(zipLogTable.ZipFile, zipfilename), :);

    if isempty(matching_rows)
        error('Could not find any entries for zip file "%s" in the log.', zipfilename);
    end
    
    files_to_zip = matching_rows.ZippedFile;
    
    output_zip_path = fullfile(log_folder, zipfilename);

    fprintf('Found %d files for archive "%s". Re-creating it at %s...\n', height(matching_rows), zipfilename, output_zip_path);

    % If the target zip file already exists, delete it first to ensure we are creating it fresh
    if isfile(output_zip_path)
        delete(output_zip_path);
    end
    
    % Create the new zip file
    zip(output_zip_path, files_to_zip);

    fprintf('Successfully re-created zip file: %s\n', output_zip_path);

end