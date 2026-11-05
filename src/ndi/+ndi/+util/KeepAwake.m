classdef KeepAwake < handle
% NDI.UTIL.KEEPAWAKE - keep this computer from sleeping while NDI works
%
%   K = ndi.util.KeepAwake.instance();     % the one for this MATLAB
%   K.hold(KEY, LABEL)    % keep the computer awake for KEY ("job x", ...)
%   K.release(KEY)        % KEY no longer needs it
%   K.toggleManual()      % the navigator's coffee-cup button
%   K.isOn()              % is the computer being kept awake now?
%
%   While anything holds it, one helper program keeps the operating system
%   from going to sleep on its own; when the last holder lets go, it is
%   stopped and the computer sleeps as it normally would:
%
%     macOS    caffeinate -ims -w <MATLAB pid>
%     Linux    systemd-inhibit --what=idle:sleep ... tail --pid=<MATLAB pid>
%     Windows  a hidden PowerShell that calls SetThreadExecutionState
%              (ES_CONTINUOUS | ES_SYSTEM_REQUIRED) and waits for MATLAB
%
%   Each helper also ends by itself when this MATLAB exits (or crashes),
%   so the computer is never left unable to sleep. The display may still
%   sleep, and closing a laptop's lid still sleeps it.
%
%   ndi.job.Job holds it while a job runs (unless the preference
%   Jobs.KeepComputerAwake is false). The navigator's NDI pane shows it as
%   a coffee cup: steaming while the computer is kept awake.
%
%   Nothing here ever stops NDI's work: if the helper cannot be started
%   (Linux without systemd, say), isOn is false and lastError says why.
%
%   See also: ndi.job.Job, ndi.gui.nav.ndiPane, ndi.util.startProcess

    events
        Changed     % a holder came or went, or the helper started or stopped
    end

    properties (SetAccess = private)
        keys = {}       % who holds it
        labels = {}     % and, for people, what each is
        lastError char = ''
    end

    properties
        % Test hook: a function @(ARGS) returning a process-like object
        % (isAlive(), destroy()). Empty: ndi.util.startProcess.
        Launcher = []
    end

    properties (Access = private)
        process = []
    end

    properties (Constant)
        ManualKey = 'manual'
    end

    methods (Static)
        function obj = instance()
        % INSTANCE - the KeepAwake of this MATLAB
            persistent the
            if isempty(the) || ~isvalid(the)
                the = ndi.util.KeepAwake();
            end
            obj = the;
        end

        function args = commandFor(platform, pid)
        % COMMANDFOR - the helper program for PLATFORM ('mac', 'linux',
        % 'windows'), tied to the process PID
            p = sprintf('%d', round(pid));
            switch char(platform)
                case 'mac'
                    % idle sleep, disk sleep, system sleep (on AC power)
                    args = {'caffeinate', '-ims', '-w', p};
                case 'linux'
                    args = {'systemd-inhibit', '--what=idle:sleep', '--who=NDI', ...
                        '--why=NDI is working', '--mode=block', ...
                        'tail', ['--pid=' p], '-f', '/dev/null'};
                case 'windows'
                    % 2147483649 = ES_CONTINUOUS (0x80000000) | ES_SYSTEM_REQUIRED (1).
                    % Sent as -EncodedCommand (base64 UTF-16LE), so nothing
                    % in it needs quoting on a Windows command line.
                    script = ['$t = Add-Type -MemberDefinition ' ...
                        '''[DllImport("kernel32.dll")] public static extern uint ' ...
                        'SetThreadExecutionState(uint f);'' ' ...
                        '-Name Power -Namespace NdiKeepAwake -PassThru; ' ...
                        '[void]$t::SetThreadExecutionState([uint32]2147483649); ' ...
                        'Wait-Process -Id ' p];
                    encoded = matlab.net.base64encode(unicode2native(script, 'UTF-16LE'));
                    args = {'powershell', '-NoProfile', '-NonInteractive', ...
                        '-WindowStyle', 'Hidden', '-EncodedCommand', encoded};
                otherwise
                    error('NDI:util:KeepAwake:platform', 'Unknown platform ''%s''.', platform);
            end
        end

        function p = platform()
        % PLATFORM - 'mac', 'windows' or 'linux'
            if ismac
                p = 'mac';
            elseif ispc
                p = 'windows';
            else
                p = 'linux';
            end
        end
    end

    methods
        function hold(obj, key, label)
        % HOLD - keep the computer awake on behalf of KEY (LABEL is for people)
            if nargin < 3, label = key; end
            key = char(key);
            if ~any(strcmp(obj.keys, key))
                obj.keys{end+1} = key;
                obj.labels{end+1} = char(label);
            end
            obj.update();
        end

        function release(obj, key)
        % RELEASE - KEY no longer needs the computer awake
            k = strcmp(obj.keys, char(key));
            obj.keys(k) = [];
            obj.labels(k) = [];
            obj.update();
        end

        function toggleManual(obj)
        % TOGGLEMANUAL - turn the manual hold (the coffee cup) on or off
            if obj.manualOn()
                obj.release(ndi.util.KeepAwake.ManualKey);
            else
                obj.hold(ndi.util.KeepAwake.ManualKey, 'you asked for it');
            end
        end

        function tf = manualOn(obj)
            tf = any(strcmp(obj.keys, ndi.util.KeepAwake.ManualKey));
        end

        function tf = isHeldBy(obj, key)
            tf = any(strcmp(obj.keys, char(key)));
        end

        function tf = isOn(obj)
        % ISON - is the helper running, so the computer cannot idle-sleep?
            tf = false;
            if isempty(obj.process), return; end
            try
                tf = logical(obj.process.isAlive());
            catch
                tf = false;
            end
        end

        function t = describe(obj)
        % DESCRIBE - one sentence for a tooltip
            if obj.isOn()
                t = sprintf(['Keeping this computer awake (%s). Click to ' ...
                    '%s.'], strjoin(obj.labels, '; '), ...
                    pick(obj.manualOn(), 'stop keeping it awake yourself', ...
                    'also keep it awake after that'));
                if obj.manualOn() && numel(obj.keys) > 1
                    t = [t ' It stays awake while the rest need it.'];
                end
            elseif ~isempty(obj.keys)
                t = sprintf('Could not keep this computer awake: %s', obj.lastError);
            else
                t = ['Let this computer sleep as usual. Click to keep it ' ...
                    'awake (jobs do this themselves while they run).'];
            end
        end

        function delete(obj)
            obj.stop();
        end
    end

    methods (Access = private)
        function update(obj)
            if ~isempty(obj.keys) && ~obj.isOn()
                obj.start();
            elseif isempty(obj.keys) && ~isempty(obj.process)
                obj.stop();
            end
            notify(obj, 'Changed');
        end

        function start(obj)
            obj.stop();
            helper = 'the keep-awake helper';
            log = fullfile(tempdir, 'ndi-keep-awake.log');
            try
                args = ndi.util.KeepAwake.commandFor( ...
                    ndi.util.KeepAwake.platform(), ndi.job.Job.processId());
                helper = args{1};
                % Said if it stops by itself (refused, or missing): see ISON.
                obj.lastError = sprintf('%s stopped; its messages are in %s.', helper, log);
                if isempty(obj.Launcher)
                    obj.process = ndi.util.startProcess(args, log, log);
                else
                    obj.process = obj.Launcher(args);
                end
            catch ME
                obj.process = [];
                obj.lastError = sprintf('%s could not be started (%s).', helper, ME.message);
            end
        end

        function stop(obj)
            if ~isempty(obj.process)
                try
                    obj.process.destroy();
                catch
                end
            end
            obj.process = [];
        end
    end
end

function v = pick(tf, a, b)
    if tf, v = a; else, v = b; end
end
