function exePath = findExecutable(name, options)
% FINDEXECUTABLE - the absolute path of an external program NDI runs
%
%   EXEPATH = ndi.fun.findExecutable(NAME, ...) returns the absolute path
%   of the program NAME (for example 'ffmpeg' or 'Rscript'), searching,
%   in order:
%
%     a) 'Path', if given: an explicitly passed program always wins (and
%        an error is raised if it does not exist)
%     b) the preference named by 'Preference', if it is set and the file
%        exists
%     c) each environment variable in 'EnvironmentVariables'. Its value
%        may be the program itself, or a folder holding NAME directly or
%        in a bin subfolder (so R_HOME works)
%     d) each folder in 'Folders' (the program's own install locations).
%        One path component may hold a * wildcard, e.g.
%        'C:\Program Files\R\R-*\bin'; matches are tried newest name
%        first
%     e) /usr/local/bin, /opt/homebrew/bin and /usr/bin (not on Windows)
%     f) the user's login shell: `/bin/sh -lc 'command -v NAME'`, or
%        `where NAME` on Windows. A MATLAB started from the macOS Dock
%        does not see the PATH a terminal does, so a plain `which`
%        misses Homebrew programs.
%
%   On Windows '.exe' is appended to NAME for steps c-e.
%
%   Steps d-f are cached in a persistent containers.Map for the rest of
%   the MATLAB session; a cached path that has since disappeared is
%   looked up again. ndi.fun.findExecutable('clear') empties the cache
%   (ndi.fun.clearAllCaches does too).
%
%   NAME must consist of letters, digits, '_' and '-' only; it is checked
%   before anything is passed to a shell.
%
%   If the program cannot be found, 'ndi:fun:findExecutable:notFound' is
%   raised, followed by 'InstallHint'.
%
%   Optional Name-Value Arguments:
%     Path                 - explicit program path (default '').
%     Preference           - dotted ndi.preferences path, e.g.
%                            'Tools.FFmpegPath' (default '').
%     EnvironmentVariables - string array of variable names (default none).
%     Folders              - string array of install folders (default none).
%     InstallHint          - text appended to the not-found error.
%     Refresh              - ignore the cache (default false).
%     IsWindows            - search as on Windows (default ispc). The
%                            shell lookup (step f) is skipped when this
%                            does not match the real platform.
%
%   Example:
%     p = ndi.fun.findExecutable('ffmpeg', 'Preference', 'Tools.FFmpegPath', ...
%         'EnvironmentVariables', "FFMPEG_BINARY");
%
%   See also: ndi.fun.systemCommandLine, ndi.fun.data.avi2mp4,
%             ndi.fun.data.prism2csv

    arguments
        name (1,:) char
        options.Path (1,:) char = ''
        options.Preference (1,:) char = ''
        options.EnvironmentVariables string = string.empty
        options.Folders string = string.empty
        options.InstallHint (1,:) char = ''
        options.Refresh (1,1) logical = false
        options.IsWindows (1,1) logical = ispc
    end

    persistent cache
    if isempty(cache) || ~isa(cache, 'containers.Map')
        cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
    end

    if strcmp(name, 'clear')
        cache = containers.Map('KeyType', 'char', 'ValueType', 'char');
        exePath = '';
        return
    end

    if isempty(regexp(name, '^[A-Za-z0-9_-]+$', 'once'))
        error('ndi:fun:findExecutable:invalidName', ...
            ['Program names may contain only letters, digits, ''_'' and ' ...
             '''-''; got "%s".'], name);
    end

    if options.IsWindows
        fileName = [name '.exe'];
    else
        fileName = name;
    end

    % a) An explicit path always wins.
    explicitPath = strtrim(options.Path);
    if ~isempty(explicitPath)
        if ~isfile(explicitPath)
            error('ndi:fun:findExecutable:badPath', ...
                'The %s program given, %s, does not exist.', name, explicitPath);
        end
        exePath = explicitPath;
        return
    end

    % b) The preference, read on every call so a change takes effect.
    if ~isempty(options.Preference)
        try
            v = strtrim(char(ndi.preferences.get(options.Preference)));
        catch
            v = '';
        end
        if ~isempty(v) && isfile(v)
            exePath = v;
            return
        end
    end

    % c) Environment variables: the program, or a folder holding it.
    for i = 1:numel(options.EnvironmentVariables)
        v = strtrim(getenv(char(options.EnvironmentVariables(i))));
        if isempty(v)
            continue
        end
        if isfile(v)
            exePath = v;
            return
        end
        for candidate = {fullfile(v, fileName), fullfile(v, 'bin', fileName)}
            if isfile(candidate{1})
                exePath = candidate{1};
                return
            end
        end
    end

    if ~options.Refresh && isKey(cache, fileName) && isfile(cache(fileName))
        exePath = cache(fileName);
        return
    end

    % d) - e) Install folders.
    folders = {};
    for i = 1:numel(options.Folders)
        folders = [folders, expandWildcard(char(options.Folders(i)))]; %#ok<AGROW>
    end
    if ~options.IsWindows
        folders = [folders, {'/usr/local/bin', '/opt/homebrew/bin', '/usr/bin'}];
    end
    for i = 1:numel(folders)
        if isempty(folders{i})
            continue
        end
        candidate = fullfile(folders{i}, fileName);
        if isfile(candidate)
            exePath = candidate;
            cache(fileName) = exePath;
            return
        end
    end

    % f) The user's own shell.
    if options.IsWindows == ispc
        exePath = shellLookup(name, options.IsWindows);
        if ~isempty(exePath)
            cache(fileName) = exePath;
            return
        end
    end

    msg = sprintf('Could not find the %s program.', name);
    if ~isempty(options.InstallHint)
        msg = [msg ' ' options.InstallHint];
    end
    error('ndi:fun:findExecutable:notFound', '%s', msg);
end

function folders = expandWildcard(pattern)
% Expand one * wildcard in a single path component; newest name first.
    if isempty(pattern)
        folders = {};
        return
    end
    if ~contains(pattern, '*')
        folders = {pattern};
        return
    end
    % An absolute POSIX path splits with a leading '', which strjoin
    % turns back into the leading separator.
    parts = regexp(pattern, '[\\/]', 'split');
    k = find(contains(parts, '*'), 1);
    base = strjoin(parts(1:k-1), filesep);
    rest = parts(k+1:end);
    d = dir(fullfile(base, parts{k}));
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    names = sort({d.name});
    names = names(end:-1:1);
    folders = cell(1, numel(names));
    for i = 1:numel(names)
        folders{i} = fullfile(base, names{i}, rest{:});
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
