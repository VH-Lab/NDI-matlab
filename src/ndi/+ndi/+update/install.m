function result = install(options)
% INSTALL - update NDI-matlab to the newest available version
%
%   RESULT = ndi.update.install()
%
%   Checks for an update with ndi.update.check and, after asking for
%   confirmation, installs it in the way that matches how NDI-matlab was
%   installed:
%
%     - git installs: runs ndi_install on the folder that holds NDI-matlab,
%       which pulls the latest main branch of NDI-matlab and updates (or
%       clones) its dependencies. Uncommitted changes in those repositories
%       are stashed by ndi_install. The NDI-matlab clone must be on the
%       main branch. If you have changed code (edited or added files, or
%       made local commits) in NDI-matlab or a dependency, the changes are
%       listed first and you are asked whether to update anyway; the
%       default answer is No.
%     - toolbox installs: downloads the .mltbx file attached to the latest
%       GitHub release and installs it over the current toolbox. Restart
%       MATLAB afterwards so that no old copy of a class stays in memory.
%       (If the toolbox came from the Add-On Explorer, updating from the
%       Add-On Manager does the same.)
%
%   After either kind of update, NDI's in-memory caches are cleared with
%   ndi.fun.clearAllCaches, so document definitions, schemas and lookups
%   are re-read from the new files.
%
%   If NDI-python was installed with ndi.python.install (or the NDI
%   installer) and is behind its main branch, it is updated afterwards by
%   running ndi.python.install again, after asking (Confirm). This happens
%   even if NDI-matlab itself is up to date. See ndi.update.checkPython.
%
%   RESULT is the structure returned by ndi.update.check before updating.
%
%   RESULT = ndi.update.install(Name, Value) accepts:
%       Confirm      - ask before installing (default true)
%       Force        - install even if no update was found (default false)
%       AllowModified - with Confirm=false, update even if you have changed
%                      code (default false, which stops with an error
%                      listing the changes instead). Ignored when Confirm
%                      is true, because you are asked instead.
%       Dependencies - for git installs, the DEPENDENCIES argument passed to
%                      ndi_install: 1 for the NDI dependencies (default) or
%                      2 for the full VH-Lab tools suite
%       Timeout      - seconds to wait for GitHub (default 10)
%       IncludePython - also update NDI-python when it needs it and can be
%                      updated (default true)
%       RepoRoot     - update the git clone of NDI-matlab in this folder
%                      instead of the running copy (default "", the
%                      running copy)
%
%   Example:
%       ndi.update.install()
%
%   See also: ndi.update.check, ndi_install

    arguments
        options.Confirm (1,1) logical = true
        options.Force (1,1) logical = false
        options.AllowModified (1,1) logical = false
        options.Dependencies (1,1) double {mustBeMember(options.Dependencies, [1 2])} = 1
        options.Timeout (1,1) double {mustBePositive} = 10
        options.RepoRoot (1,1) string = ""
        options.IncludePython (1,1) logical = true
    end

    result = ndi.update.check(Verbose = true, Timeout = options.Timeout, ...
        RepoRoot = options.RepoRoot, IncludePython = options.IncludePython);

    updateMatlab = result.UpdateAvailable || options.Force;
    updatePython = options.IncludePython && result.Python.UpdateAvailable && ...
        result.Python.CanInstall;
    if ~updateMatlab && ~updatePython
        return
    end

    if updateMatlab
        switch result.InstallType
            case "git"
                installGit(result, options);
            case "toolbox"
                installToolbox(result, options);
            otherwise
                error('ndi:update:install:unknownInstall', ...
                    ['Could not tell how NDI-matlab was installed. Reinstall with ' ...
                     'ndi_install or from the Add-On Explorer.']);
        end
    end

    if updatePython
        installPython(result.Python, options);
    end
end

function installPython(py, options)
    if options.Confirm
        prompt = "Update NDI-python (" + py.CurrentVersion + " -> " + ...
            py.LatestVersion + ") by running its installer again? Y/N [Y]: ";
        if ~confirmed(prompt)
            disp('NDI-python update cancelled.');
            return
        end
    end
    % AddToPath=false: an update leaves the user's shell profile as it is.
    ndi.python.install(AddToPath = false);
    disp('NDI-python update finished.');
end

function installGit(result, options)
    repoRoot = result.RepoRoot;

    if result.Branch ~= "main"
        error('ndi:update:install:notOnMain', ...
            ['NDI-matlab in %s is on branch ''%s''. Updates come from main; ' ...
             'run ''git checkout main'' there first.'], repoRoot, result.Branch);
    end

    if result.HasModifications
        summary = ndi.update.modificationSummary(result, MaxFiles = 25);
        if options.Confirm
            disp(summary);
            prompt = "Update anyway? Y/N [N]: ";
            if ~confirmed(prompt, false)
                disp('Update cancelled; your changes were not touched.');
                return
            end
        elseif ~options.AllowModified
            error('ndi:update:install:localModifications', ...
                ['%s\n\nUpdate cancelled. Commit, move or discard these ' ...
                 'changes, or call ndi.update.install(Confirm=false, ' ...
                 'AllowModified=true) to update anyway.'], summary);
        end
    elseif options.Confirm
        prompt = "This will run ndi_install to update NDI-matlab and its " + ...
            "dependencies in " + fileparts(repoRoot) + "." + newline + ...
            "Continue? Y/N [Y]: ";
        if ~confirmed(prompt)
            disp('Update cancelled.');
            return
        end
    end

    if ~isfile(fullfile(repoRoot, 'ndi_install.m'))
        error('ndi:update:install:noInstaller', ...
            'Could not find ndi_install.m in %s.', repoRoot);
    end

    % Put this clone's ndi_install first on the path, so it is the one run.
    addpath(char(repoRoot));
    ndi_install(char(fileparts(repoRoot)), options.Dependencies);
    clearCaches();
    disp('NDI-matlab update finished.');
end

function installToolbox(result, options)
    if strlength(result.MltbxUrl) == 0
        error('ndi:update:install:noMltbx', ...
            ['The latest NDI-matlab release has no toolbox file attached. ' ...
             'Update from the Add-On Manager, or see %s.'], result.ReleaseUrl);
    end

    if options.Confirm
        prompt = "This will download and install NDI-matlab " + ...
            result.LatestVersion + " over the installed version " + ...
            result.CurrentVersion + ". Any files you changed or added inside " + ...
            "the installed toolbox folder will be lost." + newline + ...
            "Continue? Y/N [Y]: ";
        if ~confirmed(prompt)
            disp('Update cancelled.');
            return
        end
    end

    mltbxFile = fullfile(tempdir, "NDI-matlab-" + result.LatestVersion + ".mltbx");
    cleanupFile = onCleanup(@() deleteIfPresent(mltbxFile));
    fprintf('Downloading %s...\n', result.MltbxUrl);
    websave(mltbxFile, result.MltbxUrl, weboptions('Timeout', 120));

    disp('Installing toolbox...');
    matlab.addons.install(char(mltbxFile), true, 'overwrite');
    clear cleanupFile
    clearCaches();

    fprintf(['NDI-matlab %s is installed. Please restart MATLAB before ' ...
        'using NDI.\n'], result.LatestVersion);
end

function clearCaches()
    % Drop in-memory copies of definitions, schemas and lookups that the old
    % version built, so they are re-read from the updated files. Classes
    % already loaded stay old until MATLAB restarts.
    try
        ndi.fun.clearAllCaches();
    catch ME
        warning('ndi:update:install:clearCaches', ...
            'Could not clear NDI caches after updating: %s', ME.message);
    end
end

function tf = confirmed(prompt, default)
    % Ask a Y/N question; an empty reply gives DEFAULT (true unless given).
    if nargin < 2
        default = true;
    end
    reply = strtrim(input(char(prompt), 's'));
    if isempty(reply)
        tf = default;
    else
        tf = strcmpi(reply, 'y') || strcmpi(reply, 'yes');
    end
end

function deleteIfPresent(f)
    if isfile(f)
        delete(f);
    end
end
