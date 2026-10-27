function [status, cmd] = launch(name, args, options)
% LAUNCH - run one of NDI-python's command-line tools from MATLAB
%
%   [STATUS, CMD] = ndi.python.launch(NAME, ARGS) finds the console
%   script NAME with ndi.python.findCommand, and runs it with the
%   arguments ARGS (cell array of char or string array) through SYSTEM,
%   in the background and with NDI_FROM_MATLAB=1 set. CMD is the exact
%   line that was run (see ndi.python.commandLine). For a background
%   launch, STATUS says whether the launch started, not how the program
%   ended.
%
%   Optional Name-Value Arguments:
%     Launcher - run this program instead of looking NAME up. An
%                explicitly passed launcher always wins. Default ''.
%     Wait     - block until the program exits (default false).
%     Verbose  - print the command before running it (default true).
%
%   Example:
%     ndi.python.launch('napariViewLightsheet', {sessionPath, '--list'}, 'Wait', true);
%
%   See also: ndi.python.findCommand, ndi.python.commandLine,
%             ndi.python.install

    arguments
        name (1,:) char
        args {mustBeText} = {}
        options.Launcher (1,:) char = ''
        options.Wait (1,1) logical = false
        options.Verbose (1,1) logical = true
    end

    commandPath = strtrim(options.Launcher);
    if isempty(commandPath)
        commandPath = ndi.python.findCommand(name);
    end
    cmd = ndi.python.commandLine(commandPath, args, ...
        'Wait', options.Wait, 'Title', name);
    if options.Verbose
        fprintf('Executing: %s\n', cmd);
    end
    status = system(cmd);
end
