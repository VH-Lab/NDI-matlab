function tf = sourceUnitIsTerm()
%SOURCEUNITISTERM True when the V2 schema in use stores a value's source unit as a term.
%
%   TF = ndi.v2.sourceUnitIsTerm() is true when DID_SCHEMA_PATH holds a V2
%   schema whose dimensioned values declare `source_unit` an ontology_term
%   {node, name}: did-schema V_eta_source_unit_plan.md (signed 2026-10-21),
%   the unit's registered term with its label as the name. False on
%   did-schema main (`source_unit` is char) and when no V2 schema is set.
%
%   Asked by file, the same way as ndi.v2.sessionIdIsEdge, of `time`'s value
%   cell (the plan changed every declaration at once, so one answers for all),
%   so it works before the schema cache is loaded and with a DID-matlab that
%   predates did2.schema.cache/sourceUnitIsTerm.
%
%   See also ndi.setup.V2.sourceUnit, ndi.v2.sessionIdIsEdge.

[has, decl] = ndi.setup.V2.schemaHasField('time', 'value.source_unit');
tf = has && isstruct(decl) && isfield(decl, 'type') && strcmp(char(decl.type), 'ontology_term');
end
