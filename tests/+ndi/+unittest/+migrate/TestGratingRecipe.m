classdef TestGratingRecipe < matlab.unittest.TestCase
%TESTGRATINGRECIPE ndi.migrate.internal.gratingRecipe: one NewStim parameter
%   set -> the term and parameter entries of a `method` document (did-schema
%   #88). Pure struct mapping: no database, no schema.
%
%   Run with:  runtests('ndi.unittest.migrate.TestGratingRecipe')

    methods (Test)

        function testNewStimNamesMapToMethodParameters(testCase)
            r = ndi.migrate.internal.gratingRecipe(struct('imageType', 2, ...
                'angle', 45, 'sFrequency', 0.5, 'tFrequency', 2, 'contrast', 1));
            testCase.verifyEqual(r.term, 'drifting sinusoidal grating');
            testCase.verifyEqual(param(r, 'orientation'), 45);
            testCase.verifyEqual(unit(r, 'orientation'), 'degree');
            testCase.verifyEqual(param(r, 'spatial frequency'), 0.5);
            testCase.verifyEqual(unit(r, 'spatial frequency'), 'cycles per degree');
            testCase.verifyEqual(param(r, 'temporal frequency'), 2);
            testCase.verifyEqual(unit(r, 'temporal frequency'), 'hertz');
            testCase.verifyEqual(param(r, 'contrast'), 1);
            testCase.verifyEqual(param(r, 'waveform'), 'sinusoid');
        end

        function testImageType1IsASquareWave(testCase)
            r = ndi.migrate.internal.gratingRecipe(struct('imageType', 1, 'angle', 0));
            testCase.verifyEqual(r.term, 'drifting square-wave grating');
            testCase.verifyEqual(param(r, 'waveform'), 'square wave');
        end

        function testAnAbsentFieldIsLeftOutNotZero(testCase)
            % The deleted visual_grating value wrote 0 for every absent field,
            % which reads as a measurement.
            r = ndi.migrate.internal.gratingRecipe(struct('angle', 90));
            testCase.verifyEqual({r.parameters.variable}, {'orientation'});
            testCase.verifyEqual(r.term, 'drifting grating');
        end

        function testAStaticGratingKeepsItsZeroTemporalFrequency(testCase)
            r = ndi.migrate.internal.gratingRecipe(struct('angle', 90, 'tFrequency', 0));
            testCase.verifyEqual(param(r, 'temporal frequency'), 0);
        end

        function testABlankIsABlankScreenWithNoParameters(testCase)
            r = ndi.migrate.internal.gratingRecipe(struct('isblank', 1, 'angle', 0), 'blank');
            testCase.verifyEqual(r.term, 'blank screen');
            testCase.verifyEmpty(r.parameters);
        end

        function testSnakeCaseFallback(testCase)
            r = ndi.migrate.internal.gratingRecipe(struct('orientation', 135, ...
                'spatial_frequency', 0.4, 'temporal_frequency', 4));
            testCase.verifyEqual(param(r, 'orientation'), 135);
            testCase.verifyEqual(param(r, 'spatial frequency'), 0.4);
            testCase.verifyEqual(param(r, 'temporal frequency'), 4);
        end

        function testTwoEqualParameterSetsAreEqualRecipes(testCase)
            % the dedup the caller does is isequal on the recipe
            p = struct('imageType', 2, 'angle', 45, 'sFrequency', 0.04, 'nCycles', 1);
            q = p; q.nCycles = 64;   % a field the recipe does not carry
            testCase.verifyTrue(isequal(ndi.migrate.internal.gratingRecipe(p), ...
                ndi.migrate.internal.gratingRecipe(q)));
        end

    end
end

function v = param(r, name)
v = [];
k = find(strcmp({r.parameters.variable}, name), 1);
if ~isempty(k); v = r.parameters(k).value; end
end

function u = unit(r, name)
u = '';
k = find(strcmp({r.parameters.variable}, name), 1);
if ~isempty(k); u = r.parameters(k).unit; end
end
