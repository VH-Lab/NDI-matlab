function b = ndi_install(directory, dependencies)
% NDI_INSTALL - install the NDI distribution and its ancillary directories
%
%     B = NDI_INSTALL
%
% Installs the GitHub distributions necessary to run NDI-matlab.
% These are installed at [USERPATH filesep 'tools']
%    (for example, /Users/steve/Documents/MATLAB/tools/)
%
% The startup file is edited to add a startup procedure in VHTOOLS.
%
% One can also dictate a different install directory by passing a full pathname:
%
% B = NDI_INSTALL(PATHNAME)
%
% PATHNAME should not include any shell script shortcuts (like '~').
%
% Finally, one can also install either the minimal set of tools needed for NDI 
% (DEPENDENCIES=1), or one can install the standard VHTOOLS suite (DEPENDENCIES=2).
% For developers, the option DEPENDENCIES=3 will install dependencies based
% on the locally checked out branch of NDI-matlab.
%
% B = NDI_INSTALL(PATHNAME, DEPENDENCIES)
%
% If PATHNAME is blank, then the default pathway of [USERPATH filesep 'tools'] is used.

b = git_embedded_assert;

if ~b,
    error(['The program git was not detected on the system. Please install git and restart Matlab.']);
end;

need_to_set_directory = 0;

if nargin<1,
    need_to_set_directory = 1;
    directory = ' '; % not empty
end;

if isempty(directory),
    need_to_set_directory = 1;
end;

if need_to_set_directory,
    if isempty(userpath),
        disp(['Your Matlab USERPATH is empty. This is your ''home'' directory for your Matlab use.']);
        reply = input('Can we reset your USERPATH to the default? Y/N [Y]:','s');
        if isempty(reply)
            reply = 'Y';
        end
        if strcmpi(strtrim(reply),'Y'),
            userpath('reset');
        else,
            error(['User elected NOT to reset USERPATH. USERPATH is blank, so we cannot install. See help userpath']);
        end;
    end;
    directory = [userpath filesep 'tools'];
end;

disp(['About to install at directory ' directory '...']);

if nargin<2,
    dependencies = 1;
end;

% If a numeric 
if isnumeric(dependencies),
    switch (dependencies),
        case 1,
            dependencies_filepath = 'https://raw.githubusercontent.com/VH-Lab/NDI-matlab/main/ndi-matlab-dependencies.json';
        case 2,
            dependencies_filepath = 'https://raw.githubusercontent.com/VH-Lab/vhlab_vhtools/main/vhtools_standard_distribution.json';
        case 3,
            dependencies_filepath = fullfile(ndi.util.toolboxdir, 'ndi-matlab-dependencies.json');
    end;

    if dependencies == 1 || dependencies == 2
        t = webread(dependencies_filepath);
    elseif dependencies == 3
        t = fileread(dependencies_filepath);
    else
        error('Dependencies must be 1, 2 or 3')
    end

    j = jsondecode(t);
    dependencies = j.dependency;
end;

% are we updating at least NDI?

w = which('ndi_Init');
if isempty(w),
    updating = 0;
else,
    updating = 1;
end;

if updating,
    disp(['We are updating an existing installation on the path...']);
    disp(['  We must temporarily reset the Matlab path.']);
    disp(['  startup.m will be called during the installation, which should restore your path to your desired path.']);
    currentpath = path(); % for now, don't do anything with this
    currpwd = pwd();

    % copy 'ndi_install.m' file to userpath directory
    thisfile = which('ndi_Init'); % ndi.globals is in same directory as ndi_install; ndi_install can have multiple copies
    [thisparent,thisfilename,thisextension] = fileparts(thisfile);
    copyfile([thisparent filesep 'ndi_install.m'], [userpath filesep 'ndi_install.m'],'f');

    cd(userpath);
    restoredefaultpath();
    ndi_install(directory, dependencies);

    % now clean up
    try,
        delete([userpath filesep 'ndi_install.m']);
    end;
    try,
        cd(currpwd);
    end;

    addpath(currentpath) % Restore the user's path
    
    return;
end;

for i=1:numel(dependencies),
    libparts = split(dependencies{i},'/');
    disp(['Installing/updating ' dependencies{i} '...']);
    if startsWith(dependencies{i}, 'fex')
        addonUUID = extractAfter(dependencies{i}, 'fex://');
        installFexPackage(addonUUID, directory)
    else
        git_embedded_install([directory filesep libparts{end}],dependencies{i});
    end
end;

disp(['Examining startup.m file to add startup line.']);

s = which('startup.m');

if ~isempty(s),
    t = text2cellstr_embedded(s);
else,
    s = [userpath filesep 'startup.m'];
    t = {};
end;

z = regexp(t,'vhtools_startup','forceCellOutput');

if all(cellfun('isempty',z)),
    text_to_add = ['run([''' directory filesep 'vhlab_vhtools' filesep 'vhtools_startup.m'']);'];
    disp(['Adding ' text_to_add ' to startup.m']);
    t{end+1} = text_to_add;
    cellstr2text_embedded(s,t);
else,
    disp(['startup.m seems to already have needed line. No action taken.']);
end;

startup


 % embedded version

function b = git_embedded_assert
% GIT_EMBEDDED_ASSERT - do we have command line git on this machine?
%
% B = GIT_EMBEDDED_ASSERT
%
% Tests for presence of 'git' using SYSTEM.
%
%

[status, result] = system('git');

clone = strfind(lower(result), 'clone');
branch = strfind(lower(result), 'branch');
pull = strfind(lower(result), 'pull');

b = (status==0 | status==1) & ~isempty(result) & ~isempty(clone) & ~isempty(branch) & ~isempty(pull);

function b = git_embedded_install(dirname, repository)
% GIT_INSTALL - install a git repository
%
% B = GIT_INSTALL(DIRNAME, REPOSITORY)
%
% 'Install' is our term for forcing the local directory DIRNAME to match the
% remote REPOSITORY, either by cloning or pulling the latest changes. Any files
% in the local directory DIRNAME that don't match the remote REPOSITORY are deleted.
%
% If DIRNAME does not exist, then the repository is cloned.
% If DIRNAME exists and has local changes, the changes are stashed and the
%    directory is updated by pulling
% If the DIRNAME exists and has no local changes, the directory is updated by
%    pulling.
%
% Note: if you have any local changes, GIT_INSTALL will stash them and warn the user.
%
% B is 1 if the operation is successful.
%

localparentdir = fileparts(dirname);

must_clone = 0;

if ~exist(dirname,'dir'),
    must_clone = 1;
end;

status_good = 0;
if ~must_clone,
        try,
        [uptodate,changes,untrackedfiles] = git_embedded_status(dirname);
        status_good = ~changes; %  & ~untrackedfiles;  % untracked files okay
        end;

        if status_good, % we can pull without difficulty
        b=git_embedded_pull(dirname);
        else, % stash first, then pull
        warning(['STASHING changes in ' dirname '...']);
        git_embedded_stash(dirname);
        b=git_embedded_pull(dirname);
        end;
else,
    if exist(dirname,'dir'),
        rmdir(dirname,'s');
    end;
    b=git_embedded_clone(repository,localparentdir);
end;


function b = git_embedded_pull(dirname)
% GIT_EMBEDDED_PULL - pull changes to a git repository
%
% B = GIT_EMBEDDED_PULL(DIRNAME)
%
% Pulls the remote changes to a GIT repository into the local directory
% DIRNAME.
%
% If there are local changes to be committed, the operation may fail and B
% will be 0.
%

localparentdir = fileparts(dirname);

 % see if pull succeeds

pull_success = 1; % assume success, and update to failure if need be

if ~exist(dirname,'dir'),
    pull_success = 0;
end;

if pull_success, % if we are still going, try to pull
    [status,results]=system(['git -C "' dirname '" pull']);

    pull_success=(status==0);
end;

b = pull_success;


function b = git_embedded_isgitdirectory(dirname)
% GIT_EMBEDDED_ISGITDIRECTORY - is a given directory a GIT directory?
%
% B = GIT_EMBEDDED_ISGITDIRECTORY(DIRNAME)
%
% Examines whether DIRNAME is a GIT directory.
%

if git_embedded_assert,
    [status,results] = system(['git -C "' dirname '" status']);
    b = ((status==0) | (status==1)) & ~isempty(results);
else,
    error(['GIT not available on system.']);
end;


function [uptodate, changes, untracked_present] = git_embedded_status(dirname)
% GIT_EMBEDDED_STATUS - return git working tree status
%
% [UPTODATE, CHANGES, UNTRACKED_PRESENT] = GIT_EMBEDDED_STATUS(DIRNAME)
%
% Examines whether a git working tree is up to date with its current branch
%
% UPTODATE is 1 if the working tree is up-to-date, and 0 if not.
% CHANGES is 1 if the working tree has changes to be committed, and 0 if not.
% UNTRACKED_PRESENT is 1 if there are untracked files present, and 0 if not.
%
% An error is generated if DIRNAME is not a GIT directory.
%
% See also: GIT_EMBEDDED_ISGITDIRECTORY

b = git_embedded_isgitdirectory(dirname);

if ~b,
    error(['Not a GIT directory: ' dirname '.']);
end;

[status,results] = system(['git -C "' dirname '" status ']); 

uptodate = 0;
untracked_present = 0;

if status==0,
    uptodate = ~isempty(strfind(results,'Your branch is up to date with'));
    changes = ~isempty(strfind(results,'Changes'));
    untracked_present = ~isempty(strfind(results,'untracked files present'));
else,
    error(['Error running git status: ' results]);
end;

function b = git_embedded_stash(dirname)
% GIT_EMBEDDED_STASH - stash changes to a git repository
%
% B = GIT_EMBEDDED_STASH(DIRNAME)
%
% Stash the local changes to a GIT repository in DIRNAME.
%

localparentdir = fileparts(dirname);

 % see if stash succeeds

stash_success = 1; % assume success, and update to failure if need be

if ~exist(dirname,'dir'),
    stash_success = 0;
end;

if stash_success, % if we are still going, try to
    [status,results]=system(['git -C "' dirname '" stash']);

    stash_success=(status==0);
end;

b = stash_success;


function b = git_embedded_clone(repository, localparentdir)
% GIT_EMBEDDED_CLONE - clone a git repository onto the local computer
%
% B = GIT_EMBEDDED_CLONE(REPOSITORY, LOCALPARENTDIR)
%
% Clones a git repository REPOSITORY into the local directory
% LOCALPARENTDIR.
%
% If a folder containing the local repository already exists,
% an error is returned.
%
% B is 1 if the operation is successful.
%

if ~exist(localparentdir,'dir'),
    mkdir(localparentdir);
end;

reponames = split(repository,'/');

localreponame = [localparentdir filesep reponames{end}];

if exist([localreponame],'dir'),
    error([localreponame ' already exists.']);
end;

[status,results]=system(['git -C "' localparentdir '" clone ' repository]);

b = (status==0);


function c = text2cellstr_embedded(filename)
% TEXT2CELLSTR_EMBEDDED - Read a cell array of strings from a text file
%
%  C = TEXT2CELLSTR_EMBEDDED(FILENAME)
%
%  Reads a text file and imports each line as an entry 
%  in a cell array of strings.
%  
%  See also: FGETL

c = {};

fid = fopen(filename,'rt');

if fid<0,
    error(['Could not open file ' filename ' for reading.']);
end;

while ~feof(fid),
    c{end+1} = fgetl(fid);
end;
fclose(fid);

function cellstr2text_embedded(filename, cs)
% CELLSTR2TEXT_EMBEDDED - Write a cell string to a text file
%
%   CELLSTR2TEXT_EMBEDDED(FILENAME, CS)
%
%  Writes the cell array of strings CS to the new text file FILENAME.
%
%  One entry is written per line.
%

fid = fopen(filename,'wt');

newline = sprintf('\n');

if fid>=0,
    for i=1:numel(cs),
        fwrite(fid,[cs{i} newline],'char');
    end;
    fclose(fid);
else,
    error(['Could not open ' filename ' for writing.']);
end;

function installFexPackage(toolboxIdentifier, installLocation)

    fexClient = matlab.addons.repositories.FileExchangeRepository();
    addonUrl = fexClient.getAddonURL(toolboxIdentifier);
    
    if endsWith(addonUrl, '.xml')
        [filepath, C] = tempsave(addonUrl);
        S = readstruct(filepath); delete(C)
        addonUrl = S.downloadUrl;
        addonUrl = extractBefore(addonUrl, '?');
    end

    if endsWith(addonUrl, '/zip')
        [tempFilepath, C] = tempsave(addonUrl, [char(toolboxIdentifier), '_temp.zip']);
        unzip(tempFilepath, fullfile(installLocation, S.name)); delete(C)

    elseif endsWith(addonUrl, '/mltbx')
        tempFile = websave(fullfile(tempdir,'temp.mltbx'), addonUrl );
        matlab.addons.install(tempFile);
        delete(tempFile)
    end

function [filePath, cleanupObj] = tempsave(fileUrl, fileName)
    if nargin < 2
        [~, fileName, fileExtension] = fileparts( char(fileUrl) );
    else
        [~, fileName, fileExtension] = fileparts( char(fileName) );
    end

    filePath = websave(fullfile(tempdir, [fileName, fileExtension] ), fileUrl );
    cleanupObj = onCleanup(@(filename) deleteTempFile(filePath));

function deleteTempFile(filePath)
    if isfile(filePath)
        delete(filePath)
    end
    