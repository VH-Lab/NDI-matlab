classdef TranslateQueryPathsTest < matlab.unittest.TestCase
%TRANSLATEQUERYPATHSTEST Unit tests for ndi.compat.translateQueryPaths.
%
%   Covers the depends_on entry-key expansion (a test on any one key
%   spelling -- `document_id`, `value`, `id` -- becomes the test on all
%   three, because a document keeps the dependency shape it was read in:
%   did-schema [v2 line reads and writes both], after VH-Lab/DID-matlab#204;
%   DID-matlab #389), 'or' recursion, identity for every other path, and
%   that ndi.query applies it. These tests used to pin a rewrite of `id` /
%   `value` to `document_id` alone; that rewrite would miss every v1
%   document, which now keeps its `value` key.
%
%   The probe_location / treatment field aliases are gone (Decided by Jess
%   Haley, 2026-10-23 [compat write layer removed]; VH-Lab/NDI-matlab#1055):
%   v1 documents are written in the v1 template's shape, so a query on a v1
%   path must reach that path unchanged. The tests that pinned the old
%   rewrite (probe_location.ontology_name -> probe_location.location.node,
%   treatment.ontology_name -> treatment.treatment_name.node) now pin that
%   the path is left as written.

    methods (Test)

        % ---- the v1 probe_location / treatment paths are not rewritten ----

        function test_probe_location_ontology_name_unchanged(testCase)
            ss = i_ss('probe_location.ontology_name', 'exact_string', 'uberon:1234');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'probe_location.ontology_name');
            testCase.verifyEqual(out.operation, 'exact_string');
            testCase.verifyEqual(out.param1, 'uberon:1234');
        end

        function test_probe_location_name_unchanged(testCase)
            ss = i_ss('probe_location.name', 'exact_string', 'V1');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(out.field, 'probe_location.name');
        end

        function test_treatment_paths_unchanged(testCase)
            % the v1 template's own spelling is ontologyName
            for f = {'treatment.ontologyName', 'treatment.ontology_name', 'treatment.name'}
                out = ndi.compat.translateQueryPaths(i_ss(f{1}, 'exact_string', 'chebi:9999'));
                testCase.verifyEqual(out.field, f{1});
            end
        end

        % ---- depends_on target keys: every spelling is tested ----

        function test_depends_on_each_key_becomes_all_three(testCase)
            for key = {'id', 'value', 'document_id'}
                ss = i_ss(['depends_on.' key{1}], 'exact_string', 'aabb1122ccdd3344_0011223344556677');
                out = ndi.compat.translateQueryPaths(ss);
                testCase.verifyEqual(i_orFields(out), ...
                    {'depends_on.document_id', 'depends_on.value', 'depends_on.id'}, key{1});
                testCase.verifyEqual(i_orLeaf(out, 1).operation, 'exact_string');
                testCase.verifyEqual(i_orLeaf(out, 3).param1, 'aabb1122ccdd3344_0011223344556677');
            end
        end

        function test_depends_on_indexed_key_keeps_its_index(testCase)
            ss = i_ss('depends_on(1).id', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(i_orFields(out), ...
                {'depends_on(1).document_id', 'depends_on(1).value', 'depends_on(1).id'});
        end

        function test_depends_on_indexed_two_digit_key_keeps_its_index(testCase)
            ss = i_ss('depends_on(42).value', 'exact_string', 'aabb1122ccdd3344_0011223344556677');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(i_orFields(out), ...
                {'depends_on(42).document_id', 'depends_on(42).value', 'depends_on(42).id'});
        end

        function test_negated_depends_on_key_is_and_of_negations(testCase)
            % De Morgan: no key matches = each key fails; fieldsearch ANDs
            % a struct array.
            ss = i_ss('depends_on.value', '~exact_string', 'x');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyNumElements(out, 3);
            testCase.verifyEqual({out.field}, ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
            testCase.verifyEqual(unique({out.operation}), {'~exact_string'});
        end

        function test_depends_on_unrelated_subfield_unchanged(testCase)
            % `depends_on.name` is not a target key.
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
            innerA = i_ss('depends_on.id', 'exact_string', 'a');
            innerB = i_ss('probe_location.ontology_name', 'exact_string', 'b');
            outer = struct('field', '', 'operation', 'or', ...
                'param1', innerA, 'param2', innerB);
            out = ndi.compat.translateQueryPaths(outer);
            testCase.verifyEqual(i_orFields(out.param1), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
            testCase.verifyEqual(out.param2.field, 'probe_location.ontology_name');
        end

        function test_nested_or_recurses_deeply(testCase)
            deepest = i_ss('depends_on.value', 'exact_string', 'x');
            mid = struct('field', '', 'operation', 'or', ...
                'param1', deepest, 'param2', i_ss('base.id', 'exact_string', 'y'));
            outer = struct('field', '', 'operation', 'or', ...
                'param1', mid, 'param2', i_ss('depends_on(2).id', 'exact_string', 'z'));
            out = ndi.compat.translateQueryPaths(outer);
            testCase.verifyEqual(i_orFields(out.param1.param1), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
            testCase.verifyEqual(i_orFields(out.param2), ...
                {'depends_on(2).document_id', 'depends_on(2).value', 'depends_on(2).id'});
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
            ss = struct('field', "depends_on.id", ...
                'operation', 'exact_string', 'param1', 'x', 'param2', '');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyEqual(i_orFields(out), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
        end

        function test_struct_array_each_entry_translated(testCase)
            ss(1) = i_ss('depends_on.id', 'exact_string', 'a');
            ss(2) = i_ss('treatment.ontologyName', 'exact_string', 'b');
            ss(3) = i_ss('base.id', 'exact_string', 'c');
            out = ndi.compat.translateQueryPaths(ss);
            testCase.verifyNumElements(out, 3);
            testCase.verifyEqual(i_orFields(out(1)), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
            testCase.verifyEqual(out(2).field, 'treatment.ontologyName');
            testCase.verifyEqual(out(3).field, 'base.id');
        end

        % ---- acceptance: ndi.query constructor wires in the translation ----

        function test_ndi_query_constructor_leaves_a_v1_path(testCase)
            q = ndi.query('probe_location.ontology_name', 'exact_string', ...
                'uberon:1234');
            testCase.verifyEqual(q.searchstructure.field, ...
                'probe_location.ontology_name');
            testCase.verifyEqual(q.searchstructure.param1, 'uberon:1234');
        end

        function test_ndi_query_constructor_expands_depends_on_id(testCase)
            q = ndi.query('depends_on.id', 'exact_string', ...
                'aabb1122ccdd3344_0011223344556677');
            testCase.verifyEqual(i_orFields(q.searchstructure), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
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
            q = ndi.query({'depends_on.id', 'X'});
            testCase.verifyEqual(i_orFields(q.searchstructure), ...
                {'depends_on.document_id', 'depends_on.value', 'depends_on.id'});
        end
    end
end

function s = i_ss(field, op, p1)
s = struct('field', field, 'operation', op, ...
    'param1', p1, 'param2', '');
end

function f = i_orFields(ss)
% the fields of an 'or' chain's leaves, left to right
f = {};
if strcmp(ss.operation, 'or')
    f = [i_orFields(ss.param1), i_orFields(ss.param2)];
else
    f = {char(ss.field)};
end
end

function leaf = i_orLeaf(ss, n)
% the Nth leaf of an 'or' chain
leaves = i_orLeaves(ss);
leaf = leaves{n};
end

function leaves = i_orLeaves(ss)
if strcmp(ss.operation, 'or')
    leaves = [i_orLeaves(ss.param1), i_orLeaves(ss.param2)];
else
    leaves = {ss};
end
end
