classdef whatVariesTest < matlab.unittest.TestCase
% whatVariesTest - Offline tests for ndi.fun.stimulus.whatVaries / whatIsConstant
%
%   Verifies that ndi.fun.stimulus.whatVaries correctly separates the stimulus
%   parameters that vary across a set of stimuli from those that are held
%   constant, across every accepted input shape (struct array of stimuli,
%   cell array of parameter structs, struct array of parameter structs, and a
%   document_properties-shaped struct). Also checks ndi.fun.stimulus.whatIsConstant.
%
%   These tests run fully offline (no ndi.session / database needed): the
%   stimuli are built as plain structs. They do require the vlt toolbox on the
%   path, since ndi.fun.stimulus.whatVaries uses vlt.data.structwhatvaries.
%
%   Run with: results = runtests('ndi.unittest.fun.stimulus.whatVariesTest');

    methods (Static, Access = private)
        function s = threeAngleStimuli()
            % a stimulus_presentation.stimuli-shaped struct array: angle varies,
            % contrast and sFrequency constant
            s(1).parameters = struct('angle',0,  'contrast',1,'sFrequency',0.5);
            s(2).parameters = struct('angle',90, 'contrast',1,'sFrequency',0.5);
            s(3).parameters = struct('angle',180,'contrast',1,'sFrequency',0.5);
        end
    end

    methods (Test)

        function testStimuliStructArray(testCase)
            s = ndi.unittest.fun.stimulus.whatVariesTest.threeAngleStimuli();
            [varies, constant] = ndi.fun.stimulus.whatVaries(s);

            testCase.verifyEqual(numel(varies), 1);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90 180]);

            testCase.verifyEqual({constant.parameter}, {'contrast','sFrequency'});
            testCase.verifyEqual([constant.value], [1 0.5]);
        end

        function testValuesSortedAndUnique(testCase)
            % out-of-order, with a repeat: values come back sorted and deduped
            s(1).parameters = struct('angle',180,'contrast',1);
            s(2).parameters = struct('angle',0,  'contrast',1);
            s(3).parameters = struct('angle',90, 'contrast',1);
            s(4).parameters = struct('angle',0,  'contrast',1);
            varies = ndi.fun.stimulus.whatVaries(s);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90 180]);
        end

        function testCellOfParameterStructs(testCase)
            p = { struct('angle',0,'contrast',1), ...
                  struct('angle',90,'contrast',1) };
            [varies, constant] = ndi.fun.stimulus.whatVaries(p);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90]);
            testCase.verifyEqual(constant.parameter, 'contrast');
            testCase.verifyEqual(constant.value, 1);
        end

        function testStructArrayOfParameterStructs(testCase)
            % parameter structs directly (no 'parameters' wrapper field)
            p(1) = struct('angle',0,'contrast',1);
            p(2) = struct('angle',90,'contrast',1);
            [varies, constant] = ndi.fun.stimulus.whatVaries(p);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90]);
            testCase.verifyEqual(constant.parameter, 'contrast');
        end

        function testDocumentPropertiesShapedStruct(testCase)
            s = ndi.unittest.fun.stimulus.whatVariesTest.threeAngleStimuli();
            dp.stimulus_presentation.stimuli = s;
            [varies, constant] = ndi.fun.stimulus.whatVaries(dp);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90 180]);
            testCase.verifyEqual({constant.parameter}, {'contrast','sFrequency'});
        end

        function testPoolingAcrossPresentations(testCase)
            % a struct array of document_properties-shaped structs is pooled
            s1 = ndi.unittest.fun.stimulus.whatVariesTest.threeAngleStimuli();
            s2(1).parameters = struct('angle',270,'contrast',1,'sFrequency',0.5);
            dp(1).stimulus_presentation.stimuli = s1;
            dp(2).stimulus_presentation.stimuli = s2;
            [varies, constant] = ndi.fun.stimulus.whatVaries(dp);
            testCase.verifyEqual(varies.parameter, 'angle');
            testCase.verifyEqual(varies.values, [0 90 180 270]);
            testCase.verifyEqual({constant.parameter}, {'contrast','sFrequency'});
        end

        function testFieldPresentInSomeStimuli(testCase)
            % a parameter present in some stimuli but not all is "varying"
            p(1) = struct('angle',0,'contrast',1);
            p(2).angle = 0; p(2).contrast = 1; p(2).isblank = 1;
            [varies, constant] = ndi.fun.stimulus.whatVaries(p);
            testCase.verifyEqual(varies.parameter, 'isblank');
            testCase.verifyEqual(varies.values, 1);
            testCase.verifyEqual({constant.parameter}, {'angle','contrast'});
        end

        function testNonNumericValuesReturnedAsCell(testCase)
            p(1) = struct('shape','circle','size',5);
            p(2) = struct('shape','square','size',5);
            [varies, constant] = ndi.fun.stimulus.whatVaries(p);
            testCase.verifyEqual(varies.parameter, 'shape');
            testCase.verifyEqual(varies.values, {'circle','square'});
            testCase.verifyEqual(constant.parameter, 'size');
            testCase.verifyEqual(constant.value, 5);
        end

        function testAllConstantSingleStimulus(testCase)
            p = struct('angle',0,'contrast',1);
            [varies, constant] = ndi.fun.stimulus.whatVaries(p);
            testCase.verifyEmpty(varies);
            testCase.verifyEqual({constant.parameter}, {'angle','contrast'});
            testCase.verifyEqual([constant.value], [0 1]);
        end

        function testEmptyInput(testCase)
            [varies, constant] = ndi.fun.stimulus.whatVaries({});
            testCase.verifyEmpty(varies);
            testCase.verifyEmpty(constant);
            % the empty results still carry the documented fields
            testCase.verifyTrue(all(isfield(varies, {'parameter','values'})));
            testCase.verifyTrue(all(isfield(constant, {'parameter','value'})));
        end

        function testWhatIsConstantMatchesSecondOutput(testCase)
            s = ndi.unittest.fun.stimulus.whatVariesTest.threeAngleStimuli();
            [~, constant] = ndi.fun.stimulus.whatVaries(s);
            constant2 = ndi.fun.stimulus.whatIsConstant(s);
            testCase.verifyEqual(constant2, constant);
        end

        function testBadInputErrors(testCase)
            testCase.verifyError(@() ndi.fun.stimulus.whatVaries(42), ...
                'ndi:fun:stimulus:whatVaries_parameterList:badInput');
            testCase.verifyError(@() ndi.fun.stimulus.whatVaries({42}), ...
                'ndi:fun:stimulus:whatVaries_parameterList:badCellEntry');
        end

    end % methods (Test)

end % classdef
