function cmd = commandLine(commandPath, args, options)
% COMMANDLINE - the shell line that runs an NDI-python command from MATLAB
%
%   CMD = ndi.python.commandLine(COMMANDPATH, ARGS) returns the command
%   line, for SYSTEM, that runs the program COMMANDPATH with the
%   arguments ARGS (a cell array of char or a string array), with
%   NDI_FROM_MATLAB=1 set (see ndi.python.environmentPrefix) and, unless
%   'Wait' is true, detached so MATLAB is not blocked:
%
%     Linux/macOS:  NDI_FROM_MATLAB=1 'PATH' 'ARG1' ... &
%     Windows:      set NDI_FROM_MATLAB=1&& start "TITLE" /min "PATH" "ARG1" ...
%
%   The path and each argument are quoted (ndi.python.shellQuote), so
%   spaces in either are safe.
%
%   Pure: nothing is run, so the line can be shown or tested anywhere.
%
%   Optional Name-Value Arguments:
%     Wait      - run in the foreground (default false).
%     IsWindows - build the cmd.exe form (default ispc).
%     Title     - window title for Windows' start (default 'NDI').
%
%   Example:
%     cmd = ndi.python.commandLine(ndi.python.findCommand('ndi'), {'--help'}, 'Wait', true);
%
%   See also: ndi.python.launch, ndi.python.findCommand

    arguments
        commandPath {mustBeTextScalar, mustBeNonzeroLengthText}
        args {mustBeText} = {}
        options.Wait (1,1) logical = false
        options.IsWindows (1,1) logical = ispc
        options.Title (1,:) char = 'NDI'
    end

    args = cellstr(args);
    parts = cell(1, numel(args) + 1);
    parts{1} = ndi.python.shellQuote(commandPath, 'IsWindows', options.IsWindows);
    for i = 1:numel(args)
        parts{i+1} = ndi.python.shellQuote(args{i}, 'IsWindows', options.IsWindows);
    end
    body = strjoin(parts, ' ');

    prefix = ndi.python.environmentPrefix('IsWindows', options.IsWindows);
    if options.Wait
        cmd = [prefix body];
    elseif options.IsWindows
        cmd = [prefix 'start "' options.Title '" /min ' body];
    else
        cmd = [prefix body ' &'];
    end
end
