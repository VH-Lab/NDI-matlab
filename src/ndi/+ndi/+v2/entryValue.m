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
%
%   THE NEW NUMERIC SHAPE. Entries in the flat shape of did-schema
%   did_v2_numeric_shape_plan.md ([one shape for measured numbers], Jess
%   Haley, 2026-11-17) are read too, beside the old one: `numeric` (the
%   canonical number(s)) and `source_numeric` (what the source wrote, a
%   number or text: [numeric shape details] (1)) replace `quantity.value`,
%   `quantity.source_value` and `matrix`. KIND keeps the old names, so a
%   caller reads both shapes the same: a single number, or numbers with a
%   `source_numeric`, is 'quantity' (VALUE its first number, SOURCEVALUE the
%   source's text, or its number as the shortest text that reads back as
%   it); an array with no `source_numeric` is 'matrix' (VALUE the array).

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

% the new numeric shape: flat `numeric` beside `source_numeric`
nm = fieldOf(entry, 'numeric');
if iscell(nm), nm = cellNumbers(nm); end
if (isnumeric(nm) || islogical(nm)) && ~isempty(nm)
    sv = fieldOf(entry, 'source_numeric');
    if isscalar(nm) || ~isempty(sv)
        kind = 'quantity';
        value = double(nm(1));
        sourceValue = sourceText(sv);
    else
        kind = 'matrix';
        value = double(nm);
    end
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

function t = sourceText(sv)
% what the source wrote, as text: text as it is, a number as the shortest
% decimal text that reads back as it ([numeric shape details] (1): a number
% where v1 stored a number)
t = "";
if isempty(sv), return; end
if iscell(sv)
    if all(cellfun(@(x) ischar(x) || isstring(x), sv))
        t = strjoin(string(sv), ", ");
        return;
    end
    sv = cellNumbers(sv);
end
if ischar(sv) || isstring(sv)
    t = string(sv);
elseif isnumeric(sv) || islogical(sv)
    parts = arrayfun(@(x) string(shortestText(double(x))), sv(:)');
    t = strjoin(parts, ", ");
end
end

function t = shortestText(x)
% the shortest decimal text that reads back as X, a whole number written
% out in full (500, not 5e+02)
t = sprintf('%.17g', x);
if isfinite(x) && x == round(x) && abs(x) < 1e15
    t = sprintf('%d', x);
    return;
end
for n = 1:17
    c = sprintf('%.*g', n, x);
    if str2double(c) == x
        t = c;
        return;
    end
end
end

function x = cellNumbers(c)
% a numeric array read back from JSON as a cell (a null in it, or ragged
% rows): each empty element NaN, each row a row
x = c;
try
    rows = cellfun(@(r) reshape(rowNumbers(r), 1, []), c(:), 'UniformOutput', false);
    x = cell2mat(rows);
catch
end
end

function r = rowNumbers(r)
if iscell(r)
    r = cellfun(@(e) nanIfEmpty(e), r);
else
    r = double(nanIfEmpty(r));
end
end

function e = nanIfEmpty(e)
if isempty(e), e = NaN; end
e = double(e);
end
