function s = loadStructArray(filename, fields)
% ndi.util.loadStructArray - load a struct array from a tab-delimited text file
%
% S = ndi.util.loadStructArray(FILENAME)
% S = ndi.util.loadStructArray(FILENAME, FIELDS)
%
% Reads a tab-delimited text file written by ndi.util.saveStructArray (or any
% tab-delimited file with a header row of column names) and returns a struct
% array S with one element per data row and one field per column.
%
% This is a faster, more robust drop-in alternative to vlt.file.loadStructArray.
% It uses MATLAB's READTABLE with an explicit tab Delimiter and FileType 'text',
% which avoids the delimiter mis-detection that can occur when string fields
% contain spaces.
%
% If FIELDS (a cell array or string array of names) is provided, the file is
% assumed to have NO header row, and these names are used as the field names.
% Otherwise the field names are read from the first row of the file.
%
% Text-valued columns are returned as character vectors (not as MATLAB strings
% or 1x1 cells), matching the convention of vlt.file.loadStructArray.
%
% Example:
%   s = ndi.util.loadStructArray('probes.txt');
%
% See also: ndi.util.saveStructArray, READTABLE, TABLE2STRUCT

    arguments
        filename (1,:) char
        fields = []
    end

    if ~isfile(filename),
        error('ndi:util:loadStructArray:fileNotFound', ...
            ['Could not find file ' filename '.']);
    end;

    opts = {'FileType','text','Delimiter','\t'};

    if isempty(fields),
        T = readtable(filename, opts{:}, 'ReadVariableNames', true);
    else,
        T = readtable(filename, opts{:}, 'ReadVariableNames', false);
        fields = cellstr(fields);
        if width(T) ~= numel(fields),
            error('ndi:util:loadStructArray:fieldCountMismatch', ...
                'Number of supplied FIELDS (%d) does not match number of columns (%d).', ...
                numel(fields), width(T));
        end;
        T.Properties.VariableNames = fields;
    end;

    % Normalize any string-typed columns to char so the result does not contain
    % MATLAB string objects (keeps parity with vlt.file.loadStructArray).
    vn = T.Properties.VariableNames;
    for i=1:numel(vn),
        col = T.(vn{i});
        if isstring(col),
            T.(vn{i}) = cellstr(col);
        end;
    end;

    s = table2struct(T);

end
