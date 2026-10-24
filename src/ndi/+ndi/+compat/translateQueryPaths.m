function ss = translateQueryPaths(ss)
%TRANSLATEQUERYPATHS Rewrite legacy depends_on entry keys in a query to `document_id`.
%
%   SS = ndi.compat.translateQueryPaths(SS) walks a search-structure
%   array (the shape stored on `did.query.searchstructure`) and rewrites
%   a `.field` path that names a legacy depends_on entry key to the key
%   the body carries:
%
%     depends_on.id, depends_on.value,
%     depends_on(N).id, depends_on(N).value   -> depends_on[(N)].document_id
%
%   ndi.document's constructor (ndi.compat.normalizeDependsOn), like
%   did.document's, stores every depends_on entry as {name, document_id},
%   so a query written against `id` or `value` would match nothing
%   without this. The high-level `depends_on` *operation* in did.query
%   uses param1/param2 for name/value rather than the `.field` path, so it
%   is unaffected. An 'or' operation recurses into param1 / param2. Every
%   other path passes through unchanged.
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
%     SS  Struct array - same shape, with legacy depends_on keys rewritten.
%
%   See also: ndi.compat.normalizeDependsOn, ndi.query.

    if isempty(ss) || ~isstruct(ss)
        return;
    end

    for k = 1:numel(ss)
        ss(k).field = i_translateField(ss(k).field);

        if ~isfield(ss, 'operation')
            continue;
        end
        op = ss(k).operation;
        if (ischar(op) || isstring(op)) && strcmpi(op, 'or')
            if isfield(ss, 'param1') && isstruct(ss(k).param1)
                ss(k).param1 = ndi.compat.translateQueryPaths(ss(k).param1);
            end
            if isfield(ss, 'param2') && isstruct(ss(k).param2)
                ss(k).param2 = ndi.compat.translateQueryPaths(ss(k).param2);
            end
        end
    end
end

function field = i_translateField(field)
if isstring(field)
    field = char(field);
end
if ~ischar(field) || isempty(field)
    return;
end

% Any of the legacy entry keys (`id`, `value`) collapses to `document_id`.
% The optional capture group `(\(\d+\))?` preserves any `(N)` array index
% so the rewrite is shape-preserving.
legacyKeys = {'id', 'value'};
for k = 1:numel(legacyKeys)
    lKey = legacyKeys{k};
    pattern = ['^depends_on(\(\d+\))?\.', regexptranslate('escape', lKey), '$'];
    tokens = regexp(field, pattern, 'tokens', 'once');
    if isempty(tokens)
        continue;
    end
    indexedPart = tokens{1};
    if isempty(indexedPart)
        field = 'depends_on.document_id';
    else
        field = ['depends_on', indexedPart, '.document_id'];
    end
    return;
end
end
