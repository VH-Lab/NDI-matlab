function ss = translateQueryPaths(ss)
%TRANSLATEQUERYPATHS Make a query on a depends_on entry key match every key spelling.
%
%   SS = ndi.compat.translateQueryPaths(SS) walks a search-structure
%   array (the shape stored on `did.query.searchstructure`) and replaces a
%   term whose `.field` path names a depends_on entry's target key
%
%     depends_on.document_id, depends_on.value, depends_on.id,
%     depends_on(N).document_id, depends_on(N).value, depends_on(N).id
%
%   with the same test on all three keys (`document_id`, `value`, `id`,
%   keeping any `(N)` index):
%
%     - a plain operation becomes an 'or' over the three keys: the
%       document matches when ANY key passes;
%     - a negated operation ('~exact_string', ...) becomes, by De Morgan,
%       the three negated tests side by side, which fieldsearch ANDs: the
%       document matches when NO key matches the plain test.
%
%   A document keeps the dependency shape it was read in: a v1 document's
%   entries are keyed `value` (or the older `id`), a v2 document's
%   `document_id` (DID-matlab #389; did-schema
%   did_v2_go_forward_class_audit.md [v2 line reads and writes both], Jess
%   Haley, 2026-11-03, after VH-Lab/DID-matlab#204). So a query written
%   against any one key must find both shapes; it is not rewritten from one
%   spelling to another. This is the same rule did.query's `depends_on`
%   operation follows (dependsOnSearchstructure), which the high-level
%   `depends_on` operation uses unchanged. An 'or' operation recurses into
%   param1 / param2. Every other path passes through unchanged.
%
%   Prefer the `depends_on` operation, ndi.query('', 'depends_on', NAME,
%   VALUE): it tests the name and the target of the same entry, and the
%   SQL backends match it in SQL. A `.field` path on depends_on is tested
%   only where documents are searched one by one (did.datastructures.fieldsearch).
%
%   NO FIELD ALIASES. This function used to rewrite
%   probe_location.ontology_name / .name and treatment.ontology_name / .name
%   to reshaped paths (probe_location.location.*, treatment.treatment_name.*)
%   that ndi.compat.reconcileWrite wrote into v1 databases. That write layer
%   is removed (Decided by Jess Haley, 2026-10-23 [compat write layer
%   removed]; VH-Lab/NDI-matlab#1055): v1 data is written as the v1
%   template's shape, so a query on a v1 path is left as written.
%
%   Inputs:
%     SS  Struct array - searchstructure as stored on did.query.
%
%   Outputs:
%     SS  Struct array - the same terms, a depends_on target-key term
%                        replaced by its test on every key spelling.
%
%   See also: ndi.query, did.query, ndi.document.i_readDependencyTarget.

    if isempty(ss) || ~isstruct(ss)
        return;
    end

    out = ss([]);
    for k = 1:numel(ss)
        term = ss(k);
        if isfield(term, 'operation')
            op = term.operation;
            if (ischar(op) || isstring(op)) && strcmpi(op, 'or')
                if isfield(term, 'param1') && isstruct(term.param1)
                    term.param1 = ndi.compat.translateQueryPaths(term.param1);
                end
                if isfield(term, 'param2') && isstruct(term.param2)
                    term.param2 = ndi.compat.translateQueryPaths(term.param2);
                end
            end
        end
        if isfield(term, 'field')
            prefix = i_dependsOnTargetPrefix(term.field);
            if ~isempty(prefix)
                out = cat(1, out(:), i_everyKey(term, prefix));
                continue;
            end
        end
        out = cat(1, out(:), term);
    end
    if isrow(ss)
        out = out.';
    end
    ss = out;
end

function prefix = i_dependsOnTargetPrefix(field)
% 'depends_on' or 'depends_on(N)' when FIELD names a depends_on target key
prefix = '';
if isstring(field)
    field = char(field);
end
if ~ischar(field) || isempty(field)
    return;
end
tokens = regexp(field, '^(depends_on(\(\d+\))?)\.(document_id|value|id)$', 'tokens', 'once');
if ~isempty(tokens)
    prefix = tokens{1};
end
end

function terms = i_everyKey(term, prefix)
% TERM's test on each of the three target keys: an 'or' chain for a plain
% operation, the negated tests side by side (ANDed) for a negated one.
keys = {'document_id', 'value', 'id'};
alts = repmat(term, 3, 1);
for k = 1:numel(keys)
    alts(k).field = [prefix '.' keys{k}];
end
op = char(term.operation);
if ~isempty(op) && op(1) == '~'
    terms = alts;
    return;
end
inner = term;
inner.field = '';
inner.operation = 'or';
inner.param1 = alts(2);
inner.param2 = alts(3);
terms = term;
terms.field = '';
terms.operation = 'or';
terms.param1 = alts(1);
terms.param2 = inner;
end
