function aliases = fieldAliases()
%FIELDALIASES Static V2 <-> did_v1 field-alias table.
%
%   ALIASES = NDI.COMPAT.FIELDALIASES() returns a struct describing every
%   field whose path or shape differs between the V2 canonical schema
%   and the did_v1 legacy schema. The struct is consumed by:
%     - ndi.document read-time augmentation (issue 6),
%     - ndi.document write-time re-derivation (issue 7),
%     - ndi.query path translation (issue 8).
%   This function returns data only; it performs no transformation itself.
%
%   The returned struct has one field:
%
%     aliases.fields    - cell N-by-3 of {canonicalPath, legacyPath, transform}
%                         describing dot-path field aliases inside the
%                         document body (under the class-scoped property
%                         blocks).
%
%   Note: depends_on entry-key compatibility (did_v1 `id` /
%   `value` <-> V2 `document_id`) is NOT in this table. It is
%   handled instead by the ndi.document dependency accessors
%   (set_dependency_value, dependency_value, etc.) which read
%   tolerantly across all three key spellings and write the V2
%   canonical, and by ndi.compat.translateQueryPaths which rewrites
%   query paths. The body itself only ever carries `document_id`,
%   so the depends_on struct-array schema never grows to include
%   legacy keys (avoiding the heterogeneousStrucAssignment fragility
%   class — see #801).
%
%   Row columns (for `aliases.fields`):
%     canonicalPath / canonicalKey - char, the canonical V2 path or key.
%     legacyPath  / legacyKey - char (single path) or cellstr (multi-path
%                               composition). A cellstr indicates that the
%                               V2 value is composed from more than
%                               one legacy field, and the transform handles
%                               the reshape in both directions.
%     transform               - [] for scalar identity (the value moves
%                               between paths unchanged), or a 1x2 cell
%                               {toCanonical, toLegacy} of function handles:
%                                 toCanonical(legacyValue)   -> canonicalValue
%                                 toLegacy(canonicalValue)   -> legacyValue
%                               When legacyPath is a cellstr, toCanonical
%                               receives a cell array of legacy values in
%                               the same order and toLegacy returns a cell
%                               array in the same order.
%
%   SOURCE OF TRUTH: the did_v1 side of every row below must be a field that
%   an NDI document template in ndi_common/database_documents ACTUALLY HAS.
%
%   It used to say the source of truth was the per-class conversion markdown in
%   did-schema's per-class conversion notes (deleted with did-schema #88). That was wrong, and
%   it put four fabricated rows in this table. Those markdown files were written
%   against did-schema's own V_alpha/V_beta snapshots, which for the two ontology
%   classes do not match anything NDI ever shipped. Checked against the full
%   NDI history:
%
%     ontologyImage  created 2025-07-03, three commits total, ALWAYS
%                    {ontologyNode} with an ontologyTableRow_id dependency.
%                    It has never had `ontology_name` or `ontology_region`.
%     ontologyLabel  created 2025-08-01, ALWAYS {ontologyNode}. It has never
%                    had `ontology_name`, `label_id` or `label`.
%
%   So the removed rows described documents that do not exist. They could never
%   fire on real data, and the tests that covered them were written to the same
%   fabricated shape -- which is exactly how the error survived. The identical
%   mistake in DID-matlab's migrator silently produced empty observations; see
%   did-schema/schemas/V_eta_ngrid_family_findings.md.
%
%   The probe_location and treatment rows below ARE real and stay: their
%   templates genuinely carry {ontology_name, name} and {ontologyName, name}.
%
%   KNOWN LIMITATION, RECORDED 2026-10-23 AND NOT CHANGED: these rows are
%   produced only on WRITE (ndi.compat.reconcileWrite moves the legacy fields
%   to the canonical path and strips them), and ndi.query rewrites a legacy
%   query path to the canonical one (ndi.compat.translateQueryPaths). A
%   probe_location or treatment document stored in the v1 shape -- written by
%   NDI v1 and never re-written by NDI V2 -- carries only the legacy fields,
%   so reading it works (augmentRead is a no-op and the legacy fields are
%   there) but a query on the legacy path is rewritten to a path it does not
%   have. Read from the code, not run. Until 2026-10-23 no read-time step
%   produced these canonical paths either (no base migrator exists for
%   either class), so this is not new; whether this layer stays is open.
%
%   NOT DONE HERE: whether `ontologyNode` deserves a correct row of its own
%   (e.g. ontology_label.term.node <- ontology_label.ontology_node) is a
%   separate design question, deliberately left open rather than guessed at.

    aliases.fields = { ...
        % probe_location: ontology_name + name -> location (ontology_term)
        'probe_location.location.node', 'probe_location.ontology_name', []; ...
        'probe_location.location.name', 'probe_location.name',          []; ...
        ...
        % treatment: ontology_name + name -> treatment_name (ontology_term)
        'treatment.treatment_name.node', 'treatment.ontology_name', []; ...
        'treatment.treatment_name.name', 'treatment.name',          []; ...
    };
end
