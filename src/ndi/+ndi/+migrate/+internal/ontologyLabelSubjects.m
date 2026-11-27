function [plan, report] = ontologyLabelSubjects(migratedStructs)
%ONTOLOGYLABELSUBJECTS V_eta second pass: follow each passed-through
%   `ontologyLabel`'s one edge through the migrated-id graph and give every
%   label the carry register row it is carried under.
%
%   [PLAN, REPORT] = ndi.migrate.internal.ontologyLabelSubjects(MIGRATEDSTRUCTS)
%   inspects every `ontologyLabel` document that pass 1 left unconverted.
%   Since Jess Haley's decision of 2026-11-26 (audit batch 2 (a), applying
%   [labels are a field on what they label] and [one-reading quick answers]
%   Q3, did-schema did_v2_go_forward_class_audit.md) NO label is converted
%   here: a label is a field of the document it labels, which slot the v1
%   document does not say, so every label is carried whole as v1 and REPORT
%   names its row (REPORT.carry_rows). PLAN is always empty; it is kept so
%   ndi.migrate.local/resolveOntologyLabelSubjects keeps its shape. REPORT
%   states its denominators first and splits the labels into named reasons.
%
%   A label document is found under its v1 class name, `ontologyLabel`, and
%   read in NDI's own spelling (block `ontologyLabel`, field `ontologyNode`,
%   edge `document_id` by its v1 `value`): pass 1 hands it on unrenamed, since
%   DID-matlab #351 deleted did2.convert.universalRenames ([migrators read raw
%   v1]; [ndi_document read as base], [rename clashes are malformed], Jess
%   Haley, 2026-10-31 / 2026-11-01). The renamed spelling (`ontology_label`,
%   `ontology_node`) is not read: a label block field by that name is a field
%   outside the template (carry-100). The class test is
%   ndi.migrate.internal.isOntologyLabelClass, the one place that decides.
%
%   This function is PURE: it reads structs and returns structs. It calls no
%   converter, touches no database and needs no schema -- which is what makes it
%   testable without a corpus.
%
%   Tests: tests/+ndi/+unittest/+migrate/TestOntologyLabelSubjects.m.
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
%   DECIDED SINCE: [labels are a field on what they label] (Jess Haley,
%   2026-10-27, did-schema V_eta_go_forward_class_audit.md; "an ontologyLabel
%   is almost certainly meant to be a field on the document it references.
%   The method, variable, condition, method parameter, etc."): a label on a
%   document with no subject or no time reference is carried whole as v1,
%   `needs_mapping` (carry-096), and each dataset's map names which slot of
%   the labelled document (its method, a variable, a condition, a method
%   parameter) the label fills. That is what this pass does at both carry-096
%   sites below; no dataset's map is written yet, so nothing here fills a
%   slot.
%
%   EVERY LABEL IS CARRIED (Jess Haley, 2026-11-26, audit batch 2 (a)): a
%   label whose referent HAS a subject and a time reference was written as a
%   term observation of that subject (variable 'label', D5) until then. That
%   is "every label as an observation", the reading [one-reading quick
%   answers] Q3 carries as `needs_mapping`; it is carried under carry-096,
%   the row of [labels are a field on what they label], and counted
%   `carried_target_has_subject_and_time`. The rows, in the order checked:
%     * no `document_id` edge                -> unresolved_no_document_edge (carry-097)
%     * referent not in the migrated set     -> unresolved_target_not_in_batch (carry-097)
%     * referent has no subject              -> blocked_target_has_no_subject (carry-096)
%     * referent has no time_reference       -> unresolved_target_no_time_reference (carry-096)
%     * no `ontologyNode` on the label       -> unresolved_no_ontology_node (carry-097)
%     * a field or edge outside the template -> unresolved_unplaced_fields (carry-100)
%     * otherwise (a subject and a time)     -> carried_target_has_subject_and_time (carry-096)
%   A carry-096 row names the label's target as its `dependency`, so a label
%   whose target is itself carried as v1 is counted under carry-064 by the
%   final stamp ([dependents of a carried document carry]).
%
%   REPORT fields (denominator first, unconditionally):
%     ran                        false only if it returned before reading
%     documents_inspected        migrated documents handed in
%     documents_unreadable       could not be read -- COUNTED, never dropped
%     labels_passthrough         `ontologyLabel` documents still unconverted
%     statements_indexed         migrated documents carrying a subject_id
%     resolved                   labels with a plan entry (0 since 2026-11-26)
%     blocked_target_has_no_subject          THE E. COLI HALF
%     blocked_by_target_class    struct: referent class -> blocked count
%     unresolved_no_document_edge
%     unresolved_target_not_in_batch
%     unresolved_target_no_time_reference
%     unresolved_no_ontology_node
%     unresolved_unplaced_fields
%     carried_target_has_subject_and_time
%     carry_rows                 struct {id, row, dependency}, one per label
%     changed                    true iff PLAN is non-empty (false since 2026-11-26)
%
%   See also: ndi.migrate.internal.ontologyRowsCarried,
%   ndi.migrate.internal.pathSPromotion.

arguments
    migratedStructs
end

plan = struct('source_id', {}, 'subject_id', {}, 'statement_id', {}, ...
    'time_reference_id', {}, 'ontology_node', {}, 'body', {}, 'related', {});

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
    'unresolved_unplaced_fields',          0, ...
    'carried_target_has_subject_and_time', 0, ...
    'carry_rows',                          struct('id', {}, 'row', {}, 'dependency', {}), ...
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
    subjectId = edgeValue(b, {'entity_id', 'subject_id'});
    if strcmp(cn, 'entity') || strcmp(cn, 'method')
        subjectId = '';   % an entity, or a method scoped to one, is not a statement
    end
    if ~isempty(docId)
        byId(docId) = struct('class_name', cn, ...
            'subject_id', subjectId, ...
            'time_reference_id', firstTimeReference(b));
    end
    if ~isempty(subjectId)
        report.statements_indexed = report.statements_indexed + 1;
    end
    if ndi.migrate.internal.isOntologyLabelClass(cn)   % the v1 class name
        labelIdx(end+1) = k; %#ok<AGROW>
    end
end
report.labels_passthrough = numel(labelIdx);

% ---- resolve one label at a time -----------------------------------------
for i = 1:numel(labelIdx)
    b = migratedStructs{labelIdx(i)};

    % Each label left unresolved is carried as v1 at the end of
    % ndi.migrate.local; its carry register row ([carry register], Jess
    % Haley, 2026-10-26) is recorded in REPORT.carry_rows. A label blocked
    % by its target also names the target as `dependency`: when the target
    % is itself carried as v1, the final stamp counts the label under
    % carry-064 instead ([dependents of a carried document carry], Jess
    % Haley, 2026-10-26), since a v1 target has no subject to observe.
    labelId = baseField(b, 'id');
    targetId = edgeValue(b, {'document_id'});
    if isempty(targetId)
        % carry-register: carry-097
        report.unresolved_no_document_edge = ...
            report.unresolved_no_document_edge + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-097', 'dependency', '');
        continue;
    end
    if ~isKey(byId, targetId)
        % carry-register: carry-097
        report.unresolved_target_not_in_batch = ...
            report.unresolved_target_not_in_batch + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-097', 'dependency', '');
        continue;
    end
    target = byId(targetId);

    if isempty(target.subject_id)
        % [labels are a field on what they label] (Jess Haley, 2026-10-27):
        % carried whole as v1, needs_mapping, until the dataset's map names
        % the slot of the labelled document the label fills.
        % carry-register: carry-096
        report.blocked_target_has_no_subject = ...
            report.blocked_target_has_no_subject + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-096', 'dependency', char(targetId));
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
        % reference beside the referent's own. [labels are a field on what
        % they label] (Jess Haley, 2026-10-27): carried whole as v1,
        % needs_mapping, as a label on a subject-less document is.
        % carry-register: carry-096
        report.unresolved_target_no_time_reference = ...
            report.unresolved_target_no_time_reference + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-096', 'dependency', char(targetId));
        continue;
    end

    node = labelNode(b);
    if isempty(node)
        % carry-register: carry-097
        report.unresolved_no_ontology_node = ...
            report.unresolved_no_ontology_node + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-097', 'dependency', '');
        continue;
    end
    % [generic stage is lossless] and [partly placed is carried as v1] (Jess
    % Haley, 2026-10-25, did-schema V_eta_go_forward_class_audit.md): a label
    % stating a field or edge beyond `ontologyNode` and `document_id` is
    % malformed, and that row is checked before the needs_mapping carry
    % below, as it was when the label was still written as an observation
    % (which wrote those two and nothing else; until 2026-11-26).
    %
    % ITS ROW IS carry-100, NOT THE ontologyLabel TEMPLATE-FIELD ROW.
    % [ontologyLabel row split] (Jess Haley, 2026-10-27, did-schema
    % V_eta_go_forward_class_audit.md): a field outside NDI's `ontologyLabel`
    % template, or an edge other than `document_id`, is carried under
    % carry-100 (malformed); the ontologyLabel template-field row kept only
    % template fields with no home. That row was retired by Jess Haley's
    % decision of 2026-11-06 retiring the image-label and ontologyLabel carry
    % rows (did-schema did_v2_go_forward_class_audit.md; its tag names the two
    % row ids). The template at the locked NDI-matlab
    % main (ontologyLabel.json + base.json) has ONE label field, `ontologyNode`,
    % and ONE edge, `document_id`. So everything labelHasUnplaced finds -- another
    % label field, or another edge (the `session_id` edge the migration adds
    % is not one) -- is outside the template, and no template field of a
    % label is left without a home here: that retired row never had a site
    % in this pass, as it had none in DID-matlab's +migrators_j/ontology_label.m.
    if labelHasUnplaced(b)
        % carry-register: carry-100
        report.unresolved_unplaced_fields = ...
            report.unresolved_unplaced_fields + 1;
        report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-100', 'dependency', '');
        continue;
    end

    % A LABEL ON A STATEMENT WITH A SUBJECT AND A TIME IS CARRIED TOO.
    % Jess Haley, 2026-11-26 (audit batch 2 (a), "Ok to all three"), applying
    % [labels are a field on what they label] (2026-10-27) and [one-reading
    % quick answers] Q3 (2026-10-26; did-schema
    % did_v2_go_forward_class_audit.md): writing every label as a term
    % observation of the labelled statement's subject, variable 'label', is
    % a reading chosen for the dataset, not the one correct reading. The
    % label is a field of the document it labels (its method, a variable, a
    % condition, a method parameter), and the v1 document does not say which,
    % so it is carried whole as v1, `needs_mapping`, under the decision's own
    % row, as the two sites above are; each dataset's map names the slot. The
    % target is named as the dependency, so a label whose target is itself
    % carried is counted under carry-064 by the final stamp, as today.
    % carry-register: carry-096
    report.carried_target_has_subject_and_time = ...
        report.carried_target_has_subject_and_time + 1;
    report.carry_rows(end+1) = struct('id', labelId, 'row', 'carry-096', 'dependency', char(targetId));
end

report.changed = ~isempty(plan);
end

% ===================== readers =========================================

function tf = labelHasUnplaced(b)
%LABELHASUNPLACED A non-empty `ontologyLabel` field other than ontologyNode, or
%   a non-empty edge other than document_id ([generic stage is lossless];
%   outside NDI's template: carry-100). The renamed spelling `ontology_node`
%   is such a field: nothing renames a label any more.
tf = false;
if isfield(b, 'ontologyLabel') && isstruct(b.ontologyLabel) && isscalar(b.ontologyLabel)
    fn = setdiff(fieldnames(b.ontologyLabel), {'ontologyNode'});
    for k = 1:numel(fn)
        if ~isempty(b.ontologyLabel.(fn{k}))
            tf = true;
            return;
        end
    end
end
if isfield(b, 'depends_on') && ~isempty(b.depends_on)
    deps = normaliseDeps(b.depends_on);
    for k = 1:numel(deps)
        d = deps{k};
        if ~isstruct(d) || ~isfield(d, 'name'); continue; end
        if any(strcmp(char(d.name), {'document_id', 'session_id'})); continue; end
        if ~isempty(depKeyValue(d))
            tf = true;
            return;
        end
    end
end
end


function v = labelNode(b)
%LABELNODE `ontologyLabel.ontologyNode`, NDI's own spelling (pass 1 renames
%   nothing since DID-matlab #351). The three DID-side inventions
%   (`ontology_name`, `label_id`, `label`) are NOT read:
%   +migrators_j/ontology_label.m ERRORS on a body carrying them, because their
%   presence means a fixture was built against the V_alpha snapshot rather than
%   the real document.
v = '';
if isfield(b, 'ontologyLabel') && isstruct(b.ontologyLabel) && isscalar(b.ontologyLabel)
    v = charField(b.ontologyLabel, {'ontologyNode'});
end
end

function id = firstTimeReference(b)
%FIRSTTIMEREFERENCE The statement's first time reference (`time_reference_id`
%   on #88, the lowest `time_reference_N` before).
ids = ndi.migrate.internal.etaShape.timeReferenceIds(b);
id = '';
if isempty(ids); return; end
nums = inf(1, numel(ids));
deps = normaliseDeps(b.depends_on);
k2 = 0;
for k = 1:numel(deps)
    nm = char(deps{k}.name);
    if strcmp(nm, 'time_reference_id') || startsWith(nm, 'time_reference_')
        if isempty(depKeyValue(deps{k})); continue; end
        k2 = k2 + 1;
        n = str2double(nm(numel('time_reference_')+1:end));
        if ~isnan(n); nums(k2) = n; else; nums(k2) = k2; end
    end
end
[~, i] = min(nums);
id = ids{i};
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

function s = emptyToUnknown(s)
if isempty(s); s = 'unknown_class'; end
end
