classdef FieldAliasesTest < matlab.unittest.TestCase
%FIELDALIASESTEST Unit tests for ndi.compat.fieldAliases.

    methods (Test)
        function test_returns_struct_with_expected_tables(testCase)
            aliases = ndi.compat.fieldAliases();
            testCase.verifyTrue(isstruct(aliases));
            testCase.verifyTrue(isfield(aliases, 'fields'));
            testCase.verifyTrue(isfield(aliases, 'dependsOn'));
            testCase.verifyEqual(size(aliases.fields, 2), 3);
            testCase.verifyEqual(size(aliases.dependsOn, 2), 3);
        end

        function test_probe_location_rows_present_and_identity(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'probe_location.location.node');
            testCase.verifyEqual(row{2}, 'probe_location.ontology_name');
            testCase.verifyTrue(isempty(row{3}));

            row = i_findRow(aliases.fields, 'probe_location.location.name');
            testCase.verifyEqual(row{2}, 'probe_location.name');
            testCase.verifyTrue(isempty(row{3}));
        end

        function test_treatment_rows_present_and_identity(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'treatment.treatment_name.node');
            testCase.verifyEqual(row{2}, 'treatment.ontology_name');
            testCase.verifyTrue(isempty(row{3}));

            row = i_findRow(aliases.fields, 'treatment.treatment_name.name');
            testCase.verifyEqual(row{2}, 'treatment.name');
            testCase.verifyTrue(isempty(row{3}));
        end

        function test_ontology_image_rows_present_and_identity(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'ontology_image.region.node');
            testCase.verifyEqual(row{2}, 'ontology_image.ontology_name');
            testCase.verifyTrue(isempty(row{3}));

            row = i_findRow(aliases.fields, 'ontology_image.region.name');
            testCase.verifyEqual(row{2}, 'ontology_image.ontology_region');
            testCase.verifyTrue(isempty(row{3}));
        end

        function test_ontology_label_name_row_identity(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'ontology_label.term.name');
            testCase.verifyEqual(row{2}, 'ontology_label.label');
            testCase.verifyTrue(isempty(row{3}));
        end

        function test_ontology_label_node_is_composite(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'ontology_label.term.node');
            legacyPath = row{2};
            transform  = row{3};

            testCase.verifyTrue(iscellstr(legacyPath)); %#ok<ISCLSTR>
            testCase.verifyEqual(numel(legacyPath), 2);
            testCase.verifyEqual(legacyPath{1}, 'ontology_label.ontology_name');
            testCase.verifyEqual(legacyPath{2}, 'ontology_label.label_id');

            testCase.verifyTrue(iscell(transform));
            testCase.verifyEqual(numel(transform), 2);
            testCase.verifyTrue(isa(transform{1}, 'function_handle'));
            testCase.verifyTrue(isa(transform{2}, 'function_handle'));
        end

        function test_ontology_label_node_compose_roundtrip(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'ontology_label.term.node');
            toVDelta = row{3}{1};
            toLegacy = row{3}{2};

            node = toVDelta({'allen_ccf_v3', 12345});
            testCase.verifyEqual(node, 'allen_ccf_v3:12345');

            parts = toLegacy('allen_ccf_v3:12345');
            testCase.verifyEqual(parts{1}, 'allen_ccf_v3');
            testCase.verifyEqual(parts{2}, 12345);
        end

        function test_ontology_label_node_empty_inputs(testCase)
            aliases = ndi.compat.fieldAliases();
            row = i_findRow(aliases.fields, 'ontology_label.term.node');
            toVDelta = row{3}{1};
            toLegacy = row{3}{2};

            testCase.verifyEqual(toVDelta({'', 0}), '');

            parts = toLegacy('');
            testCase.verifyEqual(parts{1}, '');
            testCase.verifyEqual(parts{2}, 0);
        end

        function test_depends_on_value_id_rename(testCase)
            aliases = ndi.compat.fieldAliases();
            testCase.verifyEqual(size(aliases.dependsOn, 1), 1);
            testCase.verifyEqual(aliases.dependsOn{1, 1}, 'value');
            testCase.verifyEqual(aliases.dependsOn{1, 2}, 'id');
            testCase.verifyTrue(isempty(aliases.dependsOn{1, 3}));
        end
    end
end

function row = i_findRow(table, vDeltaPath)
    idx = find(strcmp(table(:, 1), vDeltaPath));
    assert(numel(idx) == 1, ...
        'Expected exactly one row for vDeltaPath "%s", found %d.', ...
        vDeltaPath, numel(idx));
    row = table(idx, :);
end
