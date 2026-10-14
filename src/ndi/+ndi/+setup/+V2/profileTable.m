function P = profileTable(T, options)
%PROFILETABLE Describe every column of a table, without interpreting it.
%
%   P = ndi.setup.V2.profileTable(T) returns one row per column of table T:
%   column, class (for a cell column, the classes it holds), cellSize (the
%   sizes of the cells, from the first 50), nRows, nUnique (NaN where
%   uniqueness is not defined, e.g. image arrays), example (the first value,
%   or its class and size when it is large) and description
%   (T.Properties.VariableDescriptions, when the source set any).
%
%   This is the raw material for an import's questions -- "which column
%   identifies a worm?", "what unit is OD600 in?" -- and deliberately
%   answers none of them. A column that looks like a key has nUnique equal
%   to nRows; a column that looks like a condition has few unique values.
%
%   Options:
%     'MaxExample'  numel above which the example is summarised (default 10)

arguments
    T table
    options.MaxExample (1,1) double = 10
end

n = width(T);
P = table('Size', [n 7], ...
    'VariableTypes', {'string', 'string', 'string', 'double', 'double', 'string', 'string'}, ...
    'VariableNames', {'column', 'class', 'cellSize', 'nRows', 'nUnique', 'example', 'description'});
desc = T.Properties.VariableDescriptions;
for c = 1:n
    x = T.(c);
    P.column(c) = T.Properties.VariableNames{c};
    P.class(c) = class(x);
    P.nRows(c) = height(T);
    if iscell(x)
        P.class(c) = "cell of " + strjoin(unique(cellfun(@class, x, 'UniformOutput', false)), '/');
        sample = x(1:min(end, 50));
        P.cellSize(c) = strjoin(unique(cellfun(@(e) mat2str(size(e)), sample, ...
            'UniformOutput', false)), ' ');
    else
        P.cellSize(c) = mat2str(size(x, 2:ndims(x)));
    end
    try
        P.nUnique(c) = height(unique(x));
    catch
        P.nUnique(c) = NaN;
    end
    try
        e = x(1, :);
        if iscell(e), e = e{1}; end
        if numel(e) > options.MaxExample
            P.example(c) = sprintf('<%s %s>', class(e), mat2str(size(e)));
        else
            P.example(c) = strtrim(evalc('disp(e)'));
        end
    catch
        P.example(c) = "?";
    end
    if numel(desc) >= c
        P.description(c) = desc{c};
    end
end
end
