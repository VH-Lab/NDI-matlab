classdef FileTierMockTest < matlab.unittest.TestCase
% FILETIERMOCKTEST - the file-tier job-polling logic, against mocks.
%
% The interesting behaviours here are ones a working server will not
% produce on demand: a job that never reaches a terminal state, a
% timeout, a transient API error that a naive loop would mistake for a
% dead job, and each of the three terminal states resolving with the
% right verdict. A live cloud test (under tests/+ndi/+unittest/+cloud)
% can show the happy path works; only a mock can show what happens when
% it does not.
%
% Runs entirely through the pollStatus seam against ndi.test.helper.
% ScriptedFileTierJob.

    methods (Test)

        function testCompletedIsSuccess(testCase)
            states = { struct('ok', true, 'status', ...
                struct('state','completed','fileCount',3,'filesDone',3)) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(answer.state, 'completed');
            testCase.verifyEqual(call.callCount, 1);
        end

        function testFailedIsTerminalNotRetried(testCase)
            states = { struct('ok', true, 'status', struct('state','failed')) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, ~] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(call.callCount, 1, ...
                'a failed job must not be polled again');
        end

        function testSupersededIsTerminalNotRetried(testCase)
            % 'superseded' is unique to file-tier: a later job for the same
            % file has taken over. The caller has lost the race; polling on
            % is pointless.
            states = { struct('ok', true, 'status', struct('state','superseded')) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'superseded');
            testCase.verifyEqual(call.callCount, 1, ...
                'a superseded job must not be polled again');
        end

        function testJobIsPolledUntilItCompletes(testCase)
            states = { struct('ok', true, 'status', struct('state','queued')), ...
                       struct('ok', true, 'status', struct('state','running')), ...
                       struct('ok', true, 'status', struct('state','completed')) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyTrue(b);
            testCase.verifyEqual(call.callCount, 3);
            testCase.verifyEqual(answer.state, 'completed');
        end

        function testJobThatNeverFinishesTimesOut(testCase)
            states = { struct('ok', true, 'status', struct('state','running')) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 0.05, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyTrue(isfield(answer,'elapsed'));
        end

        function testAnApiErrorIsNotMistakenForATerminalState(testCase)
            % A failed poll is not a failed job; keep polling until the
            % deadline rather than reporting the job dead. The old
            % monolithic waitForFileTierJob returned false on the first
            % ok=false -- this test pins the sibling behaviour.
            states = { struct('ok', false, 'status', struct('message','gateway')) };
            call = ndi.test.helper.ScriptedFileTierJob(states, 'jobId', "j1", ...
                'timeout', 0.5, 'initialInterval', 0.01, 'maxInterval', 0.01);

            [b, answer] = call.execute();
            testCase.verifyFalse(b);
            testCase.verifyEqual(answer.state, 'timeout');
            testCase.verifyGreaterThan(call.callCount, 1, ...
                'a transient API error should be retried, not treated as terminal');
        end
    end
end
