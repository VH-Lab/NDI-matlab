function [v, form] = covariateValues(covariate, dimensions)
%COVARIATEVALUES The values of one covariate, read from its value form.
%
%   [V, FORM] = ndi.v2.covariateValues(COVARIATE, DIMENSIONS). COVARIATE is
%   one entry of a value's data.covariates (did-schema
%   V_eta_data_body_model_plan.md AMENDMENT 6), DIMENSIONS the value's
%   data.dimensions (needed to expand origin + spacing). FORM names the one
%   value form it carries, and V is:
%     origin_spacing  origin + spacing * (0:n-1)', n the extent of its one
%                     dimension (the canonical numbers)
%     quantity        quantity.value (canonical, in the covariate's unit)
%     count           the integers
%     term            a string array of the terms' names
%     text            the strings (a string array)
%     logical         a logical array
%     matrix          the stored array
%     key             the 0-based position of the `key_id` entry whose value
%                     gives the positions (resolve it against the document);
%                     the covariate's `key` (did-schema [covariate key],
%                     2026-11-01)
%   Each is shaped by the extents of the `along` dimensions when its element
%   count fits them (a vector along one dimension is a column).
%
%   See also ndi.v2.axesTable, ndi.v2.covariatesTable.

arguments
    covariate
    dimensions = []
end

v = []; form = "";
if ~isstruct(covariate) || isempty(covariate)
    return;
end
c = covariate(1);
dims = ndi.v2.entries(dimensions);
along = [];
if isfield(c, 'along'), along = double(c.along(:)'); end
if has(c, 'origin') || has(c, 'spacing')
    form = "origin_spacing";
    o = double(pick(c, 'origin', 0));
    s = double(pick(c, 'spacing', 1));
    n = NaN;
    if isscalar(along) && numel(dims) > along
        n = double(fieldOr(dims{along + 1}, 'n', NaN));
    end
    if ~isnan(n), v = o + s * (0:n-1)'; end
    return;
elseif has(c, 'quantity')
    form = "quantity";
    v = double(pick(c, 'quantity', []));
elseif has(c, 'count')
    form = "count";
    v = double(c.count);
elseif has(c, 'term')
    form = "term";
    t = ndi.v2.entries(c.term);
    v = strings(numel(t), 1);
    for j = 1:numel(t), v(j) = string(ndi.v2.termName(t{j})); end
elseif has(c, 'text')
    form = "text";
    v = string(c.text);
elseif isfield(c, 'logical') && ~isempty(c.logical)
    form = "logical";
    x = c.logical;
    if iscell(x), x = cellfun(@(e) logical(e), x); end
    v = logical(x);
elseif has(c, 'matrix')
    form = "matrix";
    v = c.matrix;
    return;
elseif isfield(c, 'key') && ~isempty(c.key) && ~isequal(c.key, -1)
    % did-schema [covariate key] (Jess Haley, 2026-11-01: "Yes, rename
    % document to key")
    form = "key";
    v = double(c.key);
    return;
else
    return;
end
v = shapeAlong(v, along, dims);
end

function v = shapeAlong(v, along, dims)
sz = [];
for a = along
    if numel(dims) > a
        sz(end+1) = double(fieldOr(dims{a + 1}, 'n', NaN)); %#ok<AGROW>
    end
end
if isempty(sz) || any(isnan(sz)) || prod(sz) ~= numel(v)
    return;
end
if isscalar(sz)
    v = reshape(v, sz, 1);
else
    v = reshape(v, sz);
end
end

function tf = has(s, name)
tf = isfield(s, name) && ~isempty(s.(name));
end

function x = pick(s, name, default)
% a {value, source_value} pair's canonical value, or a bare number
x = default;
if ~isfield(s, name) || isempty(s.(name)), return; end
p = s.(name);
if isstruct(p)
    if isfield(p, 'value') && ~isempty(p(1).value), x = p(1).value; end
else
    x = p;
end
end

function v = fieldOr(s, name, default)
v = default;
if isstruct(s) && isfield(s, name) && ~isempty(s(1).(name))
    v = s(1).(name);
end
end
