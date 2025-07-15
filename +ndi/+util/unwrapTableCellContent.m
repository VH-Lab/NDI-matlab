% file: +ndi/+util/unwrapTableCellContent.m
function unwrappedValue = unwrapTableCellContent(cellValue)
%UNWRAPTABLECELLCONTENT Recursively unwraps content from a potentially nested table cell.
%
%   UNWRAPPEDVALUE = NDI.UTIL.UNWRAPTABLECELLCONTENT(CELLVALUE)
%
%   This utility function takes a value, which is often a 1x1 cell array
%   when read from a MATLAB table, and unwraps it to retrieve the core data.
%   It handles cases where cells might be nested.
%
%   Inputs:
%       cellValue - The value from a table cell. This can be a direct value
%                   (numeric, char, string) or a cell array (potentially nested).
%
%   Outputs:
%       unwrappedValue - The innermost value. If the original or any nested
%                        cell is empty, it returns NaN. If the final value is
%                        a MATLAB string, it is converted to a char array for
%                        consistency.
%
%   Example:
%       myTable = table({{'some_string'}}, {42}, {{NaN}}, {{{{true}}}}, 'VariableNames', {'A','B','C','D'});
%       val_A = ndi.util.unwrapTableCellContent(myTable.A); % Returns 'some_string'
%       val_B = ndi.util.unwrapTableCellContent(myTable.B); % Returns 42
%       val_C = ndi.util.unwrapTableCellContent(myTable.C); % Returns NaN
%       val_D = ndi.util.unwrapTableCellContent(myTable.D); % Returns true
%

    currentValue = cellValue;
    unwrap_count = 0;
    max_unwrap = 10; % Safety break to prevent infinite loops

    while iscell(currentValue) && unwrap_count < max_unwrap
        if isempty(currentValue)
            currentValue = NaN; % If we encounter an empty cell, the result is NaN
            break;
        end
        currentValue = currentValue{1};
        unwrap_count = unwrap_count + 1;
    end

    if iscell(currentValue) && isempty(currentValue)
        % Handle the case where the innermost element is an empty cell
        unwrappedValue = NaN;
    else
        unwrappedValue = currentValue;
    end

    % Standardize output: cast MATLAB string to char for consistency
    if isstring(unwrappedValue)
        unwrappedValue = char(unwrappedValue);
    end
end
