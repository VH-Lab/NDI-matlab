function result = install(options)
% INSTALL - update NDI-matlab to the newest available version
%
%   RESULT = ndi.update.install()
%
%   Checks for an update with ndi.update.check and, after asking for
%   confirmation, installs it in the way that matches how NDI-matlab was
%   installed:
%
%     - git installs: pulls the latest main branch of NDI-matlab, then runs
%       ndi_install on the folder that holds NDI-matlab, which updates (or
%       clones) its dependencies. Uncommitted changes in those repositories
%       are stashed for the pull and put back afterwards (if they no
%       longer apply cleanly, 'git stash list' still has them). The
%       NDI-matlab clone must be on the main branch. If you have changed
%       code (edited tracked files, or made local commits) in NDI-matlab, a
%       dependency or a calculator repository, the changes are
%       listed first and you are asked whether to update anyway; the
%       default answer is No. Untracked files of your own are left alone and
%       need no answer, unless one is at a path the update adds a file to:
%       git will not overwrite it, so the update stops before starting and
%       asks you to move it.
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
%   NDIcalc-*-matlab calculator repositories (git clones; see
%   ndi.update.check) that are behind their upstream branch are then
%   pulled the same way, stashing and restoring edits. This happens in
%   either kind of install, and even if NDI-matlab itself is up to date.
%   If you have changed code in them and were not already asked about it,
%   you are asked (Confirm) or AllowModified decides, as above.
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
%       IncludeCalculators - also update the NDIcalc-*-matlab repositories
%                      that are behind (default true)
%       RepoRoot     - update the git clone of NDI-matlab in this folder
%                      instead of the running copy (default "", the
%                      running copy)
%       Packages     - update only these packages (default: all that
%                      need it): "NDI-matlab" (or "NDI-matlab toolbox"),
%                      names of dependencies and calculator repositories
%                      (as in ndi.update.check's Dependencies and
%                      Calculators), and "NDI-python". Named packages that
%                      are up to date are skipped. For a git install,
%                      ndi_install is then given just the named
%                      dependencies, the others are not touched, and
%                      NDI-matlab need not be on main unless it is named.
%                      Only changes in the named packages need consent.
%
%   Example:
%       ndi.update.install()
%       ndi.update.install(Packages = ["DID-matlab", "NDIcalc-vis-matlab"])
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
        options.IncludeCalculators (1,1) logical = true
        options.Packages (1,:) string = string.empty(1, 0)
    end

    result = ndi.update.check(Verbose = true, Timeout = options.Timeout, ...
        RepoRoot = options.RepoRoot, IncludePython = options.IncludePython, ...
        IncludeCalculators = options.IncludeCalculators);

    sel = selectPackages(result, options.Packages);
    if sel.All
        updateMatlab = result.UpdateAvailable || options.Force;
    elseif result.InstallType == "git"
        updateMatlab = sel.Ndi || ~isempty(sel.DepUrls);
    else
        updateMatlab = sel.Ndi && result.UpdateAvailable;
    end
    updateCalcs = options.IncludeCalculators && any(sel.Calcs);
    updatePython = options.IncludePython && sel.Python && ...
        result.Python.UpdateAvailable && result.Python.CanInstall;
    if ~updateMatlab && ~updateCalcs && ~updatePython
        return
    end

    % True once the user has agreed to every change listed in
    % result.Modifications (installGit asks about all of them, unless only
    % some packages are being updated).
    modsAgreed = false;
    if updateMatlab
        switch result.InstallType
            case "git"
                modsAgreed = installGit(result, options, sel) && sel.All;
            case "toolbox"
                installToolbox(result, options);
            otherwise
                error('ndi:update:install:unknownInstall', ...
                    ['Could not tell how NDI-matlab was installed. Reinstall with ' ...
                     'ndi_install or from the Add-On Explorer.']);
        end
    end

    if updateCalcs
        installCalculators(result, options, modsAgreed, sel.Calcs);
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

function modsAgreed = installGit(result, options, sel)
    % Updates NDI-matlab and its dependencies, or, when only some packages
    % were named (SEL), just those. MODSAGREED is true if the update went
    % ahead, so that the user agreed to (or AllowModified covered) the
    % changes in the repositories it touches.
    modsAgreed = false;
    repoRoot = result.RepoRoot;

    if sel.All
        pullNdi = result.CommitsBehind > 0;
        runInstaller = true;
        mods = result.Modifications;
    else
        pullNdi = sel.Ndi;
        runInstaller = ~isempty(sel.DepUrls);
        touched = sel.DepNames;
        if pullNdi
            touched(end+1) = "NDI-matlab";
        end
        mods = result.Modifications(arrayfun(@(m) any(m.Name == touched), ...
            result.Modifications));
    end

    % Updating only dependencies leaves NDI-matlab's branch alone.
    if (sel.All || pullNdi) && result.Branch ~= "main"
        error('ndi:update:install:notOnMain', ...
            ['NDI-matlab in %s is on branch ''%s''. Updates come from main; ' ...
             'run ''git checkout main'' there first.'], repoRoot, result.Branch);
    end

    blocking = blockingFiles(struct('Modifications', mods));
    if ~isempty(blocking)
        % git pull would stop part-way rather than overwrite these, so no
        % answer to "update anyway?" could make the update work.
        error('ndi:update:install:untrackedFilesInTheWay', ...
            ['The update adds files at these paths, where you have untracked ' ...
             'files of your own. git will not overwrite them, so the update ' ...
             'would stop part-way. Move or rename them, then update again:\n%s'], ...
            strjoin("  " + blocking, newline));
    end

    if ~isempty(mods)
        summary = ndi.update.modificationSummary(struct('Modifications', mods), ...
            MaxFiles = 25);
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
        if sel.All
            prompt = "This will run ndi_install to update NDI-matlab and its " + ...
                "dependencies in " + fileparts(repoRoot) + "." + newline + ...
                "Continue? Y/N [Y]: ";
        else
            prompt = "This will update " + strjoin(touched, ", ") + " in " + ...
                fileparts(repoRoot) + "." + newline + "Continue? Y/N [Y]: ";
        end
        if ~confirmed(prompt)
            disp('Update cancelled.');
            return
        end
    end

    if runInstaller && ~isfile(fullfile(repoRoot, 'ndi_install.m'))
        error('ndi:update:install:noInstaller', ...
            'Could not find ndi_install.m in %s.', repoRoot);
    end

    modsAgreed = true;
    % Pull NDI-matlab itself first, so that main's ndi_install.m is the one
    % run: an older ndi_install updates only the repositories listed in
    % requirements.txt, which does not include NDI-matlab.
    if pullNdi
        fprintf('Updating NDI-matlab in %s...\n', repoRoot);
        pullRepo(repoRoot, "origin main");
    end

    if runInstaller
        % Put this clone's ndi_install first on the path, so it is the one run.
        addpath(char(repoRoot));
        if sel.All
            ndi_install(char(fileparts(repoRoot)), options.Dependencies);
        else
            % Given a list, ndi_install updates (or clones) just those.
            ndi_install(char(fileparts(repoRoot)), cellstr(sel.DepUrls));
        end
    end
    clearCaches();
    disp('NDI-matlab update finished.');
end

function installCalculators(result, options, modsAgreed, which)
    % Pulls the NDIcalc-*-matlab clones selected by the logical mask WHICH
    % (each behind its upstream branch). MODSAGREED: the user already
    % agreed to result.Modifications.
    calcs = result.Calculators(which);
    names = [calcs.Name];
    mods = result.Modifications(arrayfun(@(m) any(m.Name == names), result.Modifications));

    blocking = blockingFiles(struct('Modifications', mods));
    if ~isempty(blocking)
        error('ndi:update:install:untrackedFilesInTheWay', ...
            ['The calculator update adds files at these paths, where you have ' ...
             'untracked files of your own. git will not overwrite them, so the ' ...
             'update would stop part-way. Move or rename them, then update again:\n%s'], ...
            strjoin("  " + blocking, newline));
    end

    if ~modsAgreed
        if ~isempty(mods)
            summary = ndi.update.modificationSummary(struct('Modifications', mods), ...
                MaxFiles = 25);
            if options.Confirm
                disp(summary);
                if ~confirmed("Update the calculators anyway? Y/N [N]: ", false)
                    disp('Calculator update cancelled; your changes were not touched.');
                    return
                end
            elseif ~options.AllowModified
                error('ndi:update:install:localModifications', ...
                    ['%s\n\nUpdate cancelled. Commit, move or discard these ' ...
                     'changes, or call ndi.update.install(Confirm=false, ' ...
                     'AllowModified=true) to update anyway.'], summary);
            end
        elseif options.Confirm
            prompt = "Update the calculators " + strjoin(names, ", ") + ...
                " (git pull)? Y/N [Y]: ";
            if ~confirmed(prompt)
                disp('Calculator update cancelled.');
                return
            end
        end
    end

    for i = 1:numel(calcs)
        fprintf('Updating %s in %s...\n', calcs(i).Name, calcs(i).Path);
        pullRepo(calcs(i).Path);
    end
    clearCaches();
    disp('Calculator update finished.');
end

function sel = selectPackages(result, packages)
    % Which packages to update. With no PACKAGES, all that need it
    % (sel.All). Otherwise only the named ones: "NDI-matlab" (or "NDI-matlab
    % toolbox"), dependency and calculator names, and "NDI-python". Named
    % packages that are up to date are left alone.
    calcBehind = logical(arrayfun(@(c) c.Status == "behind", result.Calculators));
    sel = struct('All', isempty(packages), 'Ndi', false, 'DepNames', strings(1, 0), ...
        'DepUrls', strings(1, 0), 'Calcs', calcBehind, 'Python', true);
    if sel.All
        return
    end

    depNames = strings(1, 0);
    for i = 1:numel(result.Dependencies)
        depNames(end+1) = result.Dependencies(i).Name; %#ok<AGROW>
    end
    calcNames = strings(1, 0);
    for i = 1:numel(result.Calculators)
        calcNames(end+1) = result.Calculators(i).Name; %#ok<AGROW>
    end
    known = ["NDI-matlab", "NDI-matlab toolbox", "NDI-python", depNames, calcNames];
    unknown = setdiff(packages, known);
    if ~isempty(unknown)
        error('ndi:update:install:unknownPackage', ...
            'Unknown package(s): %s. The packages are: %s.', ...
            strjoin(unknown, ", "), strjoin(known, ", "));
    end

    sel.Ndi = any(ismember(["NDI-matlab", "NDI-matlab toolbox"], packages));
    if result.InstallType == "git"
        sel.Ndi = sel.Ndi && result.CommitsBehind > 0;
    end
    for i = 1:numel(result.Dependencies)
        d = result.Dependencies(i);
        if any(d.Name == packages) && ismember(d.Status, ["behind", "missing"])
            sel.DepNames(end+1) = d.Name;
            sel.DepUrls(end+1) = d.Url;
        end
    end
    sel.Calcs = calcBehind & ismember(calcNames, packages);
    sel.Python = any(packages == "NDI-python");
end

function files = blockingFiles(result)
    % Full paths of the untracked files in the way of files the update adds.
    files = strings(0, 1);
    for i = 1:numel(result.Modifications)
        m = result.Modifications(i);
        files = [files; fullfile(m.Path, m.BlockingFiles)]; %#ok<AGROW>
    end
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
