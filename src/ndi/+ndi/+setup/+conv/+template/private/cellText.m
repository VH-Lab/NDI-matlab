function s = cellText(T, k, column)
%CELLTEXT Row K's cell in COLUMN, as trimmed text; '' when blank or absent.

arguments
    T table
    k (1,1) double
    column {mustBeText}
end
s = '';
if isempty(column) || ~ismember(column, T.Properties.VariableNames)
    return;
end
v = T.(column)(k);
if iscell(v), v = v{1}; end
if isstring(v) && any(ismissing(v)), v = ''; end
s = strtrim(char(string(v)));
end
