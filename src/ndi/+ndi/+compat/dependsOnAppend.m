function deps = dependsOnAppend(deps, entry)
%DEPENDSONAPPEND Append an entry to a depends_on struct array.
%
%   DEPS = ndi.compat.dependsOnAppend(DEPS, ENTRY) appends the scalar
%   struct ENTRY to the depends_on struct array DEPS, handling the
%   field-schema mismatch that would otherwise trip
%   "MATLAB:heterogeneousStrucAssignment" when one side carries the
%   legacy did_v1 alias columns (e.g., `id`) injected by
%   ndi.compat.augmentRead and the other does not.
%
%   The append uses field-by-field dynamic indexing so MATLAB
%   auto-extends the struct array with any fields ENTRY introduces and
%   pads the new slot with [] for any fields the array already carries
%   that ENTRY does not. After the append the helper re-runs the
%   depends_on aliases from ndi.compat.fieldAliases against the new
%   entry, so legacy callers still find `depends_on(end).id` mirroring
%   the canonical `depends_on(end).value`.
%
%   Inputs:
%     DEPS  Existing depends_on struct array (possibly empty), or [].
%     ENTRY 1x1 struct with at least `name` and `value` (the canonical
%           V_delta keys).
%
%   Outputs:
%     DEPS  Updated struct array with ENTRY appended at the end and
%           legacy aliases re-mirrored.
%
%   See also: ndi.compat.augmentRead, ndi.compat.fieldAliases,
%             ndi.document/set_dependency_value, ndi.document/plus.

    arguments
        deps
        entry (1,1) struct
    end

    if isempty(deps) || ~isstruct(deps)
        deps = entry;
        deps = i_mirrorEntry(deps, 1);
        return;
    end

    idx = numel(deps) + 1;
    fns = fieldnames(entry);
    for k = 1:numel(fns)
        deps(idx).(fns{k}) = entry.(fns{k});
    end

    deps = i_mirrorEntry(deps, idx);
end

function deps = i_mirrorEntry(deps, idx)
% Mirror V_delta canonical fields into their legacy aliases on the
% entry at deps(idx), using the alias table as the data-driven spec.
% The legacy field is added even if other entries didn't carry it
% (MATLAB auto-extends the struct array's field set), so the array
% stays consistent with the read-time augmentation contract.
aliases = ndi.compat.fieldAliases();
for k = 1:size(aliases.dependsOn, 1)
    vKey = aliases.dependsOn{k, 1};
    lKey = aliases.dependsOn{k, 2};
    tx   = aliases.dependsOn{k, 3};
    if ~isfield(deps, vKey)
        % V_delta canonical not present on this array; nothing to
        % mirror. Stay quiet (covers raw v1 bodies whose depends_on
        % carries only `id`).
        continue;
    end
    v = deps(idx).(vKey);
    if isempty(tx)
        deps(idx).(lKey) = v;
    else
        toLegacy = tx{2};
        deps(idx).(lKey) = toLegacy(v);
    end
end
end
