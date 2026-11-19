function cw = crosswalk(schemaPath)
%CROSSWALK did-schema's openMINDS crosswalk, the one mapping the openMINDS export reads.
%
%   CW = ndi.openminds.crosswalk() reads did_v2_openminds_crosswalk.json
%   from the schema set on DID_SCHEMA_PATH; CW = ndi.openminds.crosswalk(PATH)
%   from the schema set at PATH. CW is the decoded JSON: `openminds` (the
%   pinned openMINDS version), `types` (per openMINDS type, one row per
%   property: its `target_kind` and v2 `ndi_target`) and
%   `contribution_types` (how each contribution edge and each CRediT role
%   exports).
%
%   The mapping is read, not coded here (did-schema
%   did_v2_openminds_import_export_plan.md 3.1): when the crosswalk's rows
%   change, the export follows them.
%
%   Errors ndi:openminds:crosswalk:notFound when the schema set has no
%   crosswalk.
%
%   See also ndi.openminds.exportDataset, ndi.v2.schemaFile.

arguments
    schemaPath (1,:) char = getenv('DID_SCHEMA_PATH')
end

f = ndi.v2.schemaFile(schemaPath, 'did_v2_openminds_crosswalk.json');
if ~isfile(f)
    error('ndi:openminds:crosswalk:notFound', ['No openMINDS crosswalk ' ...
        '(did_v2_openminds_crosswalk.json) in the schema set at "%s".'], schemaPath);
end
cw = jsondecode(fileread(f));
end
