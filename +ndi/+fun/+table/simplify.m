function simplifiedTable = simplify(dataTable, keys)
%SIMPLIFY Combines table rows based on keys, erroring on conflict.
%
%   simplifiedTable = SIMPLIFY(T, KEYS)
%
%   This function takes a large, sparse table T and simplifies it by
%   merging rows that share the same values for the key variables
%   specified in KEYS.
%
%   The function operates under a "strict" no-conflict policy. For each
%   group of rows defined by the keys, it collapses them into a single row
%   by taking the unique, non-missing value from each column. If any
%   column within a group contains more than one unique, non-missing
%   value, it is considered a conflict, and the function will throw an
%   error.
%
%   Inputs:
%       T (table) - The input table to be simplified.
%       keys (text) - A required string array or cell array of character
%          vectors specifying the variable names to use as keys for
%          grouping.
%
%   Outputs:
%       simplifiedTable (table) - The simplified table with one row per
%          unique key combination.
%
%   Example:
%      % Create a table with a cell array key
%      ID = { 'A'; 'A'; 'B' };
%      Val = [10; NaN; 20];
%      T = table(ID, Val);
%
%      simplified = ndi.fun.table.simplify(T, "ID");
%      disp(simplified);
%
%   See also: unique, table

arguments
    dataTable table
    keys (1,:) {mustBeText}
end

% Ensure keys is a cell array for consistent handling
keys = cellstr(keys);

% --- Pre-processing Step: Convert Cell Array Keys to String ---
% The 'unique' function requires string arrays for grouping text in cells.
for i = 1:width(dataTable)
    varName = dataTable.Properties.VariableNames{i};
    if iscell(dataTable.(varName))
        invalid = ~ndi.fun.table.identifyValidRows(dataTable,varName,[]) | ...
            ~ndi.fun.table.identifyValidRows(dataTable,varName,NaN) | ...
             ~ndi.fun.table.identifyValidRows(dataTable,varName,'');
        validClass = unique(cellfun(@class,dataTable{~invalid,varName},'UniformOutput',false));
        invalidClass = unique(cellfun(@class,dataTable{invalid,varName},'UniformOutput',false));
        if ~eq(validClass,invalidClass)
            switch validClass{:}
                case 'char'
                    dataTable{invalid,varName} = {''};
                case 'double'
                    dataTable{invalid,varName} = {NaN};
            end
        end
    end
end

% Validate that key variables exist
missingVars = setdiff(keys, dataTable.Properties.VariableNames);
if ~isempty(missingVars)
    error('simplify:MissingKeys', ...
        'The following key variable(s) were not found in the table: %s', strjoin(missingVars, ', '));
end

% --- Manual Grouping and Aggregation ---

% 1. Find unique key combinations and an index mapping each row to a key
[uniqueKeys, ~, rowIdx] = unique(dataTable(:, keys), 'rows', 'stable');
numUniqueKeys = height(uniqueKeys);

% 2. Get data variables to aggregate
dataVars = setdiff(dataTable.Properties.VariableNames, keys, 'stable');
simplifiedTable = uniqueKeys;

% Simplified table should have unique combos...

% 3. Loop through each data variable and aggregate it for all groups
for i = 1:numel(dataVars)
    varName = dataVars{i};
    originalCol = dataTable.(varName);

    % Get a prototype (empty or scalar) to determine type and width
    prototype = strict_collapse(originalCol(1:0,:));
    
    % Create a correctly typed column pre-filled with appropriate missing values
    newCol = repmat(prototype, numUniqueKeys, 1);
    
    for j = 1:numUniqueKeys
        groupData = originalCol(rowIdx == j, :);
        try
            collapsedValue = strict_collapse(groupData);
            if ~isempty(collapsedValue)
                 newCol(j, :) = collapsedValue;
            end
        catch ME
            error('simplify:ConflictInGroup', ...
                'Conflict found in variable "%s" for key group %d. Details: %s', ...
                varName, j, ME.message);
        end
    end
    simplifiedTable.(varName) = newCol;
end

end

% --- Local Helper Function for Strict Aggregation ---
function collapsedValue = strict_collapse(data)
% Collapses data from a group, throwing an error on conflict.
    
    to_keep = true(height(data), 1);
    if isnumeric(data) || islogical(data)
        to_keep = ~any(isnan(data), 2);
    elseif isdatetime(data)
        to_keep = ~any(isnat(data), 2);
    elseif isduration(data)
        to_keep = ~any(isnan(data), 2);
    elseif isstring(data)
        to_keep = ~any(ismissing(data), 2) & strlength(join(data, '')) > 0;
    elseif iscategorical(data)
        to_keep = ~any(isundefined(data), 2);
    elseif iscell(data)
        to_keep = ~cellfun('isempty', data);
    end
    
    data = data(to_keep, :);
    
    if height(data) <= 1
        collapsedValue = data;
        return;
    end
    
    uniqueVals = unique(data, 'rows', 'stable');
    
    if height(uniqueVals) == 1
        collapsedValue = uniqueVals;
    else
        conflictingStrs = string(uniqueVals);
        error('simplify:Conflict', ...
            'A conflict was found during simplification. Multiple unique values {%s} exist within a single group.', ...
            strjoin(conflictingStrs, '; '));
    end
end