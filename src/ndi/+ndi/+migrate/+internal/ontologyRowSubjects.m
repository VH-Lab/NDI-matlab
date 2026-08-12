function [plan, report] = ontologyRowSubjects(v1Bodies, migratedStructs, options)
%ONTOLOGYROWSUBJECTS V_eta second pass (#53): resolve the SUBJECT of an
%   `ontologyTableRow` against the migrated-id graph, so pass 1 can fan the row
%   out into statements instead of passing it through.
%
%   [PLAN, REPORT] = ndi.migrate.internal.ontologyRowSubjects(V1BODIES,
%   MIGRATEDSTRUCTS) inspects every did_v1 `ontologyTableRow` body in V1BODIES
%   that pass 1 left UNCONVERTED (it is still an `ontology_table_row` document
%   in MIGRATEDSTRUCTS, carrying its source id), tries to resolve which
%   migrated `subject` the row is about, and returns a PLAN: for each row it
%   could resolve, a COPY of the v1 body with a `subject_id` dependency added.
%   The caller re-folds each planned body through did2.convert.v1_to_v2 at
%   TargetVersion V_eta, where did2.convert.migrators_j.ontology_table_row's
%   guard now passes and the per-column fan-out runs (see
%   ndi.migrate.local/resolveOntologyRowSubjects).
%
%   This function is PURE: it reads structs and returns structs. It calls no
%   converter, touches no database, and needs no schema. That is what makes it
%   testable without a corpus.
%
%   REPORT states its denominators FIRST and unconditionally, and `[]` from the
%   caller means "did not run" -- so a silent zero and a real zero are
%   distinguishable from the output alone. It is RENDERED, not merely stored:
%   ndi.migrate.local/printOntologyRowSummary prints it, because this pass
%   REMOVES the `ontology_table_row` documents it re-folds and a pass that
%   deletes while reporting to nothing is the defect this project has twice.
%
%   TWO REPORT FIELDS ANSWER QUESTIONS THAT WERE OPEN RATHER THAN MEASURED:
%   `rows_with_plural_document_id` is the arity counter V_eta_OPEN_WORK.md row
%   #105 records as missing from all three repositories, and
%   `data_cells_on_unresolved_rows` is the quantity comparable in scale to the
%   76,766 hollow statements this defect was first measured at -- as an UPPER
%   BOUND, for the reason given beside the counters below. Neither changes
%   what the pass DOES; both remove an "unmeasured" from the record.
%
%   STATUS: authored WITHOUT local MATLAB. Neither this function nor its unit
%   tests (tests/+ndi/+unittest/+migrate/TestOntologyRowSubjects.m) have been
%   run. Nothing here has been exercised against a corpus. The 76,766 and the
%   20,583 quoted below are CARRIED FROM THE RECORD, not re-derived here --
%   this container has no MATLAB and no corpus. The counters above are what
%   will re-derive them on the first production run.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A SECOND PASS
%   ---------------------------------------------------------------------
%   The real NDI template declares exactly ONE dependency, and it is not
%   `subject_id`:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyTableRow.json
%         "depends_on": [ { "name": "document_id", "value": "" } ]
%         "ontologyTableRow": { names, variableNames, ontologyNodes, data }
%
%   So `carrySubject`'s scan for a `subject_id` dependency never succeeded on a
%   real document, and every emitted statement carried `subject_id = ''`. That
%   is the 76,766 figure recorded in the migrator's own comment (corpus run
%   #256, Dab alone). It is already STOPPED: the migrator now guards on
%   `resolvedSubject` and passes the whole document through. What is left is
%   the conversion, and it needs the migrated-id graph -- which is here.
%
%   ---------------------------------------------------------------------
%   THE THREE ROUTES, AND THE WRITER EVIDENCE FOR EACH
%   ---------------------------------------------------------------------
%   The writer is ndi.setup.NDIMaker.tableDocMaker.createOntologyTableRowDoc.
%   It has TWO ways of recording a referent, and which one a dataset uses is a
%   property of the CONVERTER that called it, not of the class:
%
%     src/ndi/+ndi/+setup/+NDIMaker/tableDocMaker.m
%         if isscalar(values)
%             doc = doc.set_dependency_value('document_id',value);
%         else
%             doc = doc.add_dependency_value_n('document_id',value);
%         end
%
%   A column named as `dependencyVariable` becomes the `document_id` EDGE. A
%   column that is not named there stays in `data` as an ordinary cell --
%   including, in three of the four production converters, the cell holding a
%   subject document's id.
%
%   THE WRITER ALSO USED TO DELETE THE DEPENDENCY COLUMN, one line above:
%
%     git show <pre-repair>:src/ndi/+ndi/+setup/+NDIMaker/tableDocMaker.m
%         varNames(ismember(varNames,dependencyVariable)) = [];
%
%   so route 1 and route 2 were MUTUALLY EXCLUSIVE for a given column: the edge
%   existed OR the `data` cell did, never both. THAT DELETION IS GONE -- a
%   dependency column is now kept as an ordinary column as well as becoming an
%   edge, so a Babu row written after the repair satisfies routes 1 AND 2 with
%   the SAME id. That is not a conflict: `resolveRowSubject` collects hits from
%   every route and only refuses when they name DIFFERENT documents
%   (`unique(ids)` below), so agreement resolves exactly as a single route did.
%
%   ROWS ALREADY WRITTEN ARE UNAFFECTED BY THAT REPAIR and still carry the edge
%   alone. Both shapes must keep working, which is why neither route is
%   preferred over the other here.
%
%   ROUTE 1 -- the `document_id` edge (`document_id`, or `document_id_1..n`
%   when the writer used add_dependency_value_n).
%       +setup/+conv/+babu/import.m:379-390 passes
%           'DependencyVariable','SubjectDocumentIdentifier'
%       on all four of its tables, so a Babu row's subject is the edge.
%       The edge is NOT renamed to `subject_id` blindly: `document_id` points at
%       whatever document the row describes, which need not be a subject (a
%       Haley imageStack row's edge points at another table row). The route
%       resolves it against the migrated set and accepts it ONLY if it lands on
%       a `subject`.
%
%   ROUTE 2 -- a `SubjectDocumentIdentifier` cell in `data`.
%       +setup/+conv/+haley/doImport.m:351  wormTable(:,{'wormID','subjectName','subject_id'})
%       +setup/+conv/+haley/doImport.m:533  plateSubjectTable{'subject_id','plate_id'}
%       +setup/+conv/+haley/doImport.m:688  dataTable(:,encounterVariables), encounterVariables{1} == 'subject_id'
%       +setup/+conv/+hunsberger/doImport.m:182,231,287  {'SubjectDocumentIdentifier',...}
%       and `wormTable.subject_id` is filled by subjectMaker.addSubjectsFromTable
%       (+setup/+NDIMaker/subjectMaker.m:30-84), i.e. it holds REAL subject
%       document ids. The `data` key is the ontology SHORT NAME, and the map
%       +setup/+conv/+haley/tableDoc_dictionary.json says
%           "subject_id": "EMPTY:subject document identifier"
%       -> shortName `SubjectDocumentIdentifier`. That spelling is not guessed:
%       did2.convert.migrators_j.ontology_table_row's encounter map, written
%       from real corpus documents, already reads
%           colVal(cols, 'SubjectDocumentIdentifier')
%       and four more keys in the same map (`BacterialPatchDocumentIdentifier`,
%       `BacterialPatchIdentifier`, `BacterialOD600TargetAtSeeding`,
%       `CElegansBehavioralAssay_EncounterIdentifier`) match the same
%       dictionary's term names under the same TitleCase rule.
%
%   ROUTE 3 -- a `SubjectLocalIdentifier` cell in `data`, joined by STRING to a
%       migrated subject's `subject.local_identifier`.
%       This is the ONLY route Dabrowska has. Its dictionary
%       (+setup/+conv/+dabrowska/tableDoc_dictionary.json) contains NO document
%       identifier of any kind -- the subject column is
%           "SubjectString": "EMPTY:Subject local identifier"
%       -> shortName `SubjectLocalIdentifier` -- and
%       +setup/+conv/+dabrowska/doImport.m:442,446 pass NO dependencyVariable,
%       so there is no edge either. The string is the same one that became the
%       subject: doImport.m:158,423 assign `variableTable.SubjectString` from
%       subjectMaker.getSubjectInfoFromTable's subjectName output, and
%       subjectMaker.m:258 writes that name as
%           ndi.document('subject','subject.local_identifier', sName, ...).
%
%       A STRING JOIN IS A WEAKER GUARANTEE THAN AN ID, so this route is
%       deliberately narrow: the match must be EXACT, scoped to the same
%       `base.session_id`, and UNIQUE. Two candidate subjects means no
%       resolution (REPORT.unresolved_local_identifier_ambiguous), never a
%       guess. Set 'LocalIdentifierJoin' false to disable the route entirely;
%       the report then shows the affected rows as unresolved rather than
%       silently omitting them. WHETHER THIS ROUTE IS ACCEPTABLE AT ALL IS A
%       TEAM QUESTION -- it is reported separately from routes 1 and 2 for
%       exactly that reason.
%
%   ---------------------------------------------------------------------
%   RULES OBSERVED
%   ---------------------------------------------------------------------
%   * NO UNRESOLVABLE EDGE IS EVER MINTED. A candidate is accepted only when it
%     names a document that IS PRESENT in the migrated set AND is a `subject`.
%     `did2/+validate/references.m:90` skips empty edges, so an edge that names
%     nobody would validate clean and mean nothing -- the exact defect this
%     pass exists to remove. An unresolvable candidate leaves the row as a
%     passthrough and is COUNTED, never written.
%   * A ROW WITH NO SUBJECT COLUMN IS NOT A DEFECT. Haley's plate, image and
%     fluorescence-patch tables describe plates, images and patches; Dabrowska
%     and Hunsberger have tables that are pure covariates. Those rows stay as
%     passthroughs and are counted under
%     REPORT.unresolved_no_candidate. Forcing a subject on them would be the
%     `distance_metadata` mistake (a non-gating passthrough turned into a
%     gating orphan failure).
%   * CONFLICT IS NOT RESOLVED BY PRECEDENCE. If two routes both resolve and
%     disagree, the row is left alone (REPORT.unresolved_conflicting_candidates).
%   * NO OTHER REFERENT IS TRADED AWAY. Converting a row costs it every edge
%     but `subject_id`, because migrators_j's `startStatement` ASSIGNS
%     `body.depends_on = carrySubject(preBody)` rather than extending it. A row
%     whose `document_id` names something that is not the resolved subject is
%     therefore left as a passthrough
%     (REPORT.unresolved_edge_would_be_dropped) -- relocating a silent loss is
%     not repairing one.
%   * `element_id` IS NOT TREATED AS A DANGLING NON-SUBJECT EDGE. It is not one:
%     did2.convert.migrators_j.element promotes elements to subjects with their
%     ids PRESERVED, so an element id resolves to a `subject` in the migrated
%     set and route 1 accepts it on exactly the same terms as any other id.
%
%   ---------------------------------------------------------------------
%   DELIBERATELY NOT DONE HERE
%   ---------------------------------------------------------------------
%   * `ontology_label` is NOT touched. Its `document_id` points at an
%     `imageStack`, not a subject, so it needs a different hop. See the report
%     accompanying this build.
%   * The `strain_id` edge that `V_eta_openminds_family_record.md` Part 7
%     assigns to "the pass that mints subjects from ontologyTableRow" is NOT
%     attached, because the rows carrying `bacteriaStrain` are the ones that
%     have no subject (haley/doImport.m:196 puts it on cultivationPlateTable /
%     behaviorPlateTable, and :716 on the E. coli plateTable). Reported, not
%     decided.
%   * Rows whose every column is an identity column (Haley's
%     plateSubjectTable is `{subject_id, plate_id}`, both skipped by
%     migrateRow) produce NO statements even once the subject is known. The
%     caller reverts those to their passthrough rather than writing a
%     tombstone with a new edge and nothing else. What that row actually says
%     -- "this worm was on this plate" -- is a directed_relation, and modelling
%     it is not in this pass's scope.
%
%   See also: ndi.migrate.local, ndi.migrate.internal.pathSPromotion,
%     ndi.migrate.internal.strainAssembly,
%     did2.convert.migrators_j.ontology_table_row.

arguments
    v1Bodies cell
    migratedStructs cell
    options.LocalIdentifierJoin (1,1) logical = true
end

v1Bodies = decodeBodies(v1Bodies);
migratedStructs = decodeBodies(migratedStructs);

plan = emptyPlan();

% ---- denominators, computed and stored FIRST -----------------------------
report = struct();
report.v1_bodies_inspected      = numel(v1Bodies);
report.documents_inspected      = numel(migratedStructs);
report.v1_ontology_rows         = 0;   % did_v1 ontologyTableRow bodies present
report.rows_passthrough         = 0;   % still `ontology_table_row` after pass 1
report.rows_converted_in_pass_1 = 0;   % the per-table maps already handled these
report.subjects_indexed         = 0;   % migrated documents that ARE a subject
report.subject_local_ids_unique = 0;   % (session_id, local_identifier) keys with ONE subject
report.local_identifier_join_enabled = options.LocalIdentifierJoin;

% ---- ARITY AND SCALE: the two things this instrument could not report ----
% (a) PLURAL `document_id`. V_eta_OPEN_WORK.md row #105 records that no
%     counter in any of the three repositories can answer "how many rows
%     ALREADY WRITTEN carry document_id_1..n":
%     imagedEntitySubjects.blocked_plural_document_id is NDI-side and never
%     runs in the DID corpus harness, silentLoss.docs_multi_member is gated on
%     `referent_unique_by` and `ontology_table_row` is not one of its three
%     entries, and THIS report had no arity counter at all
%     (`resolved_via_document_id_edge` counts resolutions, not arity). The
%     in-tree population is zero BY CONSTRUCTION -- on origin/main
%     'DependencyVariable' is passed at exactly four sites, all
%     +setup/+conv/+babu/import.m:380,383,386,389, each naming ONE column --
%     so a NON-ZERO count here means an OUT-OF-TREE writer, which is exactly
%     the unmeasured population #105 names. COUNTING IS NOT DECIDING: the
%     refuse-and-count behaviour below is unchanged, and what rule a plural
%     row should follow stays a team question.
% (b) DATA CELLS. `rows_passthrough` counts ROWS; the 76,766 recorded for this
%     defect counts STATEMENTS, and the two differ by roughly the column
%     count -- so neither number can be read off the other. A cell is an
%     UPPER BOUND on statements and never an estimate:
%     did2.convert.migrators_j.ontology_table_row's migrateRow is documented
%     "One column -> one statement" and then SKIPS identity and empty columns.
%     That skip rule belongs to the migrator and is deliberately NOT
%     re-implemented here -- two copies of one rule drift, and the copy that
%     drifts is the one nobody runs.
report.document_id_edges_seen        = 0;
report.rows_with_document_id_edge    = 0;
report.rows_with_plural_document_id  = 0;
report.data_cells_seen               = 0;
report.data_cells_on_resolved_rows   = 0;
report.data_cells_on_unresolved_rows = 0;

report.resolved                            = 0;
report.resolved_via_document_id_edge       = 0;
report.resolved_via_subject_column         = 0;
report.resolved_via_local_identifier       = 0;

report.unresolved                                = 0;
report.unresolved_no_candidate                   = 0;
report.unresolved_candidate_missing              = 0;
report.unresolved_candidate_not_subject          = 0;
report.unresolved_local_identifier_missing       = 0;
report.unresolved_local_identifier_ambiguous     = 0;
report.unresolved_conflicting_candidates         = 0;
report.unresolved_edge_would_be_dropped          = 0;

report.changed = false;

if isempty(migratedStructs) || isempty(v1Bodies)
    return;
end

% ---- index the migrated set ---------------------------------------------
% byId: every migrated document, so a candidate id can be told apart from an id
% that is not in this batch at all (the discovery-mode case: a subset batch need
% not contain the subject, and that is NOT evidence the subject does not exist).
byId          = containers.Map('KeyType', 'char', 'ValueType', 'any');
passthroughId = containers.Map('KeyType', 'char', 'ValueType', 'logical');
localIdIndex  = containers.Map('KeyType', 'char', 'ValueType', 'any');

for i = 1:numel(migratedStructs)
    s = migratedStructs{i};
    id = baseField(s, 'id', '');
    if ~isempty(id)
        byId(id) = s;
    end
    cls = classNameOf(s);
    if strcmp(cls, 'ontology_table_row') && ~isempty(id)
        passthroughId(id) = true;
        report.rows_passthrough = report.rows_passthrough + 1;
    end
    if ~isSubjectDoc(s)
        continue;
    end
    report.subjects_indexed = report.subjects_indexed + 1;
    lid = subjectLocalIdentifier(s);
    if isempty(lid)
        continue;
    end
    key = localKey(baseField(s, 'session_id', ''), lid);
    if isKey(localIdIndex, key)
        hits = localIdIndex(key);
        hits{end+1} = id; %#ok<AGROW>
        localIdIndex(key) = hits;
    else
        localIdIndex(key) = {id};
    end
end

localKeys = keys(localIdIndex);
for k = 1:numel(localKeys)
    if isscalar(localIdIndex(localKeys{k}))
        report.subject_local_ids_unique = report.subject_local_ids_unique + 1;
    end
end

% ---- walk the v1 rows ----------------------------------------------------
for i = 1:numel(v1Bodies)
    b = v1Bodies{i};
    if ~isOntologyRowBody(b)
        continue;
    end
    report.v1_ontology_rows = report.v1_ontology_rows + 1;
    srcId = baseField(b, 'id', '');
    if isempty(srcId) || ~isKey(passthroughId, srcId)
        % Pass 1 already converted this row (a per-table map matched, and
        % preserveSourceId moved the id onto a statement), or it is not in the
        % migrated set at all. Either way there is nothing here to repair.
        report.rows_converted_in_pass_1 = report.rows_converted_in_pass_1 + 1;
        continue;
    end

    % Arity and scale are counted for EVERY row in scope, before the
    % resolution decides anything. A counter that runs only on one branch
    % cannot report that branch's zero, which is the defect these two exist
    % to remove.
    edgeVals = nonEmptyDependencyValues(b, 'document_id');
    report.document_id_edges_seen = ...
        report.document_id_edges_seen + numel(edgeVals);
    if ~isempty(edgeVals)
        report.rows_with_document_id_edge = ...
            report.rows_with_document_id_edge + 1;
    end
    if numel(edgeVals) > 1
        report.rows_with_plural_document_id = ...
            report.rows_with_plural_document_id + 1;
    end
    nCells = dataCellCount(b);
    report.data_cells_seen = report.data_cells_seen + nCells;

    [subjectId, route, reason] = resolveRowSubject(b, byId, localIdIndex, ...
        options.LocalIdentifierJoin);

    if isempty(subjectId)
        report.unresolved = report.unresolved + 1;
        field = ['unresolved_' reason];
        report.(field) = report.(field) + 1;
        report.data_cells_on_unresolved_rows = ...
            report.data_cells_on_unresolved_rows + nCells;
        continue;
    end

    report.resolved = report.resolved + 1;
    report.data_cells_on_resolved_rows = ...
        report.data_cells_on_resolved_rows + nCells;
    switch route
        case 'document_id_edge'
            report.resolved_via_document_id_edge = ...
                report.resolved_via_document_id_edge + 1;
        case 'subject_column'
            report.resolved_via_subject_column = ...
                report.resolved_via_subject_column + 1;
        case 'local_identifier'
            report.resolved_via_local_identifier = ...
                report.resolved_via_local_identifier + 1;
    end

    entry = struct( ...
        'source_id',  srcId, ...
        'subject_id', subjectId, ...
        'route',      route, ...
        'body',       addSubjectDependency(b, subjectId));
    plan(end+1) = entry; %#ok<AGROW>
end

report.changed = ~isempty(plan);
end

% ===================== resolution =========================================

function [subjectId, route, reason] = resolveRowSubject(b, byId, localIdIndex, allowLocal)
%RESOLVEROWSUBJECT The migrated subject this row is about, or '' with a reason.
%
%   Candidates are gathered from ALL routes before any is accepted, so a
%   disagreement between two routes is visible rather than hidden by a
%   precedence order.
subjectId = '';
route     = '';
reason    = 'no_candidate';

sawCandidate    = false;
sawMissing      = false;
sawNotSubject   = false;
sawLocalMissing = false;
sawLocalAmbig   = false;

hits = {};   % {subjectId, route} pairs, in route order

% --- route 1: the document_id edge (document_id, document_id_1..n) --------
edgeVals = dependencyValuesMatching(b, 'document_id');
for k = 1:numel(edgeVals)
    v = edgeVals{k};
    if isempty(v)
        continue;
    end
    sawCandidate = true;
    if ~isKey(byId, v)
        sawMissing = true;
        continue;
    end
    if ~isSubjectDoc(byId(v))
        sawNotSubject = true;
        continue;
    end
    hits{end+1} = {v, 'document_id_edge'}; %#ok<AGROW>
end

% --- route 2: a SubjectDocumentIdentifier cell in `data` ------------------
docCell = dataCell(b, 'SubjectDocumentIdentifier');
if ~isempty(docCell)
    sawCandidate = true;
    if ~isKey(byId, docCell)
        sawMissing = true;
    elseif ~isSubjectDoc(byId(docCell))
        sawNotSubject = true;
    else
        hits{end+1} = {docCell, 'subject_column'}; %#ok<AGROW>
    end
end

% --- route 3: a SubjectLocalIdentifier cell joined by string --------------
if allowLocal
    localCell = dataCell(b, 'SubjectLocalIdentifier');
    if ~isempty(localCell)
        sawCandidate = true;
        key = localKey(baseField(b, 'session_id', ''), localCell);
        if ~isKey(localIdIndex, key)
            sawLocalMissing = true;
        else
            matches = localIdIndex(key);
            if isscalar(matches)
                hits{end+1} = {matches{1}, 'local_identifier'}; %#ok<AGROW>
            else
                sawLocalAmbig = true;
            end
        end
    end
end

% --- accept, or explain why not ------------------------------------------
if ~isempty(hits)
    ids = cellfun(@(h) h{1}, hits, 'UniformOutput', false);
    if numel(unique(ids)) > 1
        reason = 'conflicting_candidates';
        return;
    end
    candidate = hits{1}{1};
    % CONVERTING A ROW COSTS IT ITS OTHER EDGES. migrators_j's `startStatement`
    % does `body.depends_on = carrySubject(preBody)` -- an ASSIGNMENT, not an
    % extension -- so every emitted statement carries `subject_id` and nothing
    % else. A non-empty `document_id` that is NOT the subject would therefore
    % vanish on conversion. That is the same discard `ontology_label`'s
    % migrator comment calls out ("the only link to the labelled thing"), and
    % this pass exists to remove silent losses, not relocate them. So: refuse,
    % and count it. In every in-tree converter the writer sets at most one
    % `document_id` (tableDocMaker's `isscalar(values)` branch), so this costs
    % nothing today and forbids a regression tomorrow.
    stranded = false;
    for k = 1:numel(edgeVals)
        if ~isempty(edgeVals{k}) && ~strcmp(edgeVals{k}, candidate)
            stranded = true;
        end
    end
    if stranded
        reason = 'edge_would_be_dropped';
        return;
    end
    subjectId = candidate;
    route     = hits{1}{2};
    reason    = '';
    return;
end

if ~sawCandidate
    reason = 'no_candidate';
elseif sawNotSubject
    reason = 'candidate_not_subject';
elseif sawMissing
    reason = 'candidate_missing';
elseif sawLocalAmbig
    reason = 'local_identifier_ambiguous';
elseif sawLocalMissing
    reason = 'local_identifier_missing';
else
    reason = 'no_candidate';
end
end

% ===================== body predicates / accessors ========================

function tf = isOntologyRowBody(b)
% did_v1 spells it `ontologyTableRow`; a body that has already been through
% universalRenames spells it `ontology_table_row`. Accept both -- the
% idempotent re-run path (readBodiesFromVDelta) hands back migrated structs.
c = classNameOf(b);
tf = strcmp(c, 'ontologyTableRow') || strcmp(c, 'ontology_table_row');
end

function tf = isSubjectDoc(s)
% A `subject` document, or anything whose superclass chain includes `subject`.
% Element-derived subjects reach here too: did2.convert.migrators_j.element
% promotes an element to a subject with its id PRESERVED, which is why an
% `element_id` candidate resolves through route 1 without special-casing.
tf = false;
if ~isstruct(s)
    return;
end
if strcmp(classNameOf(s), 'subject')
    tf = true;
    return;
end
if isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'superclasses')
    sc = s.document_class.superclasses;
    for k = 1:numel(sc)
        if isstruct(sc) && isfield(sc(k), 'class_name') ...
                && strcmp(char(sc(k).class_name), 'subject')
            tf = true;
            return;
        end
    end
end
end

function lid = subjectLocalIdentifier(s)
lid = '';
if isfield(s, 'subject') && isstruct(s.subject) ...
        && isfield(s.subject, 'local_identifier')
    lid = charOf(s.subject.local_identifier);
end
end

function v = dataCell(b, wantedKey)
%DATACELL The value of the `data` column whose KEY matches WANTEDKEY.
%
%   The keys of `data` are ontology SHORT NAMES and they stay camelCase:
%   universalRenames snake-cases only the IMMEDIATE field names of a property
%   block (universalRenames.m header, "nested struct values ... are left
%   alone"), and `data` is nested. The comparison is normalised anyway
%   (lowercase, underscores stripped) because a disposition that turns on a
%   spelling is exactly how `demo_ndi` went wrong.
v = '';
blk = rowBlock(b);
if ~isfield(blk, 'data') || ~isstruct(blk.data) || ~isscalar(blk.data)
    return;
end
want = normaliseKey(wantedKey);
fns = fieldnames(blk.data);
for k = 1:numel(fns)
    if ~strcmp(normaliseKey(fns{k}), want)
        continue;
    end
    v = charOf(blk.data.(fns{k}));
    return;
end
end

function blk = rowBlock(b)
blk = struct();
if isstruct(b) && isfield(b, 'ontologyTableRow') && isstruct(b.ontologyTableRow)
    blk = b.ontologyTableRow;
elseif isstruct(b) && isfield(b, 'ontology_table_row') && isstruct(b.ontology_table_row)
    blk = b.ontology_table_row;
end
end

function vals = dependencyValuesMatching(b, baseName)
%DEPENDENCYVALUESMATCHING Every depends_on value whose name is BASENAME or
%   BASENAME_<n>. `add_dependency_value_n` is what tableDocMaker uses when a
%   row names more than one referent, so a single-name lookup would miss all
%   but the scalar case.
vals = {};
if ~isstruct(b) || ~isfield(b, 'depends_on') || ~isstruct(b.depends_on)
    return;
end
deps = b.depends_on;
pattern = ['^' regexptranslate('escape', baseName) '(_\d+)?$'];
for k = 1:numel(deps)
    d = deps(k);
    if ~isfield(d, 'name')
        continue;
    end
    nm = charOf(d.name);
    if isempty(regexp(nm, pattern, 'once'))
        continue;
    end
    vals{end+1} = dependencyValueOf(d); %#ok<AGROW>
end
end

function vals = nonEmptyDependencyValues(b, baseName)
%NONEMPTYDEPENDENCYVALUES DEPENDENCYVALUESMATCHING with the empty values
%   dropped.
%
%   The template ships `document_id` with value "" on EVERY row
%   (ndi_common/database_documents/data/ontologyTableRow.json), so an empty
%   edge is the norm rather than a referent. Counting it would make every row
%   in every corpus look like it names something.
vals = dependencyValuesMatching(b, baseName);
keep = false(1, numel(vals));
for k = 1:numel(vals)
    keep(k) = ~isempty(vals{k});
end
vals = vals(keep);
end

function n = dataCellCount(b)
%DATACELLCOUNT How many `data` columns this row carries.
%
%   An UPPER BOUND on the statements the row would fan out to, never an
%   estimate. migrateRow skips identity columns and empty values, and this
%   function does not model that -- see the report block at the top for why
%   the rule is not copied here.
n = 0;
blk = rowBlock(b);
if ~isfield(blk, 'data') || ~isstruct(blk.data) || ~isscalar(blk.data)
    return;
end
n = numel(fieldnames(blk.data));
end

function v = dependencyValueOf(d)
% v1 writes {name,value} (or {name,id}); universalRenames rewrites both to
% {name,document_id}. Accept whichever is populated.
v = '';
if isfield(d, 'document_id') && ~isempty(d.document_id)
    v = charOf(d.document_id);
elseif isfield(d, 'value') && ~isempty(d.value)
    v = charOf(d.value);
elseif isfield(d, 'id') && ~isempty(d.id)
    v = charOf(d.id);
end
end

function b = addSubjectDependency(b, subjectId)
%ADDSUBJECTDEPENDENCY Add `subject_id` to a v1 body's depends_on, matching the
%   existing struct array's field schema so the append is legal.
%
%   The value key is chosen to match what is already there: a raw v1 body has
%   {name,value} (the template's own shape) and a re-read migrated body has
%   {name,document_id}. did2.convert.universalRenames normalises either to
%   {name,document_id}, and migrators_j.ontology_table_row's `resolvedSubject`
%   reads `value` then `document_id`, so both spellings arrive intact.
entry = struct('name', 'subject_id', 'value', subjectId);
if isfield(b, 'depends_on') && isstruct(b.depends_on)
    fns = fieldnames(b.depends_on);
    if any(strcmp(fns, 'document_id')) && ~any(strcmp(fns, 'value'))
        entry = struct('name', 'subject_id', 'document_id', subjectId);
    elseif any(strcmp(fns, 'id')) && ~any(strcmp(fns, 'value')) ...
            && ~any(strcmp(fns, 'document_id'))
        entry = struct('name', 'subject_id', 'id', subjectId);
    end
    % Drop any pre-existing (empty) subject_id so the append cannot duplicate
    % the name. A NON-empty one cannot occur here: the row would not have been
    % a passthrough.
    keep = true(1, numel(b.depends_on));
    for k = 1:numel(b.depends_on)
        if isfield(b.depends_on(k), 'name') ...
                && strcmp(charOf(b.depends_on(k).name), 'subject_id')
            keep(k) = false;
        end
    end
    deps = b.depends_on(keep);
    if isempty(deps)
        b.depends_on = entry;
    else
        % Reconcile field schemas before concatenating.
        entry = matchFields(entry, deps(1));
        deps(end+1) = entry;
        b.depends_on = deps;
    end
else
    b.depends_on = entry;
end
end

function entry = matchFields(entry, template)
% Give ENTRY exactly TEMPLATE's fields, in TEMPLATE's order, so a struct-array
% append does not error on a field mismatch. Fields TEMPLATE has and ENTRY does
% not are filled with ''; the value ENTRY carries is preserved under whichever
% of document_id/value/id TEMPLATE uses.
val = dependencyValueOf(entry);
tf = fieldnames(template);
out = struct();
for k = 1:numel(tf)
    switch tf{k}
        case 'name'
            out.name = entry.name;
        case {'document_id', 'value', 'id'}
            out.(tf{k}) = val;
        otherwise
            out.(tf{k}) = '';
    end
end
entry = out;
end

% ===================== small helpers ======================================

function p = emptyPlan()
p = struct('source_id', {}, 'subject_id', {}, 'route', {}, 'body', {});
end

function k = localKey(sessionId, localId)
k = [charOf(sessionId) '|' charOf(localId)];
end

function out = normaliseKey(name)
out = lower(strrep(charOf(name), '_', ''));
end

function c = classNameOf(s)
c = '';
if isstruct(s) && isfield(s, 'document_class') && isstruct(s.document_class) ...
        && isfield(s.document_class, 'class_name')
    c = charOf(s.document_class.class_name);
end
end

function v = baseField(s, name, default)
v = default;
if isstruct(s) && isfield(s, 'base') && isstruct(s.base) ...
        && isfield(s.base, name) && ~isempty(s.base.(name))
    v = charOf(s.base.(name));
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
elseif isnumeric(v) && isscalar(v) && isfinite(v)
    s = num2str(v);
end
end

function out = decodeBodies(raw)
out = {};
for k = 1:numel(raw)
    b = raw{k};
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
