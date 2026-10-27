function prefix = environmentPrefix(options)
% ENVIRONMENTPREFIX - the shell prefix that marks a command as started by MATLAB
%
%   PREFIX = ndi.python.environmentPrefix() returns the text to put in
%   front of a command line run through SYSTEM so that NDI-python's
%   console scripts see the environment variable NDI_FROM_MATLAB=1:
%
%       Linux/macOS:  'NDI_FROM_MATLAB=1 '
%       Windows:      'set NDI_FROM_MATLAB=1&& '
%
%   With that variable set, the Python side removes the library paths
%   MATLAB exports (LD_LIBRARY_PATH, DYLD_*) before loading anything, so
%   no shell wrapper is needed between MATLAB and the console script.
%
%   There is no space before && on Windows: cmd.exe would keep it in the
%   value.
%
%   Optional Name-Value Arguments:
%     IsWindows - build the cmd.exe form (default ispc).
%
%   See also: ndi.python.commandLine, ndi.python.launch

    arguments
        options.IsWindows (1,1) logical = ispc
    end

    if options.IsWindows
        prefix = 'set NDI_FROM_MATLAB=1&& ';
    else
        prefix = 'NDI_FROM_MATLAB=1 ';
    end
end
