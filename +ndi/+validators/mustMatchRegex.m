function mustMatchRegex(value, pattern)
%MUSTMATCHREGEX Custom validation function to ensure input matches a regular expression.
%   MUSTMATCHREGEX(VALUE, PATTERN) checks if the input VALUE matches the
%   regular expression specified by PATTERN. If VALUE does not match PATTERN,
%   the function throws an error.
%
%   This function is intended for use within an arguments block.
%
%   Inputs:
%       VALUE   - The value being validated. Must be a character row vector
%                 or a string scalar.
%       PATTERN - The regular expression pattern (char row vector or string scalar)
%                 that VALUE must match.
%
%   Outputs:
%       (None) - Throws an error if validation fails.
%
%   Error Conditions:
%       - Throws 'ndi:validators:mustMatchRegex:InvalidInputType' if VALUE
%         is not a character row vector or string scalar.
%       - Throws 'ndi:validators:mustMatchRegex:NoMatch' if VALUE does not
%         match the PATTERN.
%
%   Example Usage in arguments block:
%       arguments
%           inputCode (1,:) char {mustBeNonempty, ndi.validators.mustMatchRegex(inputCode, '^[A-Z]{3}\d{5}$')}
%       end
%
%   See also: arguments, regexp

% --- Input Type Validation ---
% Ensure the value itself is appropriate for regex matching (char or string)
if ~( (ischar(value) && isrow(value)) || (isstring(value) && isscalar(value)) )
    error('ndi:validators:mustMatchRegex:InvalidInputType', ...
          'Input value must be a character row vector or a string scalar to be validated with mustMatchRegex.');
end

% --- Pattern Type Validation (Optional but good practice) ---
if ~( (ischar(pattern) && isrow(pattern)) || (isstring(pattern) && isscalar(pattern)) )
     error('ndi:validators:mustMatchRegex:InvalidPatternType', ...
           'Pattern provided to mustMatchRegex must be a character row vector or a string scalar.');
end

% --- Perform Regex Match ---
% Convert value to char for regexp consistency if it's a string
value_char = char(value);
pattern_char = char(pattern); % Convert pattern too for consistency

% Use regexp with '^' and '$' implicitly applied by checking the entire string match
% Use 'once' to stop after the first match (efficient for validation)
matchResult = regexp(value_char, ['^(' pattern_char ')$'], 'once'); % Ensure full string match

% --- Throw Error if No Match ---
if isempty(matchResult)
    % Use inputname(1) to try and get the variable name being validated for a better error message
    varName = inputname(1);
    if isempty(varName)
        varName = 'Input value'; % Fallback if called outside arguments block or name not captured
    end
    error('ndi:validators:mustMatchRegex:NoMatch', ...
          '%s ("%s") does not match the required pattern: "%s".', ...
          varName, value_char, pattern_char);
end

end

