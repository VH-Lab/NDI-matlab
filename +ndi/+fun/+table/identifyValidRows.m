%IDENTIFYVALIDROWS Identifies valid rows in a MATLAB table based on specified criteria.
%
%   validInd = IDENTIFYVALIDROWS(variableTable)
%   Checks no specific variables. All rows are considered valid.
%
%   validInd = IDENTIFYVALIDROWS(variableTable, checkVariables)
%   Checks the variables specified in 'checkVariables' for NaN values by default.
%   Rows where any of the specified variables contain NaN are marked as invalid.
%
%   validInd = IDENTIFYVALIDROWS(variableTable, checkVariables, invalidValues)
%   Checks the variables in 'checkVariables' against corresponding 'invalidValues'.
%
%   INPUT ARGUMENTS:
%       variableTable: A MATLAB table. Rows typically correspond to observations
%                      and columns to variables.
%
%       checkVariables: (Optional) Names of variables within 'variableTable' to be checked.
%                      Can be a character vector, a string scalar, a string array,
%                      or a cell array of character vectors/strings.
%                      - Default: {}. If empty, the function returns all 'true' and no
%                        checks are performed, regardless of the 'invalidValues' input.
%                      - If a variable name is not found in 'variableTable', a warning
%                        is issued and that check is skipped.
%
%       invalidValues: (Optional) Specifies values to be considered invalid for
%                      the corresponding variables in 'checkVariables'.
%                      - Default: {NaN}
%                      - Can be a single value (e.g., a scalar, char, or string) to be
%                        applied as the invalid criterion for all 'checkVariables'.
%                      - Can be a cell array matching the size of 'checkVariables', where
%                        each cell specifies the invalid value for the corresponding variable.
%                      - To check for empty values, use [] in a cell (e.g., {[]}). This
%                        identifies empty cells ('') in a cell array column. For
%                        standard array columns (e.g., numeric), this check will not
%                        mark any rows as invalid.
%
%   OUTPUT ARGUMENTS:
%       validInd: A logical column vector where 'true' indicates a valid row.

arguments
    variableTable table
    checkVariables {mustBeA(checkVariables,{'char','string','cell'})} = {}
    invalidValues {mustBeA(invalidValues,{'char','string','cell','numeric'})} = {NaN}
end

% Check for empty checkVariables
if isempty(checkVariables)
    validInd = true(height(variableTable),1);
    return
end

% Ensure checkVariables is a cell array
checkVariables = cellstr(checkVariables);

% Ensure invalidValues is a cell array
if ~iscell(invalidValues)
    invalidValues = {invalidValues};
end

% Ensure invalidValues has length equal to check variables
if isscalar(invalidValues) && ~isscalar(checkVariables)
    invalidValues = repmat(invalidValues,size(checkVariables));
elseif numel(invalidValues) ~= numel(checkVariables)
    error('identifyValidRows:VariableValueMismatch',...
        'Cannot match %i variables with %i values.',...
        numel(checkVariables),numel(invalidValues))
end

% Initialize output
validInd = true(height(variableTable),1);

% Check for invalid values
for i = 1:numel(checkVariables)

    % Check if the specified column exists
    if ~ismember(checkVariables{i}, variableTable.Properties.VariableNames)
        warning('identifyValidRows:InvalidVariableName', ...
            'Variable "%s" provided in checkVariables not found in variableTable. Skipping check.', checkVariables{i});
        continue; % Skip to the next variable name if the current one doesn't exist
    end

    % Get current variable
    currentVariable = variableTable.(checkVariables{i});
    currentInvalidValue = invalidValues{i};
    
    % Determine which rows are invalid for the current variable
    isInvalid = false(height(variableTable), 1);
    
    % Check variable
    if isempty(currentInvalidValue)
        if iscell(currentVariable)
            isInvalid = cellfun(@isempty, currentVariable);
        else
            % A non-cell array cannot have empty [] elements, so none are invalid.
            isInvalid(:) = false;
        end
    elseif isnumeric(currentInvalidValue) && isnan(currentInvalidValue)
        % Handle NaN
        if iscell(currentVariable)
            isInvalid = cellfun(@(x) isnumeric(x) && any(isnan(x)), currentVariable);
        else
            isInvalid = isnan(currentVariable);
        end
    else
        % Handle all other values
        if iscell(currentVariable)
            % Use isequal for robust comparison of cell contents
            isInvalid = cellfun(@(x) isequal(x, currentInvalidValue), currentVariable);
        else
            % Standard equality check for numeric/string/etc. arrays
            isInvalid = (currentVariable == currentInvalidValue);
        end
    end
    
    % Update the overall validity index
    validInd = validInd & ~isInvalid;
end

end