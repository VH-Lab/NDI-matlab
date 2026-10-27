function [type, info] = installType()
% INSTALLTYPE - how the running copy of NDI-matlab was installed
%
%   [TYPE, INFO] = ndi.update.installType()
%
%   Returns TYPE, one of:
%       "git"     - a clone made by ndi_install (or by hand) from GitHub
%       "toolbox" - the NDI-matlab toolbox (.mltbx) installed from the
%                   Add-On Explorer or from a GitHub Release
%       "unknown" - neither could be determined
%
%   INFO is a structure with fields:
%       SourceDir      - folder holding the running +ndi package (src/ndi)
%       RepoRoot       - root of the git clone ("" unless TYPE is "git")
%       ToolboxVersion - version of the installed NDI-matlab toolbox, or ""
%       BothInstalled  - true if a git clone is running while the toolbox is
%                        also installed and enabled; one copy shadows the other
%
%   Example:
%       [type, info] = ndi.update.installType()
%
%   See also: ndi.update.check, ndi.update.install

    arguments
    end

    info.SourceDir = string(ndi.toolboxdir());
    info.RepoRoot = "";
    info.ToolboxVersion = "";
    info.BothInstalled = false;

    % src/ndi -> src -> repository root
    repoRoot = string(fileparts(fileparts(info.SourceDir)));
    isGit = exist(fullfile(repoRoot, '.git'), 'file') ~= 0; % folder, or file for worktrees

    toolboxInstalled = false;
    try
        addons = matlab.addons.installedAddons();
        match = addons.Identifier == ndi.update.toolboxIdentifier();
        if any(match)
            row = find(match, 1);
            info.ToolboxVersion = string(addons.Version(row));
            toolboxInstalled = logical(addons.Enabled(row));
        end
    catch
        % installedAddons can be unavailable (e.g., some deployed contexts)
    end

    if isGit
        type = "git";
        info.RepoRoot = repoRoot;
        info.BothInstalled = toolboxInstalled;
    elseif toolboxInstalled || strlength(info.ToolboxVersion) > 0
        type = "toolbox";
    else
        type = "unknown";
    end
end
