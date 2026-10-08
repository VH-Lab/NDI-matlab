function [docs, info] = searchStatements(container, kind, filt)
%SEARCHSTATEMENTS The statement documents of a kind that match a filter.
%
%   [DOCS, INFO] = ndi.v2.searchStatements(CONTAINER, KIND, FILT) searches the
%   ndi.session or ndi.dataset CONTAINER for statements of KIND -- 'statement'
%   (any), 'assertion', 'interaction', 'observation', 'manipulation',
%   'calculation', or a document class -- matching FILT, a struct with any of:
%
%     variable     the statement's variable
%     method       an interaction's method (an assertion has none: an error)
%     value        the statement's value
%     formulation  a dose's formulation (its name or its type)
%     subject      document ids: only statements about these subjects
%                  (searched 200 at a time)
%     at, during, before, after, duration
%                  when it held: see ndi.v2.timeFilter; 'tolerant' (true or
%                  false) widens each time by its tolerance
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
%   of FILT is one, that is an error (ndi:v2:searchStatements:noSingleValue).
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
    error('ndi:v2:searchStatements:assertionMethod', 'An assertion has no method.');
end

q = ndi.v2.isaQuery(classOf(kind));
q = andTerm(q, 'statement.variable', filt.variable);
q = andTerm(q, 'interaction.method', filt.method);
if ~isempty(filt.value) && all(cellfun(@isPlainText, filt.value))
    % a term value can be narrowed in the database; a statement whose value
    % is not a term passes to the recheck. When that finds nothing, search
    % again without it: "the variable is there, the value is not" (a
    % warning naming the values) is not "nothing has this variable"
    cand = bySubject(container, q & ...
        (ndi.v2.termQuery('term.value', filt.value) | ndi.query('', '~isa', 'term', '')), filt.subject);
    if isempty(cand)
        cand = bySubject(container, q, filt.subject);
    end
else
    cand = bySubject(container, q, filt.subject);
end

structural = {};
for i = 1:numel(cand)
    p = ndi.v2.props(cand{i});
    if ~patternsMatch(ndi.v2.blockOf(p, 'statement', 'variable', []), filt.variable), continue; end
    if ~patternsMatch(ndi.v2.blockOf(p, 'interaction', 'method', []), filt.method), continue; end
    structural{end+1} = cand{i}; %#ok<AGROW>
end
info = struct('structural', numel(structural), 'values', {{}}, 'beforeTime', 0);
docs = {};
single = 0;
forms = formulationsOf(container, structural, filt.formulation);
for i = 1:numel(structural)
    p = ndi.v2.props(structural{i});
    [kindOfValue, v, txt] = ndi.v2.statementValue(p);
    info.values{end+1} = txt;
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
tf = intersect({'at', 'during', 'before', 'after', 'duration'}, fieldnames(filt));
info.time = struct('unresolved', 0, 'nozone', 0, 'bound', 0, 'docs', 0);
info.timed = ~isempty(tf);
if info.timed && ~isempty(docs)
    tol = isfield(filt, 'tolerant') && ~isempty(filt.tolerant) && logical(filt.tolerant);
    [keepT, info.time] = ndi.v2.timeFilter(container, docs, filt, tol);
    info.beforeTime = numel(docs);
    docs = docs(keepT);
end
if ~isempty(filt.value) && ~isempty(structural) && single == 0
    error('ndi:v2:searchStatements:noSingleValue', ...
        ['Every %s matching this filter keeps its value as an array or in a data body, ' ...
         'so it has no single value to compare.'], kind);
end
info.values = unique(info.values(~cellfun(@isempty, info.values)));
end

% -------------------------------------------------------------------------

function docs = bySubject(container, q, ids)
% search Q, restricted to statements about IDS ({} for any), 200 ids a search
if isempty(ids)
    docs = container.database_search(q);
    return;
end
docs = {};
for c = 1:200:numel(ids)
    part = ids(c:min(c + 199, numel(ids)));
    qs = cellfun(@(i) ndi.v2.entityQuery(i), part, 'UniformOutput', false);
    docs = [docs, reshape(container.database_search(q & ndi.v2.anyOf(qs)), 1, [])]; %#ok<AGROW>
end
end

function filt = normalise(filt)
if ~isfield(filt, 'subject') || isempty(filt.subject)
    filt.subject = {};
else
    filt.subject = unique(cellstr(filt.subject), 'stable');
end
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
% the six kinds are the class names themselves since 2026-10-08 (isaQuery
% also finds documents written as `subject_<kind>`)
c = kind;
end

function tf = isPlainText(p)
tf = ischar(p) && ~ndi.v2.hasWildcard(p) && isempty(comparison(p));
end

function q = andTerm(q, path, patterns)
% narrow by a term field when the database can (ndi.v2.termQuery); the
% recheck does the rest
patterns = patterns(cellfun(@ischar, patterns));
if isempty(patterns), return; end
t = ndi.v2.termQuery(path, patterns);
if ~isempty(t), q = q & t; end
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
