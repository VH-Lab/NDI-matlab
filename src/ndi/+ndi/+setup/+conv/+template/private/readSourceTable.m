function T = readSourceTable(file)
%READSOURCETABLE A source table, every cell as the text the source holds.
%
%   T = readSourceTable(FILE) reads the CSV FILE with every column as text
%   (char), its header names kept as written. Nothing is converted here:
%   a stage converts a cell when it uses it, so the source's own text is
%   still at hand for `source_value`, for a correction's `was`, and for the
%   report when the cell cannot be read.

arguments
    file {mustBeFile}
end
opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ',', ...
    'VariableNamingRule', 'preserve', 'TextType', 'char');
opts = setvartype(opts, 'char');
T = readtable(file, opts);
end
