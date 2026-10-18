function txt = modificationSummary(result, options)
% MODIFICATIONSUMMARY - describe the user's code changes that an update affects
%
%   TXT = ndi.update.modificationSummary(RESULT)
%
%   Given RESULT from ndi.update.check, returns a human-readable string
%   listing, for each repository with modifications, the changed files, the
%   new files and the number of local commits, followed by what updating
%   does to each kind of change. Returns "" if there are no modifications.
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
        if ~isempty(m.NewFiles)
            counts(end+1) = numel(m.NewFiles) + " new file(s)"; %#ok<AGROW>
        end
        if m.CommitsAhead > 0
            counts(end+1) = m.CommitsAhead + " local commit(s)"; %#ok<AGROW>
        end
        parts(end+1) = "" + newline + m.Name + " (" + m.Path + "): " + ...
            strjoin(counts, ", "); %#ok<AGROW>

        files = [ "  changed: " + m.ChangedFiles; "  new:     " + m.NewFiles ];
        nShow = min(numel(files), options.MaxFiles);
        parts = [parts, files(1:nShow)']; %#ok<AGROW>
        if numel(files) > nShow
            parts(end+1) = "  ... and " + (numel(files) - nShow) + " more"; %#ok<AGROW>
        end
    end

    parts(end+1) = "" + newline + "If you update: changed files are stashed " + ...
        "(get them back with 'git stash pop' in that folder), new files are " + ...
        "left in place, and local commits are merged with the update, which " + ...
        "can stop with a merge conflict.";
    txt = strjoin(parts, newline);
end
