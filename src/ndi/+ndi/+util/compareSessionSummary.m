function report = compareSessionSummary(summary1, summary2)
% COMPARESESSIONSUMMARY - compare two session summaries and return a report
%
% REPORT = NDI.UTIL.COMPARESESSIONSUMMARY(SUMMARY1, SUMMARY2)
%
% Compares SUMMARY1 and SUMMARY2, identifying any differences in fields,
% arrays, or nested structures. Returns a cell array of character arrays
% with one entry per difference noted. If no differences are found, returns
% an empty cell array {}.
%

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
                if ~strcmp(item1, item2)
                    report{end+1} = sprintf('Field %s{%d} differs: "%s" vs "%s"', field, j, char(item1), char(item2));
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
        if ~strcmp(val1, val2)
            report{end+1} = sprintf('Field %s differs: "%s" vs "%s"', field, char(val1), char(val2));
        end

    else
        % Compare numeric/logical
        if ~isequal(val1, val2)
            report{end+1} = sprintf('Field %s differs in numeric/logical value', field);
        end
    end
end

end
