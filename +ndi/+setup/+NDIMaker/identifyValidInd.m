function validInd = identifyValidInd(variableTable,NonNaNVariableNames)

%   Input Arguments:
%       variableTable: A MATLAB table. Rows usually correspond to epochs.
%                      Columns specified by `BathVariable`,
%                      `MixtureVariable`, and `options.FilenameVariable`
%                       are used if they exist.
%       NonNaNVariableNames: Variable names in 'variableTable'. Values in
%                      these columns must not be NaN for a valid epoch.
%                      Default: {} (assumes all rows are valid epochs).
%
%   Output Arguments:
%       validInd: Indices of valid rows in the `variableTable`.

arguments
    variableTable table
    NonNaNVariableNames {mustBeA(NonNaNVariableNames,{'char','str','cell'})} = {}
end

% Ensure NonNaNVariableNames is a cell array for consistent processing
if ischar(NonNaNVariableNames)
    NonNaNVariableNames = {NonNaNVariableNames};
elseif isstring(NonNaNVariableNames) && isscalar(NonNaNVariableNames)
    NonNaNVariableNames = {char(NonNaNVariableNames)};
elseif isstring(NonNaNVariableNames) && ~isscalar(NonNaNVariableNames)
    NonNaNVariableNames = cellstr(NonNaNVariableNames);
end

% --- Identify Valid Rows ---
% Check for NaN values based on NonNaNVariableNames option
nanInd = true(height(variableTable),1);
for i = 1:numel(NonNaNVariableNames)
    % Check if the specified column exists
    if ~ismember(NonNaNVariableNames{i}, variableTable.Properties.VariableNames)
        warning('sessionMaker:NonNaNVariableNames', ...
            'Variable "%s" provided in NonNaNVariableNames not found in variableTable. Skipping check.', options.NonNaNVariableNames{i});
        continue; % Skip to the next variable name if the current one doesn't exist
    end
    % Update nanInd: a row is valid only if it passes the previous checks AND the current variable check
    nanVariable = variableTable.(NonNaNVariableNames{i});
    if iscell(nanVariable)
        nanInd = nanInd & cellfun(@(sr) ~any(isnan(sr)),nanVariable);
    else
        nanInd = nanInd & ~isnan(nanVariable);
    end
end

% Get linear indices of valid rows
validInd = find(nanInd); 

end