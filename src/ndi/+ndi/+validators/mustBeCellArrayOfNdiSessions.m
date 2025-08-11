function mustBeCellArrayOfNdiSessions(value)
%MUSTBECELLARRAYOFNDISESSIONS Validates that the input is a cell array of ndi.session.dir objects.
%
%   ndi.validators.mustBeCellArrayOfNdiSessions(VALUE)
%
%   This function is intended for use in an `arguments` block to validate
%   that a function input is a cell array where every element is an object of
%   the class `ndi.session.dir`. It throws an error if the validation fails.
%
%   Inputs:
%       value - The input value to be validated.
%
%   Throws:
%       An error with a specific identifier if the input is not a cell array
%       or if any element within the cell array is not an `ndi.session.dir` object.
%
%   Example:
%       % In a function definition:
%       arguments
%           sessionList (1,:) cell {ndi.validators.mustBeCellArrayOfNdiSessions(sessionList)}
%       end
%
    
    % First, check if the input is a cell array
    if ~iscell(value)
        error('ndi:validators:mustBeCellArrayOfNdiSessions:InputNotCell', ...
            'Input must be a cell array.');
    end
    
    % If the cell array is not empty, check each element
    if ~isempty(value)
        for i = 1:numel(value)
            % Check if the element at index i is an object of class 'ndi.session.dir'
            if ~isa(value{i}, 'ndi.session.dir')
                error('ndi:validators:mustBeCellArrayOfNdiSessions:InvalidCellContent', ...
                    'All elements of the cell array must be ndi.session.dir objects. Element %d is of class ''%s''.', ...
                    i, class(value{i}));
            end
        end
    end
end
