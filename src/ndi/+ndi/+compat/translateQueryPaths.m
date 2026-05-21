function ss = translateQueryPaths(ss)
%TRANSLATEQUERYPATHS Rewrite did_v1 legacy field paths to V_delta.
%
%   SS = ndi.compat.translateQueryPaths(SS) walks a search-structure
%   array (the shape stored on `did.query.searchstructure`) and rewrites
%   any `.field` path that names a did_v1 legacy alias to its V_delta
%   canonical counterpart, using ndi.compat.fieldAliases as the table.
%
%   This is the read-side mirror of ndi.compat.augmentRead for the
%   query path: customer code that constructs queries against the
%   legacy paths (e.g., `ndi.query('probe_location.ontology_name', ...)`)
%   keeps working after storage normalised to V_delta, because the
%   rewritten path hits the V_delta-side indexes both locally and over
%   the wire to the cloud.
%
%   Translation rules:
%     - Field-level alias rows: exact-path match in `.field`. A legacy
%       path that matches a row's second column is rewritten to the
%       row's first column (the V_delta canonical path).
%     - depends_on entry keys: paths shaped `depends_on.id`,
%       `depends_on.value`, `depends_on(N).id`, and
%       `depends_on(N).value` rewrite to `depends_on[.N].document_id`
%       (V_delta canonical). This rewrite is not driven by
%       ndi.compat.fieldAliases — depends_on entry-key compatibility
%       lives in code (here for queries; in ndi.document accessors
%       for body reads/writes) rather than in the alias table, so
%       the body's depends_on struct array never grows to include
%       legacy keys. See #801. The high-level `depends_on`
%       *operation* in did.query uses param1/param2 for name/value
%       rather than the `.field` path, so it is unaffected.
%     - 'or' operation: recurses into param1 / param2 (which hold
%       nested searchstructures).
%     - Paths not in the alias table pass through unchanged.
%
%   Composite limitation: alias rows whose legacy side is a cell-array
%   composition (e.g., `ontology_label.term.node` is composed from
%   `ontology_name` + `label_id`) collapse multiple legacy paths onto
%   a single V_delta path. The rewritten query reaches the right field
%   but the value semantics differ — the V_delta canonical for that
%   row is a CURIE like `<ontology_name>:<label_id>`, so an
%   exact_string match against the bare legacy value will no longer
%   succeed. Callers querying composite rows must update the value
%   (or operation) to match the V_delta shape; the corpus tests
%   (#785) are the catch-net for real-world breakage.
%
%   Inputs:
%     SS  Struct array - searchstructure as stored on did.query.
%
%   Outputs:
%     SS  Struct array - same shape, with legacy paths rewritten.
%
%   See also: ndi.compat.fieldAliases, ndi.compat.augmentRead,
%             ndi.compat.reconcileWrite, ndi.query.

    if isempty(ss) || ~isstruct(ss)
        return;
    end

    aliases = ndi.compat.fieldAliases();

    for k = 1:numel(ss)
        ss(k).field = i_translateField(ss(k).field, aliases);
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

function field = i_translateField(field, aliases)
if isstring(field)
    field = char(field);
end
if ~ischar(field) || isempty(field)
    return;
end

% Field-level rows: legacy is column 2, V_delta canonical is column 1.
% A legacy path may be a single char (scalar row) or a cell array of
% paths (composite row that collapses onto one V_delta path).
for r = 1:size(aliases.fields, 1)
    vDeltaPath = aliases.fields{r, 1};
    legacyPath = aliases.fields{r, 2};
    if iscell(legacyPath)
        for j = 1:numel(legacyPath)
            if strcmp(field, legacyPath{j})
                field = vDeltaPath;
                return;
            end
        end
    else
        if strcmp(field, legacyPath)
            field = vDeltaPath;
            return;
        end
    end
end

% depends_on entry-key rewrite: any of the legacy entry keys
% (`id`, `value`) collapses to the V_delta canonical `document_id`.
% The optional capture group `(\(\d+\))?` preserves any `(N)` array
% index so the rewrite is shape-preserving. This is hardcoded rather
% than data-driven because depends_on entry-key compatibility is
% deliberately out of ndi.compat.fieldAliases (see the docstring on
% that file and #801).
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
