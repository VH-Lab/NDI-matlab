classdef TestStimulusRecipe < matlab.unittest.TestCase
%TESTSTIMULUSRECIPE ndi.migrate.internal.stimulusRecipe: one NewStim
%   parameter set of any recognised kind -> the {term, parameters} recipe of a
%   `method` document. Pure (no did2, no schema, no database).
%
%   Decided by Jess Haley, 2026-10-21 [non-grating stimuli as methods]
%   (did-schema V_eta_method_plan.md): a visual stimulus that is not a grating
%   migrates the same way as a grating -- its term naming the kind, every v1
%   parameter an entry, a parameter with no ontology term taking a label.
%
%   The parameter sets are the Dab / B corpus key sets (census of the corpus
%   zips, 2026-10-21), values transcribed from real documents
%   (412690002a5a4f00_c0d24bd3bf80db54, 4126900a24601cb3_40b1ac1ec3fe452c,
%   4126900d2c0ac1aa_4086d4d285fadbce, 4126900ae617f6a5_40dec51cb9f7a5ca),
%   randState elided to three entries.

    methods (Test)

        function testDenseNoiseCarriesEveryParameter(testCase)
            r = ndi.migrate.internal.stimulusRecipe(noise(), 'stochasticgridstim');
            testCase.verifyEqual(r.term, 'dense noise');
            vars = variables(r);
            for v = {'stimulus rectangle', 'background colour', 'grid square size', ...
                    'frame count', 'frame rate', 'Random Seed', 'colour palette', ...
                    'colour weights', 'grid rotation', 'background duration before stimulus', ...
                    'background duration after stimulus', 'bit depth'}
                testCase.verifyTrue(any(strcmp(vars, v{1})), ['missing ' v{1}]);
            end
            testCase.verifyFalse(any(strcmp(vars, 'isblank')), 'isblank is the kind, not an entry');
            e = entryOf(r, 'Random Seed');
            testCase.verifyEqual(e.form, 'matrix');
            testCase.verifyEqual(e.variable.node, 'NCIT:C64220');
            testCase.verifyEqual(size(e.value), [3 1]);
            e = entryOf(r, 'colour palette');
            testCase.verifyEqual(e.value, [0 0 0; 255 255 255]);
            testCase.verifyEqual(e.unit.node, 'NCIT:C75765');
            e = entryOf(r, 'background colour');
            testCase.verifyEqual(size(e.value), [1 3], 'a flat vector is written as a row');
            e = entryOf(r, 'frame count');
            testCase.verifyEqual(e.form, 'count');
            e = entryOf(r, 'bit depth');
            testCase.verifyEqual([e.value, double(strcmp(e.form, 'count'))], [8 1]);
            e = entryOf(r, 'frame rate');
            testCase.verifyEqual(e.unit.node, 'om:hertz');
        end

        function testAFractionalPixSizeTakesNoPixelUnit(testCase)
            p = noise();
            p.pixSize = [0.1 0.1];
            r = ndi.migrate.internal.stimulusRecipe(p, 'stochasticgridstim');
            e = entryOf(r, 'grid square size (fraction of the rectangle)');
            testCase.verifyNotEmpty(e);
            testCase.verifyEmpty(e.unit);
        end

        function testSparseNoiseIsBlinkingstimWithRandomOrder(testCase)
            r = ndi.migrate.internal.stimulusRecipe(blinking(1), 'blinkingstim');
            testCase.verifyEqual(r.term, 'sparse noise');
            testCase.verifyEqual(entryOf(r, 'square colour').value, [255 255 255]);
            testCase.verifyEqual(entryOf(r, 'repetitions').value, 30);
            testCase.verifyEqual(entryOf(r, 'background pause').unit.node, 'EMPTY:0000260');
            testCase.verifyEqual(entryOf(r, 'grid square size').value, [40 40]);
            r0 = ndi.migrate.internal.stimulusRecipe(blinking(0), 'blinkingstim');
            testCase.verifyEqual(r0.term, 'sequential grid flash');
        end

        function testANegativeFpsPutsBgpauseInSeconds(testCase)
            p = blinking(1);
            p.fps = -1;
            r = ndi.migrate.internal.stimulusRecipe(p, 'blinkingstim');
            testCase.verifyEqual(entryOf(r, 'background pause').unit.node, 'om:second-Time');
        end

        function testShapeMovieKeepsItsLabel(testCase)
            r = ndi.migrate.internal.stimulusRecipe(shape('disparity', -40), 'shapemoviestim');
            testCase.verifyEqual(r.term, 'shape movie');
            testCase.verifyEqual(entryOf(r, 'disparity').value, -40);
            testCase.verifyEqual(entryOf(r, 'inter-stimulus interval').unit.node, 'om:second-Time');
            testCase.verifyEqual(entryOf(r, 'frame count').value, 160);
            testCase.verifyEmpty(entryOf(r, 'angle'));
            testCase.verifyEmpty(entryOf(r, 'background duration after stimulus'), ...
                'an empty dispprefs writes nothing');
            a = ndi.migrate.internal.stimulusRecipe(shape('angle', 22.5), 'shapemoviestim');
            testCase.verifyEqual(entryOf(a, 'angle').value, 22.5);
            testCase.verifyFalse(isequal(a, r));
        end

        function testUniformFieldBarCarriesEveryPeriodicParameter(testCase)
            r = ndi.migrate.internal.stimulusRecipe(bar(), 'periodicstim_bars');
            testCase.verifyEqual(r.term, 'uniform luminance field');
            testCase.verifyEqual(entryOf(r, 'image type').value, 0);
            testCase.verifyEqual(entryOf(r, 'orientation').value, 180);
            testCase.verifyEqual(entryOf(r, 'line offset').value, -196);
            testCase.verifyEqual(entryOf(r, 'line number').value, 1);
            testCase.verifyEqual(entryOf(r, 'high colour').value, [255 255 255]);
            testCase.verifyEqual(entryOf(r, 'stimulus rectangle').value, [20 108 820 115]);
            % 22 fields + 2 extras - dispprefs (1 pair) + 1 bit depth
            testCase.verifyEqual(numel(r.parameters), 24 - 1 + 1 + 1);
        end

        function testAnUnmappedFieldIsStillAnEntryUnderItsV1Name(testCase)
            p = shape('angle', 0);
            p.xposition = 400;
            p.note = 'left eye';
            r = ndi.migrate.internal.stimulusRecipe(p, 'shapemoviestim');
            testCase.verifyEqual(entryOf(r, 'xposition').value, 400);
            testCase.verifyEqual(entryOf(r, 'note').form, 'text');
        end

        function testGratingAndBlankAreGratingRecipeUnchanged(testCase)
            g = struct('imageType', 2, 'angle', 90, 'sFrequency', 0.1, ...
                'tFrequency', 4, 'contrast', 1);
            testCase.verifyEqual(ndi.migrate.internal.stimulusRecipe(g, 'grating'), ...
                ndi.migrate.internal.gratingRecipe(g, 'grating'));
            b = struct('isblank', 1);
            testCase.verifyEqual(ndi.migrate.internal.stimulusRecipe(b, 'blank').term, ...
                'blank screen');
        end

        function testAKindWithNoRecipeIsAnError(testCase)
            testCase.verifyError(@() ndi.migrate.internal.stimulusRecipe( ...
                struct('M', 200), 'hartleystim'), 'ndi:migrate:stimulusRecipe:kind');
        end
    end
end

% ===================== fixtures ===========================================

function p = noise()
p = struct('BG', [128; 128; 128], 'N', 100, 'angle', 0, ...
    'dispprefs', {{'BGpretime'; 0; 'BGposttime'; 3}}, ...
    'dist', [1; 1], 'fps', 15, 'pixSize', [50; 50], ...
    'randState', [0.83; 0.67; 0.08], 'rect', [0; 0; 800; 600], ...
    'values', [0 0 0; 255 255 255], 'isblank', 0);
end

function p = blinking(random)
p = struct('BG', [128; 128; 128], 'value', [255; 255; 255], 'random', random, ...
    'repeat', 30, 'bgpause', 0, 'fps', 10, 'rect', [223; 109; 623; 509], ...
    'pixSize', [40; 40], 'randState', [0.04; 0.13; 0.47], 'dispprefs', []);
end

function p = shape(labelName, labelValue)
p = struct('rect', [0; 0; 800; 600], 'BG', [0; 0; 0], 'scale', 1, 'fps', 100, ...
    'N', 160, 'isi', 0.01, 'dispprefs', []);
p.(labelName) = labelValue;
end

function p = bar()
p = struct('imageType', 0, 'animType', 0, 'flickerType', 0, 'angle', 180, ...
    'chromhigh', [255; 255; 255], 'chromlow', [0; 0; 0], 'sFrequency', 1, ...
    'sPhaseShift', 0, 'distance', 57, 'tFrequency', 10, 'barWidth', 0.5, ...
    'rect', [20; 108; 820; 115], 'nCycles', 1, 'contrast', 1, 'background', 0.5, ...
    'backdrop', 0.5, 'barColor', 1, 'nSmoothPixels', 2, 'fixedDur', 0, ...
    'windowShape', 2, 'loops', 0, 'dispprefs', {{'BGposttime'; 0}}, ...
    'lineoffset', -196, 'linenumber', 1);
end

function v = variables(r)
v = arrayfun(@(e) nameOf(e.variable), r.parameters, 'UniformOutput', false);
end

function e = entryOf(r, name)
e = [];
for k = 1:numel(r.parameters)
    if strcmp(nameOf(r.parameters(k).variable), name)
        e = r.parameters(k);
        return;
    end
end
end

function n = nameOf(v)
if isstruct(v); n = v.name; else; n = v; end
end
