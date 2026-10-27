function commandPath = findCommand(name, options)
% FINDCOMMAND - the absolute path of one of NDI-python's command-line tools
%
%   COMMANDPATH = ndi.python.findCommand(NAME) returns the absolute path
%   of the NDI-python console script NAME (for example 'ndi',
%   'napariViewGEF' or 'napariViewLightsheet'), searching, in order:
%
%     a) the explicit per-command preference, if it is set and the file
%        exists:
%          napariViewGEF        - GUI.GEFManager.ViewerLauncher
%          napariViewLightsheet - GUI.LightsheetZarrManager.ViewerLauncher
%        (the legacy default /usr/local/bin/<NAME> is not treated as an
%        explicit choice; it is still found at step e)
%     b) the folder(s) in the environment variable NDI_PYTHON_BIN
%        (several may be given, separated by pathsep)
%     c) <NDI_HOME>/bin, i.e. ~/.ndi/bin, where ndi.python.install puts
%        them (see ndi.python.ndiHome)
%     d) ~/.local/bin, where a plain `uv tool install` puts them
%     e) /usr/local/bin, /opt/homebrew/bin and /usr/bin (not on Windows)
%     f) the user's login shell: `/bin/sh -lc 'command -v NAME'`, or
%        `where NAME` on Windows
%
%   Steps b-f are done by ndi.fun.findExecutable, the lookup NDI uses for
%   every external program (ffmpeg, Rscript, ...); this function adds
%   NDI-python's own folders and preferences in front of it.
%
%   On Windows '.exe' is appended to NAME for steps b-e.
%
%   Steps b-f are cached for the rest of the MATLAB session (in
%   ndi.fun.findExecutable); a cached path that has since disappeared is
%   looked up again. The preference (step a) is read on every call, so
%   changing it takes effect at once.
%
%   ndi.python.findCommand('clear') empties the cache (see also
%   ndi.python.clearCommandCache); ndi.python.install does this itself.
%
%   NAME must consist of letters and digits only; it is checked before
%   anything is passed to a shell.
%
%   If the command cannot be found, the error 'ndi:python:commandNotFound'
%   is raised, naming ndi.python.install().
%
%   Optional Name-Value Arguments:
%     Refresh   - ignore the cache and search again (default false).
%     IsWindows - search as on Windows (default ispc). Lets the Windows
%                 naming be tested on any platform; the shell lookup
%                 (step f) is skipped when it does not match the real
%                 platform.
%
%   Example:
%     p = ndi.python.findCommand('napariViewGEF');
%
%   See also: ndi.python.install, ndi.python.launch,
%             ndi.python.clearCommandCache, ndi.python.ndiHome,
%             ndi.fun.findExecutable

    arguments
        name (1,:) char
        options.Refresh (1,1) logical = false
        options.IsWindows (1,1) logical = ispc
    end

    if strcmp(name, 'clear')
        ndi.fun.findExecutable('clear');
        commandPath = '';
        return
    end

    if isempty(regexp(name, '^[A-Za-z0-9]+$', 'once'))
        error('ndi:python:invalidCommandName', ...
            ['Command names may contain only letters and digits; ' ...
             'got "%s".'], name);
    end

    % a) An explicit preference wins, and is never cached.
    commandPath = preferredPath(name);
    if ~isempty(commandPath)
        return
    end

    % b) - d) NDI-python's own folders, searched before the standard ones.
    folders = string.empty;
    envBin = getenv('NDI_PYTHON_BIN');
    if ~isempty(envBin)
        folders = string(strsplit(envBin, pathsep));
    end
    folders = [folders, ...
        string(fullfile(ndi.python.ndiHome('IsWindows', options.IsWindows), 'bin')), ...
        string(fullfile(ndi.python.userHome('IsWindows', options.IsWindows), '.local', 'bin'))];

    % b) - f) through the shared lookup.
    try
        commandPath = ndi.fun.findExecutable(name, 'Folders', folders, ...
            'Refresh', options.Refresh, 'IsWindows', options.IsWindows);
    catch ME
        if ~strcmp(ME.identifier, 'ndi:fun:findExecutable:notFound')
            rethrow(ME);
        end
        error('ndi:python:commandNotFound', ...
            ['Could not find NDI-python''s "%s" command. Install NDI-python''s ' ...
             'command-line tools by running ndi.python.install() in MATLAB, ' ...
             'or set the environment variable NDI_PYTHON_BIN to the folder ' ...
             'that holds it.'], name);
    end
end

function p = preferredPath(name)
% The explicit preference for NAME, if there is one naming an existing file.
    p = '';
    switch name
        case 'napariViewGEF'
            prefPath = 'GUI.GEFManager.ViewerLauncher';
        case 'napariViewLightsheet'
            prefPath = 'GUI.LightsheetZarrManager.ViewerLauncher';
        otherwise
            return
    end
    try
        v = strtrim(char(ndi.preferences.get(prefPath)));
    catch
        return
    end
    % The old default was persisted for anyone who saved a preference;
    % it is a fallback (step e), not a choice the user made.
    if isempty(v) || strcmp(v, ['/usr/local/bin/' name])
        return
    end
    if isfile(v)
        p = v;
    end
end
