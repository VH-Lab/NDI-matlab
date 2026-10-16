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
%     e) /usr/local/bin and /opt/homebrew/bin (not on Windows)
%     f) the user's login shell: `/bin/sh -lc 'command -v NAME'`, or
%        `where NAME` on Windows
%
%   On Windows '.exe' is appended to NAME for steps b-e.
%
%   Steps b-f are cached in a persistent containers.Map for the rest of
%   the MATLAB session; a cached path that has since disappeared is
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
%             ndi.python.clearCommandCache, ndi.python.ndiHome

    arguments
        name (1,:) char
        options.Refresh (1,1) logical = false
        options.IsWindows (1,1) logical = ispc
    end

    persistent cache
    if isempty(cache) || ~isa(cache, 'containers.Map')
        cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
    end

    if strcmp(name, 'clear')
        cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
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

    if options.IsWindows
        fileName = [name '.exe'];
    else
        fileName = name;
    end
    cacheKey = fileName;

    if ~options.Refresh && isKey(cache, cacheKey) && isfile(cache(cacheKey))
        commandPath = cache(cacheKey);
        return
    end

    % b) - e) Known folders.
    folders = {};
    envBin = getenv('NDI_PYTHON_BIN');
    if ~isempty(envBin)
        folders = [folders, strsplit(envBin, pathsep)];
    end
    folders{end+1} = fullfile(ndi.python.ndiHome('IsWindows', options.IsWindows), 'bin');
    folders{end+1} = fullfile(ndi.python.userHome('IsWindows', options.IsWindows), ...
        '.local', 'bin');
    if ~options.IsWindows
        folders = [folders, {'/usr/local/bin', '/opt/homebrew/bin'}];
    end
    for i = 1:numel(folders)
        if isempty(folders{i})
            continue
        end
        candidate = fullfile(folders{i}, fileName);
        if isfile(candidate)
            commandPath = candidate;
            cache(cacheKey) = commandPath;
            return
        end
    end

    % f) The user's own shell.
    if options.IsWindows == ispc
        commandPath = shellLookup(name, options.IsWindows);
        if ~isempty(commandPath)
            cache(cacheKey) = commandPath;
            return
        end
    end

    error('ndi:python:commandNotFound', ...
        ['Could not find NDI-python''s "%s" command. Install NDI-python''s ' ...
         'command-line tools by running ndi.python.install() in MATLAB, ' ...
         'or set the environment variable NDI_PYTHON_BIN to the folder ' ...
         'that holds it.'], name);
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

function p = shellLookup(name, isWindows)
% Ask the user's shell where NAME is. NAME has already been validated.
    p = '';
    if isWindows
        cmd = ['where ' name];
    else
        cmd = sprintf('/bin/sh -lc ''command -v %s''', name);
    end
    try
        [status, out] = system(cmd);
    catch
        return
    end
    if status ~= 0
        return
    end
    % A login shell may print banners first; `where` may list several
    % matches. Take the first line that names an existing file.
    lines = cellstr(strtrim(splitlines(string(out))));
    for i = 1:numel(lines)
        if ~isempty(lines{i}) && isfile(lines{i})
            p = lines{i};
            return
        end
    end
end
