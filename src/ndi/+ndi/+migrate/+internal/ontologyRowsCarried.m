function report = ontologyRowsCarried(v1Bodies, migratedStructs)
%ONTOLOGYROWSCARRIED Count the v1 `ontologyTableRow` documents, and how many
%   of them the migrated set still carries as a table row.
%
%   REPORT = ndi.migrate.internal.ontologyRowsCarried(V1BODIES, MIGRATEDSTRUCTS)
%   reads every did_v1 body in V1BODIES (decoded structs, or raw JSON char) and
%   every migrated document struct in MIGRATEDSTRUCTS. It changes nothing: it
%   resolves no subject and re-folds nothing.
%
%   Decided by Jess Haley, 2026-10-30 [table rows carried as v1] (did-schema
%   V_eta_go_forward_class_audit.md): "the generic migration carries every v1
%   `ontologyTableRow` whole as v1; it resolves no subject and fans out no
%   statements, because a row does not state which entity each column is
%   about. Each dataset's import maps its own tables." Pass 1 carries every
%   row (did2.convert.migrators_j.ontology_table_row, register row carry-026),
%   so NDI's second pass no longer resolves a row's subject or re-folds it;
%   this count is what is left of that step.
%
%   REPORT states its denominators first and unconditionally:
%     v1_bodies_inspected   - entries of V1BODIES read
%     documents_inspected   - entries of MIGRATEDSTRUCTS read
%     v1_ontology_rows      - did_v1 `ontologyTableRow` bodies among them
%     rows_carried          - of those, rows whose id is still a table row
%                             (`ontology_table_row` or `ontologyTableRow`) in
%                             the migrated set
%     rows_not_carried      - rows whose id is absent from the migrated set or
%                             is another class there. Under [table rows
%                             carried as v1] this is expected to be 0; it is
%                             reported, not enforced.
%     rows_not_carried_ids  - their ids
%
%   This function is PURE: no converter, no database, no schema.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.carryUnchangedAsV1.

report = struct();
report.v1_bodies_inspected  = numel(v1Bodies);
report.documents_inspected  = numel(migratedStructs);
report.v1_ontology_rows     = 0;
report.rows_carried         = 0;
report.rows_not_carried     = 0;
report.rows_not_carried_ids = {};

carriedIds = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for i = 1:numel(migratedStructs)
    s = migratedStructs{i};
    id = baseId(s);
    if ~isempty(id) && isTableRowClass(classNameOf(s))
        carriedIds(id) = true;
    end
end

for k = 1:numel(v1Bodies)
    b = decodeOne(v1Bodies{k});
    if ~isstruct(b) || ~isTableRowClass(classNameOf(b))
        continue;
    end
    report.v1_ontology_rows = report.v1_ontology_rows + 1;
    id = baseId(b);
    if ~isempty(id) && isKey(carriedIds, id)
        report.rows_carried = report.rows_carried + 1;
    else
        report.rows_not_carried = report.rows_not_carried + 1;
        report.rows_not_carried_ids{end+1} = id;
    end
end
end

% ===================== helpers ============================================

function tf = isTableRowClass(c)
% did_v1 spells it `ontologyTableRow`; a body that has been through the
% universal renames spells it `ontology_table_row`. Both are the same row.
tf = strcmp(c, 'ontologyTableRow') || strcmp(c, 'ontology_table_row');
end

function b = decodeOne(b)
if ischar(b) || (isstring(b) && isscalar(b))
    try
        b = jsondecode(char(b));
    catch
        b = [];
    end
end
if ~(isstruct(b) && isscalar(b))
    b = [];
end
end

function c = classNameOf(s)
c = '';
if isstruct(s) && isscalar(s) && isfield(s, 'document_class') ...
        && isstruct(s.document_class) && isfield(s.document_class, 'class_name')
    c = charOf(s.document_class.class_name);
end
end

function id = baseId(s)
id = '';
if isstruct(s) && isscalar(s) && isfield(s, 'base') && isstruct(s.base) ...
        && isfield(s.base, 'id')
    id = charOf(s.base.id);
end
end

function s = charOf(v)
s = '';
if ischar(v)
    s = v;
elseif isstring(v) && isscalar(v)
    s = char(v);
elseif iscell(v) && isscalar(v)
    s = charOf(v{1});
end
end
