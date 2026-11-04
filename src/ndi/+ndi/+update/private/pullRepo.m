function pullRepo(repoDir, gitArgs)
% PULLREPO - pull a git clone, setting aside and restoring local edits
%
%   pullRepo(REPODIR) runs 'git pull' in REPODIR the way ndi_install
%   updates a repository: edits to tracked files are stashed for the pull
%   and put back afterwards; untracked files are left alone. If the edits
%   no longer apply cleanly they stay in 'git stash list' and a warning
%   says so. Errors with ndi:update:install:pullFailed if the pull fails
%   (the stashed edits are put back first).
%
%   pullRepo(REPODIR, GITARGS) passes GITARGS to 'git pull' (for example
%   "origin main"; default "", the branch's upstream).

    arguments
        repoDir (1,1) string
        gitArgs (1,1) string = ""
    end

    [s, out] = runGit(repoDir, "status --porcelain --untracked-files=no");
    if s ~= 0
        error('ndi:update:install:pullFailed', ...
            'Could not read the git status of %s: %s', repoDir, out);
    end

    stashed = false;
    if strlength(out) > 0
        fprintf('Setting aside your changes in %s while it is updated...\n', repoDir);
        % 'git stash' also succeeds when it stashes nothing, and popping
        % then would restore an older, unrelated stash: compare the ref.
        [~, before] = runGit(repoDir, "rev-parse -q --verify refs/stash");
        [s, out] = runGit(repoDir, "stash");
        [~, after] = runGit(repoDir, "rev-parse -q --verify refs/stash");
        if s ~= 0
            error('ndi:update:install:pullFailed', ...
                'Could not set aside your changes in %s: %s', repoDir, out);
        end
        stashed = strlength(after) > 0 && after ~= before;
    end

    [s, pullOut] = runGit(repoDir, strtrim("pull --no-edit " + gitArgs));

    if stashed
        [ps, ~] = runGit(repoDir, "stash pop");
        if ps == 0
            fprintf('Your changes in %s were put back.\n', repoDir);
        else
            warning('ndi:update:install:stashNotRestored', ...
                ['Your changes in %s could not be put back cleanly after the ' ...
                 'update. They are still saved: see "git -C %s stash list", ' ...
                 'and use "git stash pop" there once any conflicts are resolved.'], ...
                repoDir, repoDir);
        end
    end

    if s ~= 0
        error('ndi:update:install:pullFailed', ...
            'Updating %s failed: %s', repoDir, pullOut);
    end
end
