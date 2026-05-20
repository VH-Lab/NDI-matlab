function body = augmentRead(body)
%AUGMENTREAD Inject did_v1 legacy aliases into a V_delta document body.
%
%   BODY = ndi.compat.augmentRead(BODY) walks the static alias table
%   returned by ndi.compat.fieldAliases and, for each row, mirrors the
%   V_delta canonical value into the corresponding legacy did_v1 path.
%   The result is a body that satisfies both shapes simultaneously, so
%   customer code that still reads `doc.document_properties.probe_location.ontology_name`
%   (and the three other affected classes) keeps working after the
%   database layer has normalised the stored body to V_delta on read
%   (see ndi.database.internal.applyReadNormalization).
%
%   Field-level rows in the alias table cover the four classes whose
%   shape changed between did_v1 and V_delta:
%     probe_location, treatment, ontology_image, ontology_label.
%   The ontology_label row is composite: V_delta `ontology_label.term.node`
%   is the CURIE composed from did_v1 `ontology_name` + `label_id`. The
%   transform function in the alias table handles the decompose direction
%   used here.
%
%   The dependsOn row mirrors V_delta `depends_on(k).value` into the
%   did_v1 `depends_on(k).id` slot for every entry.
%
%   Behaviour notes:
%     - Rows whose V_delta top-level block is absent in the body are
%       skipped silently. That makes the function safe to call on any
%       document class: a treatment document does not gain a phantom
%       probe_location block.
%     - The function is idempotent. Re-running on an already-augmented
%       body overwrites legacy fields with values re-derived from the
%       V_delta canonical, which leaves the body unchanged. The V_delta
%       canonical is the source of truth at read time; write-time
%       reconciliation (legacy edits -> V_delta) is a separate concern
%       handled by issue #780 (ndi.document write-time re-derivation).
%     - The function is also safe to call on v1-shaped bodies. v1 lacks
%       every V_delta path consulted here, so every row is a no-op.
%       That lets the constructor of ndi.document call augmentRead
%       unconditionally regardless of whether the database backend has
%       already normalised the body to V_delta.
%
%   Inputs:
%     BODY  1x1 struct  - A document body, typically the
%                         document_properties payload returned by an
%                         ndi.database backend.
%
%   Outputs:
%     BODY  1x1 struct  - The same body with legacy aliases injected.
%
%   See also: ndi.compat.fieldAliases, ndi.document,
%             ndi.database.internal.applyReadNormalization.

    arguments
        body (1,1) struct
    end

    aliases = ndi.compat.fieldAliases();

    for rowIdx = 1:size(aliases.fields, 1)
        vDeltaPath = aliases.fields{rowIdx, 1};
        legacyPath = aliases.fields{rowIdx, 2};
        transform  = aliases.fields{rowIdx, 3};
        body = i_augmentFieldRow(body, vDeltaPath, legacyPath, transform);
    end

    if isfield(body, 'depends_on') && ~isempty(body.depends_on)
        body.depends_on = i_augmentDependsOn(body.depends_on, ...
            aliases.dependsOn);
    end
end

function body = i_augmentFieldRow(body, vDeltaPath, legacyPath, transform)
% Skip the row if the V_delta top-level block is absent — the row
% does not apply to this document class.
topLevel = i_firstPathComponent(vDeltaPath);
if ~isfield(body, topLevel)
    return;
end

[vValue, found] = i_getPath(body, vDeltaPath);
if ~found
    return;
end

if iscell(legacyPath)
    % Composite: V_delta value decomposes into multiple legacy values.
    if isempty(transform) || numel(transform) < 2 ...
            || ~isa(transform{2}, 'function_handle')
        error('NDI:compat:augmentRead:missingComposite', ...
            ['Alias row "%s" has a multi-path legacy target but no ' ...
             '{toVDelta, toLegacy} transform pair to decompose.'], ...
            vDeltaPath);
    end
    toLegacy = transform{2};
    legacyValues = toLegacy(vValue);
    for j = 1:numel(legacyPath)
        body = i_setPath(body, legacyPath{j}, legacyValues{j});
    end
else
    % Single legacy path; identity or scalar transform.
    if isempty(transform)
        legacyValue = vValue;
    else
        toLegacy = transform{2};
        legacyValue = toLegacy(vValue);
    end
    body = i_setPath(body, legacyPath, legacyValue);
end
end

function deps = i_augmentDependsOn(deps, dependsOnRows)
if iscell(deps)
    for k = 1:numel(deps)
        if isstruct(deps{k})
            deps{k} = i_augmentDependsOnEntry(deps{k}, dependsOnRows);
        end
    end
    return;
end
if ~isstruct(deps)
    return;
end

for rowIdx = 1:size(dependsOnRows, 1)
    vKey = dependsOnRows{rowIdx, 1};
    lKey = dependsOnRows{rowIdx, 2};
    tx   = dependsOnRows{rowIdx, 3};
    if ~isfield(deps, vKey)
        continue;
    end
    for k = 1:numel(deps)
        v = deps(k).(vKey);
        if isempty(tx)
            deps(k).(lKey) = v;
        else
            toLegacy = tx{2};
            deps(k).(lKey) = toLegacy(v);
        end
    end
end
end

function entry = i_augmentDependsOnEntry(entry, dependsOnRows)
for rowIdx = 1:size(dependsOnRows, 1)
    vKey = dependsOnRows{rowIdx, 1};
    lKey = dependsOnRows{rowIdx, 2};
    tx   = dependsOnRows{rowIdx, 3};
    if ~isfield(entry, vKey)
        continue;
    end
    v = entry.(vKey);
    if isempty(tx)
        entry.(lKey) = v;
    else
        toLegacy = tx{2};
        entry.(lKey) = toLegacy(v);
    end
end
end

function [val, found] = i_getPath(s, path)
parts = strsplit(path, '.');
val = [];
found = false;
cur = s;
for i = 1:numel(parts)
    if isstruct(cur) && isscalar(cur) && isfield(cur, parts{i})
        cur = cur.(parts{i});
    else
        return;
    end
end
val = cur;
found = true;
end

function s = i_setPath(s, path, val)
parts = strsplit(path, '.');
s = i_setPathRecursive(s, parts, val);
end

function s = i_setPathRecursive(s, parts, val)
if numel(parts) == 1
    s.(parts{1}) = val;
    return;
end
if ~isfield(s, parts{1}) || ~isstruct(s.(parts{1})) ...
        || ~isscalar(s.(parts{1}))
    s.(parts{1}) = struct();
end
s.(parts{1}) = i_setPathRecursive(s.(parts{1}), parts(2:end), val);
end

function top = i_firstPathComponent(path)
idx = find(path == '.', 1, 'first');
if isempty(idx)
    top = path;
else
    top = path(1:idx-1);
end
end
