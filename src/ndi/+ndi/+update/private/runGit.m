function [status, out] = runGit(repoDir, gitArgs)
% RUNGIT - run a git command in a repository and return trimmed output
%
%   [STATUS, OUT] = runGit(REPODIR, GITARGS) runs
%   git -C "REPODIR" GITARGS and returns the exit STATUS and the output OUT
%   as a string with trailing whitespace removed. Leading whitespace is
%   kept, because it is meaningful in 'git status --porcelain' output.

    arguments
        repoDir (1,1) string
        gitArgs (1,1) string
    end

    [status, out] = system(sprintf('git -C "%s" %s', repoDir, gitArgs));
    out = strip(string(out), 'right');
end
