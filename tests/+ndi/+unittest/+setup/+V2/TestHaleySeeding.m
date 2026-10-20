classdef TestHaleySeeding < matlab.unittest.TestCase
%TESTHALEYSEEDING Stage 8 part B of the Haley V2 import: the seeding suspensions.
%
%   Writes the seeding columns of three C. elegans studies and the E. coli
%   table (column names as in the real files) and checks
%   ndi.setup.conv.haley.seedingSuspensions against the real spec's `seeding`
%   and `corrections` (decisions #56, #57; #111 the corrections, #114 each
%   solution an entity whose formulation is its plan):
%     2023-02-17  Mini and Matching read identically: ONE solution, and since
%                 their diluents differ (LB, S-Complete) it lists none; each
%                 study's OD600 0 patch is its own diluent (decision #94)
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
                {[1 0]; 0.5}, [d1; d2] + hours(1), [1; 1]);
            writeInfo(fullfile(ce, 'foragingMatching'), [d1; d2], [10.1; 9.9375], [1117; 846], ...
                {[0 1 5]; [1 10]}, [d1; d2] + hours(2), [1; 1]);
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
                'suspension_op50gfp_20220428', 'suspension_op50gfp_20220428_od1', ...
                'suspension_op50_20231029_od1'}), ...
                'an unmeasured day is named like any other (decision #114)');
            % each stock comes before its dilutions (they name it); an
            % unmeasured day has no stock (decision #82)
            sol = testCase.S.solutions;
            testCase.verifyEqual(sort({sol.formulation}), sort(keys), 'one solution per formulation');
            for k = find(strcmp({sol.kind}, 'dilution'))
                testCase.verifyLessThan(find(strcmp(keys, sol(k).stock)), ...
                    find(strcmp(keys, sol(k).formulation)), sol(k).formulation);
            end
        end

        function testASharedSolutionWithMixedDiluentsListsNone(testCase)
            x = testCase.entry('suspension_op50_20230217');
            testCase.verifyNumElements(x.ingredients, 1, 'Mini (LB) and Matching (S-Complete) shared it');
            g = x.ingredients{1};
            testCase.verifyEqual(g.ingredient, 'OP50');
            testCase.verifyEqual(g.concentration.particles_per_liter, 1117 * 2e10, ...
                'CFU stays on the plan until a term observes it (decision #114)');
            testCase.verifyEqual(g.concentration.source_value, 10, 'the plan: target OD600 10');
            testCase.verifyEqual(g.concentration.source_unit, 'OD600');
            if ndi.setup.V2.schemaHasField('concentration', 'value.od600')
                testCase.verifyEqual(g.concentration.od600, 10, 'the od600 canonical');
            else
                testCase.verifyFalse(isfield(g.concentration, 'od600'));
            end
            st = testCase.solution('suspension_op50_20230217');
            testCase.verifyEqual(st.kind, 'stock');
            testCase.verifyEqual(st.od, 10.1, 'the measured OD600 is the solution''s, not the plan''s');
            testCase.verifyEqual(st.cfu, 1117);
            d = testCase.entry('suspension_op50_20230217_od5');
            testCase.verifyNumElements(d.ingredients, 1);
            testCase.verifyEqual(d.ingredients{1}.ingredient, 'suspension_op50_20230217');
            testCase.verifyEqual(d.ingredients{1}.concentration.volume_fraction, 0.5, 'AbsTol', 1e-12);
            testCase.verifyEqual(d.ingredients{1}.concentration.source_value, 5);
            % the OD600 0 patches that day are each study's own diluent alone
            % (decision #94): Mini's LB, Matching's S-Complete
            I = testCase.S.index;
            day = datetime(2023, 2, 17);
            at = @(folder) I.key(strcmp(I.folder, folder) & I.day == day & I.od600 == 0 & strcmp(I.kind, 'assay'));
            testCase.verifyEqual(at('foragingMini'), {'lb'});
            testCase.verifyEqual(at('foragingMatching'), {'s_complete'});
        end

        function testCorrectedCfuAndDiluents(testCase)
            a = testCase.entry('suspension_op50_20230327_a');      % Matching
            testCase.verifyFalse(isfield(a.ingredients{1}.concentration, 'particles_per_liter'), ...
                'the S-Complete seeding of 2023-03-27 measured no CFU (correction)');
            testCase.verifyEqual(a.ingredients{1}.concentration.source_value, 10, 'the plan');
            testCase.verifyEqual(testCase.solution('suspension_op50_20230327_a').od, 9.9375, 'measured');
            testCase.verifyEqual(a.ingredients{2}.ingredient, 's_complete');
            % the applied correction travels with the solution (decision #111)
            testCase.verifySubstring(testCase.solution('suspension_op50_20230327_a').note, ...
                'Corrected from 846: The S-Complete seeding of 27 Mar 2023 measured no CFU');
            testCase.verifySubstring(testCase.solution('suspension_op50_20230327_a').note, ...
                '(correction cfu_matching_2023_03_27)');
            testCase.verifyEmpty(testCase.solution('suspension_op50_20230327_b').note);
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

        function testAGrowthDayWithNoReadingIsRecordedUnmeasured(testCase)
            % decision #82: Mutants 2023-10-29 seeded acclimation plates only;
            % #114: its plan alone, named like any other, no note, no measurement
            x = testCase.entry('suspension_op50_20231029_od1');
            sx = testCase.solution('suspension_op50_20231029_od1');
            testCase.verifyEqual(sx.kind, 'suspension');
            testCase.verifyTrue(isnan(sx.od) && isnan(sx.cfu), 'nothing was measured');
            testCase.verifyEmpty(sx.note);
            testCase.verifyEqual(x.ingredients{1}.ingredient, 'OP50');
            testCase.verifyEqual(x.ingredients{1}.concentration.source_value, 1);
            testCase.verifyEqual(x.ingredients{1}.concentration.source_unit, 'OD600');
            if ndi.setup.V2.schemaHasField('concentration', 'value.od600')
                testCase.verifyEqual(x.ingredients{1}.concentration.od600, 1, 'the nominal OD600');
            end
            testCase.verifyFalse(isfield(x.ingredients{1}.concentration, 'particles_per_liter'), ...
                'no CFU was measured');
            I = testCase.S.index;
            r = strcmp(I.folder, 'foragingMutants') & I.day == datetime(2023, 10, 29) & ...
                strcmp(I.kind, 'growth');
            testCase.verifyEqual(I.key(r), {'suspension_op50_20231029_od1'});
            testCase.verifyEmpty(I.note{r}, 'the source says nothing about it (T14)');
        end

        function testChecks(testCase)
            c = testCase.Checks;
            testCase.verifyNumElements(c.growthWithoutSolution, 1);
            testCase.verifyTrue(contains(c.growthWithoutSolution{1}, 'foragingMutants 2023-10-29'));
            testCase.verifyEmpty(c.missingColumns);
            testCase.verifyEmpty(c.twoReadings);
            testCase.verifyEmpty(c.noReading);
            % the two CFU corrections still read their `was` (decision #111)
            testCase.verifyNumElements(c.corrected, 2, strjoin(c.corrected, newline));
            testCase.verifyEmpty(c.correctionNotApplied);
        end

        function testACorrectionWhoseSourceChangedIsRefused(testCase)
            % decision #111: applied only while the source still reads `was`
            spec = testCase.Spec;
            c = spec.corrections;
            if isstruct(c), c = num2cell(c); end
            for k = 1:numel(c)
                if strcmp(c{k}.key, 'cfu_matching_2023_03_27')
                    c{k}.was = 999;
                end
            end
            spec.corrections = c;
            [S, checks] = ndi.setup.conv.haley.seedingSuspensions(testCase.Root, spec);
            testCase.verifyNumElements(checks.correctionNotApplied, 1);
            testCase.verifySubstring(checks.correctionNotApplied{1}, ...
                'cfu_matching_2023_03_27: foragingMatching seeding day 2023-03-27 CFU reads "846", not "999"');
            testCase.verifyNumElements(checks.corrected, 1, 'the E. coli one still applies');
            k = find(strcmp({S.solutions.formulation}, 'suspension_op50_20230327_a'));
            testCase.assertNumElements(k, 1);
            testCase.verifyEqual(S.solutions(k).cfu, 846, 'left as the source has it');
            testCase.verifyEmpty(S.solutions(k).note, 'a refused correction leaves no note');
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
            sid = did.ido.unique_id();
            r = ndi.setup.V2.datasetMetadata(spec, sid);
            c = r.census;
            testCase.verifyEqual(sum(c.count(strcmp(c.class, 'formulation'))), ...
                n0 + numel(testCase.S.entries));
            % each solution an entity made to its plan (decision #114)
            names = containers.Map();       % a strain key -> its term (as import_V2's namesOf)
            st = spec.strains;
            if isstruct(st), st = num2cell(st); end
            for k = 1:numel(st)
                node = '';
                if isfield(st{k}, 'node') && ~isempty(st{k}.node), node = char(st{k}.node); end
                names(st{k}.key) = did2.build.term(node, char(st{k}.name));
            end
            sd = ndi.setup.conv.haley.seedingDocuments(testCase.S, r.ids, sid, 'Names', names);
            n = numel(testCase.S.solutions);
            testCase.verifyEqual([sd.counts.solutions, sd.counts.preparations], [n n]);
            stocks = sum(strcmp({testCase.S.solutions.kind}, 'stock'));
            if ndi.setup.V2.schemaHasLeaf('concentration_observation')
                testCase.verifyEqual(sd.counts.od600_observations, stocks, 'one per measured stock');
            end
            testCase.verifyEqual(sd.counts.days, numel(unique(dateshift([testCase.S.solutions.day], ...
                'start', 'day'))));
            testCase.verifyTrue(any(contains(sd.skipped, 'colony-forming-unit')), ...
                'the CFU is reported, not observed');
        end
    end

    methods
        function x = solution(testCase, key)
            arguments
                testCase (1,1) ndi.unittest.setup.V2.TestHaleySeeding
                key {mustBeText}
            end
            k = find(strcmp({testCase.S.solutions.formulation}, key));
            testCase.assertNumElements(k, 1, key);
            x = testCase.S.solutions(k);
        end

        function x = entry(testCase, key)
            arguments
                testCase (1,1) ndi.unittest.setup.V2.TestHaleySeeding
                key {mustBeText}
            end
            k = find(cellfun(@(e) strcmp(e.key, key), testCase.S.entries));
            testCase.assertNumElements(k, 1, key);
            x = testCase.S.entries{k};
        end
    end
end

function writeInfo(folder, timeSeed, od, cfu, od600, growthTimeSeed, growthOD600)
arguments
    folder {mustBeText}
    timeSeed
    od
    cfu
    od600
    growthTimeSeed
    growthOD600
end
mkdir(folder);
info = table(timeSeed, od, cfu, od600, growthTimeSeed, growthOD600, 'VariableNames', ...
    {'timeSeed', 'OD600Real', 'CFU', 'OD600', 'growthTimeSeed', 'growthOD600'}); %#ok<NASGU>
save(fullfile(folder, 'experimentInfo.mat'), 'info');
end
