function c = entries(x)
%ENTRIES A decoded JSON list as a cell array (row), one element per entry.
%
%   C = ndi.v2.entries(X). jsondecode gives a struct array when a list's
%   entries share their fields and a cell array when they do not (a term
%   parameter beside a numeric one), so a list is walked as cells and never
%   concatenated with [x{:}]. Empty gives {}.

if isempty(x)
    c = {};
elseif iscell(x)
    c = reshape(x, 1, []);
else
    c = num2cell(reshape(x, 1, []));
end
end
