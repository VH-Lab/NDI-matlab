function S_out = Struct2AlphaNumericStruct(S_in)
%STRUCT2ALPHANUMERICSTRUCT Converts an arbitrary structure to one containing
%only alphanumeric data (numbers, char arrays) or other (sub)structures.
%
%   S_OUT = ndi.util.Struct2AlphaNumericStruct(S_IN)
%
%   Inputs:
%       S_IN (1,1 struct): The input structure to convert.
%
%   Outputs:
%       S_OUT (struct): The converted structure. Leaf nodes will be numeric,
%                       logical, or character arrays. Cell arrays of strings
%                       are converted to comma-separated character arrays.
%                       String arrays/scalars are converted to comma-separated char arrays.
%
%   Description:
%       The function recursively traverses the input structure S_IN.
%       - Numeric and logical fields are kept as is.
%       - Character array fields are kept as is.
%       - String array/scalar fields are converted to comma-separated character arrays.
%       - Cell arrays containing only character arrays or scalar strings are
%         joined into a single comma-separated character array.
%       - Structures and structure arrays are traversed recursively.
%       - Any other data types (e.g., cell arrays with mixed types, tables,
%         function handles, other objects) will cause an error.
%
%   Example:
%       s.a = 10;
%       s.b = 'hello';
%       s.c = "world"; % string scalar
%       s.d = {"alpha", "beta", "gamma"}; % cell array of strings
%       s.e.f = 20;
%       s.e.g = ["string1"; "string2"]; % string array
%       s.h(1).i = 30;
%       s.h(2).i = 40;
%       s.h(2).j = {'part1', 'part2'};
%
%       s_out = ndi.util.Struct2AlphaNumericStruct(s);
%       % s_out.c will be 'world' (char)
%       % s_out.d will be 'alpha, beta, gamma' (char)
%       % s_out.e.g will be 'string1, string2' (char)
%       % s_out.h(2).j will be 'part1, part2' (char)
%
%       s_invalid.k = {1, 'mixed'};
%       % Calling ndi.util.Struct2AlphaNumericStruct(s_invalid) will error.

    arguments
        S_in (1,1) struct % Input must be a scalar structure at the top level
    end

    S_out = convertElementValueRecursive(S_in, 'S_in'); % Provide a base name for path tracking

end

% --- Local Recursive Helper Function ---
function convertedValue = convertElementValueRecursive(value, currentPath)
%convertElementValueRecursive Helper to process individual elements.

    if isstruct(value)
        if isempty(value) % Handles struct([]) or 0xN struct array if all fields are removed
            convertedValue = value; % Return empty struct/array as is
            return;
        end
        
        % Process struct or struct array
        if isscalar(value)
            tempStruct = value; % Work on a copy for scalar struct
            fieldNames = fieldnames(value);
            if isempty(fieldNames) % Handles struct() which is scalar but has no fields
                convertedValue = value;
                return;
            end
            for i = 1:numel(fieldNames)
                fn = fieldNames{i};
                fieldPath = [currentPath '.' fn];
                tempStruct.(fn) = convertElementValueRecursive(value.(fn), fieldPath);
            end
            convertedValue = tempStruct;
        else % Struct array
            convertedValue = value; % Start with a copy to preserve structure
            for k = 1:numel(value)
                elementPathForArrayElement = sprintf('%s(%d)', currentPath, k);
                % Recursively convert the k-th struct in the array.
                convertedValue(k) = convertElementValueRecursive(value(k), elementPathForArrayElement);
            end
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
                                       % cellstr of scalar "" is {''}, cellstr of empty string array is empty cell {}
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
