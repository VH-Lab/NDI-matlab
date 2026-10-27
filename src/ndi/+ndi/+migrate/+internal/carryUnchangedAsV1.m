function [docs, report] = carryUnchangedAsV1(docs, passthrough, sourceBodies, secondPassRows)
%CARRYUNCHANGEDASV1 Store each document no step changed as its v1 source, stamped 'did_v1'.
%
%   [DOCS, REPORT] = ndi.migrate.internal.carryUnchangedAsV1(DOCS, PASSTHROUGH, SOURCEBODIES)
%   [DOCS, REPORT] = ndi.migrate.internal.carryUnchangedAsV1(..., SECONDPASSROWS)
%   is the last migration step of ndi.migrate.local. DOCS is the cell of
%   did2.document the whole pipeline produced (pass 1, the DID batch passes
%   and NDI's second pass). PASSTHROUGH is pass 1's record of the v1
%   documents no migrator changed (did2.convert.v1_to_v2's
%   result.passthrough: input_index, id, class_name, body -- the body pass 1
%   emitted). SOURCEBODIES is the v1 input, in pass 1's order.
%   SECONDPASSROWS (optional) is a struct array {id, row}: each document NDI's
%   second pass declined to convert, with the carry register row its reason
%   cites (Decided by Jess Haley, 2026-10-26 [carry register]; did-schema
%   schemas/V_eta_carry_register.json). The first row named for an id counts.
%   A record may also carry `dependency`: the id of the document that blocked
%   it. When that document is itself carried as v1, the record counts under
%   carry-064 instead ([dependents of a carried document carry], Jess Haley,
%   2026-10-26): it was carried because what it depends on was.
%
%   Decided by Jess Haley, 2026-10-24 [passthrough stays v1] and
%   [passthrough stays v1: how] (did-schema V_eta_go_forward_class_audit.md):
%   a v1 document the generic migration carries through unchanged stays a v1
%   document, stamped v1, rather than becoming a V_eta document of a retired
%   class; "carried through unchanged" is judged after the whole pipeline,
%   so the second pass keeps receiving what it receives today. The v1 stamp
%   is 'did_v1' ([document stamps], 2026-10-25).
%
%   WHAT "UNCHANGED" MEANS HERE. A recorded document is unchanged when the
%   document of its id at the end is still IDENTICAL (isequaln) to the body
%   pass 1 emitted for it: no superclass or concrete migrator changed it
%   (that is what put it in PASSTHROUGH), and no later step did either. Its
%   final body is then its v1 SOURCE body, with
%   document_class.schema_version = 'did_v1' added and nothing else changed.
%   did2.database.sqlitedb stores such a document without V_eta validation
%   and counts it.
%
%   REPORT (denominators first, unconditionally):
%     documents_inspected     numel(DOCS)
%     passed_through_pass_one numel(PASSTHROUGH)
%     carried_as_v1           of those, stored as their v1 source ('did_v1')
%     changed_after_pass_one  present at the end, but a later step changed it
%     absent_at_end           no document of that id at the end (folded,
%                             replaced or removed by a later step)
%     not_a_source            the input position is past SOURCEBODIES (a
%                             transient body ndi.migrate.local added, e.g. the
%                             navigator epoch files)
%     source_unreadable       the source body could not be read as a document
%     source_id_mismatch      the source at that position has another base.id
%     carried_by_class        struct array {class_name, count}, most first
%     carried_with_second_pass_row     of carried_as_v1, those SECONDPASSROWS
%                             names (a second-pass carry, by register row)
%     carried_without_second_pass_row  of carried_as_v1, the rest (pass 1
%                             passed them through and no second-pass step
%                             named a row: pass-1 carries cite their rows in
%                             DID-matlab's notes)
%     carried_by_row          struct array {row, count}, most first: the
%                             second-pass carries by register row; the counts
%                             sum to carried_with_second_pass_row
%     changed_by_class        the same, for changed_after_pass_one
%     absent_by_class         the same, for absent_at_end
%   (class_name is the class pass 1 recorded for the document)
%   The six outcomes after the first two sum to passed_through_pass_one.
%
%   See also ndi.migrate.local, did2.convert.v1_to_v2,
%            did2.database.sqlitedb, did2.schema.isV1Stamp.

arguments
    docs cell
    passthrough struct
    sourceBodies
    secondPassRows struct = struct('id', {}, 'row', {}, 'dependency', {})
end

if ~iscell(sourceBodies)
    sourceBodies = num2cell(sourceBodies);
end

report = struct( ...
    'documents_inspected',     numel(docs), ...
    'passed_through_pass_one', numel(passthrough), ...
    'carried_as_v1',           0, ...
    'changed_after_pass_one',  0, ...
    'absent_at_end',           0, ...
    'not_a_source',            0, ...
    'source_unreadable',       0, ...
    'source_id_mismatch',      0, ...
    'carried_by_class',        struct('class_name', {}, 'count', {}), ...
    'carried_with_second_pass_row',    0, ...
    'carried_without_second_pass_row', 0, ...
    'carried_by_row',          struct('row', {}, 'count', {}), ...
    'changed_by_class',        struct('class_name', {}, 'count', {}), ...
    'absent_by_class',         struct('class_name', {}, 'count', {}));
if isempty(passthrough)
    return;
end

% base.id -> position in DOCS (the first, if an id repeats: ndi.migrate.local
% refuses a repeated id before writing anyway)
where = containers.Map('KeyType', 'char', 'ValueType', 'double');
for k = 1:numel(docs)
    id = idOf(docs{k});
    if ~isempty(id) && ~isKey(where, id)
        where(id) = k;
    end
end

% second-pass carry rows by document id (the first named wins)
rowOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
depOf = containers.Map('KeyType', 'char', 'ValueType', 'char');
hasDep = isfield(secondPassRows, 'dependency');
for r = 1:numel(secondPassRows)
    if ~isfield(secondPassRows, 'id') || ~isfield(secondPassRows, 'row')
        break;
    end
    rid = char(secondPassRows(r).id);
    rrow = char(secondPassRows(r).row);
    if ~isempty(rid) && ~isempty(rrow) && ~isKey(rowOf, rid)
        rowOf(rid) = rrow;
        if hasDep && ~isempty(secondPassRows(r).dependency)
            depOf(rid) = char(secondPassRows(r).dependency);
        end
    end
end
carriedIds = {};

carried = newTally();
byRow = newTally();
changed = newTally();
absent = newTally();
for r = 1:numel(passthrough)
    rec = passthrough(r);
    if rec.input_index > numel(sourceBodies)
        report.not_a_source = report.not_a_source + 1;
        continue;
    end
    id = char(rec.id);
    if isempty(id) || ~isKey(where, id)
        report.absent_at_end = report.absent_at_end + 1;
        absent = bump(absent, rec.class_name);
        continue;
    end
    j = where(id);
    if ~isequaln(docs{j}.toStruct(), rec.body)
        report.changed_after_pass_one = report.changed_after_pass_one + 1;
        changed = bump(changed, rec.class_name);
        continue;
    end
    src = readSource(sourceBodies{rec.input_index});
    if isempty(src)
        report.source_unreadable = report.source_unreadable + 1;
        continue;
    end
    if ~strcmp(idOf(src), id)
        report.source_id_mismatch = report.source_id_mismatch + 1;
        continue;
    end
    src.document_class.schema_version = 'did_v1';
    docs{j} = did2.document(src);
    report.carried_as_v1 = report.carried_as_v1 + 1;
    cn = '';
    if isfield(src.document_class, 'class_name')
        cn = char(src.document_class.class_name);
    end
    carried = bump(carried, cn);
    carriedIds{end+1} = id; %#ok<AGROW>
end
% by row, once every carry is known (a dependency is judged against the
% whole carried set)
carriedSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
for c = 1:numel(carriedIds)
    carriedSet(carriedIds{c}) = true;
end
for c = 1:numel(carriedIds)
    id = carriedIds{c};
    if isKey(rowOf, id)
        report.carried_with_second_pass_row = report.carried_with_second_pass_row + 1;
        row = rowOf(id);
        % carry-register: carry-064
        if isKey(depOf, id) && isKey(carriedSet, depOf(id))
            row = 'carry-064';   % [dependents of a carried document carry]
        end
        byRow = bump(byRow, row);
    else
        report.carried_without_second_pass_row = ...
            report.carried_without_second_pass_row + 1;
    end
end
report.carried_by_class = asTable(carried);
rowTable = asTable(byRow);
report.carried_by_row = struct('row', {rowTable.class_name}, 'count', {rowTable.count});
report.changed_by_class = asTable(changed);
report.absent_by_class = asTable(absent);
end

function t = newTally()
t = struct('names', {{}}, 'counts', []);
end

function t = bump(t, name)
name = char(name);
ix = find(strcmp(t.names, name), 1);
if isempty(ix)
    t.names{end+1} = name;
    t.counts(end+1) = 0;
    ix = numel(t.names);
end
t.counts(ix) = t.counts(ix) + 1;
end

function tbl = asTable(t)
[counts, order] = sort(t.counts, 'descend');
names = t.names(order);
tbl = struct('class_name', names, 'count', num2cell(counts));
if isempty(names)
    tbl = struct('class_name', {}, 'count', {});
end
end

function id = idOf(d)
id = '';
if isa(d, 'did2.document')
    d = d.toStruct();
end
if isstruct(d) && isscalar(d) && isfield(d, 'base') && isstruct(d.base) ...
        && isscalar(d.base) && isfield(d.base, 'id')
    v = d.base.id;
    if isstring(v) && isscalar(v), v = char(v); end
    if ischar(v), id = v; end
end
end

function s = readSource(raw)
% The v1 source as a struct with a document_class block, or [] when it is not one.
s = [];
try
    if isstruct(raw) && isscalar(raw)
        s = raw;
    elseif ischar(raw) || (isstring(raw) && isscalar(raw))
        s = jsondecode(char(raw));
    elseif isa(raw, 'did2.document')
        s = raw.toStruct();
    end
catch
    s = [];
end
if ~isstruct(s) || ~isscalar(s) || ~isfield(s, 'document_class') ...
        || ~isstruct(s.document_class) || ~isscalar(s.document_class)
    s = [];
end
end
