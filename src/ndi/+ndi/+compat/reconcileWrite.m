function body = reconcileWrite(body)
%RECONCILEWRITE Reconcile did_v1 legacy aliases back into V_delta canonical.
%
%   BODY = ndi.compat.reconcileWrite(BODY) is the write-side mirror of
%   ndi.compat.augmentRead. It walks the static alias table from
%   ndi.compat.fieldAliases and, for each row:
%     1. Reads the legacy did_v1 value(s) from the body, if present.
%     2. Reads the V_delta canonical value, if present.
%     3. If the legacy form is present and disagrees with (or precedes)
%        the V_delta canonical, treats the legacy form as authoritative
%        — the customer edited it — and writes the corresponding
%        V_delta canonical value back via the row's transform.
%     4. Strips the legacy field(s) from the body so only the V_delta
%        canonical hits storage.
%
%   For depends_on, the function mirrors `depends_on(k).id` back into
%   `depends_on(k).value` whenever .id is present and disagrees, then
%   strips .id from every entry.
%
%   This is the function callers should run on a document body just
%   before handing it to the database layer (or any other long-term
%   storage path) — it keeps the on-disk shape exclusively V_delta
%   while letting callers above the abstraction continue to interact
%   with legacy aliases at read time (ndi.compat.augmentRead).
%
%   Behaviour notes:
%     - Idempotent. Re-running on a body that has already been
%       reconciled (only V_delta paths remain) is a no-op because
%       the legacy fields are absent.
%     - V_delta wins only when the legacy field is absent. If the
%       legacy field is present and equals the V_delta canonical,
%       the legacy field is stripped and the canonical is unchanged.
%     - Known limitation (documented in issue #780): if a caller
%       reads a doc — which augments legacy aliases on the body —
%       then edits the V_delta canonical path directly while
%       leaving the now-stale legacy alias in place, this function
%       will treat the stale legacy as authoritative and overwrite
%       the V_delta edit. Callers who edit V_delta canonical paths
%       directly must either rmfield the legacy alias first or use
%       ndi.document/setproperties on the V_delta path (which keeps
%       the legacy alias in sync via subsequent augmentation).
%
%   Inputs:
%     BODY  1x1 struct  - A document body, typically the
%                         document_properties payload of an
%                         ndi.document.
%
%   Outputs:
%     BODY  1x1 struct  - The same body with legacy aliases reconciled
%                         back into V_delta canonical and the legacy
%                         fields stripped.
%
%   See also: ndi.compat.augmentRead, ndi.compat.fieldAliases,
%             ndi.database.internal.applyWriteReconciliation,
%             ndi.database/add, ndi.document/write.

    arguments
        body (1,1) struct
    end

    aliases = ndi.compat.fieldAliases();

    for rowIdx = 1:size(aliases.fields, 1)
        vDeltaPath = aliases.fields{rowIdx, 1};
        legacyPath = aliases.fields{rowIdx, 2};
        transform  = aliases.fields{rowIdx, 3};
        body = i_reconcileFieldRow(body, vDeltaPath, legacyPath, transform);
    end

    if isfield(body, 'depends_on') && ~isempty(body.depends_on)
        body.depends_on = i_reconcileDependsOn(body.depends_on, ...
            aliases.dependsOn);
    end
end

function body = i_reconcileFieldRow(body, vDeltaPath, legacyPath, transform)
% Skip the row if the V_delta top-level block is absent — neither
% V_delta nor legacy can apply.
topLevel = i_firstPathComponent(vDeltaPath);
if ~isfield(body, topLevel)
    return;
end

% Gather legacy presence + values.
if iscell(legacyPath)
    [legacyValues, anyPresent] = i_getCompositeLegacy(body, legacyPath);
    if ~anyPresent
        return;
    end
    if isempty(transform) || numel(transform) < 2 ...
            || ~isa(transform{1}, 'function_handle')
        error('NDI:compat:reconcileWrite:missingComposite', ...
            ['Alias row "%s" has a multi-path legacy target but no ' ...
             '{toVDelta, toLegacy} transform pair to compose.'], ...
            vDeltaPath);
    end
    toVDelta = transform{1};
    newVDeltaValue = toVDelta(legacyValues);
    body = i_setPath(body, vDeltaPath, newVDeltaValue);
    for j = 1:numel(legacyPath)
        body = i_stripPath(body, legacyPath{j});
    end
else
    [legacyValue, legacyPresent] = i_getPath(body, legacyPath);
    if ~legacyPresent
        return;
    end
    if isempty(transform)
        newVDeltaValue = legacyValue;
    else
        toVDelta = transform{1};
        newVDeltaValue = toVDelta(legacyValue);
    end
    body = i_setPath(body, vDeltaPath, newVDeltaValue);
    body = i_stripPath(body, legacyPath);
end
end

function [values, anyPresent] = i_getCompositeLegacy(body, legacyPaths)
values = cell(1, numel(legacyPaths));
anyPresent = false;
for j = 1:numel(legacyPaths)
    [v, found] = i_getPath(body, legacyPaths{j});
    if found
        anyPresent = true;
        values{j} = v;
    else
        values{j} = '';
    end
end
end

function deps = i_reconcileDependsOn(deps, dependsOnRows)
if iscell(deps)
    for k = 1:numel(deps)
        if isstruct(deps{k})
            deps{k} = i_reconcileDependsOnEntry(deps{k}, dependsOnRows);
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
    if ~isfield(deps, lKey)
        continue;
    end
    for k = 1:numel(deps)
        legacyValue = deps(k).(lKey);
        if isempty(tx)
            newCanonical = legacyValue;
        else
            toVDelta = tx{1};
            newCanonical = toVDelta(legacyValue);
        end
        if isfield(deps, vKey)
            currentCanonical = deps(k).(vKey);
            if ~isequal(currentCanonical, newCanonical) ...
                    && ~isempty(legacyValue)
                deps(k).(vKey) = newCanonical;
            end
        else
            deps(k).(vKey) = newCanonical;
        end
    end
    deps = rmfield(deps, lKey);
end
end

function entry = i_reconcileDependsOnEntry(entry, dependsOnRows)
for rowIdx = 1:size(dependsOnRows, 1)
    vKey = dependsOnRows{rowIdx, 1};
    lKey = dependsOnRows{rowIdx, 2};
    tx   = dependsOnRows{rowIdx, 3};
    if ~isfield(entry, lKey)
        continue;
    end
    legacyValue = entry.(lKey);
    if isempty(tx)
        newCanonical = legacyValue;
    else
        toVDelta = tx{1};
        newCanonical = toVDelta(legacyValue);
    end
    if isfield(entry, vKey)
        currentCanonical = entry.(vKey);
        if ~isequal(currentCanonical, newCanonical) ...
                && ~isempty(legacyValue)
            entry.(vKey) = newCanonical;
        end
    else
        entry.(vKey) = newCanonical;
    end
    entry = rmfield(entry, lKey);
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

function s = i_stripPath(s, path)
parts = strsplit(path, '.');
s = i_stripPathRecursive(s, parts);
end

function s = i_stripPathRecursive(s, parts)
if numel(parts) == 1
    if isfield(s, parts{1})
        s = rmfield(s, parts{1});
    end
    return;
end
if ~isfield(s, parts{1}) || ~isstruct(s.(parts{1})) ...
        || ~isscalar(s.(parts{1}))
    return;
end
s.(parts{1}) = i_stripPathRecursive(s.(parts{1}), parts(2:end));
end

function top = i_firstPathComponent(path)
idx = find(path == '.', 1, 'first');
if isempty(idx)
    top = path;
else
    top = path(1:idx-1);
end
end
