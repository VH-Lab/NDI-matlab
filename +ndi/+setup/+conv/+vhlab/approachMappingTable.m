function T = approachMappingTable(S, varargin)
% APPROACHMAPPINGTABLE - Creates a table of epoch approach mappings for an NDI session.
%
% T = APPROACHMAPPINGTABLE(S, ...)
%
% Creates a table with variables 'epochid', 'approachMapping', 'subjectIdentifier',
% and 'sessionPath'.
%
% This function reads a list of epochs and their types from a file within the NDI
% session directory. It then uses a JSON mapping file to expand these types into
% descriptive strings.
%
% It takes an ndi.session.dir object 'S' as input.
%
% This function can also take name/value pairs that modify its behavior:
% |--------------------------|----------------------------------------------------|
% | 'json_filename'          | The full path to the JSON file that contains the   |
% |                          | name/value mappings. Default is a file included    |
% |                          | with the NDI toolbox:                              |
% |                          | fullfile(ndi.toolboxdir, '+ndi', '+setup', ...     |
% |                          |   '+conv', '+vhlab', 'ApproachMappings.json')      |
% | 'epoch_list_filename'    | The name of the tab-delimited file in the session  |
% |                          | directory that lists epoch IDs and types.          |
% |                          | Default is 'testdirinfo.txt'.                      |
% |--------------------------|----------------------------------------------------|

% Example:
%   % Assuming 'mySession' is a valid ndi.session.dir object
%   mySession = ndi.session.dir('/path/to/my/session');
%   mapping_table = approachMappingTable(mySession);
%   disp(mapping_table);
%

    % --- Input Parsing ---
    % Define default values
    default_json_filename = fullfile(ndi.toolboxdir, '+ndi', '+setup', '+conv', '+vhlab', 'ApproachMappings.json');
    default_epoch_list_filename = 'testdirinfo.txt';

    % Setup input parser
    p = inputParser;
    addRequired(p, 'S', @(x) isa(x, 'ndi.session.dir'));
    addParameter(p, 'json_filename', default_json_filename, @ischar);
    addParameter(p, 'epoch_list_filename', default_epoch_list_filename, @ischar);

    % Parse the inputs
    parse(p, S, varargin{:});
    json_filename = p.Results.json_filename;
    epoch_list_filename = p.Results.epoch_list_filename;

    % --- File Paths and Initial Data Reading ---
    sessionPath = S.getpath();
    epoch_list_fullfile = fullfile(sessionPath, epoch_list_filename);
    subject_file = fullfile(sessionPath, 'subject.txt');

    % Verify required files exist
    if ~exist(epoch_list_fullfile, 'file')
        error('Epoch list file not found: %s', epoch_list_fullfile);
    end
    if ~exist(json_filename, 'file')
        error('JSON mapping file not found: %s', json_filename);
    end
    if ~exist(subject_file, 'file')
        error('Subject file not found: %s', subject_file);
    end

    % Read subject identifier
    subjectIdentifier = strtrim(fileread(subject_file));

    % Read the tab-delimited epoch list
    % We use readtable, which is robust for handling headers and different delimiters
    opts = detectImportOptions(epoch_list_fullfile, 'FileType', 'text');
    opts.Delimiter = '\t'; % Ensure tab is the delimiter
    epochInfo = readtable(epoch_list_fullfile, opts);
    % Standardize variable names for easier access
    epochInfo.Properties.VariableNames = {'epochid', 'type'};

    % Read and decode the JSON mapping file
    json_string = fileread(json_filename);
    mappings_data = jsondecode(json_string);
    mappings = mappings_data.approachMappings; % Access the array of structs

    % --- Processing and Table Construction ---

    % For efficiency, we will pre-calculate the total number of rows for the final table
    % and build a cell array, which is faster than appending to a table in a loop.
    
    % Create a map for quick lookup of how many mappings each type has
    type_counts = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:numel(mappings)
        typeName = mappings(i).name;
        if isKey(type_counts, typeName)
            type_counts(typeName) = type_counts(typeName) + 1;
        else
            type_counts(typeName) = 1;
        end
    end
    
    % Calculate total rows needed
    total_rows = 0;
    for i = 1:height(epochInfo)
        current_type = epochInfo.type{i};
        if isKey(type_counts, current_type)
            total_rows = total_rows + type_counts(current_type);
        end
    end

    % Pre-allocate a cell array for the results
    output_data = cell(total_rows, 4);
    
    currentRow = 1; % A pointer to the current row to fill in the cell array
    
    % Iterate through each epoch in the list
    for i = 1:height(epochInfo)
        epoch_id = epochInfo.epochid{i};
        epoch_type = epochInfo.type{i};
        
        % Find all matching mappings for the current epoch type
        for j = 1:numel(mappings)
            if strcmp(mappings(j).name, epoch_type)
                % A match is found, add a row to our output data
                output_data(currentRow, :) = { ...
                    epoch_id, ...
                    mappings(j).value, ...
                    subjectIdentifier, ...
                    sessionPath ...
                };
                currentRow = currentRow + 1;
            end
        end
    end

    % Convert the cell array to the final table with specified variable names
    T = cell2table(output_data, 'VariableNames', ...
        {'epochid', 'approachMapping', 'subjectIdentifier', 'sessionPath'});

end
