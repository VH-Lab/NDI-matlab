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
%   Both numeric shapes are read (did-schema did_v2_numeric_shape_plan.md,
%   [one shape for measured numbers], Jess Haley, 2026-11-17): the old
%   `quantity.value`, `matrix` and `origin`/`spacing` blocks {value,
%   source_value}, and the new flat `numeric` and plain `origin`/`spacing`
%   numbers. FORM keeps the old names: a `numeric` with one number per
%   position of its `along` dimensions (or with a `source_numeric`) is
%   'quantity', any other `numeric` array is 'matrix' (the stored array).
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
elseif has(c, 'numeric')
    % the new numeric shape (flat `numeric`, no wrapper)
    x = c.numeric;
    if iscell(x), x = cellNumbers(x); end
    v = double(x);
    if has(c, 'source_numeric') || fitsAlong(v, along, dims)
        form = "quantity";
    else
        form = "matrix";
        return;
    end
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

function tf = fitsAlong(v, along, dims)
% one number per position of the `along` dimensions
sz = [];
for a = along
    if numel(dims) > a
        sz(end+1) = double(fieldOr(dims{a + 1}, 'n', NaN)); %#ok<AGROW>
    end
end
tf = isempty(along) || (~isempty(sz) && ~any(isnan(sz)) && prod(sz) == numel(v));
end

function x = cellNumbers(c)
% a numeric array read back from JSON as a cell (a null in it): NaN there
x = c;
try
    x = cell2mat(cellfun(@(r) reshape(rowNumbers(r), 1, []), c(:), 'UniformOutput', false));
catch
end
end

function r = rowNumbers(r)
if iscell(r)
    r = cellfun(@(e) nanIfEmpty(e), r);
else
    r = nanIfEmpty(r);
end
end

function e = nanIfEmpty(e)
if isempty(e), e = NaN; end
e = double(e);
end

function tf = has(s, name)
tf = isfield(s, name) && ~isempty(s.(name));
end

function x = pick(s, name, default)
% a {value, source_value} pair's canonical value (old numeric shape), or a
% bare number (new numeric shape: `origin` and `spacing` are plain numbers
% beside `source_origin` and `source_spacing`)
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
