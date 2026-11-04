classdef ScriptedJob < ndi.job.Job
% SCRIPTEDJOB - an ndi.job.Job whose work is a script, for testing the job lifecycle
%
%   JOB = ndi.test.helper.ScriptedJob.create(BEATS, OUTCOME)
%
%   WORK beats BEATS times (progress k/BEATS), resuming from the last beat
%   a previous run reached, then returns ('succeed') or raises
%   'scripted:boom' ('fail').

    methods (Static)
        function job = create(beats, outcome)
            arguments
                beats (1,1) double = 5
                outcome (1,:) char = 'succeed'
            end
            job = ndi.test.helper.ScriptedJob();
            job.initialize(sprintf('scripted %s', outcome), ...
                struct('beats', beats, 'outcome', outcome));
        end
    end

    methods
        function pretendRunningIn(obj, pid)
        % Leave the job saved as running in process PID, as a crash would.
            obj.state = 'running';
            obj.pid = pid;
            obj.save();
        end
    end

    methods (Access = protected)
        function work(obj)
            first = 1;
            if isfield(obj.checkpoint, 'reached')
                first = obj.checkpoint.reached + 1;
            end
            n = obj.spec.beats;
            for k = first:n
                obj.setCheckpoint('reached', k);
                obj.beat(k / n, sprintf('step %d of %d', k, n));
            end
            if strcmp(obj.spec.outcome, 'fail')
                error('scripted:boom', 'The script failed on purpose.');
            end
        end
    end
end
