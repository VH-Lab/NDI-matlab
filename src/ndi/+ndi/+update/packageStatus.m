function [rows, summary] = packageStatus(result)
% PACKAGESTATUS - one row per package for an update dialog
%
%   [ROWS, SUMMARY] = ndi.update.packageStatus(RESULT)
%
%   Given RESULT from ndi.update.check, describes each package that
%   ndi.update.install would look at, in the order an update dialog lists
%   them:
%     - git installs: NDI-matlab, each dependency in requirements.txt, each
%       NDIcalc-*-matlab calculator repository, and NDI-python if installed
%     - toolbox installs: the NDI-matlab toolbox, the calculator
%       repositories, and NDI-python if installed
%
%   ROWS is a structure array with fields:
%       Name        - package name
%       Kind        - "ndi", "toolbox", "dependency", "calculator" or "python"
%       Path        - folder of the package, or ""
%       Installed   - installed commit or version, or ""
%       Latest      - newest commit or version, or ""
%       Status      - short status text, e.g. "3 new commits"
%       WillUpdate  - true if ndi.update.install would change this package
%       Notes       - string array of short notes (what updating does to
%                     your files, why the package is skipped, ...)
%       NoteLevels  - the level of each note: "info", "warning" or "error"
%       NoteLevel   - the most serious level in NoteLevels, or "" if there
%                     are no notes
%       Details     - longer text for the package: its path, the notes, and
%                     the files that the notes are about
%       Blocked     - true if the update cannot go ahead until something
%                     is done about this package (see Notes)
%       TouchesChanges - true if updating stashes, merges or overwrites
%                     code you changed in this package
%       Files       - the files the notes are about, one per line, each
%                     marked "changed:" or "in the way:"
%       Selectable  - true if the package can be ticked for updating
%                     (WillUpdate and not Blocked)
%       Selected    - whether it starts ticked: Selectable packages are,
%                     except those where updating touches your own work
%                     (TouchesChanges)
%
%   WillUpdate, TouchesChanges and the notes describe what happens to a
%   package if it is ticked: ndi.update.install(Packages=...) updates only
%   the packages named, so the others are not touched.
%
%   SUMMARY is a structure with fields:
%       CanUpdate     - true if any row is Selectable
%       AnyUpdate     - true if any row has WillUpdate
%       Blocked       - true if any row is blocked
%       HasUserChanges - true if any row has TouchesChanges
%       Message       - one-sentence summary for the dialog
%
%   Example:
%       r = ndi.update.check(Verbose=false);
%       rows = ndi.update.packageStatus(r);
%       struct2table(rmfield(rows, {'Notes', 'Details'}))
%
%   See also: ndi.update.check, ndi.update.install,
%   ndi.update.modificationSummary, ndi.gui.nav.updateDialog

    arguments
        result (1,1) struct
    end

    switch result.InstallType
        case "git"
            rows = gitRows(result);
        case "toolbox"
            rows = toolboxRow(result);
        otherwise
            r = newRow("NDI-matlab", "ndi", "");
            r.Status = "Could not check";
            r = addNote(r, "info", "Could not tell how NDI-matlab was installed.");
            rows = r;
    end

    for i = 1:numel(result.Calculators)
        c = result.Calculators(i);
        r = repoRow(c, "calculator");
        r.WillUpdate = c.Status == "behind";
        if c.Status == "notGit"
            r = addNote(r, "info", "Not a git clone, so it is not updated here.");
        end
        r = modificationNotes(r, result, r.WillUpdate);
        rows(end+1) = r; %#ok<AGROW>
    end

    if isfield(result, 'Python') && result.Python.Installed
        rows(end+1) = pythonRow(result.Python);
    end

    for i = 1:numel(rows)
        rows(i).Details = details(rows(i));
    end

    for i = 1:numel(rows)
        rows(i).Selectable = rows(i).WillUpdate && ~rows(i).Blocked;
        % Leave out, at first, packages where you have work of your own.
        rows(i).Selected = rows(i).Selectable && ~rows(i).TouchesChanges;
    end

    summary.AnyUpdate = any([rows.WillUpdate]);
    summary.Blocked = any([rows.Blocked]);
    summary.CanUpdate = any([rows.Selectable]);
    summary.HasUserChanges = any([rows.TouchesChanges]);
    n = nnz([rows.Selectable]);
    if summary.AnyUpdate && n == 0
        summary.Message = "Updates are available, but none can be installed " + ...
            "yet: see the packages marked with an error.";
    elseif summary.AnyUpdate
        summary.Message = n + " package(s) can be updated. Tick the ones " + ...
            "to update.";
        if summary.Blocked
            summary.Message = summary.Message + " Packages marked with an " + ...
                "error cannot be updated yet.";
        end
    else
        summary.Message = "Everything is up to date.";
    end
end

function rows = gitRows(result)
    r = newRow("NDI-matlab", "ndi", result.RepoRoot);
    r.Installed = result.CurrentVersion;
    r.Latest = result.LatestVersion;
    r.WillUpdate = result.CommitsBehind > 0;
    if result.CommitsBehind > 0
        r.Status = commitsText(result.CommitsBehind);
    elseif result.Status == "unknown"
        r.Status = "Could not check";
    elseif result.CommitsAhead > 0
        r.Status = result.CommitsAhead + " local commit(s)";
    else
        r.Status = "Up to date";
    end
    if result.Status == "unknown"
        r = addNote(r, "info", firstLine(result.Message));
    end
    if result.UpdateAvailable && result.Branch ~= "main"
        r = addNote(r, "error", "On branch '" + result.Branch + ...
            "', not main. Run 'git checkout main' in " + result.RepoRoot + ...
            " first.");
        r.Blocked = true;
    end
    if result.BothInstalled
        r = addNote(r, "warning", "The NDI-matlab toolbox is also installed; " + ...
            "only one copy can be used at a time.");
    end
    r = modificationNotes(r, result, r.WillUpdate);
    rows = r;

    for i = 1:numel(result.Dependencies)
        d = result.Dependencies(i);
        r = repoRow(d, "dependency");
        % ndi_install runs over every dependency when NDI-matlab updates.
        r.WillUpdate = result.UpdateAvailable && ismember(d.Status, ["behind", "missing"]);
        switch d.Status
            case "pinned"
                r = addNote(r, "info", "Pinned to a version by requirements.txt.");
            case "notFound"
                r = addNote(r, "info", "Not found next to NDI-matlab, so it is " + ...
                    "not updated here.");
            case "notGit"
                r = addNote(r, "info", "Not a git clone, so it is not updated here.");
        end
        % Updating the ticked packages only, ndi_install visits just these.
        r = modificationNotes(r, result, r.WillUpdate);
        rows(end+1) = r; %#ok<AGROW>
    end
end

function r = toolboxRow(result)
    r = newRow("NDI-matlab toolbox", "toolbox", "");
    r.Installed = result.CurrentVersion;
    r.Latest = result.LatestVersion;
    r.WillUpdate = result.UpdateAvailable;
    switch result.Status
        case "updateAvailable"
            r.Status = "Update available";
        case "upToDate"
            r.Status = "Up to date";
        case "ahead"
            r.Status = "Newer than latest release";
        otherwise
            r.Status = "Could not check";
            r = addNote(r, "info", firstLine(result.Message));
    end
    if result.UpdateAvailable
        r = addNote(r, "warning", "Files you changed or added inside the " + ...
            "toolbox folder will be lost.");
        r = addNote(r, "info", "Restart MATLAB after updating.");
        if strlength(result.MltbxUrl) == 0
            r = addNote(r, "error", "The latest release has no toolbox file; " + ...
                "update from the Add-On Manager.");
            r.Blocked = true;
        end
        if strlength(result.ReleaseUrl) > 0
            r = addNote(r, "info", "Release notes: " + result.ReleaseUrl);
        end
    end
    if result.BothInstalled
        r = addNote(r, "warning", "A git clone of NDI-matlab is also installed; " + ...
            "only one copy can be used at a time.");
    end
end

function r = repoRow(d, kind)
    r = newRow(d.Name, kind, d.Path);
    r.Installed = d.CurrentVersion;
    r.Latest = d.LatestVersion;
    switch d.Status
        case "behind"
            r.Status = commitsText(d.CommitsBehind);
        case "missing"
            r.Status = "Not installed; will be added";
        case "upToDate"
            r.Status = "Up to date";
        case "pinned"
            r.Status = "Pinned";
        case "notFound"
            r.Status = "Not found";
        case "notGit"
            r.Status = "Not a git clone";
        otherwise
            r.Status = "Could not check";
    end
end

function r = pythonRow(py)
    r = newRow("NDI-python", "python", "");
    r.Installed = py.CurrentVersion;
    r.Latest = py.LatestVersion;
    r.WillUpdate = py.UpdateAvailable && py.CanInstall;
    switch py.Status
        case "updateAvailable"
            if isfinite(py.CommitsBehind) && py.CommitsBehind > 0
                r.Status = commitsText(py.CommitsBehind);
            else
                r.Status = "Update available";
            end
        case "upToDate"
            r.Status = "Up to date";
        otherwise
            r.Status = "Could not check";
    end
    if py.UpdateAvailable && ~py.CanInstall
        r = addNote(r, "info", "Not installed by the NDI installer, so it is " + ...
            "not updated here.");
    end
    if r.WillUpdate
        r = addNote(r, "info", "Updated by running its installer again.");
    end
end

function r = modificationNotes(r, result, affected)
    % Notes on what updating does to the user's own changes in R's repo.
    % AFFECTED: the update runs git stash and git pull in that repo.
    if ~isfield(result, 'Modifications') || isempty(result.Modifications)
        return
    end
    m = result.Modifications([result.Modifications.Name] == r.Name);
    if isempty(m)
        return
    end
    m = m(1);
    if ~isempty(m.BlockingFiles)
        r = addNote(r, "error", numel(m.BlockingFiles) + " untracked file(s) " + ...
            "are where the update adds files; move or rename them first.");
        r.Blocked = true;
    end
    if affected
        r.TouchesChanges = ~isempty(m.ChangedFiles) || m.CommitsAhead > 0;
        if ~isempty(m.ChangedFiles)
            r = addNote(r, "warning", numel(m.ChangedFiles) + " changed file(s) " + ...
                "will be stashed and put back after the update.");
        end
        if m.CommitsAhead > 0
            r = addNote(r, "warning", m.CommitsAhead + " local commit(s) will be " + ...
                "merged with the update.");
        end
    elseif ~isempty(m.ChangedFiles) || m.CommitsAhead > 0
        r = addNote(r, "info", "You have changed code here; it is not touched.");
    end
    r.Files = [ "changed:    " + m.ChangedFiles(:); "in the way: " + m.BlockingFiles(:) ];
end

function txt = details(r)
    parts = r.Name;
    if strlength(r.Path) > 0
        parts(end+1) = r.Path;
    end
    parts(end+1) = "Status: " + r.Status;
    if ~isempty(r.Notes)
        parts = [parts, "", "- [" + r.NoteLevels + "] " + r.Notes];
    end
    if ~isempty(r.Files)
        nShow = min(numel(r.Files), 25);
        parts = [parts, "", "  " + r.Files(1:nShow)'];
        if numel(r.Files) > nShow
            parts(end+1) = "  ... and " + (numel(r.Files) - nShow) + " more";
        end
    end
    txt = strjoin(parts, newline);
end

function r = addNote(r, level, text)
    r.Notes(end+1) = string(text);
    r.NoteLevels(end+1) = level;
    order = ["", "info", "warning", "error"];
    if find(order == level) > find(order == r.NoteLevel)
        r.NoteLevel = level;
    end
end

function s = commitsText(n)
    if n == 1
        s = "1 new commit";
    else
        s = n + " new commits";
    end
end

function s = firstLine(txt)
    lines = splitlines(string(txt));
    s = lines(1);
end

function r = newRow(name, kind, folder)
    r = struct('Name', string(name), 'Kind', string(kind), 'Path', string(folder), ...
        'Installed', "", 'Latest', "", 'Status', "", 'WillUpdate', false, ...
        'Notes', strings(1, 0), 'NoteLevels', strings(1, 0), 'NoteLevel', "", ...
        'Details', "", ...
        'Blocked', false, 'TouchesChanges', false, 'Files', strings(0, 1), ...
        'Selectable', false, 'Selected', false);
end
