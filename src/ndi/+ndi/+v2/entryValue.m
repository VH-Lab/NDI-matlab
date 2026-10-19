function [value, sourceValue, kind] = entryValue(entry)
%ENTRYVALUE The one value of a condition or method-parameter entry.
%
%   [VALUE, SOURCEVALUE, KIND] = ndi.v2.entryValue(ENTRY), ENTRY one entry of
%   a statement's `conditions` or an interaction's `method_parameters` (the
%   two are the same entry: variable, unit, source_unit, approximate and ONE
%   value form). KIND names the form ('term', 'quantity', 'count', 'text', or
%   '' when the entry holds none). VALUE is the term's name, the quantity's
%   number in the entry's `unit`, the count, or the text ([] when none).
%   SOURCEVALUE is the quantity's `source_value`, the number as the source
%   wrote it (text), and "" for every other form.

arguments
    entry
end

value = []; sourceValue = ""; kind = '';
if ~isstruct(entry) || isempty(entry), return; end
entry = entry(1);
if ~isempty(fieldOf(entry, 'term'))
    kind = 'term';
    value = ndi.v2.termName(fieldOf(entry, 'term'));
elseif ~isempty(fieldOf(entry, 'quantity'))
    kind = 'quantity';
    q = fieldOf(entry, 'quantity');
    value = double(fieldOf(q, 'value'));
    sv = fieldOf(q, 'source_value');
    if ~isempty(sv), sourceValue = string(sv); end
elseif ~isempty(fieldOf(entry, 'count'))
    kind = 'count';
    value = double(fieldOf(entry, 'count'));
elseif ~isempty(fieldOf(entry, 'text'))
    kind = 'text';
    value = char(fieldOf(entry, 'text'));
end
end

function v = fieldOf(s, name)
arguments
    s
    name {mustBeText}
end
v = [];
if isstruct(s) && isfield(s, name), v = s(1).(name); end
end
