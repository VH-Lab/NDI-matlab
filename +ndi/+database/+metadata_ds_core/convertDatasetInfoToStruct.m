function datasetInfoStruct = convertDatasetInfoToStruct(datasetInfo)
%CONVERTDATASETINFOTOSTRUCT Converts datasetInfo to an NDI document-compatible structure.
%   DATASETINFOSTRUCT = ndi.database.metadata_ds_core.convertDatasetInfoToStruct(DATASETINFO)
%
%   This function takes a datasetInfo structure (typically from the
%   MetadataEditorApp's DatasetInformationStruct property, which itself is
%   built from UI components and data objects like AuthorData, SubjectData)
%   and prepares it as a plain structure (datasetInfoStruct). This output
%   structure is formatted to be suitable for creating an ndi.document of
%   type 'ndi.metadata.metadata_editor'.
%
%   Key conversions performed:
%   - For 'Description' field: ensures it's a cell array of character vectors.
%     If originally char, it's wrapped in a cell. If originally cell, it's preserved.
%   - Other cell arrays of strings/chars (e.g., DataType, TechniquesEmployed) are 
%     converted to a single comma-separated character vector.
%   - String scalars or string arrays are converted to character vectors (or comma-separated char vectors).
%   - Datetime objects are converted to character vectors (ISO 8601 format: 'yyyy-mm-ddTHH:MM:SS').
%   - Numeric or logical scalars/arrays are converted to character vector representations.
%   - Nested structures are traversed to apply these conversions to their fields.
%
%   Inputs:
%       datasetInfo: A scalar struct containing the dataset information. This struct
%                    may contain various MATLAB data types including cell arrays,
%                    datetime objects, and nested structs. It's assumed that
%                    any custom class objects (like AuthorData, SubjectData)
%                    have already been converted to plain struct arrays (e.g.,
%                    via a .toStructs() method) before being passed into this function.
%
%   Outputs:
%       datasetInfoStruct: A scalar struct where problematic data types
%                          have been converted to character vectors or cell arrays of
%                          character vectors (for Description), suitable for NDI document processing.

    fprintf('DEBUG: convertDatasetInfoToStruct: Starting conversion.\n');
    if isempty(datasetInfo) || ~isstruct(datasetInfo) || ~isscalar(datasetInfo)
        warning('convertDatasetInfoToStruct:InvalidInput', 'Input datasetInfo must be a non-empty scalar struct. Returning empty struct.');
        datasetInfoStruct = struct();
        return;
    end

    datasetInfoStruct = datasetInfo; % Work on a copy

    fprintf('DEBUG: convertDatasetInfoToStruct: Performing initial type-specific conversions.\n');

    % Handle ReleaseDate (convert datetime to ISO 8601 string)
    if isfield(datasetInfoStruct, 'ReleaseDate') && isdatetime(datasetInfoStruct.ReleaseDate)
        if isnat(datasetInfoStruct.ReleaseDate)
            datasetInfoStruct.ReleaseDate = ''; 
            fprintf('DEBUG: Converted ReleaseDate (NaT) to empty char.\n');
        else
            try
                if isempty(datasetInfoStruct.ReleaseDate.TimeZone)
                    datasetInfoStruct.ReleaseDate.TimeZone = 'local'; 
                end
                datasetInfoStruct.ReleaseDate = datestr(datasetInfoStruct.ReleaseDate, 'yyyy-mm-ddTHH:MM:SS'); 
                fprintf('DEBUG: Converted ReleaseDate to string: %s\n', datasetInfoStruct.ReleaseDate);
            catch ME_date
                fprintf(2, 'Warning: Could not convert ReleaseDate to string: %s. Setting to empty.\n', ME_date.message);
                datasetInfoStruct.ReleaseDate = '';
            end
        end
    elseif isfield(datasetInfoStruct, 'ReleaseDate') && isempty(datasetInfoStruct.ReleaseDate) 
         datasetInfoStruct.ReleaseDate = '';
         fprintf('DEBUG: ReleaseDate was empty, set to empty char.\n');
    end

    % --- Special handling for 'Description' to ensure it's a cell array of char for downstream strjoin(..., newline) ---
    if isfield(datasetInfoStruct, 'Description')
        fprintf('DEBUG: Processing Description field. Original Type: %s\n', class(datasetInfoStruct.Description));
        if ischar(datasetInfoStruct.Description)
            % If it's a char (single line or already multi-line with \n), wrap in cell
            datasetInfoStruct.Description = {datasetInfoStruct.Description};
            fprintf('DEBUG: Wrapped char Description in a cell.\n');
        elseif isstring(datasetInfoStruct.Description)
            % If it's a string array or scalar string, convert to cell array of char vectors
            datasetInfoStruct.Description = cellstr(datasetInfoStruct.Description);
            fprintf('DEBUG: Converted string Description to cellstr.\n');
        elseif iscell(datasetInfoStruct.Description)
            % Ensure all elements are char, handle empty cells
            datasetInfoStruct.Description = cellfun(@(c) ifthenelse(isempty(c),'',char(c)), datasetInfoStruct.Description, 'UniformOutput', false);
            fprintf('DEBUG: Ensured Description cell elements are char.\n');
        else
            % If it's some other type, convert to empty cell of char for safety
            fprintf(2, 'Warning: Description field was of unexpected type %s. Converting to empty cell.\n', class(datasetInfoStruct.Description));
            datasetInfoStruct.Description = {''};
        end
    end
    
    % --- Convert other specific fields that are often cell arrays of strings to comma-separated strings ---
    topLevelCellFieldsToJoinWithComma = {'DataType', 'ExperimentalApproach', 'TechniquesEmployed'};
    for k = 1:numel(topLevelCellFieldsToJoinWithComma)
        fieldName = topLevelCellFieldsToJoinWithComma{k};
        if isfield(datasetInfoStruct, fieldName) && (iscell(datasetInfoStruct.(fieldName)) || isstring(datasetInfoStruct.(fieldName)))
            currentValue = datasetInfoStruct.(fieldName);
            fprintf('DEBUG: Processing field for comma-join: %s, Original Type: %s\n', fieldName, class(currentValue));
            if iscell(currentValue)
                charValue = cellfun(@(c) ifthenelse(isempty(c),'',char(c)), currentValue, 'UniformOutput', false);
                datasetInfoStruct.(fieldName) = strjoin(charValue, ', ');
            elseif isstring(currentValue)
                datasetInfoStruct.(fieldName) = strjoin(cellstr(currentValue), ', ');
            end
            fprintf('DEBUG: Converted field %s to comma-joined string: "%s"\n', fieldName, datasetInfoStruct.(fieldName));
        end
    end
    
    fprintf('DEBUG: convertDatasetInfoToStruct: Starting recursive field processing.\n');
    datasetInfoStruct = processStructFields(datasetInfoStruct);

    fprintf('DEBUG: convertDatasetInfoToStruct: Conversion finished.\n');
end

function outStruct = processStructFields(inputStruct)
    % Recursively process fields of a struct or struct array.
    % For 'Description', 'authorRole', 'BiologicalSexList', 'StrainList': if cell, ensures cell of chars.
    % For other cell arrays of strings/chars: converts to comma-separated strings.
    % Converts string arrays/scalars to char/comma-separated char.
    % Converts datetime to char (ISO 8601).
    % Converts numeric/logical scalars/arrays to char representations.

    if ~isstruct(inputStruct)
        outStruct = inputStruct; 
        return;
    end

    outStruct = inputStruct; 
    
    fieldsToPreserveAsCellOfChar = {'Description', 'authorRole', 'BiologicalSexList', 'StrainList'};

    for i = 1:numel(inputStruct) 
        currentElement = inputStruct(i);
        fields = fieldnames(currentElement);
        
        for j = 1:numel(fields)
            fieldName = fields{j};
            value = currentElement.(fieldName);
            originalType = class(value);
            % fprintf('DEBUG (processStructFields): Processing field: %s (Element %d), Original Type: %s\n', fieldName, i, originalType);

            if ismember(fieldName, fieldsToPreserveAsCellOfChar)
                if ischar(value)
                    value = {value}; % Ensure it's a cell for consistency downstream if needed
                elseif isstring(value)
                    value = cellstr(value); % Convert string array to cell of char
                elseif iscell(value)
                    % Ensure all elements are char
                    value = cellfun(@(c) ifthenelse(isempty(c),'',char(c)), value, 'UniformOutput', false);
                else % If not char, string, or cell, convert to empty cell of char
                    value = {''};
                end
                % fprintf('DEBUG: Field %s (to preserve as cell) processed.\n', fieldName);
            elseif isstring(value)
                if isscalar(value)
                    value = char(value);
                else 
                    value = strjoin(value, ', '); 
                end
                % fprintf('DEBUG: Converted string field %s to char/joined char: "%s"\n', fieldName, value);
            elseif iscell(value)
                if all(cellfun(@(c) ischar(c) || isstring(c) || isempty(c), value))
                    charValue = cellfun(@(c) ifthenelse(isempty(c),'',char(c)), value, 'UniformOutput', false);
                    value = strjoin(charValue, ', ');
                    % fprintf('DEBUG: Converted cell field %s to joined char: "%s"\n', fieldName, value);
                else
                    try
                        value = char(jsonencode(value));
                        % fprintf('DEBUG: Converted complex cell field %s to JSON char string.\n', fieldName);
                    catch ME_json
                        fprintf(2, 'Warning: Could not jsonencode complex cell field %s: %s. Setting to empty char.\n', fieldName, ME_json.message);
                        value = '';
                    end
                end
            elseif isdatetime(value)
                if isnat(value)
                    value = '';
                else
                    if isempty(value.TimeZone), value.TimeZone = 'local'; end
                    value = datestr(value, 'yyyy-mm-ddTHH:MM:SS');
                end
                % fprintf('DEBUG: Converted datetime field %s to char: "%s"\n', fieldName, value);
            elseif isnumeric(value) || islogical(value)
                if isscalar(value)
                    value = char(string(value)); 
                else 
                    try
                        value = strjoin(cellstr(string(value(:)')),', ');
                    catch ME_numarray
                         fprintf(2, 'Warning: Could not convert numeric/logical array %s to string: %s. Using jsonencode.\n', fieldName, ME_numarray.message);
                         value = char(jsonencode(value));
                    end
                end
                % fprintf('DEBUG: Converted numeric/logical field %s to char: "%s"\n', fieldName, value);
            elseif isstruct(value)
                % fprintf('DEBUG: Field %s is a nested struct. Recursing.\n', fieldName);
                value = processStructFields(value); % Recursive call for nested structs
            elseif ~ischar(value) 
                fprintf(2, 'Warning: Field %s is of unhandled type %s. Attempting jsonencode.\n', fieldName, originalType);
                try
                    value = char(jsonencode(value));
                catch ME_unknown
                    fprintf(2, 'Warning: Could not jsonencode field %s of type %s: %s. Setting to empty char.\n', fieldName, originalType, ME_unknown.message);
                    value = '';
                end
            end
            outStruct(i).(fieldName) = value;
        end
    end
end

function result = ifthenelse(condition, trueval, falseval)
    if condition
        result = trueval;
    else
        result = falseval;
    end
end
