function result = check(options)
% CHECK - check whether a newer version of NDI-matlab is available
%
%   RESULT = ndi.update.check()
%
%   Works out how NDI-matlab was installed (see ndi.update.installType) and
%   compares the running copy with the newest one available:
%
%     - git installs (ndi_install, or a clone made by hand) are compared
%       with the latest commit on the main branch of NDI-matlab on GitHub.
%       The repositories NDI depends on (requirements.txt) that ndi_install
%       placed next to NDI-matlab are compared with their own upstream
%       branches.
%     - toolbox installs (Add-On Explorer or a .mltbx file) are compared
%       with the latest NDI-matlab release on GitHub.
%
%   NDIcalc-*-matlab calculator repositories are checked too, in either kind
%   of install: the git clones of them next to NDI-matlab (where
%   ndi_install would put them) or anywhere on the MATLAB path, each
%   against the upstream of its checked-out branch. Their results are in
%   the Calculators field and set CalculatorUpdateAvailable, not
%   UpdateAvailable.
%
%   If NDI-python is installed (its 'ndi' command is found), it is checked
%   too, against the latest commit on NDI-python's main branch; see
%   ndi.update.checkPython. Its result is in the Python field and adds a
%   line to Message, but does not set UpdateAvailable, which is about
%   NDI-matlab.
%
%   Checking a git install runs 'git fetch', which updates only the
%   remote-tracking branches; your files and checked-out branch are not
%   changed.
%
%   RESULT is a structure with fields:
%       InstallType     - "git", "toolbox", or "unknown"
%       Status          - "upToDate", "updateAvailable", "ahead" (local
%                         commits not on main), or "unknown"
%       UpdateAvailable - true if ndi.update.install would bring in changes
%       CurrentVersion  - commit (git) or version number (toolbox) running now
%       LatestVersion   - newest commit on main (git) or release (toolbox)
%       Message         - one-paragraph human-readable summary
%       Branch          - checked-out branch (git only)
%       CommitsBehind   - commits on main not in the running copy (git only)
%       CommitsAhead    - local commits not on main (git only)
%       HasModifications - true if updating would touch the user's own
%                         work in NDI-matlab or a dependency (git only): see
%                         Modifications. Untracked files alone do not count;
%                         the update leaves them where they are.
%       Modifications   - structure array, one entry per repository where
%                         updating touches the user's work (git only), with
%                         fields Name, Path, ChangedFiles (tracked files
%                         edited, deleted or staged; ndi_install stashes
%                         them for the pull and puts them back), BlockingFiles (untracked files at a path
%                         the update adds a file to; git stops rather than
%                         overwrite them, so ndi.update.install asks for them
%                         to be moved first), and CommitsAhead (local
%                         commits; merged with the update by git pull). See
%                         ndi.update.modificationSummary. Includes the
%                         calculator repositories, in either kind of
%                         install.
%       Dependencies    - structure array, one entry per dependency (git
%                         only), with fields Name, Path, Status
%                         ("upToDate", "behind", "missing", "pinned",
%                         "notFound", "notGit", or "unknown"),
%                         CommitsBehind, and CurrentVersion and
%                         LatestVersion (short commit hashes, or "")
%       Calculators     - structure array, one entry per NDIcalc-*-matlab
%                         repository found, with the fields of
%                         Dependencies (Status "upToDate", "behind",
%                         "notGit", or "unknown")
%       CalculatorUpdateAvailable - true if a calculator repository is
%                         behind its upstream branch
%       ReleaseUrl      - web page of the latest release (toolbox only)
%       MltbxUrl        - download URL of the latest toolbox (toolbox only)
%       BothInstalled   - true if a git clone and the toolbox are both
%                         installed
%       RepoRoot        - root of the git clone that was checked (git only)
%       Python          - result of ndi.update.checkPython (Status
%                         "notChecked" if IncludePython is false)
%
%   RESULT = ndi.update.check(Name, Value) accepts:
%       IncludeDependencies - also check the dependency repositories of a
%                             git install (default true)
%       Verbose             - print the summary (default true)
%       Timeout             - seconds to wait for GitHub (default 10)
%       IncludePython       - also check NDI-python, if it is installed
%                             (default true)
%       IncludeCalculators  - also check the NDIcalc-*-matlab repositories
%                             (default true)
%       RepoRoot          - check the git clone of NDI-matlab in this
%                             folder instead of the running copy (default
%                             "", the running copy). Calculators are then
%                             looked for next to that clone only, not on
%                             the MATLAB path.
%
%   Example:
%       r = ndi.update.check();
%       if r.UpdateAvailable, ndi.update.install(); end
%
%   See also: ndi.update.install, ndi.update.installType

    arguments
        options.IncludeDependencies (1,1) logical = true
        options.Verbose (1,1) logical = true
        options.Timeout (1,1) double {mustBePositive} = 10
        options.RepoRoot (1,1) string = ""
        options.IncludePython (1,1) logical = true
        options.IncludeCalculators (1,1) logical = true
    end

    [type, info] = ndi.update.installType();
    if strlength(options.RepoRoot) > 0
        type = "git";
        info.RepoRoot = options.RepoRoot;
        info.BothInstalled = false;
    end

    result = struct( ...
        'InstallType', type, ...
        'Status', "unknown", ...
        'UpdateAvailable', false, ...
        'CurrentVersion', "", ...
        'LatestVersion', "", ...
        'Message', "", ...
        'Branch', "", ...
        'CommitsBehind', NaN, ...
        'CommitsAhead', NaN, ...
        'HasModifications', false, ...
        'Modifications', emptyModifications(), ...
        'Dependencies', emptyRepos(), ...
        'Calculators', emptyRepos(), ...
        'CalculatorUpdateAvailable', false, ...
        'ReleaseUrl', "", ...
        'MltbxUrl', "", ...
        'BothInstalled', info.BothInstalled, ...
        'RepoRoot', info.RepoRoot, ...
        'Python', struct('Installed', false, 'Kind', "none", 'Status', "notChecked", ...
            'UpdateAvailable', false, 'CanInstall', false, 'Message', "", ...
            'CurrentVersion', "", 'LatestVersion', "", 'CommitsBehind', NaN));

    switch type
        case "git"
            result = checkGit(result, info, options);
        case "toolbox"
            result = checkToolbox(result, info, options);
        otherwise
            result.Message = "Could not tell how NDI-matlab was installed, " + ...
                "so cannot check for updates.";
    end

    if options.IncludeCalculators
        result = checkCalculators(result, info, options);
    end

    if result.BothInstalled
        result.Message = result.Message + newline + "Warning: the NDI-matlab " + ...
            "toolbox (version " + info.ToolboxVersion + ") is also installed. " + ...
            "Only one copy can be used at a time; consider uninstalling one " + ...
            "from the Add-On Manager or removing the git clone from the path.";
    end

    if options.IncludePython
        result.Python = ndi.update.checkPython(Timeout = options.Timeout);
        if result.Python.Installed
            result.Message = result.Message + newline + "NDI-python: " + ...
                result.Python.Message;
        end
    end

    if options.Verbose
        disp(result.Message);
    end
end

function result = checkGit(result, info, options)
    repo = info.RepoRoot;

    [s, ~] = system('git --version');
    if s ~= 0
        result.Message = "This is a git install of NDI-matlab, but the git " + ...
            "program was not found, so cannot check for updates.";
        return
    end

    [~, result.Branch] = runGit(repo, "rev-parse --abbrev-ref HEAD");
    [~, localHash] = runGit(repo, "rev-parse HEAD");
    result.CurrentVersion = shortHash(localHash);

    [s, out] = runGit(repo, "fetch --quiet origin main");
    if s ~= 0
        result.Message = "Could not reach the NDI-matlab repository on GitHub " + ...
            "to check for updates: " + out;
        return
    end

    [~, remoteHash] = runGit(repo, "rev-parse origin/main");
    [~, behind] = runGit(repo, "rev-list --count HEAD..origin/main");
    [~, ahead] = runGit(repo, "rev-list --count origin/main..HEAD");
    result.LatestVersion = shortHash(remoteHash);
    result.CommitsBehind = str2double(behind);
    result.CommitsAhead = str2double(ahead);

    mods = localModifications("NDI-matlab", repo, result.CommitsAhead, ...
        incomingNewFiles(repo, "origin/main"));

    if options.IncludeDependencies
        [result.Dependencies, depMods] = checkDependencies(repo);
        mods = [mods, depMods];
    end
    result.Modifications = mods;
    result.HasModifications = ~isempty(mods);
    depsBehind = false(1, numel(result.Dependencies));
    for i = 1:numel(result.Dependencies)
        depsBehind(i) = ismember(result.Dependencies(i).Status, ["behind", "missing"]);
    end

    if result.CommitsBehind > 0
        result.Status = "updateAvailable";
        result.Message = string(sprintf(['An NDI-matlab update is available: the main ' ...
            'branch on GitHub has %d commit(s) that you do not have ' ...
            '(you have %s, latest is %s).'], ...
            result.CommitsBehind, result.CurrentVersion, result.LatestVersion));
    elseif any(depsBehind)
        result.Status = "updateAvailable";
        result.Message = "NDI-matlab is up to date with main, but updates " + ...
            "are available for: " + strjoin([result.Dependencies(depsBehind).Name], ", ") + ".";
    elseif result.CommitsAhead > 0
        result.Status = "ahead";
        result.Message = string(sprintf(['NDI-matlab has all commits from main, plus ' ...
            '%d local commit(s) not on main (branch %s).'], ...
            result.CommitsAhead, result.Branch));
    else
        result.Status = "upToDate";
        result.Message = "NDI-matlab is up to date with the main branch on " + ...
            "GitHub (" + result.CurrentVersion + ").";
    end
    result.UpdateAvailable = result.Status == "updateAvailable";

    if result.UpdateAvailable
        if result.Branch ~= "main"
            result.Message = result.Message + newline + "Note: you are on " + ...
                "branch '" + result.Branch + "', not main. Run " + ...
                "'git checkout main' in " + repo + " before updating.";
        end
        if result.HasModifications
            result.Message = result.Message + newline + "Note: you have " + ...
                "changed code in " + strjoin([mods.Name], ", ") + ". " + ...
                "ndi.update.install will list the changes and ask before updating.";
        end
        result.Message = result.Message + newline + "Run ndi.update.install() to update.";
    end
end

function [deps, mods] = checkDependencies(repo)
    % The dependency list is read from main, so that dependencies that main
    % has added since the last update are noticed too.
    mods = emptyModifications();
    [s, txt] = runGit(repo, "show origin/main:requirements.txt");
    if s ~= 0
        reqFile = fullfile(repo, 'requirements.txt');
        if ~isfile(reqFile)
            deps = emptyRepos();
            return
        end
        txt = string(fileread(reqFile));
    end
    lines = strtrim(splitlines(txt));
    lines = lines(strlength(lines) > 0 & ~startsWith(lines, ["#", "fex://"]));

    installDir = string(fileparts(repo));
    % ndi_install always installs vhlab_vhtools next to NDI-matlab; if it is
    % there, a missing dependency is one that ndi_install has yet to clone.
    isNdiInstallLayout = isfolder(fullfile(installDir, 'vhlab_vhtools'));

    deps = emptyRepos();
    for i = 1:numel(lines)
        url = lines(i);
        pinned = contains(extractAfter(url, "://"), "@");
        name = regexprep(url, '@[^/]*$', '');
        name = regexprep(name, '\.git$', '');
        parts = split(name, "/");
        name = parts(end);
        depPath = fullfile(installDir, name);

        if pinned
            d = repoEntry(name, depPath);
            d.Status = "pinned";
        elseif ~isfolder(depPath)
            d = repoEntry(name, depPath);
            if isNdiInstallLayout
                d.Status = "missing";
            else
                d.Status = "notFound";
            end
        else
            [d, m] = checkClone(name, depPath);
            mods = [mods, m]; %#ok<AGROW>
        end
        deps(end+1) = d; %#ok<AGROW>
    end
end

function result = checkCalculators(result, info, options)
    % NDIcalc-*-matlab clones next to NDI-matlab and, for the running copy,
    % anywhere on the path. Their modifications join result.Modifications,
    % because ndi.update.install pulls them too.
    if strlength(info.RepoRoot) > 0
        installDir = string(fileparts(info.RepoRoot));
    else
        % src/ndi -> src -> NDI-matlab -> the folder holding NDI-matlab
        installDir = string(fileparts(fileparts(fileparts(info.SourceDir))));
    end
    folders = findCalculators(installDir, ...
        SearchPath = strlength(options.RepoRoot) == 0);

    calcs = emptyRepos();
    mods = emptyModifications();
    for i = 1:numel(folders)
        [~, name] = fileparts(folders(i));
        [d, m] = checkClone(string(name), folders(i));
        calcs(end+1) = d; %#ok<AGROW>
        mods = [mods, m]; %#ok<AGROW>
    end
    result.Calculators = calcs;
    result.Modifications = [result.Modifications, mods];
    result.HasModifications = ~isempty(result.Modifications);

    behind = arrayfun(@(c) c.Status == "behind", calcs);
    result.CalculatorUpdateAvailable = any(behind);
    if result.CalculatorUpdateAvailable
        result.Message = result.Message + newline + "Calculator updates are " + ...
            "available for: " + strjoin([calcs(behind).Name], ", ") + ...
            ". Run ndi.update.install() to update.";
    end
end

function [d, mods] = checkClone(name, repoDir)
    % Compares a git clone with the upstream of its checked-out branch.
    d = repoEntry(name, repoDir);
    mods = emptyModifications();
    if exist(fullfile(repoDir, '.git'), 'file') == 0
        d.Status = "notGit";
        return
    end
    [~, localHash] = runGit(repoDir, "rev-parse HEAD");
    d.CurrentVersion = shortHash(localHash);
    [s, ~] = runGit(repoDir, "fetch --quiet");
    [s2, behind] = runGit(repoDir, "rev-list --count ""HEAD..@{u}""");
    [s3, ahead] = runGit(repoDir, "rev-list --count ""@{u}..HEAD""");
    if s3 ~= 0
        ahead = "0";
    end
    mods = localModifications(name, repoDir, str2double(ahead), ...
        incomingNewFiles(repoDir, """@{u}"""));
    if s == 0 && s2 == 0
        [~, upstreamHash] = runGit(repoDir, "rev-parse ""@{u}""");
        d.LatestVersion = shortHash(upstreamHash);
        d.CommitsBehind = str2double(behind);
        if d.CommitsBehind > 0
            d.Status = "behind";
        else
            d.Status = "upToDate";
        end
    end
end

function d = repoEntry(name, repoDir)
    d = struct('Name', string(name), 'Path', string(repoDir), 'Status', "unknown", ...
        'CommitsBehind', NaN, 'CurrentVersion', "", 'LatestVersion', "");
end

function repos = emptyRepos()
    repos = struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {}, ...
        'CurrentVersion', {}, 'LatestVersion', {});
end

function result = checkToolbox(result, info, options)
    result.CurrentVersion = info.ToolboxVersion;
    try
        release = ndi.update.latestRelease(Timeout = options.Timeout);
    catch ME
        result.Message = "Could not reach GitHub to check for NDI-matlab " + ...
            "releases: " + ME.message;
        return
    end
    result.LatestVersion = release.Version;
    result.ReleaseUrl = release.Url;
    result.MltbxUrl = release.MltbxUrl;

    try
        c = ndi.update.compareVersions(result.CurrentVersion, result.LatestVersion);
    catch
        result.Message = "Could not compare installed version '" + ...
            result.CurrentVersion + "' with latest release '" + ...
            result.LatestVersion + "'.";
        return
    end

    if c < 0
        result.Status = "updateAvailable";
        result.UpdateAvailable = true;
        result.Message = "NDI-matlab " + result.LatestVersion + " is available " + ...
            "(you have " + result.CurrentVersion + "). Release notes: " + ...
            result.ReleaseUrl + newline + "Run ndi.update.install() to update, " + ...
            "or use the Add-On Manager.";
    elseif c > 0
        result.Status = "ahead";
        result.Message = "Installed NDI-matlab " + result.CurrentVersion + ...
            " is newer than the latest release (" + result.LatestVersion + ").";
    else
        result.Status = "upToDate";
        result.Message = "NDI-matlab " + result.CurrentVersion + ...
            " is the latest release.";
    end
end

function mods = localModifications(name, repoDir, commitsAhead, incoming)
    % Returns a one-element Modifications structure if updating REPODIR
    % would touch the user's work -- edited tracked files, commits not
    % upstream, or untracked files in the way of files the update adds
    % (INCOMING) -- otherwise an empty one. Other untracked files are not
    % the update's business: git stash and git pull leave them alone.
    mods = emptyModifications();
    % --untracked-files=all lists each file, not just an untracked folder,
    % so an untracked file can be matched against the update's new paths.
    [s, out] = runGit(repoDir, "status --porcelain --untracked-files=all");
    if s ~= 0
        return
    end
    lines = splitlines(out);
    lines = lines(strlength(lines) > 3);
    isNew = startsWith(lines, "??");
    files = extractAfter(lines, 3);
    changed = files(~isNew);
    blocking = intersect(files(isNew), incoming, 'stable');
    if isnan(commitsAhead)
        commitsAhead = 0;
    end
    if isempty(changed) && isempty(blocking) && commitsAhead == 0
        return
    end
    mods = struct('Name', string(name), 'Path', string(repoDir), ...
        'ChangedFiles', {changed(:)}, 'BlockingFiles', {blocking(:)}, ...
        'CommitsAhead', commitsAhead);
end

function files = incomingNewFiles(repoDir, upstream)
    % Paths that the update (HEAD -> UPSTREAM) adds as new files.
    files = strings(0, 1);
    [s, out] = runGit(repoDir, "diff --name-only --diff-filter=A HEAD " + upstream);
    if s == 0 && strlength(out) > 0
        files = splitlines(out);
        files = files(strlength(files) > 0);
    end
end

function mods = emptyModifications()
    mods = struct('Name', {}, 'Path', {}, 'ChangedFiles', {}, ...
        'BlockingFiles', {}, 'CommitsAhead', {});
end

function s = shortHash(h)
    s = extractBefore(h + "       ", 8);
    s = strtrim(s);
end
