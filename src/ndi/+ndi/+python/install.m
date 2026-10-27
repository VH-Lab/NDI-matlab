function binPath = install(options)
% INSTALL - install NDI-python's command-line tools from inside MATLAB
%
%   BINPATH = ndi.python.install() downloads NDI-python's end-user
%   installer and runs it. The installer (uv-based) puts a private Python
%   and NDI-python under NDI_HOME (~/.ndi, see ndi.python.ndiHome) and the
%   console scripts in ~/.ndi/bin:
%
%       ndi, napariViewGEF, napariViewLightsheet, uv   (.exe on Windows)
%
%   BINPATH is that folder, as the installer reports it on its last line
%   of output ("NDI installed: <folder>"). Afterwards
%   ndi.python.findCommand finds the commands there with no further
%   setup; its cache is cleared so a previous miss is forgotten.
%
%   The installer is
%       <Source>/install-ndi.sh    run with /bin/sh   (Linux, macOS)
%       <Source>/install-ndi.ps1   run with powershell -NoProfile
%                                  -ExecutionPolicy Bypass -File (Windows)
%   and is always run non-interactively (--yes / -Yes). Its output is
%   shown as it runs. A non-zero exit status raises
%   'ndi:python:installFailed' with the installer's output.
%
%   Optional Name-Value Arguments:
%     Uninstall - remove what the installer installed (--uninstall /
%                 -Uninstall) instead of installing. BINPATH is then
%                 whatever the installer reported, usually ''.
%                 Default false.
%     AddToPath - let the installer add ~/.ndi/bin to the PATH of your
%                 shell profile, so the commands also work in a terminal.
%                 false passes --no-path / -NoPath. MATLAB does not need
%                 this. Default true.
%     Source    - where the installer scripts are: a URL (the folder
%                 that holds them) or a local folder. Default
%                 https://raw.githubusercontent.com/Waltham-Data-Science/NDI-python/main/install
%
%   Example:
%     ndi.python.install();
%     ndi.python.findCommand('napariViewGEF')
%
%   See also: ndi.python.findCommand, ndi.python.ndiHome,
%             ndi.python.clearCommandCache

    arguments
        options.Uninstall (1,1) logical = false
        options.AddToPath (1,1) logical = true
        options.Source (1,:) char = ...
            'https://raw.githubusercontent.com/Waltham-Data-Science/NDI-python/main/install'
    end

    if ispc
        scriptName = 'install-ndi.ps1';
    else
        scriptName = 'install-ndi.sh';
    end

    workDir = tempname;
    mkdir(workDir);
    cleanup = onCleanup(@() rmdir(workDir, 's'));
    scriptFile = fullfile(workDir, scriptName);

    source = options.Source;
    if isfolder(source)
        copyfile(fullfile(source, scriptName), scriptFile);
    else
        url = [regexprep(source, '/+$', '') '/' scriptName];
        try
            websave(scriptFile, url);
        catch ME
            error('ndi:python:installDownloadFailed', ...
                'Could not download the NDI-python installer from %s: %s', ...
                url, ME.message);
        end
    end

    cmd = ndi.python.installerCommand(scriptFile, ...
        'Uninstall', options.Uninstall, 'AddToPath', options.AddToPath);
    fprintf('Running: %s\n', cmd);
    [status, out] = system(cmd, '-echo');

    % Whatever happened, what is installed may have changed.
    ndi.python.clearCommandCache();

    if status ~= 0
        error('ndi:python:installFailed', ...
            'The NDI-python installer exited with status %d. Its output was:\n%s', ...
            status, out);
    end

    binPath = '';
    lines = cellstr(strtrim(splitlines(string(out))));
    lines = lines(~cellfun('isempty', lines));
    if ~isempty(lines)
        tok = regexp(lines{end}, '^NDI installed:\s*(.+)$', 'tokens', 'once');
        if ~isempty(tok)
            binPath = strtrim(tok{1});
        end
    end
end
