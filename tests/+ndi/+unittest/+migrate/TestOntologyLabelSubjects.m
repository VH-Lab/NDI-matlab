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

            tc.verifyEqual(b.document_class.class_name, 'term_observation');
            tc.verifyEqual(b.document_class.schema_version, 'V_eta');
            tc.verifyEqual({b.document_class.superclasses.class_name}, ...
                {'subject_observation', 'term'});

            % the term, verbatim -- and `name` left EMPTY rather than guessed:
            % the v1 document stores only the node.
            tc.verifyEqual(b.term.value.node, 'EMPTY:0000131');
            tc.verifyEqual(b.term.value.name, '');

            % what it was about
            tc.verifyEqual(depValue(b, 'subject_id'), 'subj_group_9');
            tc.verifyEqual(depValue(b, 'derived_from_1'), 'img_1');
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
            tc.verifyEqual(plan(1).body.base.session_id, 'sess1');
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
            tc.verifyEqual(depValue(plan(1).body, 'time_reference_1'), 'anchor_1');
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

        function testAReferentWithNoTimeAnchorIsRefusedRatherThanAnchoredElsewhere(tc)
            obs = imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1');
            obs.depends_on = obs.depends_on(1);     % subject_id only
            batch = {obs, labelBody('lab_6', 'sess1', 'img_1', 'EMPTY:0000131')};
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEmpty(plan);
            tc.verifyEqual(rep.unresolved_target_no_time_reference, 1);
        end

        function testTheCamelCaseSpellingIsAlsoRead(tc)
            % A body that never went through did2.convert.universalRenames still
            % spells the block `ontologyLabel` and the field `ontologyNode`. The
            % standing migrator lesson: read snake-first with a camel fallback.
            lab = labelBody('lab_7', 'sess1', 'img_1', 'EMPTY:0000131');
            lab = rmfield(lab, 'ontology_label');
            lab.ontologyLabel = struct('ontologyNode', 'EMPTY:0000131');
            batch = { ...
                imageObservation('img_1', 'sess1', 'subj_group_9', 'anchor_1'), lab};
            [plan, rep] = ndi.migrate.internal.ontologyLabelSubjects(batch);
            tc.verifyEqual(rep.resolved, 1);
            tc.verifyEqual(plan(1).body.term.value.node, 'EMPTY:0000131');
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
%LABELBODY A passed-through `ontology_label`, as pass 1 leaves it.
%
%   TEMPLATE (git show origin/main:src/ndi/ndi_common/database_documents/data/ontologyLabel.json):
%      "ontologyLabel": { "ontologyNode": "" }
%      "depends_on":    [ { "name": "document_id", "value": "" } ]
%   ONE property field, ONE dependency. The three names the old migrator also
%   read -- `ontology_name`, `label_id`, `label` -- do not exist on the real
%   class and are deliberately absent here;
%   +did2/+convert/+migrators_j/ontology_label.m ERRORS on a body carrying them.
b = struct();
b.document_class = struct('class_name', 'ontology_label', ...
    'class_version', '2.0.0', ...
    'superclasses', struct('class_name', 'base', 'class_version', '1.0.0'), ...
    'schema_version', 'V_eta');
if isempty(targetId)
    b.depends_on = struct('name', {}, 'value', {});
else
    b.depends_on = struct('name', 'document_id', 'value', targetId);
end
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', '', 'datestamp', '2024-06-01T12:00:00.000Z');
b.ontology_label = struct('ontology_node', node);
end

function b = imageObservation(docId, sessionId, subjectId, anchorId)
%IMAGEOBSERVATION The BEHAVIOUR-session imageStack after
%   +migrators_j/image_stack.m: base.id preserved (image_stack.m:85,120), a
%   subject_id inherited from the source's subjectGroup_id, and the session
%   anchor it minted (image_stack.m:97,113).
b = struct();
b.document_class = struct('class_name', 'image_observation', ...
    'class_version', '1.0.0', ...
    'superclasses', [ ...
        struct('class_name', 'subject_observation', 'class_version', '1.0.0'), ...
        struct('class_name', 'image',               'class_version', '1.0.0')], ...
    'schema_version', 'V_eta');
b.depends_on = [ ...
    struct('name', 'subject_id',       'value', subjectId), ...
    struct('name', 'time_reference_1', 'value', anchorId)];
b.base = struct('id', docId, 'session_id', sessionId, ...
    'name', 'migrated_image', 'datestamp', '2024-06-01T12:00:00.000Z');
b.subject_statement = struct( ...
    'variable', struct('node', '', 'name', 'image'), 'storage_mode', 'body');
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
    'schema_version', 'V_eta');
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
