function valid = validateTableFile(fileName,requiredVariableNames)

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
        warning('validateTableFile: %s is missing the required columns: %s.',...
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
    warning('validateTableFile: %s contains invalid or missing data in column %s (%s): row %s',...
        fileName,missingCell{1},missingVariableName,missingCell{2});
    valid = false;
end

% Are there other checks we want to run?

end