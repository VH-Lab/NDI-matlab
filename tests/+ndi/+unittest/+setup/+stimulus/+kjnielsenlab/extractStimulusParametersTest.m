classdef extractStimulusParametersTest < matlab.unittest.TestCase
% extractStimulusParametersTest - Offline tests for
% ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters
%
%   Verifies that stimulus parameters are consolidated from analyzer.M,
%   analyzer.P.param and analyzer.loops.conds{i}, and that the display order
%   is built from the 'trialno' of each repeat.
%
%   The central case here is that 'trialno' gives the positions a repeat
%   occupied in the presentation sequence, and may hold several of them: a
%   condition shown more than once records all of its positions in one
%   repeat. Trial numbers are therefore unrelated to the number of repeats
%   stored, and may exceed it. Positions that no repeat claims are valid too,
%   and come back as NaN rather than as an error.
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

        function testRepeatMayClaimSeveralPositions(testCase)
            % Taken from a real analyzer file: 13 conditions, twelve of them
            % presented once each and one presented ten times at interleaved
            % positions. The ten positions are recorded in a single repeat as
            % a vector, which is the format's normal shape for a condition
            % shown more than once - not a malformed value. Together the two
            % sets cover positions 1 to 22 exactly once.
            scalarPositions = [15 1 3 6 10 12 13 14 16 17 20 22];
            blankPositions  = [2 4 5 7 8 9 11 18 19 21];

            condTrialNumbers = num2cell(scalarPositions);
            condTrialNumbers{end+1} = 1; % replaced with the vector below
            analyzer = buildAnalyzer(condTrialNumbers, 10*(0:12));
            analyzer.loops.conds{13}.repeats = { struct('trialno', blankPositions) };

            [parameters, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(numel(parameters), 13);
            testCase.verifyEqual(numel(displayOrder), 22);
            testCase.verifyFalse(any(isnan(displayOrder)), ...
                'Every position of the sequence should be accounted for.');
            testCase.verifyTrue(all(displayOrder(blankPositions) == 13), ...
                'Every position listed by the repeat should map to its condition.');
            for k = 1:numel(scalarPositions)
                testCase.verifyEqual(displayOrder(scalarPositions(k)), k);
            end
        end

        function testRepeatBlocksAndVectorsMixInOneFile(testCase)
            % 'repeats{r}' is the r-th repeat block and 'trialno' lists every
            % position within that block at which the condition appeared. A
            % condition normally appears once per block, giving one scalar per
            % block; one appearing several times within a block gives a vector.
            % Both shapes can occur in the same file, and conditions need not
            % share a repeat count.
            analyzer = buildAnalyzer({[1 4], [2 6], 1}, [0 90 180]);
            analyzer.loops.conds{3}.repeats = { struct('trialno', [3 5 7]) };

            [~, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);

            testCase.verifyEqual(displayOrder, [1 2 3 1 3 2 3]);
        end

        function testTrialNumberMatrixErrors(testCase)
            % A two-dimensional value is not a list of sequence positions.
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', [1 2; 3 4]);

            errorRaised = false;
            try
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer);
            catch ME
                errorRaised = true;
                testCase.verifyEqual(ME.identifier, 'extractStimulusParameters:invalidTrialNum');
                testCase.verifyTrue(contains(ME.message, '2x2 double'), ...
                    'The message should report the size and class of the value.');
            end
            testCase.verifyTrue(errorRaised, ...
                'Expected an error for a two-dimensional trial number.');
        end

        function testRepeatedPositionWithinOneRepeatErrors(testCase)
            % One repeat claiming the same position twice is ambiguous.
            analyzer = buildAnalyzer({1}, 0);
            analyzer.loops.conds{1}.repeats{1} = struct('trialno', [3 5 3]);

            testCase.verifyError( ...
                @() ndi.setup.stimulus.kjnielsenlab.extractStimulusParameters(analyzer), ...
                'extractStimulusParameters:duplicateTrial');
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
