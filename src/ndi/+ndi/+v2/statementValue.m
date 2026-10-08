function [k, v, t, u] = statementValue(p)
%STATEMENTVALUE A statement's value as one comparable thing, and as text.
%
%   [K, V, T] = ndi.v2.statementValue(P): P is a statement document's
%   properties (ndi.v2.props). K is the kind of value: 'term' (V a
%   {name, node} struct), 'date' (V the ISO instant text), 'number' (V a
%   scalar in the canonical unit; a dose's one amount), 'text', or 'none'
%   (an array, a value in a data body, a structure with no single amount,
%   or no value at all). T is V as text ('' for 'none'); U the unit of a
%   number (its canonical field, e.g. 'liters', 'celsius'). Nothing is read
%   but P: a value in a data body is 'none' without opening the body.
%
%   See also ndi.v2.searchStatements, ndi.statement/summary.

[k, v, u] = valueOf(p);
switch k
    case 'term', t = ndi.v2.termName(v);
    case {'date', 'text'}, t = v;
    case 'number', t = num2str(v, 6);
    otherwise, t = '';
end
end

function [k, v, u] = valueOf(p)
k = 'none'; v = []; u = '';
if logical(firstOr(ndi.v2.blockOf(p, 'value', 'data_body', false), false))
    return;
end
chain = ndi.v2.classChain(p);
c = '';
for i = 1:numel(chain)
    if any(strcmp(ndi.v2.directParents(chain{i}), 'value')), c = chain{i}; break; end
end
if isempty(c), return; end
raw = ndi.v2.blockOf(p, c, 'value', []);
if iscell(raw)
    if numel(raw) ~= 1, return; end
    raw = raw{1};
end
if isstruct(raw) && numel(raw) ~= 1, return; end
if strcmp(c, 'date') && isstruct(raw) && isfield(raw, 'instant')
    k = 'date'; v = char(raw.instant); return;
end
if isstruct(raw) && all(ismember(fieldnames(raw), {'name', 'node'}))
    k = 'term'; v = raw; return;
end
if ischar(raw) || isstring(raw)
    k = 'text'; v = char(raw); return;
end
if isnumeric(raw) && isscalar(raw)
    k = 'number'; v = double(raw); u = ndi.value.canonicalField(c); return;
end
if ~isstruct(raw), return; end
cf = ndi.value.canonicalField(c);
if ~isempty(cf) && isfield(raw, cf) && isnumeric(raw.(cf)) && isscalar(raw.(cf))
    k = 'number'; v = double(raw.(cf)); u = cf; return;
end
% a structured value (a dose): its one amount, if it has exactly one
amounts = []; units = {};
f = fieldnames(raw);
for i = 1:numel(f)
    s = raw.(f{i});
    sf = ndi.value.canonicalField(f{i});
    if isstruct(s) && isscalar(s) && ~isempty(sf) && isfield(s, sf) && isnumeric(s.(sf)) && isscalar(s.(sf))
        amounts(end+1) = double(s.(sf)); %#ok<AGROW>
        units{end+1} = sf; %#ok<AGROW>
    end
end
if isscalar(amounts)
    k = 'number'; v = amounts; u = units{1};
end
end

function v = firstOr(x, default)
if isempty(x), v = default; else, v = x(1); end
end
