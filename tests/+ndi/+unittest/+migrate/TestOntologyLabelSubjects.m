classdef TestOntologyLabelSubjects < matlab.unittest.TestCase
%TESTONTOLOGYLABELSUBJECTS Unit tests for the V_eta ontology_label subject
%   resolver. Pure struct logic: no database, no schema, no converter.
%
%   ndi.migrate.internal.ontologyLabelSubjects follows a passed-through
%   `ontology_label`'s ONE edge through the migrated-id graph -- the hop a
%   single-document migrator cannot see -- and returns a ready `term_observation`
%   body per resolvable label, plus an instrument REPORT.
%
%   ---------------------------------------------------------------------
%   THE SPLIT THESE TESTS EXIST TO PIN
%   ---------------------------------------------------------------------
%   The chain +did2/+convert/+migrators_j/ontology_label.m names is
%
%     ontology_label --document_id--> imageStack --migrates-->
%         image_observation --subject_id--> subject
%
%   and it DEAD-ENDS for a large share of the ~7,007 JH documents, because the
%   writer builds the imageStack two different ways:
%
%     git show origin/main:src/ndi/+ndi/+setup/+conv/+haley/doImport.m
%       BEHAVIOUR  :430 :464 :480 :499   set_dependency_value('document_id', plate_id)
%                  :432 :466 :482 :501   set_dependency_value('subject_id', subjectGroup_id)
%       E. COLI    :794 :814 :830        set_dependency_value('document_id', image_id)
%                                        -- and NO subject_id line at all
%
%   So the behaviour half is resolvable and the E. coli half is not, and the
%   difference is a property of the SOURCE, not of the migration. A resolver that
%   reported one number for both would be hiding the only interesting fact about
%   this class. testTheECaliHalfIsBlockedAndCountedSeparately is that assertion.
%
%   Every refusal leaves the label passing through and is COUNTED. That matters
%   more here than usual: `+did2/+validate/references.m:90` skips empty edges, so
%   a guessed `subject_id` would validate clean at every gate and mean nothing --
%   which is exactly what this class did before the passthrough landed.
%
%   STATUS: authored WITHOUT local MATLAB. These tests have NOT been run.
%
%   Run with:  runtests('ndi.unittest.migrate.TestOntologyLabelSubjects')

    methods (Test)

        function testDenominatorIsStatedEvenWithNothingToDo(tc)
            % Rule 5. And "did not run" (the caller's []) must stay
            % distinguishable from "ran and found nothing".
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects({});
            tc.verifyEmpty(plan);
            tc.verifyTrue(rep.ran);
            tc.verifyEqual(rep.documents_inspected, 0);
            tc.verifyEqual(rep.labels_passthrough, 0);
            tc.verifyFalse(rep.changed);
        end

        function testTheBehaviourHalfResolvesThroughTheImageObservation(tc)
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131') };
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(rep.labels_passthrough, 1);
            tc.verifyEqual(rep.resolved, 1);
            tc.verifyEqual(rep.blocked_target_has_no_subject, 0);
            tc.verifyEqual(numel(plan), 1);
            tc.verifyEqual(plan(1).subject_id, 'subj_group_9');
            tc.verifyEqual(plan(1).statement_id, 'img_1');
            tc.verifyTrue(rep.changed);
        end

        function testTheEmittedBodyIsATermObservationThatKeepsBothFacts(tc)
            % BOTH facts: the term, and what it was about. The old behaviour kept
            % the first and discarded the second, which is why it was graded
            % benign for so long -- the surviving half looked right.
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131') };
            plan = ndi.migrate.internal.ontologyLabelSubjects(batch);
            b = plan(1).body;

            % did-schema #88: the `observation` direction + the `term` kind
            tc.verifyEqual(b.document_class.class_name, 'observation');
            tc.verifyEqual(b.document_class.schema_version, 'did_v2');
            tc.verifyEqual({b.document_class.superclasses.class_name}, ...
                {'interaction', 'statement', 'base', 'term', 'value', 'data'});

            % the term, verbatim -- and `name` left EMPTY rather than guessed:
            % the v1 document stores only the node.
            tc.verifyEqual(b.term.value.node, 'EMPTY:0000131');
            tc.verifyEqual(b.term.value.name, '');
            tc.verifyEqual(b.statement.variable.name, 'label');

            % what it was about
            tc.verifyEqual(depValue(b, 'entity_id'), 'subj_group_9');
            tc.verifyEmpty(depValue(b, 'subject_id'));
            tc.verifyEmpty(depValue(b, 'derived_from_1'));

            % what it labelled: a derived_from relation, label -> statement
            tc.verifyNumElements(plan(1).related, 1);
            r = plan(1).related{1};
            tc.verifyEqual(r.document_class.class_name, 'directed_relation');
            tc.verifyEqual(depValue(r, 'child_id'), 'lab_1');
            tc.verifyEqual(depValue(r, 'parent_id'), 'img_1');
            tc.verifyTrue(ndi.v2.vocabIs('relation', r.directed_relation.relation, 'derived_from'));
        end
        function testTheIdIsPreservedSoTheReplacementSupersedesThePassthrough(tc)
            % The calculator lesson: dissolving a referenced document without
            % keeping its id cost 11,448 orphans. It also means local.m can
            % remove the passthrough safely -- two documents with one id is not a
            % state this database has a meaning for.
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131') };
            plan = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(plan(1).source_id, 'lab_1');
            tc.verifyEqual(plan(1).body.base.id, 'lab_1');
            tc.verifyEqual(sessionOf(plan(1).body), 'sess1');
        end

        function testTheTimeAnchorIsReusedNotMinted(tc)
            % `time_reference_#` carries min_count 1 on subject_interaction, so
            % it cannot be omitted -- and the label is about that observation, at
            % that time. Minting a second anchor for the same instant is #52's
            % undefined-meaning case.
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131') };
            plan = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(plan(1).time_reference_id, 'anchor_1');
            tc.verifyEqual(depValue(plan(1).body, 'time_reference_id'), 'anchor_1');
        end

        function testTheEColiHalfIsBlockedAndCountedSeparately(tc)
            % THE FINDING, not an error case. The referent EXISTS -- it is the
            % passed-through `image_stack` that +migrators_j/image_stack.m's own
            % guard produced, because doImport.m:794,814,830 set `document_id`
            % only. There is nothing to inherit, and inventing one is a team
            % modelling call this pass must not make.
            batch = { ...
                imageStackPassthrough('img_2', 'sess2', 'platerow_5'), ...
                labelBody('lab_2', 'sess2', 'img_2', 'EMPTY:0000132') };
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.labels_passthrough, 1);
            tc.verifyEqual(rep.resolved, 0);
            tc.verifyEqual(rep.blocked_target_has_no_subject, 1);
            tc.verifyEqual(rep.blocked_by_target_class.image_stack, 1);
            tc.verifyFalse(rep.changed);
        end

        function testBlockedAndMissingAreDifferentBuckets(tc)
            % "the referent exists but has no subject" and "the referent is not
            % in this batch" are completely different findings -- one is the
            % E. coli modelling gap, the other is discovery mode reading a subset
            % -- and they were one bucket in the reading that graded this class
            % benign. Both must be counted, separately, in one run.
            batch = { ...
                imageStackPassthrough('img_2', 'sess2', 'platerow_5'), ...
                labelBody('lab_2', 'sess2', 'img_2', 'EMPTY:0000132'), ...
                labelBody('lab_3', 'sess2', 'img_absent', 'EMPTY:0000132') };
            [~, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(rep.labels_passthrough, 2);
            tc.verifyEqual(rep.blocked_target_has_no_subject, 1);
            tc.verifyEqual(rep.unresolved_target_not_in_batch, 1);
        end

        function testALabelWithNoDocumentEdgeIsCountedNotGuessed(tc)
            b = labelBody('lab_4', 'sess1', '', 'EMPTY:0000131');
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects({b});
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.unresolved_no_document_edge, 1);
        end

        function testALabelWithNoOntologyNodeIsRefused(tc)
            % `term.value` is REQUIRED and, with
            % did2.schema.cache.strictMode('NonVacuousFields') armed by default,
            % an all-blank term QUARANTINES. A label with no node says nothing;
            % the passthrough at least preserves the document.
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_5', 'sess1', 'img_1', '') };
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.unresolved_no_ontology_node, 1);
        end

        function testALabelWithAFieldTheObservationCannotPlaceIsLeftAsV1(tc)
            % [generic stage is lossless] / [partly placed is carried as v1]
            % (Jess Haley, 2026-10-25): the observation writes only the node
            % and the document_id edge. A label stating anything else is not
            % replaced (it stays for the end of ndi.migrate.local to carry as
            % v1), and is counted.
            lab = labelBody('lab_8', 'sess1', 'img_1', 'EMPTY:0000131');
            lab.ontologyLabel.note = 'an extra field';
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), lab};
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.unresolved_unplaced_fields, 1);
            % the same label without the extra field is placed
            [plan2, rep2] = ndi.migrate.internal.ontologyLabelSubjects({batch{1}, ...
                labelBody('lab_8', 'sess1', 'img_1', 'EMPTY:0000131')});
            tc.verifyNumElements(plan2, 1);
            tc.verifyEqual(rep2.unresolved_unplaced_fields, 0);
        end

        function testALabelOutsideItsTemplateIsCarriedUnderCarry100(tc)
            % [ontologyLabel row split] (Jess Haley, 2026-10-27, did-schema
            % V_eta_go_forward_class_audit.md): a field outside NDI's
            % `ontologyLabel` template, or an edge other than `document_id`,
            % is carried under carry-100 (malformed), not carry-095. The
            % template (ontologyLabel.json at the locked NDI-matlab main) has
            % one field, `ontologyNode`, and one edge, `document_id`. Both
            % the stray field and the stray edge.
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            makers = {@labelBody};
            for m = 1:numel(makers)
                withField = withExtraField(makers{m}('lab_f', 'sess1', 'img_1', 'EMPTY:0000131'));
                withEdge = makers{m}('lab_e', 'sess1', 'img_1', 'EMPTY:0000131');
                withEdge.depends_on(end+1) = struct('name', 'element_id', 'value', 'elem_7');
                [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects({obs, withField, withEdge});
                tc.verifyEmpty(plan);
                tc.verifyEqual(rep.unresolved_unplaced_fields, 2);
                tc.verifyEqual({rep.carry_rows.id}, {'lab_f', 'lab_e'});
                tc.verifyEqual({rep.carry_rows.row}, {'carry-100', 'carry-100'});
                tc.verifyFalse(any(strcmp({rep.carry_rows.row}, 'carry-095')));
            end
        end

        function testAReferentWithNoTimeAnchorIsRefusedRatherThanAnchoredElsewhere(tc)
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            obs.depends_on = obs.depends_on(1);     % entity_id only
            batch = {obs, labelBody('lab_6', 'sess1', 'img_1', 'EMPTY:0000131')};
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.unresolved_target_no_time_reference, 1);
        end

        function testTheRenamedSpellingIsNotALabel(tc)
            % [ndi_document read as base], [rename clashes are malformed] and
            % [fields outside the template are malformed] (Jess Haley,
            % 2026-10-27 / 2026-10-31 / 2026-11-01): DID-matlab #351 deleted
            % did2.convert.universalRenames, so pass 1 hands a label on in
            % NDI's own spelling (class and block `ontologyLabel`, field
            % `ontologyNode`). The renamed spelling (`ontology_label`,
            % `ontology_node`) is no longer read: a document of that class is
            % not a label, and a label holding `ontology_node` in its block
            % holds a field outside its template (carry-100).
            renamed = labelBody('lab_7', 'sess1', 'img_1', 'EMPTY:0000131');
            renamed.document_class.class_name = 'ontology_label';
            renamed = rmfield(renamed, 'ontologyLabel');
            renamed.ontology_label = struct('ontology_node', 'EMPTY:0000131');
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects({obs, renamed});
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.labels_passthrough, 0);
            lab = labelBody('lab_9', 'sess1', 'img_1', 'EMPTY:0000131');
            lab.ontologyLabel.ontology_node = 'EMPTY:0000132';
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects({obs, lab});
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.labels_passthrough, 1);
            tc.verifyEqual(rep.carry_rows(1).row, 'carry-100');
        end

        function testAlreadyConvertedLabelsAreNotReprocessed(tc)
            % Idempotence. ndi.migrate.local documents itself as idempotent: a
            % re-run reads every document back and runs the second pass again.
            % The replacement is a `term_observation`, not an `ontology_label`,
            % so the second run finds nothing to do -- and a pass that "resolved"
            % its own output would double-count forever.
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            plan = ndi.migrate.internal.ontologyLabelSubjects( ...
                {obs, labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131')});
            [plan2, rep2] = ndi.migrate.internal.ontologyLabelSubjects( ...
                {obs, plan(1).body});
            tc.verifyEmpty(plan2);
            tc.verifyEqual(rep2.labels_passthrough, 0);
            tc.verifyEqual(rep2.resolved, 0);
        end

        function testAPreEightyEightReferentStillResolves(tc)
            % pass-1 output from a pre-#88 DID-matlab (subject_id,
            % time_reference_1) is read the same way
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            obs.depends_on = [ ...
                struct('name', 'subject_id',       'value', 'subj_group_9'), ...
                struct('name', 'time_reference_1', 'value', 'anchor_1')];
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects( ...
                {obs, labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131')});
            tc.verifyEqual(rep.resolved, 1);
            tc.verifyEqual(depValue(plan(1).body, 'entity_id'), 'subj_group_9');
            tc.verifyEqual(depValue(plan(1).body, 'time_reference_id'), 'anchor_1');
        end

        function testTheLabelClassHelperAcceptsTheV1SpellingOnly(tc)
            % ONE helper decides "is this a label document": the v1 class name
            % `ontologyLabel`, which pass 1 hands on unrenamed since
            % DID-matlab #351 deleted universalRenames. The renamed
            % `ontology_label` is no longer a label.
            f = @ndi.migrate.internal.isOntologyLabelClass;
            tc.verifyTrue(f('ontologyLabel'));
            tc.verifyTrue(f("ontologyLabel"));
            tc.verifyFalse(f('ontology_label'));
            tc.verifyFalse(f("ontology_label"));
            tc.verifyFalse(f('OntologyLabel'));
            tc.verifyFalse(f('ontologylabel'));
            tc.verifyFalse(f('ontology_label_x'));
            tc.verifyFalse(f('ontologyTableRow'));
            tc.verifyFalse(f('observation'));
            tc.verifyFalse(f(''));
            tc.verifyFalse(f([]));
            tc.verifyFalse(f({'ontologyLabel'}));
        end

        function testARawV1LabelIsFoundUnderItsV1ClassName(tc)
            % DID-matlab hands the second pass a label in NDI's own spelling:
            % class_name `ontologyLabel`. It is found, counted and resolved.
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), ...
                labelBody('lab_1', 'sess1', 'img_1', 'EMPTY:0000131') };
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(rep.labels_passthrough, 1);
            tc.verifyEqual(rep.resolved, 1);
            tc.verifyNumElements(plan, 1);
            tc.verifyEqual(plan(1).source_id, 'lab_1');
            tc.verifyEqual(plan(1).subject_id, 'subj_group_9');
            tc.verifyEqual(plan(1).body.document_class.class_name, 'observation');
            tc.verifyEqual(plan(1).body.term.value.node, 'EMPTY:0000131');
        end

        function testUnreadableEntriesAreCountedNotDropped(tc)
            % The silentLoss failure: a census that cannot read its input must
            % say so rather than report a clean zero.
            [~, rep] = ndi.migrate.internal.ontologyLabelSubjects( ...
                {struct(), labelBody('lab_8', 'sess1', '', 'EMPTY:0000131')});
            tc.verifyEqual(rep.documents_inspected, 2);
            tc.verifyEqual(rep.documents_unreadable, 1);
        end

    end
end

% ===================== fixtures ========================================

function b = labelBody(docId, sessionId, targetId, node)
%LABELBODY A label as pass 1 hands it on: RAW v1, the NDI template's own
%   class name (`ontologyLabel`), block (`ontologyLabel.ontologyNode`) and v1
%   document_class, as NDI writes it. DID-matlab renames nothing since #351
%   deleted universalRenames.
%
%   TEMPLATE (git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyLabel.json):
%      "ontologyLabel": { "ontologyNode": "" }
%      "depends_on":    [ { "name": "document_id", "value": "" } ]
%   ONE property field, ONE dependency. The three names the old migrator also
%   read -- `ontology_name`, `label_id`, `label` -- do not exist on the real
%   class and are deliberately absent here;
%   +did2/+convert/+migrators_j/ontology_label.m ERRORS on a body carrying them.
b = struct();
b.document_class = struct( ...
    'definition', '$NDIDOCUMENTPATH/data/ontologyLabel.json', ...
    'validation', '$NDISCHEMAPATH/data/ontologyLabel_schema.json', ...
    'class_name', 'ontologyLabel', ...
    'property_list_name', 'ontologyLabel', ...
    'class_version', 1, ...
    'superclasses', struct('definition', '$NDIDOCUMENTPATH/base.json'));
if isempty(targetId)
    b.depends_on = struct('name', {}, 'value', {});
else
    b.depends_on = struct('name', 'document_id', 'value', targetId);
end
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
b.ontologyLabel = struct('ontologyNode', node);
end

function b = withExtraField(b)
%WITHEXTRAFIELD A label stating a field the observation cannot place.
b.ontologyLabel.note = 'an extra field';
end

function b = imageObservation(docId, sessionId, subjectId, anchorId)
% what migrators_j.image_stack emits on did-schema #88 for a stack with a
% subject: an `observation` with the `intensity` kind, id preserved
b = struct();
b.document_class = struct('class_name', 'observation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'interaction', 'class_version', '1.0.0'), ...
        struct('class_name', 'statement',   'class_version', '1.0.0'), ...
        struct('class_name', 'base',        'class_version', '1.0.0'), ...
        struct('class_name', 'intensity',   'class_version', '1.0.0'), ...
        struct('class_name', 'value',       'class_version', '1.0.0'), ...
        struct('class_name', 'data',        'class_version', '1.0.0')], ...
    'schema_version', 'did_v2');
b.depends_on = [ ...
    struct('name', 'entity_id',         'value', subjectId), ...
    struct('name', 'time_reference_id', 'value', anchorId)];
b.base = struct('id', docId, 'session_id', sessionId, ...
    'creation_timestamp', '2024-06-01T12:00:00.000Z');
b.statement = struct('variable', struct('node', '', 'name', 'image intensity'));
end

function b = imageStackPassthrough(docId, sessionId, targetId)
%IMAGESTACKPASSTHROUGH The E. COLI imageStack, as image_stack.m:78-81 leaves it.
%   The writer set `document_id` and no `subject_id`
%   (doImport.m:794 / :814 / :830), so the guard passes the whole document
%   through rather than emitting an image_observation about nobody.
b = struct();
b.document_class = struct('class_name', 'image_stack', ...
    'class_version', '1.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'did_v2');
b.depends_on = struct('name', 'document_id', 'value', targetId);
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
b.image_stack = struct('label', '', 'format_ontology', 'NCIT:C85437');
end

function v = depValue(b, name)
v = '';
if ~isfield(b, 'depends_on') || isempty(b.depends_on); return; end
deps = b.depends_on;
for k = 1:numel(deps)
    if ~isfield(deps(k), 'name') || ~strcmp(char(deps(k).name), name); continue; end
    if isfield(deps(k), 'value') && ~isempty(deps(k).value)
        v = char(deps(k).value);
    elseif isfield(deps(k), 'document_id') && ~isempty(deps(k).document_id)
        v = char(deps(k).document_id);
    end
    return;
end
end

function sid = sessionOf(b)
if isfield(b.base, 'session_id')
    sid = b.base.session_id;
else
    sid = depValue(b, 'session_id');
end
end
