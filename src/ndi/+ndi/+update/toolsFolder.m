function folder = toolsFolder()
% TOOLSFOLDER - the folder that holds NDI-matlab and the tools ndi_install installed
%
%   FOLDER = ndi.update.toolsFolder()
%
%   Returns the folder that ndi_install installed NDI-matlab and its
%   dependencies into: the folder that holds the NDI-matlab git clone that
%   is running. By default this is [userpath filesep 'tools'], for example
%   /Users/me/Documents/MATLAB/tools; ndi_install(PATHNAME) installs into
%   PATHNAME instead. startup.m runs vhtools_startup from this folder, which
%   puts everything in it on the MATLAB path.
%
%   FOLDER is "" if NDI-matlab is not a git clone (for example, if it was
%   installed as a toolbox from the Add-On Explorer): then MATLAB decides
%   where it lives, and there is no tools folder to move.
%
%   Example:
%       ndi.update.toolsFolder()
%
%   See also: ndi.update.moveToolsFolder, ndi.update.installType, ndi_install

    arguments
    end

    [type, info] = ndi.update.installType();
    if type == "git"
        folder = string(fileparts(char(info.RepoRoot)));
    else
        folder = "";
    end
end
