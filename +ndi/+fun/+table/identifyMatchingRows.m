function rowInd = identifyMatchingRows(dataTable, columnNames, dataValues)
%IDENTIFYMATCHINGROWS Identifies rows in a MATLAB table that match specified criteria.
%
%   rowInd = identifyMatchingRows(dataTable, columnNames, dataValues) returns
%   a logical index vector indicating which rows in 'dataTable' have values
%   in 'columnNames' that match the corresponding 'dataValues'.
%
% Inputs:
%   dataTable   - A MATLAB table.
%   columnNames - A character vector, string scalar, string array, or cell array
%                 of character vectors/strings specifying the variable names
%                 (columns) to check.
%   dataValues  - The values to match against the specified columns.
%                 - If 'columnNames' specifies a single column, 'dataValues'
%                   can be a single value (numeric, char, string, logical)
%                   or a cell array of valid values for that column.
%                 - If 'columnNames' specifies multiple columns, 'dataValues'
%                   must be a cell array, where each element corresponds to
%                   the respective column in 'columnNames'. Each element within
%                   this cell array can itself be a single value or a cell array
%                   of valid values for that specific column.
%
% Output:
%   rowInd      - A logical column vector where 'true' indicates a row that
%                 matches the criteria, and 'false' indicates a non-matching row.
%
% Example Usage:
%   % Create a sample table
%   T = table({'apple';'banana';'cherry'}, [10;20;30], {'red';'yellow';'red'}, ...
%             'VariableNames', {'Fruit','Count','Color'});
%
%   % Example 1: Match rows where 'Fruit' is 'banana'
%   rowInd1 = identifyMatchingRows(T, 'Fruit', 'banana');
%   % rowInd1 will be [false; true; false]
%
%   % Example 2: Match rows where 'Fruit' is 'apple' OR 'cherry'
%   rowInd2 = identifyMatchingRows(T, 'Fruit', {'apple','cherry'});
%   % rowInd2 will be [true; false; true]
%
%   % Example 3: Match rows where 'Fruit' is 'apple' AND 'Count' is 10
%   rowInd3 = identifyMatchingRows(T, {'Fruit','Count'}, {'apple',10});
%   % rowInd3 will be [true; false; false]
%
%   % Example 4: Match rows where 'Fruit' is 'apple' OR 'banana', AND 'Color' is 'red'
%   rowInd4 = identifyMatchingRows(T, {'Fruit','Color'}, {{'apple','banana'},'red'});
%   % rowInd4 will be [true; false; true]
%
% See also: table, strcmp, ismember

% Input argument validation
arguments
    dataTable table
    columnNames {mustBeText} % Ensures char vector, string scalar, string array, or cell array of char vectors/strings
    dataValues % Can be any type, will be validated below
end

% Ensure columnNames is a cell array of character vectors for consistent iteration
columnNames = cellstr(columnNames);

% Initialize output as all true; rows will be set to false if they don't match
rowInd = true(height(dataTable), 1);

% Check if dataValues needs to be wrapped in a cell array based on columnNames count
if numel(columnNames) > 1 && ~iscell(dataValues)
    error('identifyMatchingRows:InvalidDataValues', ...
          'When more than one column is specified, dataValues must be a cell array.');
elseif isscalar(columnNames) && iscell(dataValues) && numel(dataValues) > 1 && ~iscell(dataValues{1})
    % If single column, but dataValues is a cell array with multiple elements
    % and the first element is not a cell, assume it's a list of valid values for that column
    dataValues = {dataValues}; % Wrap it once more for consistent iteration below
elseif numel(columnNames) > 1 && iscell(dataValues) && numel(dataValues) ~= numel(columnNames)
    error('identifyMatchingRows:MismatchCount', ...
          'The number of dataValues elements must match the number of columnNames when multiple columns are specified.');
elseif isscalar(columnNames) && ~iscell(dataValues)
    dataValues = {{dataValues}}; % Wrap for consistency, e.g., 'abc' becomes {{'abc'}}
elseif isscalar(columnNames) && iscell(dataValues) && iscell(dataValues{1}) && isscalar(dataValues)
    % This handles rowInd = identifyMatchingRows(dataTable, 'column1',{'abc'})
    % which means match 'abc'
    % No action needed, already in correct {{'value'}} format for iteration
elseif isscalar(columnNames) && iscell(dataValues) && ~iscell(dataValues{1})
    % This handles rowInd = identifyMatchingRows(dataTable, 'column1',{{'a','b','c'}})
    % No action needed, already in correct {{'value1','value2'}} format for iteration
else
    % Ensure dataValues is consistently a cell array of cell arrays for iteration,
    % where each inner cell contains the possible match values for a column.
    if ~iscell(dataValues) || (iscell(dataValues) && ~iscell(dataValues{1}))
        tempValues = cell(size(columnNames));
        if iscell(dataValues) % e.g., {'a',1}
            for k = 1:numel(dataValues)
                tempValues{k} = dataValues(k);
            end
        else % e.g., 'abc' (when columnNames is single)
            tempValues{1} = {dataValues};
        end
        dataValues = tempValues;
    end
end


% Iterate through each column and its corresponding match values
for i = 1:numel(columnNames)
    currentColumnName = columnNames{i};

    % Check if the specified column exists in the table
    if ~ismember(currentColumnName, dataTable.Properties.VariableNames)
        warning('identifyMatchingRows:ColumnNotFound', ...
            'Column "%s" not found in the table. Skipping this column for matching.', currentColumnName);
        % If a column isn't found, no rows can match based on this criterion,
        % so we should mark all rows as non-matching for this specific column.
        rowInd = false(height(dataTable), 1);
        return; % Exit early as no rows can satisfy criteria with a missing column
    end

    currentTableColumn = dataTable.(currentColumnName);
    currentMatchValues = dataValues{i};

    % Initialize a temporary logical vector for current column matches
    colMatchInd = false(height(dataTable), 1);

    % Handle cases where data is wrapped in cells in the table column
    isTableColumnCell = iscell(currentTableColumn);

    % Iterate through each valid value for the current column
    for j = 1:numel(currentMatchValues)
        matchVal = currentMatchValues{j};

        if isTableColumnCell
            % If table data is in cells, compare contents
            if ischar(matchVal) || isstring(matchVal)
                % Case-insensitive string comparison for text data
                colMatchInd = colMatchInd | cellfun(@(x) ischar(x) && strcmpi(x,matchVal) || ...
                                                   (isstring(x) && strcmpi(string(x),string(matchVal))), ...
                                                    currentTableColumn);
            else
                % Numeric or other data types in cells
                colMatchInd = colMatchInd | cellfun(@(x) isequal(x,matchVal), currentTableColumn);
            end
        else
            % If table data is not in cells, direct comparison
            if ischar(matchVal) || isstring(matchVal)
                % Case-insensitive string comparison for text data
                colMatchInd = colMatchInd | (strcmpi(string(currentTableColumn), string(matchVal)));
            else
                % Numeric or other data types
                colMatchInd = colMatchInd | (currentTableColumn == matchVal);
            end
        end
    end
    % Combine results for the current column with the overall rowInd using logical AND
    rowInd = rowInd & colMatchInd;
end

end