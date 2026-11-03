function body = normalizeDependsOn(body)
%NORMALIZEDEPENDSON Canonicalize depends_on entry keys to document_id.
%
%   BODY = ndi.compat.normalizeDependsOn(BODY) walks the body's
%   `depends_on` struct array (if present) and ensures every entry
%   uses the v2 key `document_id`. v1 bodies carry the dependency
%   target under `value` (NDI's v1 templates) or the older `id`. This
%   helper accepts either of those (with precedence
%   `document_id > value > id` when more than one is populated on the
%   same entry) and produces a depends_on whose struct schema is
%   exactly `{name, document_id}`.
%
%   An EXPLICIT conversion. The ndi.document constructor no longer calls
%   it: a document keeps the dependency shape it was read in, v1 `value`
%   or v2 `document_id` (did-schema did_v2_go_forward_class_audit.md [v2
%   line reads and writes both], Jess Haley, 2026-11-03, after
%   VH-Lab/DID-matlab#204; DID-matlab #389 made did.document do the
%   same). did.document's setters write the key the entries already
%   carry, its readers accept every key, and
%   ndi.compat.translateQueryPaths makes a query on one key spelling
%   test all three. Converting is a caller's deliberate step, as
%   ndi.calculator does for a parameter specification it concatenates
%   with `document_id` entries.
%
%   Inputs:
%     BODY  1x1 struct  - A document body, typically
%                         document_properties.
%
%   Outputs:
%     BODY  1x1 struct  - Same body with depends_on normalised.
%
%   See also: ndi.document, ndi.compat.translateQueryPaths,
%             did.document.i_normalizeDependsOn.

    arguments
        body (1,1) struct
    end

    if ~isfield(body, 'depends_on')
        return;
    end

    body.depends_on = i_normalize(body.depends_on);
end

function deps = i_normalize(deps)
if iscell(deps)
    for k = 1:numel(deps)
        if isstruct(deps{k})
            deps{k} = i_normalizeEntry(deps{k});
        end
    end
    return;
end
if ~isstruct(deps)
    return;
end

hasId    = isfield(deps, 'id');
hasValue = isfield(deps, 'value');
hasDocId = isfield(deps, 'document_id');

n = numel(deps);

if n == 0
    % Empty struct array: canonicalise the field schema by
    % rebuilding the 0x0 struct with exactly {name, document_id}.
    % Legacy `id` / `value` keys (if any) are dropped from the
    % schema; document_id is added. Avoids the asymmetry where
    % rmfield('value') leaves the schema as {name} and the loop
    % that adds document_id doesn't run for n=0.
    deps = struct('name', {}, 'document_id', {});
    return;
end

if ~hasId && ~hasValue
    if hasDocId
        return;
    end
    % No id-bearing key at all. Stamp an empty `document_id` field so
    % the struct schema is canonical; entries with no target are
    % allowed by the schema (mustBeNonEmpty=false), so empty is fine.
    for k = 1:numel(deps)
        deps(k).document_id = '';
    end
    return;
end
docIds = cell(1, n);
for k = 1:n
    if hasDocId && ~isempty(deps(k).document_id)
        docIds{k} = deps(k).document_id;
    elseif hasValue && ~isempty(deps(k).value)
        docIds{k} = deps(k).value;
    elseif hasId
        docIds{k} = deps(k).id;
    else
        docIds{k} = '';
    end
end

if hasId
    deps = rmfield(deps, 'id');
end
if hasValue
    deps = rmfield(deps, 'value');
end

for k = 1:n
    deps(k).document_id = docIds{k};
end
end

function entry = i_normalizeEntry(entry)
hasId    = isfield(entry, 'id');
hasValue = isfield(entry, 'value');
hasDocId = isfield(entry, 'document_id');

if ~hasId && ~hasValue
    if ~hasDocId
        entry.document_id = '';
    end
    return;
end

if hasDocId && ~isempty(entry.document_id)
    docId = entry.document_id;
elseif hasValue && ~isempty(entry.value)
    docId = entry.value;
elseif hasId
    docId = entry.id;
else
    docId = '';
end

if hasId
    entry = rmfield(entry, 'id');
end
if hasValue
    entry = rmfield(entry, 'value');
end
entry.document_id = docId;
end
