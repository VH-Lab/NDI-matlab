classdef ReconcileWriteTest < matlab.unittest.TestCase
%RECONCILEWRITETEST Unit tests for ndi.compat.reconcileWrite.
%
%   Covers the write-side reconciliation of legacy did_v1 aliases back
%   into V_delta canonical paths plus the strip step that keeps only
%   V_delta on the wire to the database.

    methods (Test)

        % ---- field-level rows ----

        function test_probe_location_legacy_edit_wins(testCase)
            % User edited the legacy `ontology_name` after a read; the
            % V_delta canonical still carries the (stale) read-time
            % value. Reconciliation should take the legacy edit and
            % strip the legacy alias.
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1111', 'name', 'old'), ...
                'ontology_name', 'uberon:9999', ...
                'name',          'new');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.probe_location.location.node, ...
                'uberon:9999');
            testCase.verifyEqual(out.probe_location.location.name, 'new');
            testCase.verifyFalse(isfield(out.probe_location, 'ontology_name'));
            % 'name' is also a legacy alias (probe_location.name maps
            % to probe_location.location.name) so it must be stripped.
            testCase.verifyFalse(isfield(out.probe_location, 'name'));
        end

        function test_probe_location_legacy_only(testCase)
            % Customer constructed a doc with only legacy paths.
            % Reconciliation should populate V_delta canonical and
            % strip legacy.
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'ontology_name', 'uberon:9999', ...
                'name',          'V1');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.probe_location.location.node, ...
                'uberon:9999');
            testCase.verifyEqual(out.probe_location.location.name, 'V1');
            testCase.verifyFalse(isfield(out.probe_location, 'ontology_name'));
            testCase.verifyFalse(isfield(out.probe_location, 'name'));
        end

        function test_treatment_legacy_edit_wins(testCase)
            body = i_baseBody('treatment');
            body.treatment = struct( ...
                'treatment_name', struct('node', 'chebi:1111', ...
                                         'name', 'old'), ...
                'ontology_name',  'chebi:9999', ...
                'name',           'tetrodotoxin');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.treatment.treatment_name.node, ...
                'chebi:9999');
            testCase.verifyEqual(out.treatment.treatment_name.name, ...
                'tetrodotoxin');
            testCase.verifyFalse(isfield(out.treatment, 'ontology_name'));
            testCase.verifyFalse(isfield(out.treatment, 'name'));
        end

        function test_ontology_image_legacy_edit_wins(testCase)
            body = i_baseBody('ontology_image');
            body.ontology_image = struct( ...
                'region', struct('node', 'uberon:1111', 'name', 'old'), ...
                'ontology_name',   'uberon:0002435', ...
                'ontology_region', 'striatum');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.ontology_image.region.node, ...
                'uberon:0002435');
            testCase.verifyEqual(out.ontology_image.region.name, ...
                'striatum');
            testCase.verifyFalse(isfield(out.ontology_image, 'ontology_name'));
            testCase.verifyFalse(isfield(out.ontology_image, 'ontology_region'));
        end

        function test_ontology_label_composite_legacy_wins(testCase)
            body = i_baseBody('ontology_label');
            body.ontology_label = struct( ...
                'term', struct('node', 'old:0', 'name', 'old'), ...
                'ontology_name', 'allen_ccf_v3', ...
                'label_id',      12345, ...
                'label',         'primary visual area');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.ontology_label.term.node, ...
                'allen_ccf_v3:12345');
            testCase.verifyEqual(out.ontology_label.term.name, ...
                'primary visual area');
            testCase.verifyFalse(isfield(out.ontology_label, 'ontology_name'));
            testCase.verifyFalse(isfield(out.ontology_label, 'label_id'));
            testCase.verifyFalse(isfield(out.ontology_label, 'label'));
        end

        function test_ontology_label_composite_legacy_only_partial(testCase)
            % Only one of the two composite legacy fields is set.
            % The composing transform still runs; the missing legacy
            % field contributes empty.
            body = i_baseBody('ontology_label');
            body.ontology_label = struct( ...
                'ontology_name', 'allen_ccf_v3');
            out = ndi.compat.reconcileWrite(body);
            % toVDelta({'allen_ccf_v3', ''}) = 'allen_ccf_v3:' (empty
            % numeric -> '0', then composed)
            testCase.verifyTrue(isfield(out.ontology_label, 'term'));
            testCase.verifyFalse(isfield(out.ontology_label, 'ontology_name'));
            testCase.verifyFalse(isfield(out.ontology_label, 'label_id'));
        end

        function test_legacy_absent_no_op(testCase)
            % If only V_delta canonical is present, reconciliation
            % is a no-op (nothing to copy, nothing to strip).
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.probe_location.location.node, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.location.name, 'V1');
            testCase.verifyFalse(isfield(out.probe_location, 'ontology_name'));
            testCase.verifyFalse(isfield(out.probe_location, 'name'));
        end

        function test_unaffected_class_unchanged(testCase)
            body = i_baseBody('demo_a');
            body.demo_a = struct('marker', 'hello');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.demo_a.marker, 'hello');
            testCase.verifyFalse(isfield(out, 'probe_location'));
            testCase.verifyFalse(isfield(out, 'treatment'));
            testCase.verifyFalse(isfield(out, 'ontology_image'));
            testCase.verifyFalse(isfield(out, 'ontology_label'));
        end

        % ---- depends_on rows ----

        function test_depends_on_id_copied_and_stripped(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'}, ...
                'id',    {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(numel(out.depends_on), 1);
            testCase.verifyEqual(out.depends_on(1).value, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_depends_on_id_edit_wins_over_value(testCase)
            % User edited the legacy `.id` after a read; the V_delta
            % canonical .value carries the stale value.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'}, ...
                'id',    {'eeff5566eeff5566_8899aabbccddeeff'});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.depends_on(1).value, ...
                'eeff5566eeff5566_8899aabbccddeeff');
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_depends_on_id_empty_does_not_overwrite_value(testCase)
            % An empty legacy .id (the augmentation-of-empty case)
            % must not blow away a real .value.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'}, ...
                'id',    {''});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.depends_on(1).value, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_depends_on_no_legacy_field_no_op(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.depends_on(1).value, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_depends_on_legacy_only(testCase)
            % v1-shaped body has only .id, not .value. Reconciliation
            % must move .id -> .value and strip .id.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name', {'parent'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(out.depends_on(1).value, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
        end

        function test_depends_on_empty_array(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct('name', {}, 'value', {});
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyEqual(numel(out.depends_on), 0);
        end

        function test_depends_on_missing(testCase)
            body = i_baseBody('demo_a');
            out = ndi.compat.reconcileWrite(body);
            testCase.verifyFalse(isfield(out, 'depends_on'));
        end

        % ---- idempotency + round-trip ----

        function test_idempotent(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'), ...
                'ontology_name', 'uberon:1234', ...
                'name',          'V1');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'}, ...
                'id',    {'aabb1122ccdd3344_0011223344556677'});
            once  = ndi.compat.reconcileWrite(body);
            twice = ndi.compat.reconcileWrite(once);
            testCase.verifyEqual(twice, once);
        end

        function test_round_trip_augment_then_reconcile(testCase)
            % Pristine V_delta -> augment -> reconcile must return
            % byte-equivalent V_delta.
            pristine = i_baseBody('probe_location');
            pristine.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            pristine.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            augmented   = ndi.compat.augmentRead(pristine);
            reconciled  = ndi.compat.reconcileWrite(augmented);
            testCase.verifyEqual(reconciled, pristine);
        end

        function test_round_trip_after_legacy_edit(testCase)
            % Read -> augment -> user edits legacy -> write reconcile.
            % The reconciled body must reflect the edit in V_delta
            % canonical with no legacy fields remaining.
            pristine = i_baseBody('probe_location');
            pristine.probe_location = struct( ...
                'location', struct('node', 'uberon:1111', 'name', 'old'));
            augmented = ndi.compat.augmentRead(pristine);
            % User edits legacy.
            augmented.probe_location.ontology_name = 'uberon:9999';
            augmented.probe_location.name          = 'new';
            reconciled = ndi.compat.reconcileWrite(augmented);
            testCase.verifyEqual(reconciled.probe_location.location.node, ...
                'uberon:9999');
            testCase.verifyEqual(reconciled.probe_location.location.name, ...
                'new');
            testCase.verifyFalse(isfield(reconciled.probe_location, ...
                'ontology_name'));
            testCase.verifyFalse(isfield(reconciled.probe_location, ...
                'name'));
        end

        % ---- acceptance: applyWriteReconciliation + ndi.document.fromBody ----

        function test_applyWriteReconciliation_returns_stripped_ndocument(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'), ...
                'ontology_name', 'uberon:1234', ...
                'name',          'V1');
            ndoc = ndi.document(body);
            out = ndi.database.internal.applyWriteReconciliation(ndoc);
            testCase.verifyClass(out, 'ndi.document');
            testCase.verifyFalse(isfield( ...
                out.document_properties.probe_location, 'ontology_name'));
            testCase.verifyFalse(isfield( ...
                out.document_properties.probe_location, 'name'));
            testCase.verifyEqual( ...
                out.document_properties.probe_location.location.node, ...
                'uberon:1234');
        end

        function test_applyWriteReconciliation_accepts_cell_array(testCase)
            % ndi.session.database_add passes a cell array of
            % ndi.document through ndi.database.add, so the helper
            % must accept that shape.
            bodyA = i_baseBody('probe_location');
            bodyA.probe_location = struct( ...
                'location', struct('node', 'uberon:1', 'name', 'A'), ...
                'ontology_name', 'uberon:1', 'name', 'A');
            bodyB = i_baseBody('treatment');
            bodyB.treatment = struct( ...
                'treatment_name', struct('node', 'chebi:1', 'name', 'B'), ...
                'ontology_name', 'chebi:1', 'name', 'B');
            docs = {ndi.document(bodyA), ndi.document(bodyB)};
            out = ndi.database.internal.applyWriteReconciliation(docs);
            testCase.verifyClass(out, 'cell');
            testCase.verifyEqual(numel(out), 2);
            testCase.verifyFalse(isfield( ...
                out{1}.document_properties.probe_location, 'ontology_name'));
            testCase.verifyFalse(isfield( ...
                out{2}.document_properties.treatment, 'ontology_name'));
        end

        function test_applyWriteReconciliation_rejects_bad_input(testCase)
            testCase.verifyError(@() ...
                ndi.database.internal.applyWriteReconciliation(struct()), ...
                'NDI:database:reconcileBadInput');
        end

        function test_fromBody_does_not_augment(testCase)
            % Direct check that the bypass factory returns a document
            % with the body verbatim (no legacy alias re-injection).
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            ndoc = ndi.document.fromBody(body);
            testCase.verifyFalse(isfield( ...
                ndoc.document_properties.probe_location, 'ontology_name'));
            testCase.verifyFalse(isfield( ...
                ndoc.document_properties.probe_location, 'name'));
            testCase.verifyEqual( ...
                ndoc.document_properties.probe_location.location.node, ...
                'uberon:1234');
        end
    end
end

function body = i_baseBody(className)
body = struct();
body.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '2.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '2.0.0'));
body.base = struct( ...
    'id',         'aabb1122ccdd3344_1234567890abcdef', ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       className, ...
    'datestamp',  '2026-05-20T12:00:00.000Z');
end
