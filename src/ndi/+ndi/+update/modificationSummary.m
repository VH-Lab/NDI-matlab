function txt = modificationSummary(result, options)
% MODIFICATIONSUMMARY - describe the user's code changes that an update affects
%
%   TXT = ndi.update.modificationSummary(RESULT)
%
%   Given RESULT from ndi.update.check, returns a human-readable string
%   listing, for each repository where updating touches the user's work,
%   the changed files, the untracked files in the way of files the update
%   adds, and the number of local commits, followed by what updating does
%   to each. Returns "" if there are none. Other untracked files are not
%   listed: the update leaves them where they are.
%
%   TXT = ndi.update.modificationSummary(RESULT, MaxFiles=N) lists at most N
%   files per repository (default 10) and counts the rest.
%
%   Example:
%       r = ndi.update.check(Verbose=false);
%       disp(ndi.update.modificationSummary(r))
%
%   See also: ndi.update.check, ndi.update.install

    arguments
        result (1,1) struct
        options.MaxFiles (1,1) double {mustBeInteger, mustBePositive} = 10
    end

    txt = "";
    if ~isfield(result, 'Modifications') || isempty(result.Modifications)
        return
    end

    parts = "You have changed code that the update will touch:";
    for i = 1:numel(result.Modifications)
        m = result.Modifications(i);
        counts = strings(0);
        if ~isempty(m.ChangedFiles)
            counts(end+1) = numel(m.ChangedFiles) + " changed file(s)"; %#ok<AGROW>
        end
        if ~isempty(m.BlockingFiles)
            counts(end+1) = numel(m.BlockingFiles) + ...
                " untracked file(s) in the way of new files"; %#ok<AGROW>
        end
        if m.CommitsAhead > 0
            counts(end+1) = m.CommitsAhead + " local commit(s)"; %#ok<AGROW>
        end
        parts(end+1) = "" + newline + m.Name + " (" + m.Path + "): " + ...
            strjoin(counts, ", "); %#ok<AGROW>

        files = [ "  changed:    " + m.ChangedFiles; "  in the way: " + m.BlockingFiles ];
        nShow = min(numel(files), options.MaxFiles);
        parts = [parts, files(1:nShow)']; %#ok<AGROW>
        if numel(files) > nShow
            parts(end+1) = "  ... and " + (numel(files) - nShow) + " more"; %#ok<AGROW>
        end
    end

    parts(end+1) = "" + newline + "If you update: changed files are stashed " + ...
        "and put back after the update (if they no longer apply cleanly, " + ...
        "'git stash list' in that folder still has them), and local " + ...
        "commits are merged with the update, which can stop with a merge " + ...
        "conflict. An untracked file in the way of a file the update adds " + ...
        "must be moved or renamed first: git will not overwrite it. Your " + ...
        "other untracked files are left alone.";
    txt = strjoin(parts, newline);
end
