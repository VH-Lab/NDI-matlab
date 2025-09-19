function valid = validateTableFile(fileName,requiredVariableNames)
%VALIDATETABLEFILE Validates the format and integrity of a tabular data file.
%
%   valid = VALIDATETABLEFILE(fileName, requiredVariableNames) performs a
%   series of checks on the specified file to ensure it is well-formed and
%   contains the necessary data.
%
%   Description:
%   This function serves as a pre-import check for tabular data files like
%   CSV or Excel spreadsheets. It verifies two main conditions:
%   1.  Column Integrity: It checks if a specified set of required column
%       headers exists in the file.
%   2.  Data Integrity: It checks for missing or improperly formatted data
%       within those required columns.
%
%   The function returns a logical flag indicating whether the file passed
%   all checks. Warnings are issued to the command window detailing any
%   failures.
%
%   Input Arguments:
%   fileName              - A character vector or string scalar specifying the
%                           full path to the file to be validated. The file
%                           must exist.
%   requiredVariableNames - (Optional) A string array or cell array of
%                           character vectors listing the exact column
%                           headers that must be present in the file. If
%                           left empty, this check is skipped.
%
%   Output Arguments:
%   valid                 - A logical scalar. Returns 'true' if the file
%                           passes all validation checks, and 'false' if any
%                           check fails.
%
%   Example:
%       % Assume 'subject_data.csv' is missing a 'Cage' column.
%       requiredCols = {'Animal', 'Cage', 'Label'};
%       isValid = validateTableFile('subject_data.csv', requiredCols);
%
%       % This would display a warning about the missing 'Cage' column
%       % and the value of 'isValid' would be false.

% Input argument validation
arguments
    fileName {mustBeFile}
    requiredVariableNames {mustBeText} = '';
end

valid = true;

% Get import options
importOptions = detectImportOptions(fileName);

% Check that file contains the required variable names
if ~isempty(requiredVariableNames)
    requiredVariableNames = cellstr(requiredVariableNames);
    missingVariableNames = setdiff(requiredVariableNames,importOptions.VariableNames);
    if ~isempty(missingVariableNames)
        warning('validateTableFile:missingVariables','%s is missing the required columns: %s.',...
            fileName,strjoin(missingVariableNames,', '));
        valid = false;
    end
end

% Check that no data is missing
importOptions.SelectedVariableNames = requiredVariableNames;
importOptions.ImportErrorRule = 'error';
importOptions.MissingRule = 'error';
try
    readtable(fileName,importOptions);
catch ME
    missingCell = regexp(ME.message,'\d+','match');
    missingVariableName = requiredVariableNames{str2double(missingCell{1})};
    warning('validateTableFile:missingData','%s contains invalid or missing data in column %s (%s): row %s',...
        fileName,missingCell{1},missingVariableName,missingCell{2});
    valid = false;
end

end