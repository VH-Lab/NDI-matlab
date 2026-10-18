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
%       LocalChanges    - true if there are uncommitted changes (git only);
%                         ndi_install stashes these before updating
%       Dependencies    - structure array, one entry per dependency (git
%                         only), with fields Name, Path, Status, CommitsBehind
%       ReleaseUrl      - web page of the latest release (toolbox only)
%       MltbxUrl        - download URL of the latest toolbox (toolbox only)
%       BothInstalled   - true if a git clone and the toolbox are both
%                         installed
%
%   RESULT = ndi.update.check(Name, Value) accepts:
%       IncludeDependencies - also check the dependency repositories of a
%                             git install (default true)
%       Verbose             - print the summary (default true)
%       Timeout             - seconds to wait for GitHub (default 10)
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
    end

    [type, info] = ndi.update.installType();

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
        'LocalChanges', false, ...
        'Dependencies', struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {}), ...
        'ReleaseUrl', "", ...
        'MltbxUrl', "", ...
        'BothInstalled', info.BothInstalled);

    switch type
        case "git"
            result = checkGit(result, info, options);
        case "toolbox"
            result = checkToolbox(result, info, options);
        otherwise
            result.Message = "Could not tell how NDI-matlab was installed, " + ...
                "so cannot check for updates.";
    end

    if result.BothInstalled
        result.Message = result.Message + newline + "Warning: the NDI-matlab " + ...
            "toolbox (version " + info.ToolboxVersion + ") is also installed. " + ...
            "Only one copy can be used at a time; consider uninstalling one " + ...
            "from the Add-On Manager or removing the git clone from the path.";
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
    [~, dirty] = runGit(repo, "status --porcelain --untracked-files=no");
    result.LocalChanges = strlength(dirty) > 0;
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

    if options.IncludeDependencies
        result.Dependencies = checkDependencies(repo);
    end
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
        if result.LocalChanges
            result.Message = result.Message + newline + "Note: NDI-matlab " + ...
                "has uncommitted changes; updating will stash them.";
        end
        result.Message = result.Message + newline + "Run ndi.update.install() to update.";
    end
end

function deps = checkDependencies(repo)
    % The dependency list is read from main, so that dependencies that main
    % has added since the last update are noticed too.
    [s, txt] = runGit(repo, "show origin/main:requirements.txt");
    if s ~= 0
        reqFile = fullfile(repo, 'requirements.txt');
        if ~isfile(reqFile)
            deps = struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {});
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

    deps = struct('Name', {}, 'Path', {}, 'Status', {}, 'CommitsBehind', {});
    for i = 1:numel(lines)
        url = lines(i);
        pinned = contains(extractAfter(url, "://"), "@");
        name = regexprep(url, '@[^/]*$', '');
        name = regexprep(name, '\.git$', '');
        parts = split(name, "/");
        name = parts(end);
        depPath = fullfile(installDir, name);

        d = struct('Name', name, 'Path', depPath, 'Status', "unknown", 'CommitsBehind', NaN);
        if pinned
            d.Status = "pinned";
        elseif ~isfolder(depPath)
            if isNdiInstallLayout
                d.Status = "missing";
            else
                d.Status = "notFound";
            end
        elseif exist(fullfile(depPath, '.git'), 'file') == 0
            d.Status = "notGit";
        else
            [s, ~] = runGit(depPath, "fetch --quiet");
            [s2, behind] = runGit(depPath, "rev-list --count ""HEAD..@{u}""");
            if s == 0 && s2 == 0
                d.CommitsBehind = str2double(behind);
                if d.CommitsBehind > 0
                    d.Status = "behind";
                else
                    d.Status = "upToDate";
                end
            end
        end
        deps(end+1) = d; %#ok<AGROW>
    end
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

function s = shortHash(h)
    s = extractBefore(h + "       ", 8);
    s = strtrim(s);
end
