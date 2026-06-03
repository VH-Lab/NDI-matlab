function saveStructArray(filename, s)
% ndi.util.saveStructArray - save a struct array to a tab-delimited text file
%
% ndi.util.saveStructArray(FILENAME, S)
%
% Writes the struct array S to FILENAME as a tab-delimited text file with a
% header row of field names. Each element of S becomes one row; each field of S
% becomes one column.
%
% This is a faster, more robust drop-in alternative to vlt.file.saveStructArray.
% It uses MATLAB's WRITETABLE with an explicit tab Delimiter and FileType 'text',
% which avoids the delimiter mis-detection that can occur when string fields
% contain spaces. Files written here can be read back with
% ndi.util.loadStructArray.
%
% Each field of S should hold a scalar numeric/logical value or a character
% vector / string scalar in each element, so that the data map onto a flat
% table. (Non-scalar numeric fields do not round-trip through a tab-delimited
% file and are not supported.)
%
% Example:
%   s = struct('name',{'probe A';'probe B'},'count',{100;250});
%   ndi.util.saveStructArray('probes.txt', s);
%
% See also: ndi.util.loadStructArray, WRITETABLE, STRUCT2TABLE

    arguments
        filename (1,:) char
        s struct
    end

    if isempty(s),
        error('ndi:util:saveStructArray:emptyStruct', ...
            'Cannot save an empty struct array.');
    end;

    T = struct2table(s, 'AsArray', true);

    writetable(T, filename, 'FileType', 'text', 'Delimiter', '\t', ...
        'WriteVariableNames', true, 'WriteRowNames', false);

end
