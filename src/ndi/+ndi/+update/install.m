function result = install(options)
% INSTALL - update NDI-matlab to the newest available version
%
%   RESULT = ndi.update.install()
%
%   Checks for an update with ndi.update.check and, after asking for
%   confirmation, installs it in the way that matches how NDI-matlab was
%   installed:
%
%     - git installs: runs ndi_install on the folder that holds NDI-matlab,
%       which pulls the latest main branch of NDI-matlab and updates (or
%       clones) its dependencies. Uncommitted changes in those repositories
%       are stashed by ndi_install. The NDI-matlab clone must be on the
%       main branch.
%     - toolbox installs: downloads the .mltbx file attached to the latest
%       GitHub release and installs it over the current toolbox. Restart
%       MATLAB afterwards so that no old copy of a class stays in memory.
%       (If the toolbox came from the Add-On Explorer, updating from the
%       Add-On Manager does the same.)
%
%   RESULT is the structure returned by ndi.update.check before updating.
%
%   RESULT = ndi.update.install(Name, Value) accepts:
%       Confirm      - ask before installing (default true)
%       Force        - install even if no update was found (default false)
%       Dependencies - for git installs, the DEPENDENCIES argument passed to
%                      ndi_install: 1 for the NDI dependencies (default) or
%                      2 for the full VH-Lab tools suite
%       Timeout      - seconds to wait for GitHub (default 10)
%
%   Example:
%       ndi.update.install()
%
%   See also: ndi.update.check, ndi_install

    arguments
        options.Confirm (1,1) logical = true
        options.Force (1,1) logical = false
        options.Dependencies (1,1) double {mustBeMember(options.Dependencies, [1 2])} = 1
        options.Timeout (1,1) double {mustBePositive} = 10
    end

    result = ndi.update.check(Verbose = true, Timeout = options.Timeout);

    if ~result.UpdateAvailable && ~options.Force
        return
    end

    switch result.InstallType
        case "git"
            installGit(result, options);
        case "toolbox"
            installToolbox(result, options);
        otherwise
            error('ndi:update:install:unknownInstall', ...
                ['Could not tell how NDI-matlab was installed. Reinstall with ' ...
                 'ndi_install or from the Add-On Explorer.']);
    end
end

function installGit(result, options)
    [~, info] = ndi.update.installType();
    repoRoot = info.RepoRoot;

    if result.Branch ~= "main"
        error('ndi:update:install:notOnMain', ...
            ['NDI-matlab in %s is on branch ''%s''. Updates come from main; ' ...
             'run ''git checkout main'' there first.'], repoRoot, result.Branch);
    end

    if ~isfile(fullfile(repoRoot, 'ndi_install.m'))
        error('ndi:update:install:noInstaller', ...
            'Could not find ndi_install.m in %s.', repoRoot);
    end

    if options.Confirm
        prompt = "This will run ndi_install to update NDI-matlab and its " + ...
            "dependencies in " + fileparts(repoRoot) + "." + newline + ...
            "Uncommitted changes in those repositories will be stashed." + newline + ...
            "Continue? Y/N [Y]: ";
        if ~confirmed(prompt)
            disp('Update cancelled.');
            return
        end
    end

    if isempty(which('ndi_install'))
        addpath(char(repoRoot));
    end
    ndi_install(char(fileparts(repoRoot)), options.Dependencies);
    disp('NDI-matlab update finished.');
end

function installToolbox(result, options)
    if strlength(result.MltbxUrl) == 0
        error('ndi:update:install:noMltbx', ...
            ['The latest NDI-matlab release has no toolbox file attached. ' ...
             'Update from the Add-On Manager, or see %s.'], result.ReleaseUrl);
    end

    if options.Confirm
        prompt = "This will download and install NDI-matlab " + ...
            result.LatestVersion + " over the installed version " + ...
            result.CurrentVersion + "." + newline + "Continue? Y/N [Y]: ";
        if ~confirmed(prompt)
            disp('Update cancelled.');
            return
        end
    end

    mltbxFile = fullfile(tempdir, "NDI-matlab-" + result.LatestVersion + ".mltbx");
    cleanupFile = onCleanup(@() deleteIfPresent(mltbxFile));
    fprintf('Downloading %s...\n', result.MltbxUrl);
    websave(mltbxFile, result.MltbxUrl, weboptions('Timeout', 120));

    disp('Installing toolbox...');
    matlab.addons.install(char(mltbxFile), true, 'overwrite');
    clear cleanupFile

    fprintf(['NDI-matlab %s is installed. Please restart MATLAB before ' ...
        'using NDI.\n'], result.LatestVersion);
end

function tf = confirmed(prompt)
    reply = strtrim(input(char(prompt), 's'));
    tf = isempty(reply) || strcmpi(reply, 'y') || strcmpi(reply, 'yes');
end

function deleteIfPresent(f)
    if isfile(f)
        delete(f);
    end
end
