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
%   Every test needs did2.build (a source unit is a registered term, built
%   with did2.build.term); the last also builds the entries with
%   ndi.setup.V2.datasetMetadata, which needs a V2 schema.
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
            testCase.assumeTrue(~isempty(which('did2.build.term')), ...
                'did2.build (DID-matlab V2) is not on the path');
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
            testCase.verifyFalse(isfield(g.concentration, 'particles_per_liter'), ...
                'the measured CFU is an observation of the solution, not its plan (decision #129)');
            testCase.verifyEqual(g.concentration.source_value, 10, 'the plan: target OD600 10');
            testCase.verifyEqual(g.concentration.source_unit, ndi.setup.V2.sourceUnit('OD600'));
            testCase.verifyEqual(g.concentration.optical_density, 10, 'the optical_density canonical (OD600 by its source unit)');
            st = testCase.solution('suspension_op50_20230217');
            testCase.verifyEqual(st.kind, 'stock');
            testCase.verifyEqual(st.od, 10.1, 'the measured OD600 is the solution''s, not the plan''s');
            testCase.verifyEqual(st.cfu, 1117);
            d = testCase.entry('suspension_op50_20230217_od5');
            testCase.verifyNumElements(d.ingredients, 1);
            testCase.verifyEqual(d.ingredients{1}.ingredient, 'suspension_op50_20230217');
            testCase.verifyEqual(d.ingredients{1}.concentration.liters_per_liter, 0.5, 'AbsTol', 1e-12);
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
            testCase.verifyFalse(isfield(b.ingredients{1}.concentration, 'particles_per_liter'), ...
                'the plan holds no measured value (decision #129)');
            testCase.verifyEqual(testCase.solution('suspension_op50_20230327_b').cfu, 846, ...
                'the CFU is the solution''s, observed');
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
            testCase.verifyEqual(x.ingredients{1}.concentration.source_unit, ndi.setup.V2.sourceUnit('OD600'));
            testCase.verifyEqual(x.ingredients{1}.concentration.optical_density, 1, 'the nominal OD600');
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
            sp = getenv('DID_SCHEMA_PATH');
            testCase.assumeTrue(~isempty(sp) && isfile(fullfile(sp, 'entity.json')), ...
                'DID_SCHEMA_PATH does not hold a V2 schema with `entity` (did-schema #88)');
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
            % each solution an entity made to its plan (decision #114),
            % asserted as its composition, not dosed (decision #146)
            sd = ndi.setup.conv.haley.seedingDocuments(testCase.S, r.ids, sid);
            n = numel(testCase.S.solutions);
            testCase.verifyEqual([sd.counts.solutions, sd.counts.preparations], [n n]);
            leaf = cellfun(@ndi.v2.leafName, sd.documents, 'UniformOutput', false);
            testCase.verifyFalse(any(strcmp(leaf, 'dose_manipulation')), ...
                'a solution is not dosed (decision #146)');
            pa = sd.documents(strcmp(leaf, 'formulation_assertion'));
            testCase.verifyNumElements(pa, n, 'one composition assertion per solution');
            x = testCase.S.solutions(1);
            p1 = pa(cellfun(@(d) strcmp(edgeOf(d, 'entity_id'), sd.ids(x.key)), pa));
            testCase.verifyNumElements(p1, 1);
            testCase.verifyEqual(edgeOf(p1{1}, 'value_id'), r.ids(x.formulation), ...
                'its value is its formulation, through value_id');
            testCase.verifyEqual(p1{1}.statement.variable.node, 'PATO:0000025', 'composition');
            testCase.verifyEmpty(edgeOf(p1{1}, 'formulation_id'), 'no dose edge');
            testCase.verifyEmpty(edgeOf(p1{1}, 'time_reference_id'), ...
                'an assertion is timeless (decision #147)');
            e1 = sd.documents(cellfun(@(d) strcmp(d.base.id, sd.ids(x.key)), sd.documents));
            testCase.verifyNotEmpty(edgeOf(e1{1}, 'time_reference_id'), ...
                'the seeding day is on the solution entity (decision #147)');
            % each dilution derived_from its stock solution (decision #147)
            isDil = strcmp({testCase.S.solutions.kind}, 'dilution');
            testCase.verifyGreaterThan(sum(isDil), 0);
            testCase.verifyEqual(sd.counts.derivations, sum(isDil));
            rel = sd.documents(strcmp(leaf, 'directed_relation'));
            testCase.verifyNumElements(rel, sum(isDil));
            dx = testCase.S.solutions(find(isDil, 1));
            r1 = rel(cellfun(@(d) strcmp(edgeOf(d, 'child_id'), sd.ids(dx.key)), rel));
            testCase.verifyNumElements(r1, 1);
            testCase.verifyEqual(edgeOf(r1{1}, 'parent_id'), sd.ids([dx.stock '#solution']), ...
                'derived from its stock solution');
            testCase.verifyEqual(r1{1}.directed_relation.relation.node, 'RO:0001000');
            stocks = sum(strcmp({testCase.S.solutions.kind}, 'stock'));
            testCase.verifyEqual(sd.counts.od600_observations, stocks, 'one per measured stock');
            testCase.verifyEqual(sd.counts.days, numel(unique(dateshift([testCase.S.solutions.day], ...
                'start', 'day'))));
            % each measured stock with a CFU: a Cell Density observation by
            % viable cell count, in particles_per_liter (decision #129)
            withCfu = sum(strcmp({testCase.S.solutions.kind}, 'stock') & ~isnan([testCase.S.solutions.cfu]));
            testCase.verifyGreaterThan(withCfu, 0);
            testCase.verifyEqual(sd.counts.cfu_observations, withCfu, 'one per stock with a CFU');
            ob = sd.documents(strcmp(leaf, 'concentration_observation'));
            nodeOf = @(t) t.node;
            node = cellfun(@(d) nodeOf(ndi.v2.blockOf(d, 'statement', 'variable')), ob, ...
                'UniformOutput', false);
            cd = ob(strcmp(node, 'NCIT:C120538'));
            testCase.verifyNumElements(cd, withCfu);
            testCase.verifyEqual(nodeOf(ndi.v2.blockOf(cd{1}, 'interaction', 'method').term), ...
                'NCIT:C130166', 'Viable Cell Count');
            dep = cd{1}.depends_on;
            if iscell(dep), dep = [dep{:}]; end
            testCase.verifyFalse(any(strcmp({dep.name}, 'instrument_id') & ...
                ~cellfun(@isempty, {dep.document_id})), ...
                'the colonies were not counted with the spectrophotometer');
            c = ndi.v2.blockOf(cd{1}, 'concentration', 'value');
            if iscell(c), c = c{1}; end
            testCase.verifyEqual(c(1).source_unit, ndi.setup.V2.sourceUnit('CFU/mL'));
            testCase.verifyEqual(c(1).particles_per_liter, 1000 * c(1).source_value, 'RelTol', 1e-12, ...
                'per mL -> per L');
            od = ob(strcmp(node, 'MCO:0000059'));
            testCase.verifyEqual(nodeOf(ndi.v2.blockOf(od{1}, 'interaction', 'method').term), ...
                'NCIT:C85776', 'Optical Density Measurement (decision #129)');
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

function v = edgeOf(doc, name)
% the document id of DOC's first edge NAME ('' when it has none)
v = '';
if ~isfield(doc, 'depends_on') || isempty(doc.depends_on)
    return;
end
dep = doc.depends_on;
if iscell(dep), dep = [dep{:}]; end
for k = 1:numel(dep)
    if strcmp(dep(k).name, name)
        v = dep(k).document_id;
        return;
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
