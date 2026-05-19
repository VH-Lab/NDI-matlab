function aliases = fieldAliases()
%FIELDALIASES Static V_delta <-> did_v1 field-alias table.
%
%   ALIASES = NDI.COMPAT.FIELDALIASES() returns a struct describing every
%   field whose path or shape differs between the V_delta canonical schema
%   and the did_v1 legacy schema. The struct is consumed by:
%     - ndi.document read-time augmentation (issue 6),
%     - ndi.document write-time re-derivation (issue 7),
%     - ndi.query path translation (issue 8).
%   This function returns data only; it performs no transformation itself.
%
%   The returned struct has two fields:
%
%     aliases.fields    - cell N-by-3 of {vDeltaPath, legacyPath, transform}
%                         describing dot-path field aliases inside the
%                         document body (under the class-scoped property
%                         blocks).
%
%     aliases.dependsOn - cell M-by-3 of {vDeltaKey, legacyKey, transform}
%                         describing per-entry key renames inside each
%                         element of the document's depends_on array.
%
%   Row columns:
%     vDeltaPath / vDeltaKey - char, the canonical V_delta path or key.
%     legacyPath  / legacyKey - char (single path) or cellstr (multi-path
%                               composition). A cellstr indicates that the
%                               V_delta value is composed from more than
%                               one legacy field, and the transform handles
%                               the reshape in both directions.
%     transform               - [] for scalar identity (the value moves
%                               between paths unchanged), or a 1x2 cell
%                               {toVDelta, toLegacy} of function handles:
%                                 toVDelta(legacyValue)   -> vDeltaValue
%                                 toLegacy(vDeltaValue)   -> legacyValue
%                               When legacyPath is a cellstr, toVDelta
%                               receives a cell array of legacy values in
%                               the same order and toLegacy returns a cell
%                               array in the same order.
%
%   Source of truth for each row is the per-class conversion markdown in
%   did-schema/schemas/V_delta/conversions/from_did_v1/*.md.

    aliases.fields = { ...
        % probe_location: ontology_name + name -> location (ontology_term)
        'probe_location.location.node', 'probe_location.ontology_name', []; ...
        'probe_location.location.name', 'probe_location.name',          []; ...
        ...
        % treatment: ontology_name + name -> treatment_name (ontology_term)
        'treatment.treatment_name.node', 'treatment.ontology_name', []; ...
        'treatment.treatment_name.name', 'treatment.name',          []; ...
        ...
        % ontology_image: ontology_name + ontology_region -> region (ontology_term)
        'ontology_image.region.node', 'ontology_image.ontology_name',   []; ...
        'ontology_image.region.name', 'ontology_image.ontology_region', []; ...
        ...
        % ontology_label: ontology_name + label_id + label -> term (ontology_term).
        % term.node is the CURIE "<ontology_name>:<label_id>", so it is
        % composed from two legacy fields. term.name maps to legacy `label`.
        'ontology_label.term.node', ...
            {'ontology_label.ontology_name', 'ontology_label.label_id'}, ...
            {@i_labelNodeToVDelta, @i_labelNodeToLegacy}; ...
        'ontology_label.term.name', 'ontology_label.label', []; ...
    };

    aliases.dependsOn = { ...
        % did_v1 stored the referenced document id under depends_on(k).id;
        % V_delta renames the key to depends_on(k).value.
        'value', 'id', []; ...
    };
end

function vDeltaNode = i_labelNodeToVDelta(legacyValues)
    % Compose did_v1 {ontology_name, label_id} into a V_delta CURIE.
    ontologyName = legacyValues{1};
    labelId      = legacyValues{2};
    if isempty(ontologyName) && (isempty(labelId) || isequal(labelId, 0))
        vDeltaNode = '';
        return;
    end
    if isnumeric(labelId)
        labelIdStr = num2str(labelId);
    else
        labelIdStr = char(labelId);
    end
    vDeltaNode = [char(ontologyName) ':' labelIdStr];
end

function legacyValues = i_labelNodeToLegacy(vDeltaNode)
    % Decompose a V_delta CURIE into {ontology_name, label_id}. label_id is
    % returned as numeric (did_v1 declared it as integer with default 0);
    % if the local part is non-numeric, it is returned as a char.
    vDeltaNode = char(vDeltaNode);
    if isempty(vDeltaNode)
        legacyValues = {'', 0};
        return;
    end
    colonIdx = find(vDeltaNode == ':', 1, 'first');
    if isempty(colonIdx)
        legacyValues = {vDeltaNode, 0};
        return;
    end
    prefix    = vDeltaNode(1:colonIdx-1);
    localPart = vDeltaNode(colonIdx+1:end);
    numericId = str2double(localPart);
    if isnan(numericId)
        legacyValues = {prefix, localPart};
    else
        legacyValues = {prefix, numericId};
    end
end
