function mustBeCellArrayOfNonEmptyCharacterArrays(value)
%MUSTBECELLARRAYOFNONEMPTYCHARACTERARRAYS Validates that input is a cell array of non-empty char vectors.
%
%   ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(VALUE)
%
%   This function is intended for use in an `arguments` block. It validates
%   that the input VALUE is a cell array, and that every element within the
%   cell array is a character vector that is not empty.
%
%   Inputs:
%       value - The input value to be validated.
%
%   Throws:
%       An error with a specific identifier if the input is not a cell array
%       or if any element is not a non-empty character vector.
%
%   Example:
%       % In a function definition:
%       arguments
%           inputNames (1,:) cell {ndi.validators.mustBeCellArrayOfNonEmptyCharacterArrays(inputNames)}
%       end
%
    
    % First, check if the input is a cell array
    if ~iscell(value)
        error('ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InputNotCell', ...
            'Input must be a cell array.');
    end
    
    % If the cell array is not empty, check each element
    if ~isempty(value)
        for i = 1:numel(value)
            val_here = value{i};
            % Check if the element is a char vector and is not empty
            if ~(ischar(val_here) && ~isempty(val_here))
                error('ndi:validators:mustBeCellArrayOfNonEmptyCharacterArrays:InvalidCellContent', ...
                    'All elements of the cell array must be non-empty character vectors. Element %d is not.', i);
            end
        end
    end
end
