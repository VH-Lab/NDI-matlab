function [value, sourceValue, kind] = entryValue(entry)
%ENTRYVALUE The one value of a condition or method-parameter entry.
%
%   [VALUE, SOURCEVALUE, KIND] = ndi.v2.entryValue(ENTRY), ENTRY one entry of
%   a statement's `conditions` or an interaction's `method.parameters` (the
%   two are the same entry: variable, unit, source_unit, approximate and ONE
%   value form). KIND names the form ('term', 'quantity', 'count', 'text',
%   'logical', 'matrix', or '' when the entry holds none). VALUE is the term's
%   name, the quantity's number in the entry's `unit`, the count, the text, the
%   logical (Jess Haley 2026-10-22 [logical entries]) or the numeric array
%   ([] when none).
%   SOURCEVALUE is the quantity's `source_value`, the number as the source
%   wrote it (text), and "" for every other form.
%
%   The form is the one that holds something: a stored entry can carry the
%   other forms' blanks. Entries written before data_body AMENDMENT 3
%   (2026-10-19) are read too: a condition's `term.value`, `count.value` and
%   `quantity.value(1).{value, source_value}`, and a parameter's `value`.

arguments
    entry
end

value = []; sourceValue = ""; kind = '';
if ~isstruct(entry) || isempty(entry), return; end
entry = entry(1);

t = fieldOf(entry, 'term');
if isstruct(t) && isfield(t, 'value') && ~isfield(t, 'node'), t = t(1).value; end
if ~isempty(ndi.v2.termName(t))
    kind = 'term';
    value = ndi.v2.termName(t);
    return;
end

q = fieldOf(entry, 'quantity');
if isempty(q), q = fieldOf(entry, 'value'); end            % a parameter, before 2026-10-19
if isstruct(q) && isfield(q, 'value') && isstruct(q(1).value)
    q = q(1).value;                                         % a condition, before 2026-10-19
end
v = fieldOf(q, 'value');
if (isnumeric(v) || islogical(v)) && ~isempty(v)
    kind = 'quantity';
    value = double(v(1));
    sv = fieldOf(q, 'source_value');
    if ~isempty(sv), sourceValue = string(sv); end
    return;
end

x = fieldOf(entry, 'text');
if ~isempty(x)
    kind = 'text';
    value = char(x);
    return;
end

m = fieldOf(entry, 'matrix');
if (isnumeric(m) || islogical(m) || iscell(m)) && ~isempty(m)
    kind = 'matrix';
    if iscell(m)
        try m = cell2mat(cellfun(@(r) reshape(double(cell2mat(r)), 1, []), m(:), ...
                'UniformOutput', false)); catch, end
    end
    value = double(m);
    return;
end

% `logical` (did-schema #88, Jess Haley 2026-10-22 [logical entries]). Its
% blank is false and `count`'s blank is 0, so an entry carrying both blanks
% is told apart by which one holds something: a stored `true`, or an entry
% with no count at all, is logical
l = fieldOf(entry, 'logical');
c = fieldOf(entry, 'count');
if isstruct(c), c = fieldOf(c, 'value'); end              % a condition, before 2026-10-19
if (islogical(l) || isnumeric(l)) && ~isempty(l) && ...
        (isempty(c) || (logical(l(1)) && isequal(double(c(1)), 0)))
    kind = 'logical';
    value = logical(l(1));
    return;
end

if ~isempty(c)
    kind = 'count';
    value = double(c(1));
end
end

function v = fieldOf(s, name)
arguments
    s
    name {mustBeText}
end
v = [];
if isstruct(s) && ~isempty(s) && isfield(s, name), v = s(1).(name); end
end
