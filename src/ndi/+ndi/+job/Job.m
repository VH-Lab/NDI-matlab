classdef Job < handle
% NDI.JOB.JOB - a long piece of work that can be paused, resumed and restarted
%
%   A job is one long task -- building a lightsheet pyramid and streaming
%   it to NDI Cloud takes hours -- kept as a folder under ndi.job.Job.root()
%   (~/.ndi/jobs by default) with a job.json describing it. Everything the
%   job needs to carry on is in that folder, not in MATLAB's memory, so a
%   job interrupted by a dropped connection, a crash, or quitting MATLAB
%   can be resumed from where it stopped, and the navigator's Jobs pane
%   (ndi.gui.nav.jobsPane) can list and control jobs it did not start.
%
%   A job subclass defines WORK (and may define ONRESTART); everything else
%   is here. The lifecycle:
%
%     queued      created, never run
%     running     RUN is working on it. A job whose process is gone is
%                 shown as interrupted (see effectiveState).
%     paused      stopped at your request (requestPause), resumable
%     interrupted stopped without finishing (Ctrl+C, MATLAB quit,
%                 crash), resumable
%     failed      WORK raised an error, recorded in lastError; resumable
%                 once the cause is fixed
%     done        finished
%
%   PAUSING IS COOPERATIVE. requestPause leaves a flag in the job's folder
%   (so it works from another MATLAB too); the job sees it at its next
%   heartbeat (BEAT, which WORK calls regularly -- for a pyramid, after
%   every super-block) and stops there with 'NDI:job:paused'.
%
%   Example:
%       job = ndi.job.LightsheetToCloud.create(choices);
%       job.run();                 % until done, paused or failed
%       jobs = ndi.job.Job.list(); % every job on this computer
%       jobs{1}.run();             % resume
%
%   See also: ndi.job.LightsheetToCloud, ndi.gui.nav.jobsPane

    properties (SetAccess = protected)
        id char = ''
        kind char = ''          % the subclass's class name
        title char = ''
        created char = ''
        state char = 'queued'
        progress double = 0     % 0 to 1
        message char = ''       % the latest word from WORK
        lastError char = ''     % the report of the error that failed it
        updated char = ''       % the last time anything was saved
        heartbeat char = ''     % the last sign of life while running
        pid double = 0          % the MATLAB process running it, 0 if none
        spec struct = struct()  % what to do (JSON-safe, subclass-defined)
        checkpoint struct = struct()  % what is done so far
    end

    properties (Transient)
        % Test hooks. Api is handed to the cloud writer a job makes;
        % PauseAfterBeats requests a pause after that many heartbeats.
        Api = []
        PauseAfterBeats = Inf
    end

    properties (Access = private, Transient)
        lastSaved = []
        beats = 0
        lastPaneRefresh = []
    end

    methods (Abstract, Access = protected)
        work(obj)
    end

    methods
        function f = folder(obj)
            f = fullfile(ndi.job.Job.root(), obj.id);
        end

        function run(obj)
        % RUN - do the work: from the start, or from where it stopped
        %
        %   Returns when the job is done, paused or failed; the outcome is
        %   in obj.state (and obj.lastError). Refused while another MATLAB
        %   is running the same job.
            if strcmp(obj.effectiveState(), 'running')
                error('NDI:job:alreadyRunning', ...
                    'Job "%s" is already running (MATLAB process %d).', obj.title, obj.pid);
            end
            if strcmp(obj.state, 'done')
                return
            end
            obj.clearPause();
            obj.state = 'running';
            obj.pid = feature('getpid');
            obj.lastError = '';
            obj.message = 'Starting...';
            obj.beats = 0;
            obj.save();
            obj.refreshPane(true);
            % Ctrl+C runs no catch block, but it does run this.
            guard = onCleanup(@() obj.stoppedWithoutCatch());
            try
                obj.work();
                obj.state = 'done';
                obj.progress = 1;
                obj.message = 'Done.';
            catch ME
                if strcmp(ME.identifier, 'NDI:job:paused')
                    obj.state = 'paused';
                    obj.message = sprintf('Paused at %.0f%%.', 100 * obj.progress);
                    obj.clearPause();
                else
                    obj.state = 'failed';
                    obj.message = ME.message;
                    obj.lastError = getReport(ME, 'extended', 'hyperlinks', 'off');
                end
            end
            obj.pid = 0;
            obj.save();
            clear guard
            obj.refreshPane(true);
        end

        function beat(obj, fraction, text)
        % BEAT - WORK's regular sign of life: progress, and the chance to pause
        %
        %   BEAT(JOB, FRACTION, TEXT) records progress (saved at most every
        %   5 s), lets the navigator redraw (so its buttons respond while
        %   the job holds MATLAB), and stops the job with 'NDI:job:paused'
        %   if a pause was requested. Pass it as a progress callback.
            if nargin < 3, text = ''; end
            obj.progress = max(0, min(1, double(fraction)));
            if ~isempty(text), obj.message = char(text); end
            obj.heartbeat = ndi.job.Job.now();
            obj.beats = obj.beats + 1;
            if obj.beats >= obj.PauseAfterBeats
                obj.requestPause();
            end
            if isempty(obj.lastSaved) || toc(obj.lastSaved) >= 5
                obj.save();
            end
            obj.refreshPane(false);
            drawnow limitrate;
            if obj.pauseRequested()
                error('NDI:job:paused', 'Job "%s" was paused.', obj.title);
            end
        end

        function requestPause(obj)
        % REQUESTPAUSE - ask a running job to stop at its next heartbeat
        %
        %   Works from any MATLAB: the request is a file in the job's folder.
            fid = fopen(fullfile(obj.folder(), 'pause.request'), 'w');
            if fid > 0, fclose(fid); end
        end

        function tf = pauseRequested(obj)
            tf = isfile(fullfile(obj.folder(), 'pause.request'));
        end

        function restart(obj)
        % RESTART - forget the progress, so the next RUN starts from scratch
            if strcmp(obj.effectiveState(), 'running')
                error('NDI:job:running', 'Pause job "%s" before restarting it.', obj.title);
            end
            obj.onRestart();
            obj.checkpoint = struct();
            obj.progress = 0;
            obj.state = 'queued';
            obj.message = 'Will start over.';
            obj.lastError = '';
            obj.clearPause();
            obj.save();
        end

        function remove(obj)
        % REMOVE - delete the job's record (its folder) from this computer
            if strcmp(obj.effectiveState(), 'running')
                error('NDI:job:running', 'Pause job "%s" before removing it.', obj.title);
            end
            if isfolder(obj.folder())
                rmdir(obj.folder(), 's');
            end
        end

        function s = effectiveState(obj)
        % EFFECTIVESTATE - the state, with a vanished runner shown as 'interrupted'
        %
        %   A job saved as running whose MATLAB process no longer exists
        %   (it crashed, or was quit or killed) is 'interrupted'.
            s = obj.state;
            if strcmp(s, 'running') && obj.pid ~= feature('getpid') && ...
                    ~ndi.job.Job.processAlive(obj.pid)
                s = 'interrupted';
            end
        end

        function tf = canResume(obj)
            tf = any(strcmp(obj.effectiveState(), {'queued', 'paused', 'interrupted', 'failed'}));
        end

        function save(obj)
        % SAVE - write job.json (via a temporary file, so a reader never
        % sees half of it)
            f = obj.folder();
            if ~isfolder(f), mkdir(f); end
            obj.updated = ndi.job.Job.now();
            s = struct();
            for name = ndi.job.Job.savedFields()
                s.(name{1}) = obj.(name{1});
            end
            tmp = fullfile(f, ['job.json.' char(did.ido.unique_id()) '.tmp']);
            fid = fopen(tmp, 'w');
            if fid < 0
                error('NDI:job:cannotSave', 'Could not write %s.', tmp);
            end
            fwrite(fid, jsonencode(s, 'PrettyPrint', true), 'char');
            fclose(fid);
            movefile(tmp, fullfile(f, 'job.json'), 'f');
            obj.lastSaved = tic;
        end
    end

    methods (Access = protected)
        function initialize(obj, title, spec)
        % For a subclass's CREATE: name the job, keep SPEC, write it out.
            obj.id = char(did.ido.unique_id());
            obj.kind = class(obj);
            obj.title = char(title);
            obj.created = ndi.job.Job.now();
            obj.spec = spec;
            obj.save();
        end

        function onRestart(~)
        % Subclasses discard what a fresh start must not reuse.
        end

        function setCheckpoint(obj, name, value)
            obj.checkpoint.(name) = value;
            obj.save();
        end
    end

    methods (Access = private)
        function clearPause(obj)
            f = fullfile(obj.folder(), 'pause.request');
            if isfile(f), delete(f); end
        end

        function stoppedWithoutCatch(obj)
            % Reached only if RUN did not finish normally (Ctrl+C).
            if isvalid(obj) && strcmp(obj.state, 'running')
                obj.state = 'interrupted';
                obj.message = sprintf('Interrupted at %.0f%%.', 100 * obj.progress);
                obj.pid = 0;
                try
                    obj.save();
                catch
                end
            end
        end

        function refreshPane(obj, force)
            % Keep an open navigator's Jobs pane current, at most every 5 s.
            if ~force && ~isempty(obj.lastPaneRefresh) && toc(obj.lastPaneRefresh) < 5
                return
            end
            obj.lastPaneRefresh = tic;
            try
                navs = ndi.gui.navigator.findOpen();
                for k = 1:numel(navs)
                    p = navs(k).jobsPaneHandle();
                    if ~isempty(p), p.refresh(); end
                end
            catch
            end
        end
    end

    methods (Static)
        function r = root()
        % ROOT - the folder jobs are kept in
        %
        %   The environment variable NDI_JOBS_DIR, if set (tests use it),
        %   else ~/.ndi/jobs. Created if missing.
            r = getenv('NDI_JOBS_DIR');
            if isempty(r)
                r = fullfile(ndi.common.PathConstants.Preferences, 'jobs');
            end
            if ~isfolder(r), mkdir(r); end
        end

        function job = load(idOrFolder)
        % LOAD - the job with this id (or folder), read from its job.json
            f = char(idOrFolder);
            if ~isfolder(f)
                f = fullfile(ndi.job.Job.root(), f);
            end
            file = fullfile(f, 'job.json');
            if ~isfile(file)
                error('NDI:job:notFound', 'There is no job at %s.', f);
            end
            s = jsondecode(fileread(file));
            job = feval(s.kind);
            for name = ndi.job.Job.savedFields()
                if isfield(s, name{1})
                    v = s.(name{1});
                    if isempty(v) && any(strcmp(name{1}, {'spec', 'checkpoint'}))
                        v = struct();
                    end
                    job.(name{1}) = v;
                end
            end
        end

        function jobs = list()
        % LIST - every job on this computer, oldest first (unreadable ones skipped)
            jobs = {};
            d = dir(ndi.job.Job.root());
            d = d([d.isdir] & ~startsWith({d.name}, '.'));
            for k = 1:numel(d)
                try
                    jobs{end+1} = ndi.job.Job.load(fullfile(d(k).folder, d(k).name)); %#ok<AGROW>
                catch
                end
            end
            if ~isempty(jobs)
                [~, order] = sort(cellfun(@(j) j.created, jobs, 'UniformOutput', false));
                jobs = jobs(order);
            end
        end

        function tf = processAlive(pid)
        % PROCESSALIVE - is there a process with this id on this computer?
            tf = false;
            if isempty(pid) || pid <= 0, return; end
            if ispc
                [~, out] = system(sprintf('tasklist /FI "PID eq %d" /NH', pid));
                tf = contains(out, sprintf(' %d ', pid));
            else
                tf = system(sprintf('kill -0 %d 2>/dev/null', pid)) == 0;
            end
        end

        function t = now()
            t = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
        end
    end

    methods (Static, Access = private)
        function f = savedFields()
            f = {'id', 'kind', 'title', 'created', 'state', 'progress', 'message', ...
                'lastError', 'updated', 'heartbeat', 'pid', 'spec', 'checkpoint'};
        end
    end
end
