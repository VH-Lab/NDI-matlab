classdef TestJob < matlab.unittest.TestCase
    % TestJob - the ndi.job.Job lifecycle, and the navigator's Jobs pane.
    %
    % Jobs are kept in a temporary NDI_JOBS_DIR. ndi.test.helper.ScriptedJob
    % is the work: a number of heartbeats, then success or a failure.
    %
    % Authored without a local MATLAB runtime; needs MATLAB to validate/run.

    properties
        launcher    % ndi.test.helper.FakeLauncher: nothing really stays awake
    end

    methods (TestMethodSetup)
        function privateJobsFolder(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            import matlab.unittest.fixtures.EnvironmentVariableFixture
            f = testCase.applyFixture(TemporaryFolderFixture);
            testCase.applyFixture(EnvironmentVariableFixture('NDI_JOBS_DIR', f.Folder));
            testCase.launcher = ndi.test.helper.FakeLauncher.install(testCase);
            % As the user has it, put back afterwards.
            was = ndi.preferences.get('Jobs.KeepComputerAwake');
            testCase.addTeardown(@() ndi.preferences.set('Jobs.KeepComputerAwake', was));
            ndi.preferences.set('Jobs.KeepComputerAwake', true);
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
            job.pretendRunningIn(ndi.job.Job.processId());
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

        % -- the shared format ------------------------------------------

        function testJobJsonFollowsTheSchema(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            job.run();
            s = jsondecode(fileread(fullfile(job.folder(), 'job.json')));
            schema = jsondecode(fileread(fullfile(ndi.common.PathConstants.CommonFolder, ...
                'job_schema', 'job.schema.json')));
            for k = 1:numel(schema.required)
                testCase.verifyTrue(isfield(s, schema.required{k}), ...
                    sprintf('job.json lacks the required field %s', schema.required{k}));
            end
            testCase.verifyEqual(s.formatVersion, 1);
            testCase.verifyEqual(s.kind, 'test.scripted', 'a neutral kind, not a class name');
            testCase.verifyEqual(s.runtime, 'matlab');
            testCase.verifyNotEmpty(s.host);
            utc = '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$';
            for f = {'created', 'updated', 'heartbeat'}
                testCase.verifyNotEmpty(regexp(s.(f{1}), utc, 'once'), ...
                    sprintf('%s is UTC with a Z: %s', f{1}, s.(f{1})));
            end
            testCase.verifyTrue(any(strcmp(s.state, schema.properties.state.enum)));
        end

        function testAnotherLanguagesJobIsListedButNotRun(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            job.pretendFrom('somePythonOnlyKind', 'python', 1);
            jobs = ndi.job.Job.list();
            testCase.verifyClass(jobs{1}, 'ndi.job.ForeignJob');
            testCase.verifyEqual(jobs{1}.kind, 'somePythonOnlyKind');
            testCase.verifyEqual(jobs{1}.runtime, 'python');
            testCase.verifyFalse(jobs{1}.canResume());
            testCase.verifyError(@() jobs{1}.run(), 'NDI:job:foreign');
            rows = ndi.gui.nav.jobsPane.rowsFor(jobs);
            testCase.verifyEqual(rows{1, 1}, 'scripted succeed', 'still listed');
        end

        function testANewerFormatIsNotRun(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            job.pretendFrom('test.scripted', 'matlab', 2);
            again = ndi.job.Job.load(job.id);
            testCase.verifyClass(again, 'ndi.job.ForeignJob', ...
                'a format newer than this code reads is not run');
        end

        function testTimesAreShownInLocalTime(testCase)
            t = ndi.job.Job.localTime('2026-01-01T00:00:00Z');
            testCase.verifyNotEmpty(regexp(t, '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$', 'once'));
            testCase.verifyEqual(ndi.job.Job.localTime(''), '');
        end

        function testRowsForThePane(testCase)
            job = ndi.test.helper.ScriptedJob.create(4);
            job.PauseAfterBeats = 2;
            job.run();
            rows = ndi.gui.nav.jobsPane.rowsFor(ndi.job.Job.list());
            testCase.verifyEqual(rows(1, 1:4), {'scripted succeed', 'paused', '50%', ''}, ...
                'no time left is shown for a job that is not running');
            testCase.verifyNotEmpty(regexp(rows{1, 5}, '^\d{2}:\d{2}:\d{2}$', 'once'), ...
                'updated today: the time of day');
        end

        % -- staying awake ------------------------------------------------

        function testARunKeepsTheComputerAwakeUntilItStops(testCase)
            job = ndi.test.helper.ScriptedJob.create(3);
            job.run();
            testCase.verifyTrue(job.checkpoint.keptAwake, 'awake while it ran');
            testCase.verifyFalse(ndi.util.KeepAwake.instance().isOn(), ...
                'allowed to sleep once it finished');
            testCase.verifyEqual(testCase.launcher.running(), 0);
        end

        function testAPausedOrFailedRunLetsItSleep(testCase)
            job = ndi.test.helper.ScriptedJob.create(4);
            job.PauseAfterBeats = 2;
            job.run();
            testCase.verifyEqual(job.state, 'paused');
            testCase.verifyFalse(ndi.util.KeepAwake.instance().isOn(), 'paused');
            bad = ndi.test.helper.ScriptedJob.create(1, 'fail');
            bad.run();
            testCase.verifyEqual(bad.state, 'failed');
            testCase.verifyFalse(ndi.util.KeepAwake.instance().isOn(), 'failed');
        end

        function testTheManualHoldOutlastsAJob(testCase)
            k = ndi.util.KeepAwake.instance();
            k.toggleManual();
            ndi.test.helper.ScriptedJob.create(1).run();
            testCase.verifyTrue(k.isOn(), 'the cup was turned on by hand: still on');
            k.toggleManual();
            testCase.verifyFalse(k.isOn());
        end

        function testThePreferenceTurnsItOff(testCase)
            ndi.preferences.set('Jobs.KeepComputerAwake', false);
            job = ndi.test.helper.ScriptedJob.create(1);
            job.run();
            testCase.verifyFalse(job.checkpoint.keptAwake);
            testCase.verifyEmpty(testCase.launcher.processes, 'no helper was started');
        end

        function testTheNavigatorsCoffeeCup(testCase)
            nav = ndi.gui.navigator('Visible', 'off');
            testCase.addTeardown(@() delete(nav.Figure));
            pane = [];
            for i = 1:numel(nav.Panes)
                if isa(nav.Panes{i}, 'ndi.gui.nav.ndiPane'), pane = nav.Panes{i}; end
            end
            testCase.assertNotEmpty(pane);
            cup = pane.CupButton;
            testCase.verifySubstring(char(cup.Icon), 'coffee_cold_icon.svg');
            pane.toggleAwake();
            testCase.verifySubstring(char(cup.Icon), 'coffee_hot_icon.svg', ...
                'a steaming cup while the computer is kept awake');
            testCase.verifySubstring(cup.Tooltip, 'Keeping this computer awake');
            pane.toggleAwake();
            testCase.verifySubstring(char(cup.Icon), 'coffee_cold_icon.svg');
        end

        % -- time left ---------------------------------------------------

        function testARunRecordsWhenItBegan(testCase)
            job = ndi.test.helper.ScriptedJob.create(10);
            job.PauseAfterBeats = 4;
            job.run();
            again = ndi.job.Job.load(job.id);
            testCase.verifyNotEmpty(again.runStarted);
            testCase.verifyEqual(again.runStartProgress, 0);
            again.run();
            testCase.verifyEqual(again.runStartProgress, 0.4, 'AbsTol', 1e-12, ...
                'a resumed run is paced from where it resumed');
        end

        function testTimeLeftFollowsThisRunsPace(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            % A quarter of the way in 100 s: three quarters, about 300 s, to go.
            job.pretendPace(0, 0.25, 100);
            testCase.verifyEqual(job.remainingSeconds(), 300, 'AbsTol', 5);
            % Resumed at 0.5; 0.1 more in 60 s: 0.4 to go, about 240 s.
            job.pretendPace(0.5, 0.6, 60);
            testCase.verifyEqual(job.remainingSeconds(), 240, 'AbsTol', 5);
            rows = ndi.gui.nav.jobsPane.rowsFor({job});
            testCase.verifyEqual(rows{1, 4}, '4m');
        end

        function testNoTimeLeftWithoutAPace(testCase)
            job = ndi.test.helper.ScriptedJob.create(2);
            testCase.verifyTrue(isnan(job.remainingSeconds()), 'queued');
            job.pretendPace(0.2, 0.2, 300);
            testCase.verifyTrue(isnan(job.remainingSeconds()), 'no progress yet');
            job.pretendPace(0, 0.1, 10);
            testCase.verifyTrue(isnan(job.remainingSeconds()), 'too soon to say');
        end

        function testDurationText(testCase)
            f = @ndi.gui.nav.jobsPane.durationText;
            testCase.verifyEqual(f(NaN), '');
            testCase.verifyEqual(f(20), '<1m');
            testCase.verifyEqual(f(12 * 60), '12m');
            testCase.verifyEqual(f(3 * 3600 + 5 * 60), '3h 05m');
            testCase.verifyEqual(f(2 * 86400 + 3 * 3600), '2d 3h');
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
