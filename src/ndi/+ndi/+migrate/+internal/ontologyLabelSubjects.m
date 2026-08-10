function [plan, report] = ontologyLabelSubjects(migratedStructs)
%ONTOLOGYLABELSUBJECTS V_eta second pass: give each passed-through
%   `ontology_label` the SUBJECT it is about, by following its one edge through
%   the migrated-id graph.
%
%   [PLAN, REPORT] = ndi.migrate.internal.ontologyLabelSubjects(MIGRATEDSTRUCTS)
%   inspects every `ontology_label` document that pass 1 left unconverted and,
%   for each one whose referent resolves to a statement that HAS a subject,
%   returns a ready V_eta `term_observation` body to replace it with. REPORT
%   states its denominators first and splits the unresolved into named reasons.
%
%   This function is PURE: it reads structs and returns structs. It calls no
%   converter, touches no database and needs no schema -- which is what makes it
%   testable without a corpus. ndi.migrate.local/resolveOntologyLabelSubjects
%   does the fold.
%
%   STATUS: authored WITHOUT local MATLAB. Neither this function nor its unit
%   tests (tests/+ndi/+unittest/+migrate/TestOntologyLabelSubjects.m) have been
%   run. Nothing here has been exercised against a corpus.
%
%   ---------------------------------------------------------------------
%   WHY THIS IS A SECOND PASS
%   ---------------------------------------------------------------------
%   The real NDI class declares ONE property field and ONE dependency, and the
%   dependency is not a subject:
%
%     git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyLabel.json
%        "ontologyLabel": { "ontologyNode": "" }
%        "depends_on": [ { "name": "document_id", "value": "" } ]
%
%   `document_id` points at the document being LABELLED -- typically an image
%   stack. Renaming it to `subject_id` would assert that an image stack is a
%   subject. The subject is one hop further on, and the hop is only visible with
%   the whole migrated set in hand:
%
%     ontology_label --document_id--> imageStack --migrates-->
%         image_observation --subject_id--> subject
%
%   That is the chain +did2/+convert/+migrators_j/ontology_label.m names in its
%   own header, and it is why that migrator passes the document through instead
%   of converting it (~7,007 documents in the JH corpus). The half that used to
%   be worse -- an emitted, EMPTY `subject_id` while `document_id` was discarded
%   -- is already stopped by the passthrough. What is left is that the documents
%   are UNATTRIBUTED.
%
%   ---------------------------------------------------------------------
%   THE CHAIN DEAD-ENDS FOR A LARGE SHARE, AND THAT IS THE SOURCE'S DOING
%   ---------------------------------------------------------------------
%   From the writer -- +ndi/+setup/+conv/+haley/doImport.m on origin/main, whose
%   two sessions treat the imageStack differently:
%
%     BEHAVIOUR sessions   :421 :461 :477 :496  build the imageStack, and
%                          :430 :464 :480 :499  set `document_id` (the plate row)
%                          :432 :466 :482 :501  set `subject_id` = subjectGroup_id
%                          -> RESOLVABLE. The group id resolves because
%                             +migrators_j/subject_group.m preserves it onto a
%                             bare `subject`.
%
%     E. COLI session      :789 :811 :827  build the imageStack, and
%                          :794 :814 :830  set `document_id` ONLY.
%                          -> BLOCKED. There is no subject_id to inherit,
%                             because the images are of bacterial patches on
%                             plates and that session has no subject.
%
%   Those are the same imageStacks behind the JH `image_observation.subject_id`
%   row in the empty-required-edge census, and they are the reason
%   +migrators_j/image_stack.m now passes a subject-less stack through instead of
%   emitting an observation about nobody.
%
%   THIS PASS DOES NOT DECIDE THE E. COLI HALF. Whether a bacterial patch ever
%   gets a subject -- a plate? a lawn? nothing? -- is a modelling call, and
%   modelling calls are the team's (operating rule 4). This pass COUNTS them,
%   under `blocked_target_has_no_subject`, broken down by the class the referent
%   migrated into, and leaves every one of those documents passing through
%   exactly as it does today. Nothing is lost by waiting; something would be
%   invented by guessing.
%
%   ---------------------------------------------------------------------
%   WHAT IS EMITTED, AND WHAT IS DELIBERATELY NOT
%   ---------------------------------------------------------------------
%   A `term_observation` (⊂ subject_observation, term), per Decision D5
%   (V_eta_migration_plan.md D.2: "locus / label terms -> term_observation;
%   element = subject, labeling relation = variable, term = value"), matching the
%   two shipped siblings +migrators_j/probe_location.m ('anatomical location')
%   and +migrators_j/ontology_image.m ('imaged region'):
%
%     base.id          PRESERVED from the ontology_label. The calculator lesson:
%                      dissolving a referenced document without keeping its id
%                      cost 11,448 orphans, and existence-only `must_refer` means
%                      a preserved id keeps every inbound edge resolving whether
%                      or not one exists today.
%     subject_id       the subject the referent statement is about
%     derived_from_1   the referent statement itself -- so BOTH facts survive:
%                      the term, and what it was about. This is the edge whose
%                      absence made the old behaviour a loss rather than a rename.
%     time_reference_1 REUSED from the referent statement, not minted. The label
%                      is about that observation and shares its time; minting a
%                      second anchor for the same instant would be #52's
%                      undefined-meaning case, and `time_reference_#` carries
%                      min_count 1 so it cannot simply be omitted.
%     term.value       the ontology node, verbatim
%     variable         {node: '', name: 'label'}  <- OPEN QUESTION, see below
%
%   NOT EMITTED, and each refusal is counted rather than papered over:
%     * no `document_id` edge                -> unresolved_no_document_edge
%     * referent not in the migrated set     -> unresolved_target_not_in_batch
%     * referent has no subject              -> blocked_target_has_no_subject
%     * referent has no time_reference       -> unresolved_target_no_time_reference
%     * no `ontology_node` on the label      -> unresolved_no_ontology_node
%       (`term.value` is REQUIRED and, with strictMode('NonVacuousFields') armed,
%       an all-blank term QUARANTINES. A label with no node says nothing; the
%       passthrough at least preserves the document.)
%
%   OPEN QUESTION, FOR THE TEAM, NOT DECIDED HERE. `subject_statement.variable`
%   is REQUIRED and non-blank, and D5 fixes its ROLE ("the labeling relation")
%   without fixing its TERM for this class. Its two shipped siblings use bare
%   noun phrases with a staged empty node ('anatomical location', 'imaged
%   region'); D5's own prose offers `annotated_as`. This pass emits 'label',
%   which is the class's own word and the most neutral of the three, with an
%   empty node like all 34 other staged terms. It is ONE CONSTANT
%   (LABEL_VARIABLE below); changing it is a one-line change and a re-run.
%
%   REPORT fields (denominator first, unconditionally):
%     ran                        false only if it returned before reading
%     documents_inspected        migrated documents handed in
%     documents_unreadable       could not be read -- COUNTED, never dropped
%     labels_passthrough         `ontology_label` documents still unconverted
%     statements_indexed         migrated documents carrying a subject_id
%     resolved                   labels with a plan entry
%     blocked_target_has_no_subject          THE E. COLI HALF
%     blocked_by_target_class    struct: referent class -> blocked count
%     unresolved_no_document_edge
%     unresolved_target_not_in_batch
%     unresolved_target_no_time_reference
%     unresolved_no_ontology_node
%     changed                    true iff PLAN is non-empty
%
%   See also: ndi.migrate.internal.ontologyRowSubjects,
%   ndi.migrate.internal.pathSPromotion.

arguments
    migratedStructs
end

% The one naming choice in this file, isolated so it is a one-line change.
LABEL_VARIABLE = 'label';

plan = struct('source_id', {}, 'subject_id', {}, 'statement_id', {}, ...
    'time_reference_id', {}, 'ontology_node', {}, 'body', {});

report = struct( ...
    'ran',                                 false, ...
    'documents_inspected',                 0, ...
    'documents_unreadable',                0, ...
    'labels_passthrough',                  0, ...
    'statements_indexed',                  0, ...
    'resolved',                            0, ...
    'blocked_target_has_no_subject',       0, ...
    'blocked_by_target_class',             struct(), ...
    'unresolved_no_document_edge',         0, ...
    'unresolved_target_not_in_batch',      0, ...
    'unresolved_target_no_time_reference', 0, ...
    'unresolved_no_ontology_node',         0, ...
    'changed',                             false);

if isempty(migratedStructs)
    report.ran = true;
    return;
end
if ~iscell(migratedStructs)
    migratedStructs = num2cell(migratedStructs(:)');
end
report.documents_inspected = numel(migratedStructs);
report.ran = true;

% ---- index the migrated set by base.id -----------------------------------
% One entry per document: its class, its subject edge (if any) and its first
% time anchor (if any). A document with no subject is INDEXED ANYWAY -- that is
% how "the referent exists but has no subject" stays distinguishable from "the
% referent is not here at all", which are two completely different findings and
% were one bucket in the reading that graded this class benign.
byId = containers.Map('KeyType', 'char', 'ValueType', 'any');
labelIdx = [];
for k = 1:numel(migratedStructs)
    b = migratedStructs{k};
    if ~isstruct(b) || ~isscalar(b) || isempty(fieldnames(b))
        report.documents_unreadable = report.documents_unreadable + 1;
        continue;
    end
    docId = baseField(b, 'id');
    cn    = classNameOf(b);
    subjectId = edgeValue(b, {'subject_id'});
    if ~isempty(docId)
        byId(docId) = struct('class_name', cn, ...
            'subject_id', subjectId, ...
            'time_reference_id', firstTimeReference(b));
    end
    if ~isempty(subjectId)
        report.statements_indexed = report.statements_indexed + 1;
    end
    if strcmp(cn, 'ontology_label')
        labelIdx(end+1) = k; %#ok<AGROW>
    end
end
report.labels_passthrough = numel(labelIdx);

% ---- resolve one label at a time -----------------------------------------
for i = 1:numel(labelIdx)
    b = migratedStructs{labelIdx(i)};

    targetId = edgeValue(b, {'document_id'});
    if isempty(targetId)
        report.unresolved_no_document_edge = ...
            report.unresolved_no_document_edge + 1;
        continue;
    end
    if ~isKey(byId, targetId)
        report.unresolved_target_not_in_batch = ...
            report.unresolved_target_not_in_batch + 1;
        continue;
    end
    target = byId(targetId);

    if isempty(target.subject_id)
        report.blocked_target_has_no_subject = ...
            report.blocked_target_has_no_subject + 1;
        fn = matlab.lang.makeValidName(emptyToUnknown(target.class_name));
        if isfield(report.blocked_by_target_class, fn)
            report.blocked_by_target_class.(fn) = ...
                report.blocked_by_target_class.(fn) + 1;
        else
            report.blocked_by_target_class.(fn) = 1;
        end
        continue;
    end
    if isempty(target.time_reference_id)
        % `time_reference_#` carries min_count 1 on subject_interaction, so
        % there is no honest way to emit the observation without one, and
        % minting a session anchor here would put a SECOND, differently-anchored
        % reference beside the referent's own.
        report.unresolved_target_no_time_reference = ...
            report.unresolved_target_no_time_reference + 1;
        continue;
    end

    node = labelNode(b);
    if isempty(node)
        report.unresolved_no_ontology_node = ...
            report.unresolved_no_ontology_node + 1;
        continue;
    end

    body = termObservationBody(b, target, targetId, node, LABEL_VARIABLE);
    plan(end+1) = struct( ...                                        %#ok<AGROW>
        'source_id',         baseField(b, 'id'), ...
        'subject_id',        target.subject_id, ...
        'statement_id',      targetId, ...
        'time_reference_id', target.time_reference_id, ...
        'ontology_node',     node, ...
        'body',              body);
    report.resolved = report.resolved + 1;
end

report.changed = ~isempty(plan);
end

% ===================== the body ========================================

function body = termObservationBody(labelBody, target, targetId, node, variableName)
%TERMOBSERVATIONBODY One V_eta `term_observation`, tagged so v1_to_v2
%   short-circuits it (isAlreadyTarget) to ensureClassBlocks + validate rather
%   than trying to migrate it -- the footing pathSPromotion and
%   ensembleMembership already use for minted bodies.
body = struct();
body.document_class = struct('class_name', 'term_observation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_observation', 'class_version', '1.0.0'), ...
        struct('class_name', 'term',                'class_version', '1.0.0')], ...
    'schema_version', 'V_eta');
body.depends_on = [ ...
    struct('name', 'subject_id',       'value', target.subject_id), ...
    struct('name', 'time_reference_1', 'value', target.time_reference_id), ...
    struct('name', 'derived_from_1',   'value', targetId)];
% base PRESERVED, id included. `base.name` is kept as the source wrote it so a
% by-name query still answers; only an absent name gets a generic stand-in.
body.base = struct( ...
    'id',         baseField(labelBody, 'id'), ...
    'session_id', baseField(labelBody, 'session_id'), ...
    'name',       defaultTo(baseField(labelBody, 'name'), 'migrated_label'), ...
    'datestamp',  defaultTo(baseField(labelBody, 'datestamp'), ...
                            '2024-01-01T00:00:00.000Z'));
body.subject_statement = struct( ...
    'variable', struct('node', '', 'name', variableName), ...
    'storage_mode', 'inline');
body.subject_interaction = struct( ...
    'method', struct('node', '', 'name', ''), ...
    'sample_time', struct('kind', 'point'));
body.subject_observation = struct();
% The term itself, VERBATIM. `name` is left empty rather than guessed: the v1
% document stores only the node, and ndi.ontology.lookup is what turns a node
% into a label -- doing that here would be this pass inventing a string the
% source never carried.
body.term = struct('value', struct('node', node, 'name', ''));
end

% ===================== readers =========================================

function v = labelNode(b)
%LABELNODE `ontologyLabel.ontologyNode`, snake-cased by universalRenames.
%   Read snake-first with the camelCase fallback, per the standing migrator
%   lesson. The three DID-side inventions (`ontology_name`, `label_id`, `label`)
%   are NOT read: +migrators_j/ontology_label.m ERRORS on a body carrying them,
%   because their presence means a fixture was built against the V_alpha
%   snapshot rather than the real document.
v = '';
for blk = {'ontology_label', 'ontologyLabel'}
    if ~isfield(b, blk{1}) || ~isstruct(b.(blk{1})) || ~isscalar(b.(blk{1}))
        continue;
    end
    v = charField(b.(blk{1}), {'ontology_node', 'ontologyNode'});
    if ~isempty(v); return; end
end
end

function id = firstTimeReference(b)
%FIRSTTIMEREFERENCE The referent statement's own anchor, '' when it has none.
%   `time_reference_#` is a numbered family; take the lowest-numbered member
%   present. Until #52 role-names them, a bare index carries no meaning beyond
%   order, so "the first" is the only defensible choice and it is the one the
%   referent itself is anchored by.
id = edgeValue(b, {'time_reference_1'});
if ~isempty(id); return; end
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = normaliseDeps(b.depends_on);
best = inf;
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    nm = char(d.name);
    if ~startsWith(nm, 'time_reference_'); continue; end
    n = str2double(nm(numel('time_reference_')+1:end));
    if isnan(n) || n >= best; continue; end
    v = depKeyValue(d);
    if isempty(v); continue; end
    best = n;
    id = v;
end
end

function v = edgeValue(b, names)
%EDGEVALUE First non-empty depends_on value among NAMES.
%   Tolerant of the three key spellings the pipeline uses at different stages
%   (`value`, `document_id`, raw v1 `id`), and iterates element-wise: a
%   jsondecode'd depends_on is a CELL whenever its entries do not all carry the
%   same keys, and `[deps{:}]` throws on that.
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = normaliseDeps(b.depends_on);
for k = 1:numel(deps)
    d = deps{k};
    if ~isstruct(d) || ~isfield(d, 'name'); continue; end
    if ~any(strcmp(char(d.name), names)); continue; end
    v = depKeyValue(d);
    if ~isempty(v); return; end
end
end

function items = normaliseDeps(deps)
if iscell(deps)
    items = deps(:)';
elseif isstruct(deps)
    items = num2cell(deps(:)');
else
    items = {};
end
end

function v = depKeyValue(d)
v = '';
for key = {'value', 'document_id', 'id'}
    if ~isfield(d, key{1}); continue; end
    x = d.(key{1});
    if (ischar(x) || (isstring(x) && isscalar(x))) && ~isempty(char(x))
        v = char(x);
        return;
    end
end
end

function cn = classNameOf(b)
cn = '';
if isfield(b, 'document_class') && isstruct(b.document_class) ...
        && isscalar(b.document_class) ...
        && isfield(b.document_class, 'class_name')
    cn = char(b.document_class.class_name);
end
end

function v = baseField(b, name)
v = '';
if ~isfield(b, 'base') || ~isstruct(b.base) || ~isscalar(b.base) ...
        || ~isfield(b.base, name)
    return;
end
x = b.base.(name);
if ischar(x) || (isstring(x) && isscalar(x)); v = char(x); end
end

function v = charField(s, names)
v = '';
for k = 1:numel(names)
    if ~isfield(s, names{k}); continue; end
    x = s.(names{k});
    if (ischar(x) || (isstring(x) && isscalar(x))) && ~isempty(char(x))
        v = char(x);
        return;
    end
end
end

function v = defaultTo(v, fallback)
if isempty(v); v = fallback; end
end

function s = emptyToUnknown(s)
if isempty(s); s = 'unknown_class'; end
end
