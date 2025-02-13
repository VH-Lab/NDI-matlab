function concatenateFiles(directory, outputFile, options)
%concatenateFiles Concatenates text files within a directory and its 
% subdirectories into a single output file.
%
%   concatenateFiles(directory, outputFile) concatenates all text files 
%   within the specified directory and its subdirectories into the 
%   specified output file.
%
%   concatenateFiles(directory, outputFile, options) allows specifying
%   optional parameters in the 'options' structure.
%
%   Inputs:
%       directory:  The path to the directory to search.
%       outputFile: The path to the output file.
%       options: A structure containing optional parameters:
%           'IgnoreFile': Path to a JSON file containing a list of files to
%                         ignore.  The JSON file should contain a JSON array
%                         of strings, where each string is a filename to
%                         ignore.
%           'Extensions': A cell array of strings specifying the file
%                         extensions to include (e.g., {'.txt', '.log'}).
%           'ParentDir':  A path to be prepended to the files in 'IgnoreFile'
%
%   Example:
%       concatenateFiles('my_data_dir', 'combined_data.txt');
%       options.IgnoreFile = 'ignore_list.json';
%       concatenateFiles('my_data_dir', 'combined_data.txt', options);
%       options.Extensions = {'.txt', '.csv'};
%       concatenateFiles('my_data_dir', 'combined_data.txt', options);
%       options.IgnoreFile = 'ignore_list.json';
%       options.Extensions = {'.txt'};
%       concatenateFiles('my_data_dir', 'combined_data.txt', options);
%
%   See also: dir, fopen, fprintf, fclose, jsondecode

arguments
    directory (1,:) {mustBeFolder(directory)}
    outputFile (1,:) {mustBeText}
    options.IgnoreFile (1,:) {mustBeText} = ''  % Default empty string
    options.Extensions (1,:) cell {mustBeText} = {} % Default empty cell array
    options.ParentDir (1,:) char {mustBeText} = '';
end

% Load ignore list if provided
ignoreList = {};
if ~isempty(options.IgnoreFile)
    try
        ignoreList = jsondecode(fileread(options.IgnoreFile));
        if ~iscellstr(ignoreList) %check if it's a cell array of strings
            error("Ignore file must contain a json array of strings.");
        end
        for i=1:numel(ignoreList)
            ignoreList{i} = [options.ParentDir filesep ignoreList{i}];
        end
    catch e
        warning('Error reading or parsing ignore file: %s. Ignoring ignore list.', e.message);
    end
end

% Open output file
fid = fopen(outputFile, 'w');
if fid == -1
    error('Could not open output file for writing.');
end

try
    % Find all files recursively
    files = dir(fullfile(directory, '**', '*')); % '**' for recursive search, '*' for all files
    files = files(~[files.isdir]); % Keep only files, remove directories.

    for i = 1:length(files)
        file = files(i);
        fullPath = fullfile(file.folder, file.name); % Construct full path

        % Check if file should be included
        [~, ~, ext] = fileparts(file.name);

        if ~isempty(options.Extensions) && ~any(strcmpi(ext, options.Extensions))
            continue; % Skip if extension doesn't match
        end

        if ~isempty(ignoreList) && any(strcmp(fullPath, ignoreList))
            continue; % Skip if file is in ignore list
        end

        try
            % Read and write file content
            fileFid = fopen(fullPath, 'r');
            if fileFid ~= -1
                fileContent = fread(fileFid, '*char')'; % Read the whole file at once.
                fclose(fileFid);

                if ~isempty(fileContent) % Check if the file is not empty.
                    fprintf(fid, '%s', fileContent);

                    % Add newline only if the content doesn't already end with one
                    if ~isempty(fileContent) && fileContent(end) ~= newline
                        fprintf(fid, '\n');
                    end
                end
            end
        catch e
            warning('Error processing file %s: %s', fullPath, e.message);
        end
    end
catch e
    fclose(fid);  % Close file in case of error
    rethrow(e); % Re-throw the error after closing the file.
end

% Close output file
fclose(fid);

end


