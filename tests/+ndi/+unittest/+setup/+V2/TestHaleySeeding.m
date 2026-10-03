classdef TestHaleySeeding < matlab.unittest.TestCase
%TESTHALEYSEEDING Stage 8 part B of the Haley V2 import: the seeding suspensions.
%
%   Writes the seeding columns of three C. elegans studies and the E. coli
%   table (column names as in the real files) and checks
%   ndi.setup.conv.haley.seedingSuspensions against the real spec's `seeding`
%   and `corrections` (decisions #56, #57):
%     2023-02-17  Mini and Matching read identically: ONE solution, and since
%                 their diluents differ (LB, S-Complete) it lists none
%     2023-03-27  Matching (S-Complete, CFU corrected away) and Mini (LB) read
%                 differently: two solutions, _a and _b; Matching's
%                 acclimation plates use Mini's LB solution
%     Mutants     a growth seeding day with no solution is reported
%     E. coli     OP50-GFP in LB with carbenicillin; CFU corrected away; OD600
%                 0 is the diluent itself
%   The last test builds the entries with ndi.setup.V2.datasetMetadata (needs
%   did2.build and a V2 schema); the others need neither.
%
%   UNVERIFIED: written without MATLAB; test-import-v2.yml is the first run.

    properties
        Root
        Spec
        S
        Checks
    end

    methods (TestClassSetup)
        function fixture(testCase)
            testCase.Root = tempname;
            testCase.addTeardown(@() rmdir(testCase.Root, 's'));
            specFile = fullfile(fileparts(which('ndi.setup.conv.haley.import_V2')), ...
                'import_V2_spec.json');
            testCase.Spec = jsondecode(fileread(specFile));
            ce = fullfile(testCase.Root, 'haley', 'celegans');
            d1 = datetime(2023, 2, 17, 10, 0, 0);
            d2 = datetime(2023, 3, 27, 10, 0, 0);
            writeInfo(fullfile(ce, 'foragingMini'), [d1; d2], [10.1; 10.4], [1117; 846], ...
                [1; 0.5], [d1; d2] + hours(1), [1; 1]);
            writeInfo(fullfile(ce, 'foragingMatching'), [d1; d2], [10.1; 9.9375], [1117; 846], ...
                {[1 5]; [1 10]}, [d1; d2] + hours(2), [1; 1]);
            d3 = datetime(2023, 10, 30, 10, 0, 0);
            writeInfo(fullfile(ce, 'foragingMutants'), [d3; d3], [10.3125; 10.3125], [585; 585], ...
                [1; 1], [d3 - days(1); d3], [1; 1]);
            e = fullfile(testCase.Root, 'haley', 'ecoli');
            mkdir(e);
            d4 = datetime(2022, 4, 28, 10, 0, 0);
            info = table([d4; d4], [10.275; 10.275], [457; 457], [1; 0], ...
                'VariableNames', {'timeSeed', 'OD600Real', 'CFU', 'OD600'}); %#ok<NASGU>
            save(fullfile(e, 'bacteria.mat'), 'info');
            [testCase.S, testCase.Checks] = ndi.setup.conv.haley.seedingSuspensions( ...
                testCase.Root, testCase.Spec);
        end
    end

    methods (Test)
        function testSolutionsAndDilutions(testCase)
            keys = cellfun(@(x) x.key, testCase.S.entries, 'UniformOutput', false);
            testCase.verifyEqual(sort(keys), sort({ ...
                'suspension_op50_20230217', 'suspension_op50_20230217_od1', 'suspension_op50_20230217_od5', ...
                'suspension_op50_20230327_a', 'suspension_op50_20230327_a_od1', ...
                'suspension_op50_20230327_b', 'suspension_op50_20230327_b_od0p5', 'suspension_op50_20230327_b_od1', ...
                'suspension_op50_20231030', 'suspension_op50_20231030_od1', ...
                'suspension_op50gfp_20220428', 'suspension_op50gfp_20220428_od1'}));
            % each solution comes before its dilutions (they name it)
            for k = 1:numel(keys)
                if contains(keys{k}, '_od')
                    base = regexprep(keys{k}, '_od[0-9p]+$', '');
                    testCase.verifyLessThan(find(strcmp(keys, base)), k, keys{k});
                end
            end
        end

        function testASharedSolutionWithMixedDiluentsListsNone(testCase)
            x = testCase.entry('suspension_op50_20230217');
            testCase.verifyNumElements(x.ingredients, 1, 'Mini (LB) and Matching (S-Complete) shared it');
            g = x.ingredients{1};
            testCase.verifyEqual(g.ingredient, 'OP50');
            testCase.verifyEqual(g.concentration.particles_per_liter, 1117 * 2e10);
            testCase.verifyEqual(g.concentration.source_value, 10.1);
            testCase.verifyEqual(g.concentration.source_unit, 'OD600');
            d = testCase.entry('suspension_op50_20230217_od5');
            testCase.verifyNumElements(d.ingredients, 1);
            testCase.verifyEqual(d.ingredients{1}.ingredient, 'suspension_op50_20230217');
            testCase.verifyEqual(d.ingredients{1}.concentration.volume_fraction, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(d.ingredients{1}.concentration.source_value, 5);
        end

        function testCorrectedCfuAndDiluents(testCase)
            a = testCase.entry('suspension_op50_20230327_a');      % Matching
            testCase.verifyFalse(isfield(a.ingredients{1}.concentration, 'particles_per_liter'), ...
                'the S-Complete seeding of 2023-03-27 measured no CFU (correction)');
            testCase.verifyEqual(a.ingredients{1}.concentration.source_value, 9.9375);
            testCase.verifyEqual(a.ingredients{2}.ingredient, 's_complete');
            b = testCase.entry('suspension_op50_20230327_b');      % Mini
            testCase.verifyEqual(b.ingredients{1}.concentration.particles_per_liter, 846 * 2e10);
            testCase.verifyEqual(b.ingredients{2}.ingredient, 'lb');
            e = testCase.entry('suspension_op50gfp_20220428');
            testCase.verifyEqual(e.ingredients{1}.ingredient, 'OP50-GFP');
            testCase.verifyFalse(isfield(e.ingredients{1}.concentration, 'particles_per_liter'));
            testCase.verifyEqual(e.ingredients{2}.ingredient, 'lb_carb');
        end

        function testIndexPointsEachSeedingAtItsFormulation(testCase)
            I = testCase.S.index;
            at = @(folder, day, od, kind) I.key(strcmp(I.folder, folder) & I.day == day & ...
                I.od600 == od & strcmp(I.kind, kind));
            d2 = datetime(2023, 3, 27);
            testCase.verifyEqual(at('foragingMatching', d2, 10, 'assay'), {'suspension_op50_20230327_a'});
            testCase.verifyEqual(at('foragingMatching', d2, 1, 'growth'), {'suspension_op50_20230327_b_od1'}, ...
                'Matching''s acclimation plates use that day''s LB solution (Mini''s)');
            testCase.verifyEqual(at('foragingMini', d2, 1, 'growth'), {'suspension_op50_20230327_b_od1'});
            testCase.verifyEqual(at('ecoli', datetime(2022, 4, 28), 0, 'assay'), {'lb_carb'});
            testCase.verifyEqual(at('foragingMutants', datetime(2023, 10, 30), 1, 'growth'), ...
                {'suspension_op50_20231030_od1'});
        end

        function testChecks(testCase)
            c = testCase.Checks;
            testCase.verifyNumElements(c.growthWithoutSolution, 1);
            testCase.verifyTrue(contains(c.growthWithoutSolution{1}, 'foragingMutants 2023-10-29'));
            testCase.verifyEmpty(c.missingColumns);
            testCase.verifyEmpty(c.twoReadings);
            testCase.verifyEmpty(c.noReading);
        end

        function testTheEntriesBuild(testCase)
            testCase.assumeTrue(~isempty(which('did2.build.document')), ...
                'did2.build (DID-matlab V2) is not on the path');
            testCase.assumeTrue(ndi.setup.V2.schemaHasField('formulation', 'value'), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `formulation`');
            spec = testCase.Spec;
            f = spec.formulations;
            if isstruct(f), f = num2cell(f); end
            n0 = numel(f);
            spec.formulations = [reshape(f, 1, []), testCase.S.entries];
            r = ndi.setup.V2.datasetMetadata(spec, did.ido.unique_id());
            c = r.census;
            testCase.verifyEqual(sum(c.count(strcmp(c.class, 'formulation'))), ...
                n0 + numel(testCase.S.entries));
        end
    end

    methods
        function x = entry(testCase, key)
            k = find(cellfun(@(e) strcmp(e.key, key), testCase.S.entries));
            testCase.assertNumElements(k, 1, key);
            x = testCase.S.entries{k};
        end
    end
end

function writeInfo(folder, timeSeed, od, cfu, od600, growthTimeSeed, growthOD600)
mkdir(folder);
info = table(timeSeed, od, cfu, od600, growthTimeSeed, growthOD600, 'VariableNames', ...
    {'timeSeed', 'OD600Real', 'CFU', 'OD600', 'growthTimeSeed', 'growthOD600'}); %#ok<NASGU>
save(fullfile(folder, 'experimentInfo.mat'), 'info');
end
