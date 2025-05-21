function validInd = identifyValidRows(variableTable,checkVariables,invalidValues)
%IDENTIFYVALIDROWS Identifies valid rows in a MATLAB table based on specified criteria.
%
%   validInd = IDENTIFYVALIDROWS(variableTable)
%   Checks no specific variables by default. All rows are considered valid unless
%   checkVariables and invalidValues are provided. This usage returns all true.
%
%   validInd = IDENTIFYVALIDROWS(variableTable, checkVariables)
%   Checks the variables specified in 'checkVariables' for NaN values.
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
%                      Default: {} (empty cell array). If empty, and 'invalidValues'
%                      is also empty or not provided, all rows are marked valid.
%
%       invalidValues: (Optional) Specifies the values to be considered invalid for
%                      the corresponding variables in 'checkVariables'.
%                      - If not provided or empty (and 'checkVariables' is provided):
%                        Defaults to checking for NaN in each 'checkVariables'.
%                      - If a single scalar value (numeric, char, string, logical):
%                        This value is treated as the invalid marker for ALL variables
%                        listed in 'checkVariables'.
%                      - If a cell array: Must contain the same number of elements as
%                        'checkVariables'. Each cell 'invalidValues{j}' specifies the
%                        invalid value for the variable 'checkVariables{j}'.
%                        Elements can be numeric (including NaN), char, string, or logical.
%
%   OUTPUT ARGUMENTS:
%       validInd: A logical column vector with the same number of rows as
%                 'variableTable'. 'true' indicates a valid row, 'false'
%                 indicates an invalid row.

% Input argument validation
arguments
    variableTable table
    checkVariables {mustBeA(checkVariables,{'char','str','cell'})} = {}
    invalidValues {mustBeA(invalidValues,{'char','str','cell','numeric'})} = {NaN}
end

% Check for empty checkVariables
if isempty(checkVariables)
    validInd = true(height(variableTable),1);
    return
end

% Ensure checkVariables is a cell array for consistent processing
if ischar(checkVariables)
    checkVariables = {checkVariables};
elseif isstring(checkVariables) && isscalar(checkVariables)
    checkVariables = {char(checkVariables)};
elseif isstring(checkVariables) && ~isscalar(checkVariables)
    checkVariables = cellstr(checkVariables);
end

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

    % Check variable
    if iscell(currentVariable) & isnan(invalidValues{i})
        validInd = validInd & cellfun(@(x) ~any(isnan(x)),currentVariable);
    elseif iscell(currentVariable)
        validInd = validInd & cellfun(@(x) ~any(eq(x,invalidValues{i})),currentVariable);
    elseif isnan(invalidValues{i})
        validInd = validInd & ~isnan(currentVariable);
    else
        validInd = validInd & ~eq(currentVariable,invalidValues{i});
    end
end

end