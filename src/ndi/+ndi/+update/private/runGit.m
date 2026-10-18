function [status, out] = runGit(repoDir, gitArgs)
% RUNGIT - run a git command in a repository and return trimmed output
%
%   [STATUS, OUT] = runGit(REPODIR, GITARGS) runs
%   git -C "REPODIR" GITARGS and returns the exit STATUS and the output OUT
%   as a trimmed string.

    arguments
        repoDir (1,1) string
        gitArgs (1,1) string
    end

    [status, out] = system(sprintf('git -C "%s" %s', repoDir, gitArgs));
    out = strtrim(string(out));
end
