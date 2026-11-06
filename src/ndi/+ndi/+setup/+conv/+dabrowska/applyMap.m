function report = applyMap(path, v1Bodies, options)
%APPLYMAP The Dabrowska dataset map, applied to a migrated V2 database.
%
%   REPORT = ndi.setup.conv.dabrowska.applyMap(PATH, V1BODIES)
%
%   PATH      - the session root that ndi.migrate.local migrated (it holds
%               PATH/.ndi/did_v2.sqlite).
%   V1BODIES  - the Dabrowska v1 documents that were migrated, as JSON text
%               or decoded structs (the migration's input).
%
%   It reads every document of the migrated database, plans the Dabrowska
%   slices and tetanus runs (ndi.setup.conv.dabrowska.sliceTetanus), folds
%   the documents it mints through did2.convert.v1_to_v2 (validated), and
%   writes the result back into the same database: the minted documents
%   added, the documents whose edge moved replaced (base.id kept), and the
%   documents it supersedes removed. REPORT is sliceTetanus's report plus
%   what was written, denominators first.
%
%   WHERE THIS COMES FROM
%     Decided by Jess Haley, 2026-10-25 [sliceTetanus to Dab map]: the slice
%       and tetanus step comes out of the generic stage (NDI's second pass)
%       into the Dabrowska dataset map; the generic stage carries those
%       documents as v1, and the Dab corpus test checks that generic stage +
%       map reproduces the output of the old second-pass step.
%     Decided by Jess Haley, 2026-10-26 [dataset map location]: the map is
%       applied by its own step after the generic migration has written the
%       V2 database, beside the importer and its decision log (this folder).
%     Decided by Jess Haley, 2026-10-26 [dataset map edits V2]: the map runs
%       AFTER the generic migration and may change V2 documents it wrote
%       (mint the slices, add the tetanus runs, move the baths and statements
%       from the animal to its slice, drop the before/after labels).
%     Jess Haley, 2026-11-06 ("a"): build the move now.
%   (all in did-schema docs/plans/did_v2_go_forward_class_audit.md; the
%   Dabrowska decisions themselves are V2_decisions.md in this folder.)
%
%   NOT DECIDED, so not built here: the map's file format and how a map file
%   is applied in general (did-schema docs/V2_PLAN.md, DQ23). The draft rows
%   (VH-Lab/NDI-matlab#1148) are not read. This function is the one Dabrowska
%   pass the map holds today (the draft's row dab-p01), called by the Dab
%   corpus test (ndi.unittest.migrate.TestMigrateLocalEtaDab). Nothing in
%   ndi.migrate.local calls it: the generic stage has no dataset slots.
%
%   RE-RUNNING IT on a database it already mapped plans nothing new: the
%   bath stimulators' statements are on the slices already, so it reports
%   what it read and changes nothing it cannot match. Re-run it on a fresh
%   migration.
%
%   THE STORED MIGRATION REPORT is the generic stage's: it lists the 635
%   approach documents as carried as v1 (carry-165), and this map then
%   removes them. The map's own record is REPORT and its printed census.

arguments
    path (1,:) char
    v1Bodies cell
    options.Validate (1,1) logical = true
    options.SchemaCache = []
    options.Verbose (1,1) logical = true
end

ndiDir = fullfile(path, '.ndi');
dstPath = ndi.database.implementations.database.did2sqlite.FILEIN(ndiDir);
if ~isfile(dstPath)
    error('NDI:dabrowska:applyMap:noDatabase', ...
        'No migrated V2 database at %s; run ndi.migrate.local first.', dstPath);
end

tStart = tic;
db = did2.database.sqlitedb(dstPath, 'SchemaCache', options.SchemaCache);
dbCleanup = onCleanup(@() db.close());
ids = db.allIds();
structs = cell(1, numel(ids));
for k = 1:numel(ids)
    structs{k} = db.get(ids{k}).toStruct();
end
tRead = toc(tStart);

epochIndex = epochIndexOf(structs);
v1 = decodeBodies(v1Bodies);
[plan, report] = ndi.setup.conv.dabrowska.sliceTetanus(v1, structs, epochIndex);
report.database = dstPath;
report.database_documents_before = numel(ids);
report.minted_folded = 0;
report.minted_quarantined = 0;
report.quarantine = {};
report.folded = false;
report.reattributions_applied = 0;
report.removals_applied = 0;
report.replacements_refused_have_files = 0;
report.database_documents_after = numel(ids);
report.seconds_read = tRead;
if ~report.changed
    report.seconds_total = toc(tStart);
    if options.Verbose; printSliceTetanus(report); end
    return;
end

% ---- fold the minted documents (the same call the second-pass step made) ----
minted = containers.Map('KeyType', 'char', 'ValueType', 'logical');
mintedDocs = {};
if ~isempty(plan.minted)
    sub = did2.convert.v1_to_v2(plan.minted, ...
        'Validate',      options.Validate, ...
        'SchemaCache',   options.SchemaCache, ...
        'TargetVersion', 'did_v2', ...
        'Verbose',       false);
    report.minted_folded = numel(sub.migrated);
    report.minted_quarantined = numel(sub.quarantine);
    report.quarantine = sub.quarantine;
    for k = 1:numel(sub.migrated)
        minted(sub.migrated{k}.get('base.id')) = true;
    end
    mintedDocs = reshape(sub.migrated, 1, []);
end

% A document is dropped only when nothing minted failed (a failed mint keeps
% what it would replace); a move stands only when its new target was minted.
% A document both moved and dropped is dropped, as the second-pass step did.
present = containers.Map(ids, num2cell(true(size(ids))));
removeSet = containers.Map('KeyType', 'char', 'ValueType', 'logical');
if report.minted_quarantined == 0
    for k = 1:numel(plan.removed)
        if isKey(present, plan.removed{k})
            removeSet(plan.removed{k}) = true;
        end
    end
end
removeIds = keys(removeSet);
replacedById = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(plan.replaced)
    s = plan.replaced{k};
    id = s.base.id;
    if isKey(removeSet, id) || ~isKey(present, id) || ~movedTargetMinted(s, minted)
        continue;
    end
    if ~isempty(db.fileNames(id))
        % replacing is remove + add, and remove deletes ingested bytes
        report.replacements_refused_have_files = ...
            report.replacements_refused_have_files + 1;
        continue;
    end
    replacedById(id) = s;
end

% ---- write: remove, then add the replacements and the minted documents ----
% The add is one transaction (all or nothing); if it is refused, the removed
% documents are put back as they were, so a refused map leaves the generic
% output, never a half-mapped database.
replaceIds = keys(replacedById);
toAdd = cell(1, numel(replaceIds));
for k = 1:numel(replaceIds)
    toAdd{k} = did2.document(replacedById(replaceIds{k}));
end
toAdd = [toAdd, mintedDocs];
goneIds = [reshape(removeIds, 1, []), reshape(replaceIds, 1, [])];
originals = cell(1, numel(goneIds));
for k = 1:numel(goneIds)
    originals{k} = db.get(goneIds{k});
end
for k = 1:numel(goneIds)
    db.remove(goneIds{k});
end
try
    if ~isempty(toAdd)
        db.add(toAdd, 'Validate', options.Validate);
    end
catch ME
    db.add(originals, 'Validate', false);
    rethrow(ME);
end
report.reattributions_applied = numel(replaceIds);
report.removals_applied = numel(removeIds);
report.database_documents_after = db.count();
report.folded = true;
report.seconds_total = toc(tStart);
if options.Verbose; printSliceTetanus(report); end
end

% ---------------------------------------------------------------------------

function idx = epochIndexOf(structs)
%EPOCHINDEXOF (session_id, local_identifier, epoch_document_id) of every epoch
%   entity in the database: what did2.convert.epochMint published as
%   `epoch_index` during the migration, read back from the stored documents.
%   A (session, epoch) pair claimed by two epoch documents is left out, as
%   did2.convert.epochIndex refuses it (never a guess).
idx = struct('session_id', {}, 'local_identifier', {}, 'epoch_document_id', {});
keyCount = containers.Map('KeyType', 'char', 'ValueType', 'double');
rows = struct('session_id', {}, 'local_identifier', {}, 'epoch_document_id', {});
for k = 1:numel(structs)
    b = structs{k};
    if ~isfield(b, 'document_class') || ~strcmp(char(b.document_class.class_name), 'entity') ...
            || ~isfield(b, 'entity') || ~isstruct(b.entity) || ~isscalar(b.entity) ...
            || ~isfield(b.entity, 'type') || ~isstruct(b.entity.type) ...
            || ~did2.build.isVocabulary(b.entity.type, 'entity_type', 'epoch')
        continue;
    end
    lid = '';
    if isfield(b.entity, 'local_identifier'); lid = char(b.entity.local_identifier); end
    sid = char(did2.schema.cache.sessionIdOf(b));
    if isempty(lid) || isempty(sid); continue; end
    key = [sid '|' lid];
    if isKey(keyCount, key)
        keyCount(key) = keyCount(key) + 1;
    else
        keyCount(key) = 1;
    end
    rows(end+1) = struct('session_id', sid, 'local_identifier', lid, ...
        'epoch_document_id', char(b.base.id)); %#ok<AGROW>
end
for k = 1:numel(rows)
    if keyCount([rows(k).session_id '|' rows(k).local_identifier]) == 1
        idx(end+1) = rows(k); %#ok<AGROW>
    end
end
end

function out = decodeBodies(bodies)
% A cell of scalar structs: JSON text is decoded, structs pass through.
out = {};
for k = 1:numel(bodies)
    b = bodies{k};
    if ischar(b) || (isstring(b) && isscalar(b))
        try
            b = jsondecode(char(b));
        catch
            continue;
        end
    end
    if isstruct(b) && isscalar(b)
        out{end+1} = b; %#ok<AGROW>
    end
end
end

function tf = movedTargetMinted(s, minted)
% The moved edge -- `entity_id` on a statement, `parent_id` on a relation
% (did-schema #88; `subject_id` / `parent` before) -- always names a minted
% slice; the move stands only if that slice was folded.
edges = {'entity_id', 'subject_id'};
if strcmp(s.document_class.class_name, 'directed_relation')
    edges = {'parent_id', 'parent'};
end
tf = false;
for k = 1:numel(s.depends_on)
    if any(strcmp(s.depends_on(k).name, edges))
        v = '';
        if isfield(s.depends_on(k), 'value'); v = s.depends_on(k).value;
        elseif isfield(s.depends_on(k), 'document_id'); v = s.depends_on(k).document_id; end
        tf = ischar(v) && isKey(minted, v);
        return;
    end
end
end

function printSliceTetanus(r)
%PRINTSLICETETANUS The map's census, denominators first, in the log.
fprintf(['SLICE / TETANUS (Dabrowska map, ndi.setup.conv.dabrowska.applyMap)\n' ...
    '  DENOMINATOR: %d v1 document(s), %d migrated document(s) in the database, %d epoch index entr(ies)\n' ...
    '  stimulators %d: slice baths %d, not a slice bath %d, animal mismatch %d\n' ...
    '  slices minted %d; new animals %d (epochs on a nested date %d); strain assertions copied %d\n' ...
    '  epoch-anchored statements examined %d: matched %d, unmatched %d\n' ...
    '  unanchored statements examined %d: matched %d, ambiguous %d\n' ...
    '  element observes-relations examined %d: matched %d, ambiguous %d\n' ...
    '  approach labels %d; runs examined %d; refused: not a clean switch %d, no epoch doc %d, no gap %d\n' ...
    '  tetanus manipulations %d (on a new animal %d): with target region %d, without %d; ' ...
    'with parameters %d, without %d\n' ...
    '  labels rebuilt %d/%d (not rebuilt %d); approach documents removed %d\n' ...
    '  treatment manipulations found %d: superseded %d, kept (no run) %d; part-subjects superseded %d\n' ...
    '  minted %d (folded %d, quarantined %d); re-attributed %d; removed %d; removals withheld %d\n' ...
    '  WRITTEN: replaced %d, removed %d, replacements refused (document has files) %d; ' ...
    'database %d -> %d document(s); %.1f s (read %.1f s)\n'], ...
    r.v1_documents_read, r.migrated_documents_read, r.epoch_index_entries, ...
    r.stimulators, r.slice_bath_stimulators, r.stimulators_not_a_slice_bath, ...
    r.stimulators_animal_mismatch, r.slices, r.new_animals, ...
    r.epochs_on_a_nested_date, r.new_animal_strain_assertions_copied, ...
    r.epoch_statements_examined, r.epoch_statements_matched, r.epoch_statements_unmatched, ...
    r.unanchored_statements_examined, r.unanchored_statements_matched, ...
    r.unanchored_statements_ambiguous, r.element_relations_examined, ...
    r.element_relations_matched, r.element_relations_ambiguous, ...
    r.approach_labels, r.runs_examined, r.runs_refused_not_a_clean_switch, ...
    r.runs_refused_no_epoch_document, r.runs_refused_no_gap, ...
    r.tetanus_manipulations, r.tetanus_on_new_animal, r.tetanus_with_target_region, ...
    r.tetanus_without_target_region, r.tetanus_with_parameters, r.tetanus_without_parameters, ...
    r.labels_rebuilt, r.approach_labels, r.labels_not_rebuilt, r.approach_labels_removed, ...
    r.treatment_manipulations_found, r.treatment_manipulations_superseded, ...
    r.treatment_manipulations_kept_no_run, r.treatment_part_subjects_superseded, ...
    r.documents_minted, r.minted_folded, r.minted_quarantined, ...
    r.documents_reattributed, r.documents_removed, r.removals_withheld_still_referenced, ...
    r.reattributions_applied, r.removals_applied, r.replacements_refused_have_files, ...
    r.database_documents_before, r.database_documents_after, r.seconds_total, r.seconds_read);
cls = fieldnames(r.reattributed_by_class);
for k = 1:numel(cls)
    fprintf('    re-attributed %-28s %d\n', cls{k}, r.reattributed_by_class.(cls{k}));
end
end
