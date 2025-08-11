function [dataTable] = moveColumnsLeft(dataTable,columnNames)
%MOVECOLUMNSLEFT Moves specified columns to the far left of a table.
%
%   dataTable = moveColumnsLeft(dataTable, columnNames) rearranges the
%   columns in the input table 'dataTable' so that the columns specified
%   in 'columnNames' are moved to the leftmost positions. The order of
%   the moved columns among themselves is preserved, as is the relative
%   order of the other columns.
%
% Inputs:
%   dataTable - A MATLAB table. The table whose columns you want to rearrange.
%   columnNames - A string, character array, or cell array of strings
%                 containing the name(s) of the columns to be moved to the left.
%
% Output:
%   dataTable - The modified table with the specified columns moved to the left.
%
% See also: movevars, table

% Input argument validation
arguments
    dataTable table
    columnNames {mustBeText}
end

% Move columns to end
dataTable = movevars(dataTable,columnNames);

% Get left-most variable name
firstVar = dataTable.Properties.VariableNames{1};

% Move columns to beginning
dataTable = movevars(dataTable,columnNames,'Before',firstVar);

end