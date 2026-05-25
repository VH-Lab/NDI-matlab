classdef AugmentReadTest < matlab.unittest.TestCase
%AUGMENTREADTEST Unit tests for ndi.compat.augmentRead.
%
%   Covers the field-level alias rows: the four collapsed-ontology
%   classes (probe_location, treatment, ontology_image,
%   ontology_label) plus the daqmetadatareader rename.
%
%   depends_on entry-key compatibility is NOT exercised here — see
%   #801: that responsibility moved to
%   ndi.compat.normalizeDependsOn (constructor-level) and to
%   ndi.document's dependency-accessor methods. augmentRead does
%   not touch depends_on at all.

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
            testCase.verifyEqual(out.ontology_label.ontology_name, ...
                'allen_ccf_v3');
            testCase.verifyEqual(out.ontology_label.label_id, 12345);
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

        function test_idempotent_when_run_twice(testCase)
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'location', struct('node', 'uberon:1234', 'name', 'V1'));
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
            % A document of a class that has no aliased fields is
            % left structurally unchanged.
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
            % no-op, so the body must come out structurally
            % unchanged.
            body = i_baseBody('probe_location');
            body.probe_location = struct( ...
                'ontology_name', 'uberon:1234', ...
                'name',          'V1');
            out = ndi.compat.augmentRead(body);
            testCase.verifyEqual(out.probe_location.ontology_name, ...
                'uberon:1234');
            testCase.verifyEqual(out.probe_location.name, 'V1');
            testCase.verifyFalse(isfield(out.probe_location, 'location'));
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

        function test_does_not_touch_depends_on(testCase)
            % Regression for #801: augmentRead must NOT inject .id
            % onto depends_on entries (the old mirror that extended
            % the struct-array schema). depends_on entry-key
            % compatibility lives elsewhere now.
            body = i_baseBody('demo_a');
            body.depends_on = struct( ...
                'name',         {'parent'}, ...
                'document_id',  {'aabb1122ccdd3344_0011223344556677'});
            out = ndi.compat.augmentRead(body);
            testCase.verifyFalse(isfield(out.depends_on, 'id'));
            testCase.verifyFalse(isfield(out.depends_on, 'value'));
            testCase.verifyTrue(isfield(out.depends_on, 'document_id'));
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
