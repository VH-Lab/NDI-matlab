function combinedTable = join(tables, options)
% JOIN Combines two or more tables using common variables as keys, with custom aggregation.
%
%   COMBINEDTABLE = JOIN(TABLES)
%   COMBINEDTABLE = JOIN(TABLES, uniqueVariables=VARIABLE_NAMES)
%
%   Combines a cell array of tables (TABLES) into a single table. The tables
%   are joined using all common variables as keys.
%
%   An optional 'uniqueVariables' parameter can be used to specify column
%   names for which only unique values should be kept per aggregated row.
%   Any duplicate rows (based on the 'uniqueVariables') are combined by
%   aggregating the values of other columns into comma-separated strings.
%   Numeric values are converted to strings for aggregation unless they
%   result in a single unique numeric value, in which case the number is
%   retained.
%
%   Inputs:
%       TABLES - A cell array of MATLAB table objects, e.g., {table1, table2, ...}.
%                Must be non-empty and contain only table objects.
%
%   Optional Name-Value Pair Arguments (passed in an 'options' struct or as name=value):
%       uniqueVariables - A character array or string array specifying the
%                         variable names that should have only unique values
%                         in the output table. Duplicate rows based on these
%                         variables will be collapsed, and values from other
%                         columns will be aggregated into comma-separated strings.
%                         If not provided or empty, no special aggregation
%                         for unique values is performed beyond the standard join.
%                         (default: '')
%
%   Outputs:
%       COMBINEDTABLE - The resulting combined and aggregated MATLAB table.
%
%   Example:
%      % Sample data
%      a = {1; 1; 2; 2};
%      c_t1 = {'a';'a';'b';'b'};
%      table1 = table(a,c_t1);
%      table1.Properties.VariableNames = {'a','c'}; % Ensure common variable name 'c'
%
%      b = {'a';'b';'a';'b'};
%      c_t2 = {'a';'a';'b';'b'};
%      table2 = table(b,c_t2);
%      table2.Properties.VariableNames = {'b','c'}; % Ensure common variable name 'c'
%
%      % Join and aggregate by 'c' using the new syntax
%      combinedTable = join({table1, table2}, uniqueVariables='c');
%
%      disp('Input Table 1:'); disp(table1);
%      disp('Input Table 2:'); disp(table2);
%      disp('Output Combined Table:'); disp(combinedTable);
%
%      % Example with no uniqueVariables specified (standard join result)
%      combinedTableNoAgg = join({table1, table2});
%      disp('Output Combined Table (No Aggregation):'); disp(combinedTableNoAgg);
%
%   See also: table, join, unique, strjoin, groupsummary

arguments
    tables (1,:) cell {mustBeNonempty, mustContainTables}
    options.uniqueVariables (1,:) {mustBeText} = ''
end

% Extract uniqueVariables from options struct
uniqueVariables = cellstr(options.uniqueVariables); % Convert to cell array for consistency

% Step 1: Perform initial innerjoin of all tables
combinedTable = tables{1};
if ~isscalar(tables)
    for k = 2:numel(tables)
        % Call innerjoin and capture the index vector 'ileft'
        [combinedTable, ileft] = innerjoin(combinedTable, tables{k});
        
        % Create a sorting index from 'ileft' to restore original order
        [~, sort_idx] = sort(ileft);
        
        % Apply the sorting index to the result
        combinedTable = combinedTable(sort_idx, :);
    end
end

% Step 2: Handle uniqueVariables and aggregation if specified
if isempty(uniqueVariables{1})
    return;
end
    
% Validate that uniqueVariables exist in the combined table
variableNames = combinedTable.Properties.VariableNames;
missingVars = setdiff(uniqueVariables, variableNames);
if ~isempty(missingVars)
    error('join:InvalidUniqueVariables', ...
        'The following uniqueVariables were not found in the combined table: %s', ...
        strjoin(missingVars, ', '));
end

% Identify other variables to aggregate (all variables not in uniqueVariables)
otherVars = setdiff(variableNames, uniqueVariables, 'stable');

% Get unique combinations of grouping keys and their row indices
% 'rows' option ensures uniqueness across selected columns
% 'stable' preserves the order of the first occurrence
[uniqueGroupingCombos, ~, rowIdx] = unique(combinedTable(:, uniqueVariables), 'rows', 'stable');

% Initialize the final table with unique grouping combinations
uniqueTable = uniqueGroupingCombos;

% Manually aggregate other variables
for i = 1:numel(otherVars)
    currentOtherVarName = otherVars{i};
    aggregatedColumnValues = cell(height(uniqueTable), 1); % Pre-allocate cell array for results

    for u_idx = 1:height(uniqueTable)
        % Get data for the current group for the current 'otherVar'
        dataForGroup = combinedTable.(currentOtherVarName)(rowIdx == u_idx);

        % Aggregate the data using the custom helper function
        aggregatedColumnValues{u_idx} = aggregateVarData(dataForGroup);
    end

    % Check if all non-empty cells contain a scalar numeric value
    nonEmptyIdx = ~cellfun('isempty', aggregatedColumnValues);
    areAllNumeric = all(cellfun(@(x) isnumeric(x) && isscalar(x), aggregatedColumnValues(nonEmptyIdx)));
    
    % Assign the aggregated column to the final table
    if areAllNumeric
        % All results are numbers. Convert the column back to a numeric array.
        finalColumn = NaN(height(uniqueTable), 1); % Pre-fill with NaN
        finalColumn(nonEmptyIdx) = cell2mat(aggregatedColumnValues(nonEmptyIdx));
        uniqueTable.(currentOtherVarName) = finalColumn;
    else
        % Contains mixed types (strings, etc.). Keep as a cell array.
        uniqueTable.(currentOtherVarName) = aggregatedColumnValues;
    end
end
combinedTable = uniqueTable;

end

% --- Nested Helper Function for `arguments` validation ---
function mustContainTables(c)
    if ~all(cellfun(@(x) isa(x, 'table'), c))
        error('join:InvalidTableInput', 'All elements in the TABLES cell array must be MATLAB table objects.');
    end
end


% --- Helper function for custom aggregation logic ---
function result = aggregateVarData(data)
% AGGREGATEVARDATA Aggregates a column's data for a group.
% Handles various data types and returns numbers where appropriate, or strings.

% Ensure data is a cell array for consistent filtering and processing
if ischar(data) && isrow(data) % If it's a single char array (e.g., from table.Variable)
    data_cell = {data};
elseif isstring(data)
    data_cell = cellstr(data); % Convert string array to cell array of chars
elseif isnumeric(data) || islogical(data)
    data_cell = num2cell(data); % Convert numeric/logical array to cell array of its values
elseif iscell(data)
    data_cell = data; % Already a cell array
else % For other data types, try to convert to cell array of strings for aggregation
    try
        data_cell = arrayfun(@(x) char(string(x)), data, 'UniformOutput', false);
    catch
        % Fallback for types that can't be easily converted to char/string
        % If data is empty or problematic, return empty string.
        result = '';
        return;
    end
end

% Filter out empty values (empty char, empty string, empty numeric, NaN)
filtered_data_cell = cell(size(data_cell));
for k = 1:numel(data_cell)
    item = data_cell{k};
    if ischar(item) || isstring(item) % Handle char/string types
        if ~isempty(item) && ~all(isspace(item)) % Keep non-empty, non-whitespace strings
            filtered_data_cell{k} = char(item); % Store as char array
        end
    elseif isnumeric(item) || islogical(item) % Handle numeric/logical types
        if ~isempty(item) && ~isnan(item) % Keep non-empty, non-NaN values
            filtered_data_cell{k} = item; % Store as original numeric/logical type for now
        end
    else % Handle other complex types
        try
             if ~isempty(item)
                filtered_data_cell{k} = char(string(item)); % Convert to char representation
             end
        catch
            % Skip if conversion is problematic or item is genuinely empty/unrepresentable
        end
    end
end
indEmpty = cellfun(@isempty,filtered_data_cell);
filtered_data_cell(indEmpty) = [];

% If no meaningful data remains after filtering, return an empty string
if isempty(filtered_data_cell)
    result = ''; 
    return;
end

% Check if all remaining filtered items are numeric/logical
all_numeric_or_logical = all(cellfun(@(x) isnumeric(x) || islogical(x), filtered_data_cell));

if all_numeric_or_logical
    % If all are numeric/logical, convert to numeric array and find unique values
    numeric_values = cell2mat(filtered_data_cell);
    unique_numeric = unique(numeric_values, 'stable');
    
    if isscalar(unique_numeric)
        result = unique_numeric; % Return the single unique number as a number (e.g., {1} not {'1'})
    else
        % Multiple unique numbers, convert all to string and join
        string_representations = arrayfun(@num2str, unique_numeric, 'UniformOutput', false);
        result = strjoin(string_representations, ',');
    end
else
    % Mix of types or all strings/chars, convert all to string representation and join
    string_representations = cell(size(filtered_data_cell));
    for k = 1:numel(filtered_data_cell)
        item = filtered_data_cell{k};
        if ischar(item) || isstring(item)
            string_representations{k} = char(item);
        elseif isnumeric(item) || islogical(item)
            string_representations{k} = num2str(item);
        else % This handles any other complex types, converting them to char
            string_representations{k} = char(string(item)); 
        end
    end
    string_representations = unique(string_representations, 'stable');
    result = strjoin(string_representations, ',');
end

end