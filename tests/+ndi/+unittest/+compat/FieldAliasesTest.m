classdef FieldAliasesTest < matlab.unittest.TestCase
%FIELDALIASESTEST Unit tests for ndi.compat.fieldAliases.

    methods (Test)
        function test_returns_struct_with_expected_tables(testCase)
            aliases = ndi.compat.fieldAliases();
            testCase.verifyTrue(isstruct(aliases));
            testCase.verifyTrue(isfield(aliases, 'fields'));
            testCase.verifyEqual(size(aliases.fields, 2), 3);
            % dependsOn was removed in #801: depends_on entry-key
            % compatibility now lives in ndi.document accessors +
            % ndi.compat.translateQueryPaths, not in this table.
            testCase.verifyFalse(isfield(aliases, 'dependsOn'));
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






        function test_fabricated_ontology_rows_are_absent(testCase)
            % The ontologyImage and ontologyLabel templates have only ever
            % carried `ontologyNode`. Rows claiming `ontology_name`,
            % `ontology_region`, `label_id` or `label` described documents
            % that do not exist and were removed. Guard against them coming
            % back -- the old tests asserted their PRESENCE, which is how the
            % fabrication survived review.
            aliases = ndi.compat.fieldAliases();
            for k = 1:size(aliases.fields, 1)
                legacyPath = aliases.fields{k, 2};
                if ~iscell(legacyPath); legacyPath = {legacyPath}; end
                for j = 1:numel(legacyPath)
                    testCase.verifyEmpty( ...
                        regexp(legacyPath{j}, '^ontology_(image|label)\.', 'once'), ...
                        sprintf('fabricated alias row reintroduced: %s', legacyPath{j}));
                end
            end
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
