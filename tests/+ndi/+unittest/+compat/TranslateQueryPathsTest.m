classdef TranslateQueryPathsTest < matlab.unittest.TestCase
%TRANSLATEQUERYPATHSTEST Unit tests for ndi.compat.translateQueryPaths.
%
%   Covers field-level alias rewrites, depends_on substring rewrites,
%   'or' recursion, identity for non-aliased paths, and the
%   acceptance check that ndi.query constructed with a legacy path
%   ends up with the V_delta canonical path in its searchstructure.

    methods (Test)

        % ---- field-level scalar rows ----

        function test_probe_location_ontology_name_rewritten(testCase)
            ss = i_ss('probe_location.ontology_name', 'exact_string', 'uberon:1234');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'probe_location.location.node');
            testCase.verifyEqual(out.operation, 'exact_string');
            testCase.verifyEqual(out.param1, 'uberon:1234');
        end

        function test_probe_location_name_rewritten(testCase)
            ss = i_ss('probe_location.name', 'exact_string', 'V1');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'probe_location.location.name');
        end

        function test_treatment_ontology_name_rewritten(testCase)
            ss = i_ss('treatment.ontology_name', 'exact_string', 'chebi:9999');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'treatment.treatment_name.node');
        end

        function test_ontology_image_rewritten(testCase)
            ss = i_ss('ontology_image.ontology_name', 'exact_string', 'uberon:0002435');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'ontology_image.region.node');
        end

        function test_ontology_image_region_rewritten(testCase)
            ss = i_ss('ontology_image.ontology_region', 'exact_string', 'striatum');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'ontology_image.region.name');
        end

        function test_ontology_label_label_rewritten(testCase)
            ss = i_ss('ontology_label.label', 'exact_string', 'primary visual area');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'ontology_label.term.name');
        end

        % ---- composite legacy paths collapse to one V_delta path ----

        function test_ontology_label_composite_ontology_name(testCase)
            % Composite row: both legacy paths point at term.node.
            ss = i_ss('ontology_label.ontology_name', 'exact_string', 'allen_ccf_v3');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'ontology_label.term.node');
        end

        function test_ontology_label_composite_label_id(testCase)
            ss = i_ss('ontology_label.label_id', 'exact_number', 12345);
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'ontology_label.term.node');
        end

        % ---- depends_on substring rewrites ----

        function test_depends_on_id_rewritten(testCase)
            ss = i_ss('depends_on.id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'depends_on.value');
        end

        function test_depends_on_indexed_id_rewritten(testCase)
            ss = i_ss('depends_on(1).id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'depends_on(1).value');
        end

        function test_depends_on_indexed_two_digit_id_rewritten(testCase)
            ss = i_ss('depends_on(42).id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'depends_on(42).value');
        end

        function test_depends_on_value_unchanged(testCase)
            % Already V_delta canonical; identity.
            ss = i_ss('depends_on.value', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'depends_on.value');
        end

        function test_depends_on_unrelated_subfield_unchanged(testCase)
            % `depends_on.name` is not the legacy `id` alias.
            ss = i_ss('depends_on.name', 'exact_string', 'parent');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'depends_on.name');
        end

        % ---- identity for non-aliased paths ----

        function test_base_id_unchanged(testCase)
            ss = i_ss('base.id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'base.id');
        end

        function test_arbitrary_path_unchanged(testCase)
            ss = i_ss('foo.bar.baz', 'exact_string', 'value');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'foo.bar.baz');
        end

        function test_empty_field_unchanged(testCase)
            ss = i_ss('', 'isa', 'base');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, '');
        end

        % ---- 'or' recursion ----

        function test_or_param1_param2_recursed(testCase)
            % An 'or' searchstructure stores nested searchstructures in
            % param1 and param2; both branches must be translated.
            innerA = i_ss('probe_location.ontology_name', 'exact_string', 'a');
            innerB = i_ss('treatment.ontology_name', 'exact_string', 'b');
            outer = struct('field', '', 'operation', 'or', ...
                'param1', innerA, 'param2', innerB);
            out = ndi.compat.translateQueryPaths(outer);
            testCase.verifyEqual(out.param1.field, ...
                'probe_location.location.node');
            testCase.verifyEqual(out.param2.field, ...
                'treatment.treatment_name.node');
        end

        function test_nested_or_recurses_deeply(testCase)
            deepest = i_ss('probe_location.ontology_name', 'exact_string', 'x');
            mid = struct('field', '', 'operation', 'or', ...
                'param1', deepest, 'param2', i_ss('base.id', 'exact_string', 'y'));
            outer = struct('field', '', 'operation', 'or', ...
                'param1', mid, 'param2', i_ss('treatment.ontology_name', 'exact_string', 'z'));
            out = ndi.compat.translateQueryPaths(outer);
            testCase.verifyEqual(out.param1.param1.field, ...
                'probe_location.location.node');
            testCase.verifyEqual(out.param2.field, ...
                'treatment.treatment_name.node');
            testCase.verifyEqual(out.param1.param2.field, 'base.id');
        end

        % ---- input shape edges ----

        function test_empty_struct_array_passes_through(testCase)
            ss = did.datastructures.emptystruct('field','operation','param1','param2');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(numel(out), 0);
        end

        function test_string_field_handled(testCase)
            % Some callers pass MATLAB strings rather than char.
            ss = struct('field', "probe_location.ontology_name", ...
                'operation', 'exact_string', 'param1', 'x', 'param2', '');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(char(out.field), ...
                'probe_location.location.node');
        end

        function test_struct_array_each_entry_translated(testCase)
            ss(1) = i_ss('probe_location.ontology_name', 'exact_string', 'a');
            ss(2) = i_ss('treatment.ontology_name', 'exact_string', 'b');
            ss(3) = i_ss('base.id', 'exact_string', 'c');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out(1).field, 'probe_location.location.node');
            testCase.verifyEqual(out(2).field, 'treatment.treatment_name.node');
            testCase.verifyEqual(out(3).field, 'base.id');
        end

        % ---- acceptance: ndi.query constructor wires in the translation ----

        function test_ndi_query_constructor_rewrites_field(testCase)
            q = ndi.query('probe_location.ontology_name', 'exact_string', ...
                'uberon:1234');
            testCase.verifyEqual(q.searchstructure.field, ...
                'probe_location.location.node');
            testCase.verifyEqual(q.searchstructure.param1, 'uberon:1234');
        end

        function test_ndi_query_constructor_rewrites_depends_on_id(testCase)
            q = ndi.query('depends_on.id', 'exact_string', ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyEqual(q.searchstructure.field, 'depends_on.value');
        end

        function test_ndi_query_constructor_passes_unaliased_path(testCase)
            q = ndi.query('base.id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            testCase.verifyEqual(q.searchstructure.field, 'base.id');
        end

        function test_ndi_query_cell_input_translated(testCase)
            % The struct-input form of ndi.query / did.query is
            % currently latent-broken (the shape-strict eqlen check
            % in did.query rejects a 4x1 fieldnames cell against a
            % 1x4 literal). Cover the cell-input form instead, which
            % goes through searchcellarray2searchstructure and
            % builds the struct internally before our translation
            % hook runs.
            q = ndi.query({'probe_location.ontology_name', 'X'});
            testCase.verifyEqual(q.searchstructure.field, ...
                'probe_location.location.node');
        end
    end
end

function s = i_ss(field, op, p1)
s = struct('field', field, 'operation', op, ...
    'param1', p1, 'param2', '');
end
