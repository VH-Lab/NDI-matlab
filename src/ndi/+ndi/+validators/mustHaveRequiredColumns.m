function mustHaveRequiredColumns(t, requiredCols)
%MUSTHAVEREQUIREDCOLUMNS Validates if a table contains specified columns.
%
%   ndi.validation.mustHaveRequiredColumns(t, requiredCols)
%
%   Checks if the input table 't' contains all column names listed in
%   'requiredCols'. If any columns are missing, it throws an error.
%
%   Args:
%       t (table): The input table to check.
%       requiredCols (char | string | cell): A character vector, string, or
%                            cell array of character vectors/strings,
%                            where each element represents a required column name.
%                            If provided as char or string, it's treated as a
%                            single required column.
%
%   Throws:
%       error: If any columns specified in 'requiredCols' are not found in
%              the table 't'. The error identifier is
%              'ndi:validation:MissingColumns'.
%       error: If 'requiredCols' is not text (char, string, or cell array
%              of text), caught by the input parser.

arguments
    t table % Accept any table size, specific size checks are up to the caller
    requiredCols {mustBeText(requiredCols)} % Use built-in validator for text types
end

% --- Input Handling ---
% If requiredCols is a single char vector or string, convert it to a cell array
% This ensures the setdiff logic works correctly. mustBeText ensures it's
% either char, string, or cell array of text at this point.
if ~iscell(requiredCols)
    requiredCols = {requiredCols};
end

% --- Core Logic ---
actualCols = t.Properties.VariableNames;
missingCols = setdiff(requiredCols, actualCols); % Now works for single or multiple cols

if ~isempty(missingCols)
    % Use a specific, identifiable error ID
    error('ndi:validation:MissingColumns', ...
          'Input table is missing required column(s): %s', ...
          strjoin(missingCols, ', '));
end

end % function mustHaveRequiredColumns

