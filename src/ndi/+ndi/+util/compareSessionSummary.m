function report = compareSessionSummary(summary1, summary2, options)
% COMPARESESSIONSUMMARY - compare two session summaries and return a report
%
% REPORT = NDI.UTIL.COMPARESESSIONSUMMARY(SUMMARY1, SUMMARY2, ...)
%
% Compares SUMMARY1 and SUMMARY2, identifying any differences in fields,
% arrays, or nested structures. Returns a cell array of character arrays
% with one entry per difference noted. If no differences are found, returns
% an empty cell array {}.
%
% This function accepts name-value pair arguments:
%   'excludeFiles' - A cell array of strings or character arrays specifying
%                    filenames (or directories) to ignore when comparing the
%                    'files' and 'filesInDotNDI' fields.
%

arguments
    summary1 (1,1) struct
    summary2 (1,1) struct
    options.excludeFiles (1,:) cell = {}
end

report = {};

% 1. Fields check
fields1 = fieldnames(summary1);
fields2 = fieldnames(summary2);

diff_fields = setdiff(fields1, fields2);
for i = 1:numel(diff_fields)
    report{end+1} = sprintf('Field %s is in summary1 but not summary2', diff_fields{i});
end

diff_fields = setdiff(fields2, fields1);
for i = 1:numel(diff_fields)
    report{end+1} = sprintf('Field %s is in summary2 but not summary1', diff_fields{i});
end

common_fields = intersect(fields1, fields2);

% 2. Compare common fields
for i = 1:numel(common_fields)
    field = common_fields{i};
    val1 = summary1.(field);
    val2 = summary2.(field);

    % Filter excluded files if checking file arrays
    if ~isempty(options.excludeFiles) && (strcmp(field, 'files') || strcmp(field, 'filesInDotNDI'))
        if iscell(val1)
            val1 = setdiff(val1, options.excludeFiles);
        end
        if iscell(val2)
            val2 = setdiff(val2, options.excludeFiles);
        end
    end

    % Handle JSON decode empty array vs empty cell array issue
    if isempty(val1) && isempty(val2)
        continue;
    end

    % If one is cell and other is string/char array (sometimes happens with single elements in JSON)
    if iscell(val1) && ~iscell(val2) && numel(val1) == 1
        val1 = val1{1};
    elseif ~iscell(val1) && iscell(val2) && numel(val2) == 1
        val2 = val2{1};
    end

    if iscell(val1) && iscell(val2)
        % Compare cells
        if numel(val1) ~= numel(val2)
            report{end+1} = sprintf('Field %s has different lengths in summary1 (%d) and summary2 (%d)', field, numel(val1), numel(val2));
            continue;
        end

        for j = 1:numel(val1)
            item1 = val1{j};
            item2 = val2{j};

            % Very basic struct/string comparison for cells
            if ischar(item1) || isstring(item1)
                item1Str = regexprep(char(item1), '[\r\n]+', '');
                item2Str = regexprep(char(item2), '[\r\n]+', '');
                if ~strcmp(item1Str, item2Str)
                    report{end+1} = sprintf('Field %s{%d} differs: "%s" vs "%s"', field, j, item1Str, item2Str);
                end
            elseif isstruct(item1)
                sub_report = ndi.util.compareSessionSummary(item1, item2);
                for k = 1:numel(sub_report)
                    report{end+1} = sprintf('Field %s{%d} struct diff: %s', field, j, sub_report{k});
                end
            else
                if ~isequal(item1, item2)
                    report{end+1} = sprintf('Field %s{%d} differs in content', field, j);
                end
            end
        end

    elseif isstruct(val1) && isstruct(val2)
        % Compare structs
        if numel(val1) ~= numel(val2)
            report{end+1} = sprintf('Field %s struct array has different lengths in summary1 (%d) and summary2 (%d)', field, numel(val1), numel(val2));
            continue;
        end

        for j = 1:numel(val1)
            sub_report = ndi.util.compareSessionSummary(val1(j), val2(j));
            for k = 1:numel(sub_report)
                report{end+1} = sprintf('Field %s(%d) struct diff: %s', field, j, sub_report{k});
            end
        end

    elseif ischar(val1) || isstring(val1)
        val1Str = regexprep(char(val1), '[\r\n\t]+', '');
        val2Str = regexprep(char(val2), '[\r\n\t]+', '');
        if ~strcmp(val1Str, val2Str)
            report{end+1} = sprintf('Field %s differs: "%s" vs "%s"', field, val1Str, val2Str);
        end

    else
        % Compare numeric/logical or objects

        is_same = false;
        if isnumeric(val1) && isnumeric(val2) || islogical(val1) && islogical(val2)
            % Compare vectorized form to avoid row/col orientation issues from jsondecode
            is_same = isequaln(val1(:), val2(:));
        else
            is_same = isequaln(val1, val2);

            % If not strictly equal, check if their JSON serializations are identical
            % (e.g. NDI objects, or objects containing path separators that differ)
            if ~is_same
                try
                    v1Str = regexprep(jsonencode(val1), '[\r\n\t]+', '');
                    v2Str = regexprep(jsonencode(val2), '[\r\n\t]+', '');
                    is_same = strcmp(v1Str, v2Str);
                catch
                    % Fallback to false
                end
            end
        end

        if ~is_same
            try
                % Try to format numeric/logical values
                if isnumeric(val1) || islogical(val1)
                    v1Str = mat2str(val1);
                    v2Str = mat2str(val2);
                else
                    v1Str = jsonencode(val1);
                    v2Str = jsonencode(val2);
                end
            catch
                v1Str = '<unprintable>';
                v2Str = '<unprintable>';
            end
            report{end+1} = sprintf('Field %s differs in value/object:\n  Val1: %s\n  Val2: %s', field, v1Str, v2Str);
        end
    end
end

end
