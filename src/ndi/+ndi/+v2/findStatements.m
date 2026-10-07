function [docs, info] = findStatements(container, kind, filt)
%FINDSTATEMENTS The statement documents of a kind that match a filter.
%
%   [DOCS, INFO] = ndi.v2.findStatements(CONTAINER, KIND, FILT) searches the
%   ndi.session or ndi.dataset CONTAINER for statements of KIND -- 'statement'
%   (any), 'assertion', 'interaction', 'observation', 'manipulation',
%   'calculation', or a document class -- matching FILT, a struct with any of:
%
%     variable     the statement's variable
%     method       an interaction's method (an assertion has none: an error)
%     value        the statement's value
%     formulation  a dose's formulation (its name or its type)
%
%   Each is a pattern or a cell array of patterns (any of them). A pattern
%   matches a term's name ignoring case or its node exactly, '*' being a
%   wildcard and '\*' a literal star (ndi.v2.matchTerm). A VALUE is matched by
%   the kind of value the statement has:
%
%     a term ({name, node})   as above
%     a date (an ISO instant) as text ('2023-11-*'), or compared: '>2023-11-16',
%                             '>=', '<', '<=', at the coarser of the two
%                             precisions ('2023-11' is neither before nor
%                             after '2023-11-16'; '>=' and '<=' hold)
%     a single number         equal to a number (20 or '20'), or compared:
%                             '>20', '>=0.02', in the value's canonical unit
%                             (a dose: its one amount -- volume in liters,
%                             mass in grams, ...)
%   A value kept as an array or in a data body has no single value: a VALUE
%   pattern does not match it, and if every statement that matched the rest
%   of FILT is one, that is an error (ndi:v2:findStatements:noSingleValue).
%
%   The class, variable and method narrow the database search (wildcards
%   too, when did2 has the `wildcard` operator: DID-matlab #218); a plain
%   text value narrows it for terms; everything is then rechecked here.
%   DOCS is a cell array. INFO has fields:
%     structural   the statements matching class, variable and method
%     values       the text of each one's value (for "values here: ...")

arguments
    container
    kind (1,:) char
    filt (1,1) struct
end
filt = normalise(filt);
if ~isempty(filt.method) && strcmp(kind, 'assertion')
    error('ndi:v2:findStatements:assertionMethod', 'An assertion has no method.');
end

q = ndi.query('', 'isa', classOf(kind), '');
q = andTerm(q, 'subject_statement.variable', filt.variable);
q = andTerm(q, 'subject_interaction.method', filt.method);
if ~isempty(filt.value) && all(cellfun(@isPlainText, filt.value))
    % a term value can be narrowed in the database; a statement whose value
    % is not a term passes to the recheck. When that finds nothing, search
    % again without it: "the variable is there, the value is not" (a
    % warning naming the values) is not "nothing has this variable"
    cand = container.database_search(q & ...
        (termQuery('term.value', filt.value) | ndi.query('', '~isa', 'term', '')));
    if isempty(cand)
        cand = container.database_search(q);
    end
else
    cand = container.database_search(q);
end

structural = {};
for i = 1:numel(cand)
    p = ndi.v2.props(cand{i});
    if ~patternsMatch(ndi.v2.blockOf(p, 'subject_statement', 'variable', []), filt.variable), continue; end
    if ~patternsMatch(ndi.v2.blockOf(p, 'subject_interaction', 'method', []), filt.method), continue; end
    structural{end+1} = cand{i}; %#ok<AGROW>
end
info = struct('structural', numel(structural), 'values', {{}});
docs = {};
single = 0;
forms = formulationsOf(container, structural, filt.formulation);
for i = 1:numel(structural)
    p = ndi.v2.props(structural{i});
    [kindOfValue, v] = valueOf(p);
    info.values{end+1} = textOf(kindOfValue, v);
    if ~strcmp(kindOfValue, 'none'), single = single + 1; end
    if ~isempty(filt.value) && ~any(cellfun(@(pat) valueMatches(kindOfValue, v, pat), filt.value))
        continue;
    end
    if ~isempty(filt.formulation)
        f = ndi.v2.edgeIds(p, 'formulation_id');
        if ~any(cellfun(@(x) isKey(forms, x) && forms(x), f)), continue; end
    end
    docs{end+1} = structural{i}; %#ok<AGROW>
end
if ~isempty(filt.value) && ~isempty(structural) && single == 0
    error('ndi:v2:findStatements:noSingleValue', ...
        ['Every %s matching this filter keeps its value as an array or in a data body, ' ...
         'so it has no single value to compare.'], kind);
end
info.values = unique(info.values(~cellfun(@isempty, info.values)));
end

% -------------------------------------------------------------------------

function filt = normalise(filt)
for f = {'variable', 'method', 'value', 'formulation'}
    if ~isfield(filt, f{1}) || isempty(filt.(f{1}))
        filt.(f{1}) = {};
    elseif ~iscell(filt.(f{1}))
        filt.(f{1}) = {filt.(f{1})};
    end
    filt.(f{1}) = cellfun(@asPattern, filt.(f{1}), 'UniformOutput', false);
end
end

function x = asPattern(x)
if isstring(x), x = char(x); end
end

function c = classOf(kind)
short = {'statement', 'assertion', 'interaction', 'observation', 'manipulation', 'calculation'};
if any(strcmp(kind, short))
    c = ['subject_' kind];
else
    c = kind;
end
end

function tf = isPlainText(p)
tf = ischar(p) && ~ndi.v2.hasWildcard(p) && isempty(comparison(p));
end

function q = andTerm(q, path, patterns)
% narrow by a term field when the database can: a plain pattern always, a
% wildcard when did2 has the operator; otherwise the recheck does it alone
if isempty(patterns), return; end
if any(cellfun(@ndi.v2.hasWildcard, patterns)) && ~ndi.v2.hasWildcardOperator()
    return;
end
q = q & termQuery(path, patterns);
end

function q = termQuery(path, patterns)
q = [];
for k = 1:numel(patterns)
    p = patterns{k};
    if ~ischar(p), continue; end
    if ndi.v2.hasWildcard(p)
        one = ndi.query([path '.name'], 'wildcard', p, '') | ndi.query([path '.node'], 'wildcard', p, '');
    else
        one = ndi.query([path '.name'], 'exact_string_anycase', strrep(p, '\*', '*'), '') | ...
            ndi.query([path '.node'], 'exact_string', strrep(p, '\*', '*'), '');
    end
    if isempty(q), q = one; else, q = q | one; end
end
end

function tf = patternsMatch(term, patterns)
tf = isempty(patterns) || any(cellfun(@(p) ischar(p) && ndi.v2.matchTerm(term, p), patterns));
end

function forms = formulationsOf(container, docs, patterns)
% formulation id -> does it match one of PATTERNS (by its name or its type)
forms = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if isempty(patterns), return; end
ids = {};
for i = 1:numel(docs)
    ids = [ids, ndi.v2.edgeIds(ndi.v2.props(docs{i}), 'formulation_id')]; %#ok<AGROW>
end
ids = unique(ids);
if isempty(ids), return; end
ents = ndi.entity.fetchMany(container, ids);
for i = 1:numel(ents)
    e = ents{i};
    t = ndi.v2.blockOf(e.document_properties(), 'formulation', 'value', struct());
    ty = [];
    if isstruct(t) && isfield(t, 'type'), ty = t.type; end
    forms(e.document_id) = any(cellfun(@(p) ischar(p) && ...
        (ndi.v2.matchTerm(struct('name', e.name, 'node', ''), p) || ndi.v2.matchTerm(ty, p)), patterns));
end
end

function [k, v] = valueOf(p)
% the statement's value as one of: 'term' {name,node}, 'date' (ISO text),
% 'number' (a scalar, canonical unit), 'text', or 'none' (an array, a body,
% a structure with no single amount, or no value)
k = 'none'; v = [];
if logical(firstOr(ndi.v2.blockOf(p, 'data_type', 'data_body', false), false))
    return;
end
chain = ndi.v2.classChain(p);
c = '';
for i = 1:numel(chain)
    if any(strcmp(ndi.v2.directParents(chain{i}), 'data_type')), c = chain{i}; break; end
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
    k = 'number'; v = double(raw); return;
end
if ~isstruct(raw), return; end
cf = ndi.data_type.canonicalField(c);
if ~isempty(cf) && isfield(raw, cf) && isnumeric(raw.(cf)) && isscalar(raw.(cf))
    k = 'number'; v = double(raw.(cf)); return;
end
% a structured value (a dose): its one amount, if it has exactly one
amounts = [];
f = fieldnames(raw);
for i = 1:numel(f)
    s = raw.(f{i});
    sf = ndi.data_type.canonicalField(f{i});
    if isstruct(s) && isscalar(s) && ~isempty(sf) && isfield(s, sf) && isnumeric(s.(sf)) && isscalar(s.(sf))
        amounts(end+1) = double(s.(sf)); %#ok<AGROW>
    end
end
if isscalar(amounts)
    k = 'number'; v = amounts;
end
end

function t = textOf(k, v)
switch k
    case 'term', t = ndi.v2.termName(v);
    case {'date', 'text'}, t = v;
    case 'number', t = num2str(v, 6);
    otherwise, t = '';
end
end

function tf = valueMatches(k, v, pat)
tf = false;
[op, rhs] = comparison(pat);
switch k
    case 'term'
        tf = isempty(op) && ischar(pat) && ndi.v2.matchTerm(v, pat);
    case 'text'
        tf = isempty(op) && ischar(pat) && ndi.v2.matchTerm(struct('name', v, 'node', ''), pat);
    case 'date'
        if ~isempty(op)
            n = min(numel(v), numel(rhs));
            tf = compareText(v(1:n), rhs(1:n), op);
        elseif ischar(pat)
            tf = ndi.v2.matchTerm(struct('name', v, 'node', ''), pat);
        end
    case 'number'
        if ~isempty(op)
            r = str2double(rhs);
            tf = ~isnan(r) && compareNumber(v, r, op);
        elseif isnumeric(pat) && isscalar(pat)
            tf = v == pat;
        elseif ischar(pat) && ~ndi.v2.hasWildcard(pat)
            tf = v == str2double(pat);
        end
end
end

function [op, rhs] = comparison(pat)
% '>=x', '<=x', '>x', '<x' (a leading '\' makes the sign literal)
op = ''; rhs = '';
if ~ischar(pat) || isempty(pat), return; end
t = regexp(pat, '^(>=|<=|>|<)\s*(.+)$', 'tokens', 'once');
if ~isempty(t), op = t{1}; rhs = strtrim(t{2}); end
end

function tf = compareText(a, b, op)
c = sign(double(strcmp(a, b) == 0) * (2 * double(issorted({b, a})) - 1));
tf = applyOp(c, op);
end

function tf = compareNumber(a, b, op)
tf = applyOp(sign(a - b), op);
end

function tf = applyOp(c, op)
switch op
    case '>',  tf = c > 0;
    case '>=', tf = c >= 0;
    case '<',  tf = c < 0;
    case '<=', tf = c <= 0;
    otherwise, tf = false;
end
end

function v = firstOr(x, default)
if isempty(x), v = default; else, v = x(1); end
end
