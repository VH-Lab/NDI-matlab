classdef WaitForDocumentCountMockTest < matlab.unittest.TestCase
% WAITFORDOCUMENTCOUNTMOCKTEST - the document-count wait, against mocks.
%
% A working server ingests a small upload in seconds, so the live cloud
% tests only show the happy path. The cases that matter are the ones it
% will not produce on demand: a count that lags for several polls, one
% that never arrives, and a transient API error that a naive loop would
% treat as the end of the wait.
%
% Runs entirely through the pollCount seam against ndi.test.helper.
% ScriptedDocumentCount.

    methods (Test)

        function testCountAlreadyReachedReturnsAtOnce(testCase)
            polls = { struct('ok', true, 'count', 5) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.state, 'complete');
            testCase.verifyEqual(answer.count, 5);
            testCase.verifyEqual(answer.expectedCount, 5);
            testCase.verifyEqual(call.callCount, 1);
        end

        function testCountAboveTargetIsSuccess(testCase)
            % Another upload may have landed meanwhile; the target is a floor.
            polls = { struct('ok', true, 'count', 7) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.count, 7);
        end

        function testLaggingCountIsPolledUntilItArrives(testCase)
            polls = { struct('ok', true, 'count', 0), ...
                      struct('ok', true, 'count', 3), ...
                      struct('ok', true, 'count', 5) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.state, 'complete');
            testCase.verifyEqual(call.callCount, 3);
        end

        function testCountThatNeverArrivesTimesOut(testCase)
            polls = { struct('ok', true, 'count', 4) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 0.05, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyEqual(answer.count, 4, ...
                'the timeout should report the last count seen');
            testCase.verifyGreaterThanOrEqual(answer.elapsed, 0.05);
        end

        function testAnApiErrorIsRetriedNotFatal(testCase)
            polls = { struct('ok', false, 'count', struct('message', 'gateway')), ...
                      struct('ok', true, 'count', 5) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.count, 5);
            testCase.verifyEqual(call.callCount, 2);
        end

        function testOnlyApiErrorsTimeOutWithNoCount(testCase)
            polls = { struct('ok', false, 'count', struct('message', 'gateway')) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 5, ...
                'timeout', 0.05, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyTrue(isnan(answer.count), ...
                'no successful poll means no count to report');
            testCase.verifyGreaterThan(call.callCount, 1);
        end

        function testZeroExpectedIsImmediatelyMet(testCase)
            polls = { struct('ok', true, 'count', 0) };
            call = ndi.test.helper.ScriptedDocumentCount(polls, ...
                'cloudDatasetID', "d1", 'expectedCount', 0, ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, ~] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 1);
        end
    end
end
