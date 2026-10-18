function py = checkPython(options)
% CHECKPYTHON - check whether NDI-python is installed and up to date
%
%   PY = ndi.update.checkPython()
%
%   Looks for NDI-python's 'ndi' command (see ndi.python.findCommand) and,
%   if it is found, compares the installed NDI-python with the latest
%   commit on the main branch of NDI-python on GitHub. NDI-python has no
%   releases; every install follows main.
%
%   How the installed commit is found:
%     1. ~/.ndi/install.json, if the NDI-python installer wrote one with a
%        'commit' field.
%     2. For a copy that the NDI installer did not install (for example a
%        developer clone), the commit that 'ndi version' reports.
%     3. Otherwise, for an installer install, only the time it was
%        installed is known (from ~/.ndi/venvs/ndi/uv-receipt.toml), and
%        the commits made to main since then are counted.
%
%   PY is a structure with fields:
%       Installed       - true if the 'ndi' command was found
%       Kind            - "installer" (installed by ndi.python.install or
%                         the NDI installer into ~/.ndi), "other", or "none"
%       Command         - full path of the 'ndi' command, or ""
%       CurrentVersion  - installed commit, or "installed <date>", or ""
%       LatestVersion   - latest commit on NDI-python's main branch
%       InstalledAt     - install time (UTC, ISO 8601) if that is all that is
%                         known, otherwise ""
%       CommitsBehind   - commits on main that the install does not have
%       Status          - "notInstalled", "upToDate", "updateAvailable",
%                         or "unknown"
%       UpdateAvailable - true if main has changes the install lacks
%       CanInstall      - true if ndi.update.install can update it (Kind is
%                         "installer"; it then runs ndi.python.install)
%       Message         - one-paragraph human-readable summary
%
%   PY = ndi.update.checkPython(Name, Value) accepts:
%       Timeout    - seconds to wait for GitHub (default 10)
%       Repository - "owner/name" on GitHub (default
%                    "Waltham-Data-Science/NDI-python")
%       NdiHome    - look only in this folder's bin subfolder instead of
%                    searching for the command (default "", search; used
%                    by tests)
%       GitHubApi  - function handle DATA = F(APIPATH, TIMEOUT) used to
%                    query GitHub (default: the GitHub REST API; used by
%                    tests)
%
%   It never errors: anything that goes wrong gives Status "unknown".
%
%   Example:
%       py = ndi.update.checkPython()
%
%   See also: ndi.update.check, ndi.python.install, ndi.python.findCommand

    arguments
        options.Timeout (1,1) double {mustBePositive} = 10
        options.Repository (1,1) string = "Waltham-Data-Science/NDI-python"
        options.NdiHome (1,1) string = ""
        options.GitHubApi (1,1) function_handle = @githubApi
    end

    py = struct( ...
        'Installed', false, ...
        'Kind', "none", ...
        'Command', "", ...
        'CurrentVersion', "", ...
        'LatestVersion', "", ...
        'InstalledAt', "", ...
        'CommitsBehind', NaN, ...
        'Status', "notInstalled", ...
        'UpdateAvailable', false, ...
        'CanInstall', false, ...
        'Message', "NDI-python is not installed.");

    try
        [py, home] = findInstall(py, options);
        if ~py.Installed
            return
        end
        py = compareWithMain(py, home, options);
    catch ME
        py.Status = "unknown";
        py.UpdateAvailable = false;
        py.Message = "Could not check NDI-python for updates: " + ME.message;
    end
end

function [py, home] = findInstall(py, options)
    if strlength(options.NdiHome) > 0
        home = options.NdiHome;
        cmd = fullfile(home, "bin", "ndi");
        if ispc
            cmd = cmd + ".exe";
        end
        if ~isfile(cmd)
            return
        end
    else
        home = string(ndi.python.ndiHome());
        try
            cmd = string(ndi.python.findCommand('ndi'));
        catch
            return
        end
    end
    py.Installed = true;
    py.Command = cmd;
    if startsWith(cmd, fullfile(home, "bin"))
        py.Kind = "installer";
    else
        py.Kind = "other";
    end
    py.CanInstall = py.Kind == "installer";
end

function py = compareWithMain(py, home, options)
    repo = "repos/" + options.Repository;
    sha = installedCommit(py, home);

    head = options.GitHubApi(repo + "/commits/main", options.Timeout);
    py.LatestVersion = shortHash(string(head.sha));

    if strlength(sha) > 0
        py.CurrentVersion = shortHash(sha);
        c = options.GitHubApi(repo + "/compare/" + sha + "...main", options.Timeout);
        py.CommitsBehind = double(c.ahead_by);
        sinceText = "";
    else
        installedAt = installTime(py, home);
        if ismissing(installedAt)
            py.Status = "unknown";
            py.Message = "NDI-python is installed (" + py.Command + "), but " + ...
                "its version could not be determined.";
            return
        end
        py.InstalledAt = string(installedAt, "yyyy-MM-dd'T'HH:mm:ss'Z'");
        py.CurrentVersion = "installed " + string(installedAt, "yyyy-MM-dd");
        commits = options.GitHubApi(repo + "/commits?sha=main&per_page=100&since=" + ...
            py.InstalledAt, options.Timeout);
        py.CommitsBehind = numel(commits);
        sinceText = " since it was installed on " + string(installedAt, "yyyy-MM-dd");
    end

    if py.CommitsBehind > 0
        py.Status = "updateAvailable";
        py.UpdateAvailable = true;
        count = string(py.CommitsBehind);
        if strlength(sinceText) > 0 && py.CommitsBehind >= 100
            count = "100 or more";
        end
        py.Message = "An NDI-python update is available: main has " + count + ...
            " commit(s)" + sinceText + " that the installed copy lacks " + ...
            "(latest is " + py.LatestVersion + ").";
        if py.CanInstall
            py.Message = py.Message + " Run ndi.update.install() to update it.";
        else
            py.Message = py.Message + " This copy was not installed by the NDI " + ...
                "installer (" + py.Command + "); update it the way you installed it.";
        end
    else
        py.Status = "upToDate";
        py.Message = "NDI-python is up to date with main (" + py.LatestVersion + ").";
    end
end

function sha = installedCommit(py, home)
    sha = "";
    receipt = fullfile(home, "install.json");
    if isfile(receipt)
        try
            j = jsondecode(fileread(receipt));
            if isfield(j, 'commit') && ~isempty(j.commit)
                sha = string(j.commit);
                return
            end
        catch
            % an unreadable receipt is treated as no receipt
        end
    end
    if py.Kind == "other"
        % A developer copy reports its git commit (git describe --always).
        [s, out] = system(ndi.python.commandLine(char(py.Command), {'version'}, 'Wait', true));
        if s == 0
            tok = regexp(out, 'NDI-python\s+([0-9a-f]{7,40})\>', 'tokens', 'once');
            if ~isempty(tok)
                sha = string(tok{1});
            end
        end
    end
end

function t = installTime(py, home)
    % uv writes this receipt each time it installs the 'ndi' tool.
    t = NaT('TimeZone', 'UTC');
    if py.Kind ~= "installer"
        return
    end
    candidates = [fullfile(home, "venvs", "ndi", "uv-receipt.toml"), py.Command];
    for f = candidates
        if isfile(f)
            d = dir(f);
            t = datetime(d.datenum, 'ConvertFrom', 'datenum', 'TimeZone', 'local');
            t.TimeZone = 'UTC';
            return
        end
    end
end

function s = shortHash(h)
    s = extractBefore(h + "       ", 8);
    s = strtrim(s);
end
