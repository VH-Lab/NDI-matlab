% Filename: +ndi/+validator/mustBeID.m

function mustBeID(inputArg)
%MUSTBEID Validate input is a correctly formatted NDI ID string.
%
%   ndi.validator.mustBeID(inputArg)
%
%   Validates that the input argument INPUTARG meets the NDI ID format criteria:
%     - Must be a character row vector.
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
%          subjectID (1,1) {mustBeTextScalar, ndi.validator.mustBeID}
%      end
%
%   See also: mustBeTextScalar, ischar, isrow, numel, isstrprop

    % Define a prefix for error identifiers
    eid_prefix = 'NDI:Validation:InvalidID';

    % Ensure input is treated as char for checks (robust if string is passed)
    try
        inputChar = char(inputArg);
    catch
         error(eid_prefix + ':NotConvertibleToChar', 'Input could not be converted to a character array.');
    end

    % 1. Check if it's effectively a char row vector after potential conversion
    %    (mustBeTextScalar in calling function often handles the initial type/shape)
    if ~isrow(inputChar) && ~isempty(inputChar) % Allow empty string to be caught by length check
         error(eid_prefix + ':NotCharRowVector', 'Input must be convertible to a character row vector.');
    end

    % 2. Check length
    expectedLength = 33;
    actualLength = numel(inputChar); % Use numel, works for empty too
    if actualLength ~= expectedLength
        error(eid_prefix + ':WrongLength', ...
            'Input must be exactly %d characters long (actual length was %d).', ...
            expectedLength, actualLength);
    end

    % 3. Check underscore at position 17
    if inputChar(17) ~= '_'
         error(eid_prefix + ':MissingUnderscore', ...
               'Character 17 must be an underscore (_), but found ''%c''.', inputChar(17));
    end

    % 4. Check alphanumeric for other positions
    % Create logical index for characters *not* at position 17
    idx = true(1, expectedLength);
    idx(17) = false;
    charsToCheck = inputChar(idx);

    if ~all(isstrprop(charsToCheck, 'alphanum'))
        % Find the first invalid character for a slightly more helpful error
        firstInvalidIdx = find(~isstrprop(charsToCheck, 'alphanum'), 1, 'first');
        % Adjust index back to original string index
        originalInvalidIdx = find(idx, firstInvalidIdx, 'first');
        if isempty(originalInvalidIdx), originalInvalidIdx = NaN; end % Should not happen if check failed

        error(eid_prefix + ':InvalidChars', ...
              'Characters 1-16 and 18-33 must be alphanumeric (A-Z, a-z, 0-9). Found invalid character ''%c'' at position %d.', ...
              inputChar(originalInvalidIdx), originalInvalidIdx);
    end

    % If all checks passed, the function completes silently.

end % function mustBeID


