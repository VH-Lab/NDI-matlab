function [status, out] = runGit(repoDir, gitArgs)
% RUNGIT - run a git command in a repository and return trimmed output
%
%   [STATUS, OUT] = runGit(REPODIR, GITARGS) runs
%   git -C "REPODIR" GITARGS and returns the exit STATUS and the output OUT
%   as a string with trailing whitespace removed. Leading whitespace is
%   kept, because it is meaningful in 'git status --porcelain' output.
%
%   git is never allowed to wait for input: its standard input is empty,
%   it may not prompt for credentials, and it may not open a pager or an
%   editor. Under MATLAB's system (and in CI, where nobody can answer) a
%   command that waited would hang MATLAB.

    arguments
        repoDir (1,1) string
        gitArgs (1,1) string
    end

    [status, out] = system(nonInteractiveGit(repoDir, gitArgs));
    out = strip(string(out), 'right');
end

function cmd = nonInteractiveGit(repoDir, gitArgs)
    gitCmd = sprintf('git -c core.pager=cat -c core.editor=true -C "%s" %s', repoDir, gitArgs);
    if ispc
        cmd = ['set GIT_TERMINAL_PROMPT=0&& ' gitCmd ' < NUL'];
    else
        cmd = ['GIT_TERMINAL_PROMPT=0 ' gitCmd ' < /dev/null'];
    end
end
