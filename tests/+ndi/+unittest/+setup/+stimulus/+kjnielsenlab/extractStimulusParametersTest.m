classdef extractStimulusParametersTest < matlab.unittest.TestCase
% extractStimulusParametersTest - Offline tests for
% ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters
%
%   Verifies that stimulus parameters are consolidated from analyzer.M,
%   analyzer.P.param and analyzer.loops.conds{i}, and that the display order
%   is built from the 'trialno' of each repeat.
%
%   The central case here is a run whose repeats do not cover every position
%   of the stimulus sequence. 'trialno' is a trial's position in the
%   presentation sequence, so a run that was aborted before all planned
%   trials were presented stores fewer repeats than the sequence has
%   positions, and its trial numbers may exceed the number of repeats stored.
%   That is a valid file, not an error.
%
%   These tests run fully offline: the analyzer structures are built as plain
%   structs, with no ndi.session, database or data files needed.
%
%   Run with: results = runtests('ndi.unittest.setup.stimulus.kjnielsenlab.extractStimulusParametersTest');

    methods (Test)

        function testCompleteRunMapsEveryPosition(testCase)
            % Two conditions interleaved over a complete four-trial sequence.
            analyzer = buildAnalyzer({[1 3], [2 4]}, [0 90]);

            [parameters, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(displayOrder, [1 2 1 2]);
            testCase.verifyEqual(numel(parameters), 2);
        end

        function testTruncatedRunHasNoGaps(testCase)
            % A run stopped after three of a planned longer sequence: the
            % trials that ran occupy positions 1..3, so nothing is missing
            % within the recorded sequence and no warning is issued.
            analyzer = buildAnalyzer({[1 3], 2}, [0 90]);

            [~, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(displayOrder, [1 2 1]);
        end

        function testTrialNumberBeyondRepeatCountIsNotAnError(testCase)
            % Regression test. 13 repeats are stored but the highest recorded
            % position is 15. Deriving the sequence length from the number of
            % repeats made this raise 'invalid or out-of-range trial number';
            % the sequence length is the largest 'trialno' instead.
            testCase.applyFixture(matlab.unittest.fixtures.SuppressedWarningsFixture( ...
                'extractStimulusParameters:unassignedTrials'));

            analyzer = buildAnalyzer({15, 1:12}, [0 90]);

            [~, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(numel(displayOrder), 15);
            testCase.verifyEqual(displayOrder(15), 1);
            testCase.verifyTrue(all(displayOrder(1:12) == 2));
            testCase.verifyTrue(all(isnan(displayOrder(13:14))));
        end

        function testUnrecordedPositionsWarn(testCase)
            % Positions with no recorded trial are reported, not thrown.
            analyzer = buildAnalyzer({15, 1:12}, [0 90]);

            testCase.verifyWarning( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:unassignedTrials');
        end

        function testDuplicateTrialNumberErrors(testCase)
            % Two conditions claiming the same position is genuinely ambiguous.
            analyzer = buildAnalyzer({[1 2], 2}, [0 90]);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:duplicateTrial');
        end

        function testNonIntegerTrialNumberErrors(testCase)
            analyzer = buildAnalyzer({[1 2.5]}, 0);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:invalidTrialNum');
        end

        function testZeroTrialNumberErrors(testCase)
            % Positions are 1-based; 0 is not a valid position.
            analyzer = buildAnalyzer({[1 0]}, 0);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:invalidTrialNum');
        end

        function testNonFiniteTrialNumberErrors(testCase)
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', NaN);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:invalidTrialNum');
        end

        function testNonNumericTrialNumberErrors(testCase)
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', 'first');

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:invalidTrialNum');
        end

        function testMissingTrialNoFieldErrors(testCase)
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trial', 1);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:invalidRepeatStruct');
        end

        function testZeroTrialsReturnsEmptyDisplayOrder(testCase)
            % A condition list with no repeats at all is valid.
            analyzer = buildAnalyzer({[]}, 0);

            [parameters, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEmpty(displayOrder);
            testCase.verifyEqual(numel(parameters), 1);
        end

        function testParametersCombineAllSources(testCase)
            % Global (M), primary (P.param) and condition-specific (symbol/val)
            % values all land in the returned parameter struct.
            analyzer = buildAnalyzer({1, 2}, [0 90]);

            parameters = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(parameters{1}.screenDistance, 25);
            testCase.verifyEqual(parameters{1}.contrast, 1);
            testCase.verifyEqual(parameters{1}.sFrequency, 0.5);
            testCase.verifyEqual(parameters{1}.ori, 0);
            testCase.verifyEqual(parameters{2}.ori, 90);
        end

        function testEmptyTrialNumberIsSkipped(testCase)
            % A repeat whose trial was never presented records an empty
            % 'trialno'. It occupies no position in the sequence, so it is
            % skipped rather than treated as a bad value.
            analyzer = buildAnalyzer({[1 2], 3}, [0 90]);
            analyzer.loops.conds{2}.repeats{1} = struct('trialno', []);

            [~, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(displayOrder, [1 1]);
        end

        function testAllTrialNumbersEmptyGivesEmptyDisplayOrder(testCase)
            analyzer = buildAnalyzer({1, 2}, [0 90]);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', []);
            analyzer.loops.conds{2}.repeats{1} = struct('trialno', []);

            [parameters, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEmpty(displayOrder);
            testCase.verifyEqual(numel(parameters), 2);
        end

        function testNonScalarTrialNumberErrorDescribesTheValue(testCase)
            % A trial number holding several positions is genuinely ambiguous
            % and still errors, but the message must report the size and the
            % contents: reporting only the class hides what is wrong.
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', [15 16]);

            errorRaised = false;
            try
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, 'extractStimulusParameters:invalidTrialNum');
                testCase.verifyTrue(contains(ME.message, '1x2 double'), ...
                    'The message should report the size and class of the value.');
                testCase.verifyTrue(contains(ME.message, '[15 16]'), ...
                    'The message should report the contents of the value.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Expected an error for a non-scalar trial number.');
        end

    end

end

function analyzer = buildAnalyzer(condTrialNumbers, oriValues)
% buildAnalyzer - assemble a minimal analyzer structure for testing.
%
%   condTrialNumbers is a cell array with one entry per condition, each a
%   numeric vector of the sequence positions ('trialno') that condition
%   occupied. oriValues gives the 'ori' value of each condition.

    analyzer = struct();
    analyzer.M = struct('screenDistance', 25);

    analyzer.P = struct();
    analyzer.P.param = { {'contrast', 'float', 1}, {'sFrequency', 'float', 0.5} };

    conds = cell(1, numel(condTrialNumbers));
    for i = 1:numel(condTrialNumbers)
        trialNumbers = condTrialNumbers{i};
        repeats = cell(1, numel(trialNumbers));
        for j = 1:numel(trialNumbers)
            repeats{j} = struct('trialno', trialNumbers(j));
        end

        condData = struct();
        condData.symbol = {'ori'};
        condData.val = {oriValues(i)};
        condData.repeats = repeats;
        conds{i} = condData;
    end

    analyzer.loops = struct();
    analyzer.loops.conds = conds;
end
