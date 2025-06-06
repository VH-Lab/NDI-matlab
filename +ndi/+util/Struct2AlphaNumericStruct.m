function S_out = Struct2AlphaNumericStruct(S_in)
%STRUCT2ALPHANUMERICSTRUCT Converts an arbitrary structure array to one containing
%only alphanumeric data (numbers, char arrays) or other (sub)structures.
%
%   S_OUT = ndi.util.Struct2AlphaNumericStruct(S_IN)
%
%   Inputs:
%       S_IN (struct): The input structure array to convert. Can be any size.
%
%   Outputs:
%       S_OUT (struct): The converted structure array, returned with the same
%                       dimensions as S_IN. Leaf nodes will be numeric,
%                       logical, or character arrays. Cell arrays of strings
%                       are converted to comma-separated character arrays.
%                       String arrays/scalars are converted to comma-separated char arrays.
%
%   Description:
%       The function iterates through each element of the input structure array
%       S_IN and recursively traverses its fields.

    arguments
        S_in struct % Input can be a struct array of any size
    end

    S_out = convertElementValueRecursive(S_in, 'S_in'); % Provide a base name for path tracking

end

% --- Local Recursive Helper Function ---
function convertedValue = convertElementValueRecursive(value, currentPath)
%convertElementValueRecursive Helper to process individual elements.

    if isstruct(value)
        if isempty(value) % Handles struct([]) or 0xN struct array
            convertedValue = value; % Return empty struct/array as is
            return;
        end
        
        % Process struct or struct array by element
        convertedValue = value; % Start with a copy to preserve structure and size
        for k = 1:numel(value)
            elementPathForArrayElement = currentPath;
            if ~isscalar(value) % Only add index to path if it's an array
                if isvector(value)
                    % Use linear index for vectors
                    elementPathForArrayElement = sprintf('%s(%d)', currentPath, k);
                else
                    % Use ind2sub for multi-dimensional arrays
                    siz = size(value);
                    sub_indices = cell(1, numel(siz));
                    [sub_indices{:}] = ind2sub(siz, k);
                    elementPathForArrayElement = sprintf('%s(%s)', currentPath, strjoin(cellfun(@num2str, sub_indices, 'UniformOutput', false), ','));
                end
            end

            % Recursively convert the k-th struct element's fields
            tempStruct = value(k); % Get scalar struct
            fieldNames = fieldnames(tempStruct);
            if isempty(fieldNames)
                % Handles struct() which has no fields, no change needed
                continue; 
            end
            for i = 1:numel(fieldNames)
                fn = fieldNames{i};
                fieldPath = [elementPathForArrayElement '.' fn];
                tempStruct.(fn) = convertElementValueRecursive(tempStruct.(fn), fieldPath);
            end
            convertedValue(k) = tempStruct;
        end

    elseif iscell(value)
        if isempty(value)
            convertedValue = ''; % Empty cell becomes empty char
        else
            isAllCharOrString = true;
            firstNonStringType = '';
            for i = 1:numel(value)
                % Each cell element must be a char row vector or a scalar string
                if ~((ischar(value{i}) && (isrow(value{i}) || isempty(value{i}))) || ...
                     (isstring(value{i}) && isscalar(value{i})))
                    isAllCharOrString = false;
                    firstNonStringType = class(value{i});
                    break;
                end
            end
            if isAllCharOrString
                % Convert all to char for strjoin (handles strings correctly)
                charCell = cellfun(@char, value, 'UniformOutput', false);
                convertedValue = strjoin(charCell, ', ');
            else
                error('ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                      'Field "%s" is a cell array that does not exclusively contain character arrays (row vectors) or scalar strings. Encountered type: %s.', ...
                      currentPath, firstNonStringType);
            end
        end
    elseif isstring(value)
        % Convert string array/scalar to a cell array of char vectors, then join.
        if isempty(value) && ~(isscalar(value) && value == "") % handles strings(0,N) etc. but not scalar ""
            convertedValue = '';
        else % handles scalar strings (including "") and non-empty string arrays
            charCell = cellstr(value); % Convert to cell array of char vectors
            if isempty(charCell)
                convertedValue = '';
            else
                convertedValue = strjoin(charCell(:)', ', '); % Join, ensuring row vector for strjoin
            end
        end
    elseif isnumeric(value) || islogical(value) % Logical is also numeric
        convertedValue = value; % Keep as is
    elseif ischar(value)
        convertedValue = value; % Keep as is
    else
        % Unsupported type
        error('ndi:util:Struct2AlphaNumericStruct:UnsupportedType', ...
              'Field "%s" contains an unsupported data type: %s.', ...
              currentPath, class(value));
    end
end