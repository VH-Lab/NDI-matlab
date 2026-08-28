classdef extractStimulusParametersFromFileTest < matlab.unittest.TestCase
% extractStimulusParametersFromFileTest - Offline tests for
% ndi.setup.stimulus.kjnielsenlab.extractStimulusParametersFromFile
%
%   Verifies that a '.analyzer' file is loaded and decoded, and - the point of
%   the function - that any error raised on the way is re-thrown naming the
%   file, while keeping the original identifier and attaching the original
%   exception as a cause.
%
%   The analyzer files are written into a temporary folder by the tests
%   themselves, so no session, database or recorded data is needed.
%
%   Run with: results = runtests('ndi.unittest.setup.stimulus.kjnielsenlab.extractStimulusParametersFromFileTest');

    methods (Test)

        function testReadsAValidFile(testCase)
            analyzerFile = writeAnalyzerFile(testCase, 'good.analyzer', ...
                buildAnalyzer({[1 3], [2 4]}, [0 90]));

            [parameters, displayOrder] = ...
                ndi.setup.stimulus.kjnielsenlab.extractStimulusParametersFromFile(analyzerFile);

            testCase.verifyEqual(displayOrder, [1 2 1 2]);
            testCase.verifyEqual(numel(parameters), 2);
            testCase.verifyEqual(parameters{2}.ori, 90);
        end

        function testDecodingErrorNamesTheFile(testCase)
            % Two conditions claiming the same sequence position. The error
            % comes from extractStimulusParameters, which never sees a
            % filename, so the wrapper is what must supply it.
            analyzerFile = writeAnalyzerFile(testCase, 'duplicate.analyzer', ...
                buildAnalyzer({[1 2], 2}, [0 90]));

            thrown = captureError(testCase, analyzerFile);

            testCase.verifyEqual(thrown.identifier, 'extractStimulusParameters:duplicateTrial');
            verifyNamesFile(testCase, thrown, 'duplicate.analyzer');
            testCase.verifyNotEmpty(thrown.cause);
        end

        function testInvalidTrialNumberErrorNamesTheFile(testCase)
            analyzerFile = writeAnalyzerFile(testCase, 'badTrialNumber.analyzer', ...
                buildAnalyzer({[1 0]}, 0));

            thrown = captureError(testCase, analyzerFile);

            testCase.verifyEqual(thrown.identifier, 'extractStimulusParameters:invalidTrialNum');
            verifyNamesFile(testCase, thrown, 'badTrialNumber.analyzer');
        end

        function testMissingAnalyzerVariableNamesTheFile(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folderFixture = testCase.applyFixture(TemporaryFolderFixture);
            analyzerFile = fullfile(folderFixture.Folder, 'noAnalyzer.analyzer');
            somethingElse = 1; %#ok<NASGU>
            save(analyzerFile, 'somethingElse', '-mat');

            thrown = captureError(testCase, analyzerFile);

            testCase.verifyEqual(thrown.identifier, ...
                'extractStimulusParametersFromFile:missingAnalyzer');
            verifyNamesFile(testCase, thrown, 'noAnalyzer.analyzer');
        end

        function testUnreadableFileNamesTheFile(testCase)
            % A path that does not exist cannot be resolved on disk, so the
            % name the caller supplied is reported instead.
            import matlab.unittest.fixtures.TemporaryFolderFixture
            folderFixture = testCase.applyFixture(TemporaryFolderFixture);
            analyzerFile = fullfile(folderFixture.Folder, 'notThere.analyzer');

            thrown = captureError(testCase, analyzerFile);

            verifyNamesFile(testCase, thrown, 'notThere.analyzer');
        end

    end

end

function analyzerFile = writeAnalyzerFile(testCase, fileName, Analyzer) %#ok<INUSD>
% Writes ANALYZER into a temporary '.analyzer' file and returns its path.

    import matlab.unittest.fixtures.TemporaryFolderFixture
    folderFixture = testCase.applyFixture(TemporaryFolderFixture);
    analyzerFile = fullfile(folderFixture.Folder, fileName);
    save(analyzerFile, 'Analyzer', '-mat');
end

function thrown = captureError(testCase, analyzerFile)
% Calls the function under test and returns the exception it raised. The
% assertion is made after the try block so that its own failure is not caught
% here in place of the exception under test.

    thrown = MException('extractStimulusParametersFromFileTest:noErrorRaised', ...
                        'No error was raised.');
    errorRaised = false;
    try
        ndi.setup.stimulus.kjnielsenlab.extractStimulusParametersFromFile(analyzerFile);
    catch ME
        thrown = ME;
        errorRaised = true;
    end
    testCase.assertTrue(errorRaised, 'Expected an error, but none was raised.');
end

function verifyNamesFile(testCase, thrown, expectedFileName)
% Checks that the re-thrown message identifies the analyzer file. The name is
% compared rather than the whole path, because a temporary folder's path can
% be reported through a different but equivalent prefix.

    testCase.verifyTrue(contains(thrown.message, 'Analyzer file:'), ...
        'The error message should label the analyzer file.');
    testCase.verifyTrue(contains(thrown.message, expectedFileName), ...
        'The error message should name the analyzer file.');
end

function analyzer = buildAnalyzer(condTrialNumbers, oriValues)
% Assembles a minimal analyzer structure. condTrialNumbers holds one numeric
% vector per condition, giving the sequence positions that condition occupied.

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
