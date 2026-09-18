function info = install(options)
% NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL - check the JRCLUST installation NDI will use
%
% INFO = NDI.FUN.PROBE.IMPORT.JRCLUST.INSTALL(...)
%
% Examines the JRCLUST installation that is visible on the MATLAB path and reports
% whether it can drive the NDI pipeline. NDI needs the VH Lab fork of JRCLUST
% (https://github.com/VH-Lab/JRCLUST), which adds the 'ndi' recording format so that
% JRCLUST reads sample data straight out of an ndi.element. That support lives on
% the fork's 'ndi_import' branch; a stock JaneliaSciComp JRCLUST will not work.
%
% INFO is a struct with the fields:
%   installed        - true if JRCLUST is on the MATLAB path
%   path             - the JRCLUST installation folder ('' if not found)
%   version          - JRCLUST's version string ('' if it could not be read)
%   hasNdiSupport    - true if the NDI-aware files are present (see below)
%   missingFiles     - cell array of the NDI-aware files that are missing
%   isGit            - true if the installation is a git working copy
%   branch           - the checked-out branch ('' if unknown or detached HEAD)
%   commit           - the checked-out commit hash ('' if unknown)
%   expectedBranch   - the branch NDI expects (default 'ndi_import')
%   onExpectedBranch - true if BRANCH is EXPECTEDBRANCH
%   remoteUrl        - the 'origin' remote URL ('' if unknown)
%   isVHLabFork      - true if REMOTEURL points at the VH-Lab fork
%   ok               - true if INSTALLED and HASNDISUPPORT (the pipeline can run)
%   summary          - a multi-line, human-readable report of all of the above
%
% NDI checks for these NDI-aware JRCLUST files:
%   @JRC/bootstrapNDI.m               - jrc('bootstrap','ndi',...)
%   +jrclust/+detect/ndiRecording.m   - the 'ndi' recording format reader
%
% ok is deliberately based on the files rather than on the branch name: a working
% copy can carry the NDI support under another branch name (or as a detached HEAD),
% and NDI only needs the code. onExpectedBranch is reported separately so a user can
% see whether the installation is on the branch the lab documents.
%
% This function takes name/value pairs that modify its operation:
% ---------------------------------------------------------------------------------
% | Parameter (default)      | Description                                         |
% |--------------------------|-----------------------------------------------------|
% | expectedBranch           | The JRCLUST branch NDI expects to find.             |
% |   ('ndi_import')         |                                                     |
% | jrclustPath ('')         | Check this folder instead of the one on the path.   |
% ---------------------------------------------------------------------------------
%
% See also: NDI.FUN.PROBE.EXPORT.JRCLUST, NDI.FUN.PROBE.IMPORT.JRCLUST.RUN,
%   NDI.GUI.APP.JRCLUST
%
% Example:
%    info = ndi.fun.probe.import.jrclust.install();
%    disp(info.summary);
%

    arguments
        options.expectedBranch (1,:) char = 'ndi_import'
        options.jrclustPath (1,:) char = ''
    end

    info = struct('installed', false, 'path', '', 'version', '', ...
        'hasNdiSupport', false, 'missingFiles', {{}}, ...
        'isGit', false, 'branch', '', 'commit', '', ...
        'expectedBranch', options.expectedBranch, 'onExpectedBranch', false, ...
        'remoteUrl', '', 'isVHLabFork', false, 'ok', false, 'summary', '');

    % Step 1: where is JRCLUST?

    % NOTE: JRCLUST's own functions are always called through feval here. This file
    % lives in the package ndi.fun.probe.import.jrclust, so an unqualified reference
    % to 'jrclust.utils.basedir' could be resolved against this package rather than
    % against JRCLUST's top-level 'jrclust' package; feval resolves the name the way
    % the command line would.
    jrcRoot = options.jrclustPath;
    if isempty(jrcRoot),
        try
            jrcRoot = feval('jrclust.utils.basedir'); % the fork's own answer, if it responds
        catch
            jrcRoot = '';
        end;
    end;
    if isempty(jrcRoot),
        w = which('jrc');
        if ~isempty(w),
            jrcRoot = fileparts(w);
        end;
    end;

    if isempty(jrcRoot) || ~isfolder(jrcRoot),
        info.summary = ['JRCLUST was not found on the MATLAB path. Install the VH Lab fork ' ...
            '(https://github.com/VH-Lab/JRCLUST), check out the ''' options.expectedBranch ''' ' ...
            'branch, and add it to the path (addpath(genpath(''/path/to/JRCLUST''))).'];
        return;
    end;

    info.installed = true;
    info.path = jrcRoot;

    % Step 2: version (best effort; a stock JRCLUST answers this too)

    try
        info.version = feval('jrclust.utils.version');
    catch
        info.version = '';
    end;

    % Step 3: are the NDI-aware files present?

    needed = { fullfile('@JRC','bootstrapNDI.m'), ...
               fullfile('+jrclust','+detect','ndiRecording.m') };
    missing = {};
    for i=1:numel(needed),
        if ~isfile(fullfile(jrcRoot, needed{i})),
            missing{end+1} = needed{i}; %#ok<AGROW>
        end;
    end;
    info.missingFiles = missing;
    info.hasNdiSupport = isempty(missing);
    info.ok = info.installed & info.hasNdiSupport;

    % Step 4: git working copy: branch, commit, and remote

    [info.isGit, info.branch, info.commit] = i_gitHead(jrcRoot);
    info.onExpectedBranch = strcmp(info.branch, options.expectedBranch);
    info.remoteUrl = i_gitRemote(jrcRoot);
    info.isVHLabFork = ~isempty(regexpi(info.remoteUrl,'vh-?lab/jrclust','once'));

    % Step 5: the human-readable report

    lines = {};
    lines{end+1} = ['JRCLUST found at: ' jrcRoot];
    if ~isempty(info.version),
        lines{end+1} = ['Version: ' info.version];
    end;
    if info.isGit,
        if isempty(info.branch),
            lines{end+1} = ['Branch: (detached HEAD at ' info.commit ')'];
        else,
            lines{end+1} = ['Branch: ' info.branch];
        end;
        if ~isempty(info.remoteUrl),
            lines{end+1} = ['Remote: ' info.remoteUrl];
        end;
    else,
        lines{end+1} = 'Branch: (not a git working copy, so the branch cannot be checked)';
    end;
    if info.hasNdiSupport,
        lines{end+1} = 'NDI support: present (JRCLUST can read ndi.element data directly).';
    else,
        lines{end+1} = ['NDI support: MISSING (' strjoin(missing, ', ') ').'];
        lines{end+1} = ['This is probably a stock JRCLUST. Install the VH Lab fork ' ...
            '(https://github.com/VH-Lab/JRCLUST) and check out the ''' ...
            options.expectedBranch ''' branch.'];
    end;
    if info.hasNdiSupport && info.isGit && ~info.onExpectedBranch,
        lines{end+1} = ['Note: the expected branch is ''' options.expectedBranch '''. The NDI ' ...
            'files are present on this working copy, so the pipeline should run, but ' ...
            'consider: git -C "' jrcRoot '" checkout ' options.expectedBranch];
    end;
    if info.ok,
        lines{end+1} = 'Ready to run the NDI/JRCLUST pipeline.';
    end;
    info.summary = strjoin(lines, newline);

end % install()

function [isGit, branch, commit] = i_gitHead(root)
% Read the checked-out branch/commit without requiring the git command line.
    isGit = false; branch = ''; commit = '';

    gitPath = fullfile(root, '.git');
    gitDir = '';
    if isfolder(gitPath),
        gitDir = gitPath;
    elseif isfile(gitPath),
        % a worktree or submodule: the file holds 'gitdir: <path>'
        txt = strtrim(fileread(gitPath));
        tok = regexp(txt,'^gitdir:\s*(.*)$','tokens','once');
        if ~isempty(tok),
            gitDir = strtrim(tok{1});
            if ~i_isAbsolute(gitDir),
                gitDir = fullfile(root, gitDir);
            end;
        end;
    end;

    if isempty(gitDir) || ~isfolder(gitDir),
        return;
    end;
    isGit = true;

    headFile = fullfile(gitDir,'HEAD');
    if ~isfile(headFile),
        return;
    end;
    head = strtrim(fileread(headFile));
    tok = regexp(head,'^ref:\s*refs/heads/(.*)$','tokens','once');
    if ~isempty(tok),
        branch = strtrim(tok{1});
        % resolve the branch to a commit, from the loose ref or packed-refs
        refFile = fullfile(gitDir,'refs','heads',branch);
        if isfile(refFile),
            commit = strtrim(fileread(refFile));
        else,
            packed = fullfile(gitDir,'packed-refs');
            if isfile(packed),
                tok2 = regexp(fileread(packed), ...
                    ['([0-9a-f]{40})\s+refs/heads/' regexptranslate('escape',branch) '\s'], ...
                    'tokens','once');
                if ~isempty(tok2),
                    commit = tok2{1};
                end;
            end;
        end;
    else,
        commit = head; % detached HEAD: the file holds the hash itself
    end;
end % i_gitHead()

function url = i_gitRemote(root)
% Read the 'origin' remote URL from .git/config (best effort).
    url = '';
    cfg = fullfile(root,'.git','config');
    if ~isfile(cfg),
        return;
    end;
    txt = fileread(cfg);
    % the url line within the [remote "origin"] section
    tok = regexp(txt,'\[remote\s+"origin"\][^\[]*?url\s*=\s*([^\r\n]*)','tokens','once');
    if ~isempty(tok),
        url = strtrim(tok{1});
    end;
end % i_gitRemote()

function tf = i_isAbsolute(p)
    tf = false;
    if isempty(p), return; end;
    if ispc,
        tf = ~isempty(regexp(p,'^([A-Za-z]:[\\/]|\\\\)','once'));
    else,
        tf = p(1)==filesep;
    end;
end % i_isAbsolute()
