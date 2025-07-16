function mustBeID(inputArg)
%MUSTBEID Validate input is a correctly formatted NDI ID string.
%
%   ndi.validators.mustBeID(inputArg)
%
%   Validates that the input argument INPUTARG meets the NDI ID format criteria:
%     - Must be a character row vector or a string scalar.
%     - Must be exactly 33 characters long.
%     - Character at index 17 must be an underscore ('_').
%     - All other characters (1-16 and 18-33) must be alphanumeric (A-Z, a-z, 0-9).
%
%   This function is intended for use within function `arguments` blocks.
%   It throws an error with a descriptive message identifier ('NDI:Validation:InvalidID:...')
%   if the input does not meet the criteria.
%
%   Example Usage in an arguments block:
%      arguments
%          subjectID (1,1) {mustBeTextScalar, ndi.validators.mustBeID}
%      end
%
%   See also: mustBeTextScalar, ischar, isrow, numel, isstrprop

    % Ensure input is treated as char for checks (robust if string is passed)
    try
        inputChar = char(inputArg);
    catch
         error('NDI:Validation:InvalidID:NotConvertibleToChar', 'Input could not be converted to a character array.');
    end

    % 1. Check if it's effectively a char row vector after potential conversion
    if ~isrow(inputChar) && ~isempty(inputChar)
         error('NDI:Validation:InvalidID:NotCharRowVector', 'Input must be convertible to a character row vector.');
    end

    % 2. Check length
    expectedLength = 33;
    actualLength = numel(inputChar);
    if actualLength ~= expectedLength
        error('NDI:Validation:InvalidID:WrongLength', ...
            'Input must be exactly %d characters long (actual length was %d).', ...
            expectedLength, actualLength);
    end

    % 3. Check underscore at position 17
    if inputChar(17) ~= '_'
         error('NDI:Validation:InvalidID:MissingUnderscore', ...
               'Character 17 must be an underscore (_), but found ''%c''.', inputChar(17));
    end

    % 4. Check alphanumeric for other positions
    idx = true(1, expectedLength);
    idx(17) = false;
    charsToCheck = inputChar(idx);

    if ~all(isstrprop(charsToCheck, 'alphanum'))
        % Find the first invalid character for a slightly more helpful error
        firstInvalidIdx = find(~isstrprop(charsToCheck, 'alphanum'), 1, 'first');
        % Adjust index back to original string index
        originalInvalidIdx = find(idx);
        originalInvalidIdx = originalInvalidIdx(firstInvalidIdx);

        error('NDI:Validation:InvalidID:InvalidChars', ...
              'Characters 1-16 and 18-33 must be alphanumeric (A-Z, a-z, 0-9). Found invalid character ''%c'' at position %d.', ...
              inputChar(originalInvalidIdx), originalInvalidIdx);
    end

    % If all checks passed, the function completes silently.

end % function mustBeID
