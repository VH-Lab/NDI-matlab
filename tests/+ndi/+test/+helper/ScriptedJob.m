classdef ScriptedJob < ndi.job.Job
% SCRIPTEDJOB - an ndi.job.Job whose work is a script, for testing the job lifecycle
%
%   JOB = ndi.test.helper.ScriptedJob.create(BEATS, OUTCOME)
%
%   WORK beats BEATS times (progress k/BEATS), resuming from the last beat
%   a previous run reached, then returns ('succeed') or raises
%   'scripted:boom' ('fail').

    properties (Constant)
        Kind = 'test.scripted'
    end

    methods (Static)
        function job = create(beats, outcome)
            arguments
                beats (1,1) double = 5
                outcome (1,:) char = 'succeed'
            end
            ndi.job.Job.register('test.scripted', 'ndi.test.helper.ScriptedJob');
            job = ndi.test.helper.ScriptedJob();
            job.initialize(sprintf('scripted %s', outcome), ...
                struct('beats', beats, 'outcome', outcome));
        end
    end

    methods
        function pretendFrom(obj, kind, runtime, formatVersion)
        % Rewrite the saved job as one another language (or a newer
        % version) made, for the ForeignJob paths.
            obj.save();
            f = fullfile(obj.folder(), 'job.json');
            s = jsondecode(fileread(f));
            s.kind = kind;
            s.runtime = runtime;
            s.formatVersion = formatVersion;
            fid = fopen(f, 'w');
            fwrite(fid, jsonencode(s), 'char');
            fclose(fid);
        end

        function pretendPace(obj, startProgress, progress, startedSecondsAgo)
        % Leave the job running in this MATLAB, having gone from
        % STARTPROGRESS to PROGRESS since a run began STARTEDSECONDSAGO,
        % with a heartbeat just now.
            obj.pretendRunningIn(ndi.job.Job.processId());
            fmt = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            utcNow = datetime('now', 'TimeZone', 'UTC', 'Format', fmt);
            obj.runStarted = char(utcNow - seconds(startedSecondsAgo));
            obj.runStartProgress = startProgress;
            obj.progress = progress;
            obj.heartbeat = char(utcNow);
            obj.save();
        end

        function pretendRunningIn(obj, pid)
        % Leave the job saved as running in process PID on this computer,
        % as a crash would.
            obj.state = 'running';
            obj.host = ndi.job.Job.hostName();
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
