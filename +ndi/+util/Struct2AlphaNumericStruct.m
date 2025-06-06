function S_out = Struct2AlphaNumericStruct(S_in, options)
%STRUCT2ALPHANUMERICSTRUCT Converts an arbitrary structure array to one containing
%only alphanumeric data.
%
%   S_OUT = ndi.util.Struct2AlphaNumericStruct(S_IN)
%   S_OUT = ndi.util.Struct2AlphaNumericStruct(S_IN, 'Delimiter', DELIM)
%
%   Inputs:
%       S_IN (struct): The input structure array to convert. Can be any size.
%
%   Name-Value Pairs:
%       Delimiter (char vector): The delimiter to use when joining
%           cell arrays of strings. Defaults to ', '.
%
%   Outputs:
%       S_OUT (struct): The converted structure array, returned with the same
%                       dimensions as S_IN. datetime objects are converted to
%                       ISO 8601 character vectors.

    arguments
        S_in struct
        options.Delimiter (1,:) char = ', ' % Optional name-value pair
    end
    
    S_out = convertElementValueRecursive(S_in, 'S_in', options.Delimiter);

end

% --- Local Recursive Helper Function ---
function convertedValue = convertElementValueRecursive(value, currentPath, delimiter)
%convertElementValueRecursive Helper to process individual elements.

    if isstruct(value)
        if isempty(value)
            convertedValue = value;
            return;
        end
        
        convertedValue = value; 
        for k = 1:numel(value)
            elementPathForArrayElement = currentPath;
            if ~isscalar(value)
                if isvector(value)
                    elementPathForArrayElement = sprintf('%s(%d)', currentPath, k);
                else
                    siz = size(value);
                    sub_indices = cell(1, numel(siz));
                    [sub_indices{:}] = ind2sub(siz, k);
                    elementPathForArrayElement = sprintf('%s(%s)', currentPath, strjoin(cellfun(@num2str, sub_indices, 'UniformOutput', false), ','));
                end
            end

            tempStruct = value(k);
            fieldNames = fieldnames(tempStruct);
            if isempty(fieldNames)
                continue; 
            end
            for i = 1:numel(fieldNames)
                fn = fieldNames{i};
                fieldPath = [elementPathForArrayElement '.' fn];
                tempStruct.(fn) = convertElementValueRecursive(tempStruct.(fn), fieldPath, delimiter);
            end
            convertedValue(k) = tempStruct;
        end

    elseif iscell(value)
        if isempty(value)
            convertedValue = ''; 
        else
            isAllCharOrString = all(cellfun(@(x) (ischar(x) && (isrow(x) || isempty(x))) || (isstring(x) && isscalar(x)), value));
            
            if isAllCharOrString
                charCell = cellfun(@char, value, 'UniformOutput', false);
                convertedValue = strjoin(charCell, delimiter);
            else
                firstNonStringIdx = find(~cellfun(@(x) (ischar(x) && (isrow(x) || isempty(x))) || (isstring(x) && isscalar(x)), value), 1);
                firstNonStringType = class(value{firstNonStringIdx});
                error('ndi:util:Struct2AlphaNumericStruct:InvalidCellContent', ...
                      'Field "%s" is a cell array that does not exclusively contain text. Encountered type: %s.', ...
                      currentPath, firstNonStringType);
            end
        end
    elseif isstring(value)
        if isempty(value) && ~(isscalar(value) && value == "")
            convertedValue = '';
        else
            charCell = cellstr(value); 
            if isempty(charCell)
                convertedValue = '';
            else
                convertedValue = strjoin(charCell(:)', delimiter);
            end
        end
    elseif isdatetime(value)
        % Corrected: Handle datetime objects using MATLAB syntax
        if isempty(value) || all(isnat(value(:)))
            convertedValue = '';
        else
            % Ensure timezone is UTC for consistent ISO 8601 representation
            value.TimeZone = 'UTC';
            % Set the display format to ISO 8601 with milliseconds and 'Z' for UTC
            value.Format = 'yyyy-MM-dd''T''HH:mm:ss.SSS''Z''';
            % Convert to string, then to char array
            convertedValue = char(string(value));
        end
    elseif isnumeric(value) || islogical(value) || ischar(value)
        convertedValue = value;
    else
        error('ndi:util:Struct2AlphaNumericStruct:UnsupportedType', ...
              'Field "%s" contains an unsupported data type: %s.', ...
              currentPath, class(value));
    end
end