function mustBeTextLike(value)
%MUSTBETEXTLIKE Validates that input is a character vector, string, or cell array of text.
%
%   ndi.validators.mustBeTextLike(VALUE)
%
%   This function is intended for use in an `arguments` block. It validates
%   that the input VALUE is one of the following:
%     - A character vector (e.g., 'hello')
%     - A string scalar (e.g., "world")
%     - A cell array where every element is either a character vector or a string.
%
%   Inputs:
%       value - The input value to be validated.
%
%   Throws:
%       An error with a specific identifier if the input does not meet one of
%       the allowed text-like formats.
%
%   Example:
%       % In a function definition:
%       arguments
%           input_a (1,:) char {ndi.validators.mustBeTextLike(input_a)}
%           input_b (1,1) string {ndi.validators.mustBeTextLike(input_b)}
%           input_c (1,:) cell {ndi.validators.mustBeTextLike(input_c)}
%       end
%
    
    % Check for the most common single-item cases first
    if ischar(value) || isstring(value)
        return; % It's valid
    end

    % If it's a cell, check its contents
    if iscell(value)
        % Check if all elements are either char or string
        isTextElement = cellfun(@(x) ischar(x) || isstring(x), value);
        if all(isTextElement(:)) % Use (:) to handle any shape of cell array
            return; % It's a valid cell array of text
        end
    end

    % If we've reached this point, the type is not valid
    error('ndi:validators:mustBeTextLike:InvalidType', ...
        'Input must be a character vector, a string, or a cell array of character vectors/strings.');
end
