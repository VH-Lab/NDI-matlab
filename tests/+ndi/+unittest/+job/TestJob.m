classdef TestJob < matlab.unittest.TestCase
    % TestJob - the ndi.job.Job lifecycle, and the navigator's Jobs pane.
    %
    % Jobs are kept in a temporary NDI_JOBS_DIR. ndi.test.helper.ScriptedJob
    % is the work: a number of heartbeats, then success or a failure.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    methods (TestMethodSetup)
        function privateJobsFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            f = testCase.applyFixture(TemporaryFolderFixture);
            testCase.applyFixture(EnvironmentVariableFixture('NDI_JOBS_DIR', f.Folder));
        end
    end

    methods (Test)

        function testACreatedJobIsListedAndReloads(testCase)
            job = ndi.test.helper.ScriptedJob.create(3);
            jobs = ndi.job.Job.list();
            testCase.verifyNumElements(jobs, 1);
            testCase.verifyClass(jobs{1}, 'ndi.test.helper.ScriptedJob');
            testCase.verifyEqual(jobs{1}.id, job.id);
            testCase.verifyEqual(jobs{1}.state, 'queued');
            testCase.verifyEqual(jobs{1}.spec.beats, 3);
        end

        function testARunFinishes(testCase)
            job = ndi.test.helper.ScriptedJob.create(4);
            job.run();
            testCase.verifyEqual(job.state, 'done');
            testCase.verifyEqual(job.progress, 1);
            again = ndi.job.Job.load(job.id);
            testCase.verifyEqual(again.state, 'done', 'the outcome is saved');
            testCase.verifyEqual(again.pid, 0);
        end

        function testAFailureIsRecordedAndResumable(testCase)
            job = ndi.test.helper.ScriptedJob.create(2, 'fail');
            job.run();
            testCase.verifyEqual(job.state, 'failed');
            testCase.verifySubstring(job.lastError, 'on purpose');
            testCase.verifyTrue(job.canResume());
        end

        function testPauseStopsAtAHeartbeatAndResumeCarriesOn(testCase)
            job = ndi.test.helper.ScriptedJob.create(10);
            job.PauseAfterBeats = 3;
            job.run();
            testCase.verifyEqual(job.state, 'paused');
            testCase.verifyEqual(job.progress, 0.3, 'AbsTol', 1e-12);
            testCase.verifyFalse(job.pauseRequested(), ...
                'the request is consumed when the job next runs, not left behind');

            again = ndi.job.Job.load(job.id);   % as a later MATLAB would
            testCase.verifyEqual(again.checkpoint.reached, 3);
            again.run();
            testCase.verifyEqual(again.state, 'done');
        end

        function testARunnerThatVanishedIsInterrupted(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            job.pretendRunningIn(2^31 - 2);     % no such process
            again = ndi.job.Job.load(job.id);
            testCase.verifyEqual(again.state, 'running');
            testCase.verifyEqual(again.effectiveState(), 'interrupted');
            testCase.verifyTrue(again.canResume());
            again.run();
            testCase.verifyEqual(again.state, 'done');
        end

        function testARunningJobIsNotRunTwice(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            job.pretendRunningIn(feature('getpid'));
            other = ndi.job.Job.load(job.id);
            % Saved as running in this process: alive, so refused elsewhere.
            testCase.verifyEqual(other.effectiveState(), 'running');
            testCase.verifyError(@() other.restart(), 'NDI:job:running');
            testCase.verifyError(@() other.remove(), 'NDI:job:running');
        end

        function testRestartForgetsProgress(testCase)
            job = ndi.test.helper.ScriptedJob.create(10);
            job.PauseAfterBeats = 4;
            job.run();
            job.restart();
            testCase.verifyEqual(job.state, 'queued');
            testCase.verifyEqual(job.progress, 0);
            testCase.verifyFalse(isfield(job.checkpoint, 'reached'));
        end

        function testRemoveDeletesTheRecord(testCase)
            job = ndi.test.helper.ScriptedJob.create(1);
            job.remove();
            testCase.verifyEmpty(ndi.job.Job.list());
        end

        function testRowsForThePane(testCase)
            job = ndi.test.helper.ScriptedJob.create(4);
            job.PauseAfterBeats = 2;
            job.run();
            rows = ndi.gui.nav.jobsPane.rowsFor(ndi.job.Job.list());
            testCase.verifyEqual(rows(1, 1:3), {'scripted succeed', 'paused', '50%'});
        end

        function testTheNavigatorShowsJobs(testCase)
            ndi.test.helper.ScriptedJob.create(1);
            nav = ndi.gui.navigator('Visible', 'off');
            testCase.addTeardown(@() delete(nav.Figure));
            p = nav.jobsPaneHandle();
            testCase.assertNotEmpty(p);
            testCase.verifyTrue(p.Engaged, 'the pane opens when there is a job');
            testCase.verifyEqual(size(p.Table.Data, 1), 1);
        end

        function testTheJobsPaneStartsClosedWithoutJobs(testCase)
            nav = ndi.gui.navigator('Visible', 'off');
            testCase.addTeardown(@() delete(nav.Figure));
            testCase.verifyFalse(nav.jobsPaneHandle().Engaged);
        end
    end
end
