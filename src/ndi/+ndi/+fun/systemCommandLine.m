function cmd = systemCommandLine(exePath, args, options)
% SYSTEMCOMMANDLINE - the line SYSTEM needs to run an external program safely
%
%   CMD = ndi.fun.systemCommandLine(EXEPATH, ARGS) returns the command
%   line, for SYSTEM, that runs the program EXEPATH with the arguments
%   ARGS (a cell array of char or a string array). The program and each
%   argument are quoted as one argument, so paths with spaces or quotes
%   in them are safe:
%
%     Linux/macOS:  LD_LIBRARY_PATH="<pre-MATLAB value>" 'EXEPATH' 'ARG1' ...
%     Windows:      ""EXEPATH" "ARG1" ..."
%
%   On Linux, MATLAB puts its own library folders on LD_LIBRARY_PATH and
%   every program started with SYSTEM inherits them, so an ffmpeg or R
%   built against the system's libraries can load MATLAB's copies and
%   fail. The prefix restores the value from before MATLAB started (see
%   ndi.common.systemCurlEnvPrefix); turn it off with 'CleanLibraryPath'.
%
%   On Windows, SYSTEM runs cmd /c, which strips the first and last
%   quote of a line holding more than two; the extra outer pair is there
%   to be stripped, so a quoted program path survives.
%
%   Pure: nothing is run, so the line can be shown or tested anywhere.
%
%   Optional Name-Value Arguments:
%     IsWindows        - build the cmd.exe form (default ispc).
%     CleanLibraryPath - restore LD_LIBRARY_PATH on Linux (default true).
%
%   Example:
%     exe = ndi.fun.findExecutable('ffmpeg');
%     [status, out] = system(ndi.fun.systemCommandLine(exe, {'-version'}));
%
%   See also: ndi.fun.findExecutable, ndi.common.systemCurlEnvPrefix, system

    arguments
        exePath {mustBeTextScalar, mustBeNonzeroLengthText}
        args {mustBeText} = {}
        options.IsWindows (1,1) logical = ispc
        options.CleanLibraryPath (1,1) logical = true
    end

    args = cellstr(args);
    parts = cell(1, numel(args) + 1);
    parts{1} = quote(char(exePath), options.IsWindows);
    for i = 1:numel(args)
        parts{i+1} = quote(args{i}, options.IsWindows);
    end
    body = strjoin(parts, ' ');

    if options.IsWindows
        cmd = ['"' body '"'];
    else
        prefix = '';
        if options.CleanLibraryPath && ~ispc
            prefix = ndi.common.systemCurlEnvPrefix();
        end
        cmd = [prefix body];
    end
end

function s = quote(str, isWindows)
    if isWindows
        s = ['"' strrep(str, '"', '""') '"'];
    else
        s = ['''' strrep(str, '''', '''\''''') ''''];
    end
end
