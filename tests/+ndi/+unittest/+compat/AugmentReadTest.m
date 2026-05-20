classdef AugmentReadTest < matlab.unittest.TestCase
%AUGMENTREADTEST Unit tests for ndi.compat.augmentRead.
%
%   Covers the four collapsed-ontology classes (probe_location,
%   treatment, ontology_image, ontology_label), the depends_on
%   value -> id mirror, idempotency, and no-op behaviour on bodies
%   that don't carry any aliased fields (including raw v1 bodies).
%
%   Also includes acceptance tests that route a V_delta body
%   through the ndi.document constructor and verify the legacy
%   paths are visible on document_properties.

    methods (Test)

        function test_probe_location_node_and_name_mirrored(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.name, 'V1');
        end

        function test_treatment_node_and_name_mirrored(testCase)
            body = i_baseBody('treatment');
            body.treatment = struct( ...
                'treatment_name', struct('node', 'chebi:9999', ...
                                         'name', 'tetrodotoxin'));
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.treatment.ontology_name, 'chebi:9999');
            testCase.verifyEqual(out.treatment.name, 'tetrodotoxin');
        end

        function test_ontology_image_region_mirrored(testCase)
            body = i_baseBody('ontology_image');
            body.ontology_image = struct( ...
                'region', struct('node', 'uberon:0002435', ...
                                 'name', 'striatum'));
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.ontology_image.ontology_name, ...
                'uberon:0002435');
            testCase.verifyEqual(out.ontology_image.ontology_region, ...
                'striatum');
        end

        function test_ontology_label_composite_decomposed(testCase)
            body = i_baseBody('ontology_label');
            body.ontology_label = struct( ...
                'term', struct('node', 'allen_ccf_v3:12345', ...
                               'name', 'primary visual area'));
            out = ndi.compat.augmentRead(body);
            % term.node decomposes into ontology_name + label_id
            testCase.verifyEqual(out.ontology_label.ontology_name, ...
                'allen_ccf_v3');
            testCase.verifyEqual(out.ontology_label.label_id, 12345);
            % term.name maps identity to label
            testCase.verifyEqual(out.ontology_label.label, ...
                'primary visual area');
        end

        function test_ontology_label_composite_empty_node(testCase)
            body = i_baseBody('ontology_label');
            body.ontology_label = struct( ...
                'term', struct('node', '', 'name', ''));
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.ontology_label.ontology_name, '');
            testCase.verifyEqual(out.ontology_label.label_id, 0);
            testCase.verifyEqual(out.ontology_label.label, '');
        end

        function test_depends_on_value_mirrored_to_id(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent', 'sibling'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677', ...
                          'aabb1122ccdd3344_8899aabbccddeeff'});
            out = ndi.compat.augmentRead(body);
            testCase.verifyTrue(isfield(out.depends_on, 'id'));
            testCase.verifyEqual(out.depends_on(1).id, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyEqual(out.depends_on(2).id, ...
                'aabb1122ccdd3344_8899aabbccddeeff');
        end

        function test_depends_on_empty_array_left_alone(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct('name', {}, 'value', {});
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(numel(out.depends_on), 0);
        end

        function test_depends_on_missing_field_does_not_crash(testCase)
            body = i_baseBody('demo_a');
            % No depends_on field at all — some document classes don't
            % carry depends_on.
            out = ndi.compat.augmentRead(body);
            testCase.verifyFalse(isfield(out, 'depends_on'));
        end

        function test_idempotent_when_run_twice(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            once  = ndi.compat.augmentRead(body);
            twice = ndi.compat.augmentRead(once);
            testCase.verifyEqual(twice, once);
        end

        function test_idempotent_when_legacy_alias_already_present(testCase)
            % If a body already carries the legacy alias and matches
            % the V_delta canonical, augmentRead leaves it untouched.
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'), ...
                'ontology_name', 'uberon:1234', ...
                'name',          'V1');
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.name, 'V1');
            % V_delta canonical is preserved verbatim.
            testCase.verifyEqual(out.probe_location.location.node, ...
                'uberon:1234');
        end

        function test_legacy_alias_overwritten_when_inconsistent(testCase)
            % If a body carries a stale legacy alias that disagrees
            % with the V_delta canonical, the V_delta value wins
            % (V_delta is the source of truth at read time).
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'), ...
                'ontology_name', 'stale_value', ...
                'name',          'stale_name');
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.name, 'V1');
        end

        function test_unaffected_class_passes_through(testCase)
            % A document of a class that has no aliased fields is left
            % structurally unchanged (modulo the depends_on .id mirror).
            body = i_baseBody('demo_a');
            body.demo_a = struct('marker', 'hello');
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.demo_a, body.demo_a);
            testCase.verifyFalse(isfield(out, 'probe_location'));
            testCase.verifyFalse(isfield(out, 'treatment'));
            testCase.verifyFalse(isfield(out, 'ontology_image'));
            testCase.verifyFalse(isfield(out, 'ontology_label'));
        end

        function test_noop_on_v1_shaped_body(testCase)
            % A v1 body has no V_delta paths; every alias row is a
            % no-op, so the body must come out byte-identical (modulo
            % field ordering).
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'ontology_name', 'uberon:1234', ...
                'name',          'V1');
            body.depends_on = struct( ...
                'name', {'parent'}, ...
                'id',   {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.augmentRead(body);
            % V_delta paths were not present; legacy paths survive.
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.name, 'V1');
            testCase.verifyFalse(isfield(out.probe_location, 'location'));
            % depends_on entries still have id; no .value was added.
            testCase.verifyEqual(out.depends_on(1).id, ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
        end

        function test_partial_block_skips_missing_subfields(testCase)
            % If only one of the V_delta subfields is present, only
            % that legacy alias is mirrored.
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234'));
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyFalse(isfield(out.probe_location, 'name'));
        end

        % ---- acceptance: hooked into ndi.document constructor ----

        function test_ndi_document_constructor_augments_probe_location(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
            doc = ndi.document(body);
            testCase.verifyEqual( ...
                doc.document_properties.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual( ...
                doc.document_properties.probe_location.name, 'V1');
        end

        function test_ndi_document_constructor_mirrors_depends_on(testCase)
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',  {'parent'}, ...
                'value', {'aabb1122ccdd3344_0011223344556677'});
            doc = ndi.document(body);
            testCase.verifyTrue( ...
                isfield(doc.document_properties.depends_on, 'id'));
            testCase.verifyEqual( ...
                doc.document_properties.depends_on(1).id, ...
                'aabb1122ccdd3344_0011223344556677');
        end
    end
end

function body = i_baseBody(className)
% Build a minimal V_delta-shaped document body for the given class.
% Mirrors the helper in TestApplyReadNormalization but exposes the
% class name so we can build per-class fixtures.
body = struct();
body.document_class = struct( ...
    'class_name',    className, ...
    'class_version', '2.0.0', ...
    'superclasses',  struct( ...
        'class_name',    'base', ...
        'class_version', '2.0.0'));
body.base = struct( ...
    'id',         ['aabb1122ccdd3344_' i_pad16(className)], ...
    'session_id', 'aabb1122ccdd3344_9900aabbccddeeff', ...
    'name',       className, ...
    'datestamp',  '2026-05-20T12:00:00.000Z');
end

function s = i_pad16(name)
hex = lower(dec2hex(double(name)));
joined = strjoin(cellstr(hex(:)'), '');
joined = [joined repmat('0', 1, 16)];
s = joined(1:16);
end
