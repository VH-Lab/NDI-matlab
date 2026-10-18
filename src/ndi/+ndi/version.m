function [v, url] = version
    % VERSION - return the version string for NDI
    %
    % [V, URL] = ndi.version()
    %
    % Return the Git version string V for the currently installed
    % version of NDI. URL is the url of the NDI distribution.
    % If NDI was installed as a toolbox (no git clone), V is the
    % toolbox's release version number (e.g., '1.1.2').
    %
    % To check for a newer version, see ndi.update.check.
    %
    % Example:
    %   v = ndi.version()
    %

    filename = which('ndi.version');

    [parentdir,file,ext] = fileparts(filename);

    try,
        [v,url] = vlt.git.git_repo_version(parentdir);
    catch,
        % not a git clone; an installed toolbox reports its release version
        v = '$Format:%H$';
        url = 'https://github.com/VH-Lab/NDI-matlab';
        try
            [~, info] = ndi.update.installType();
            if strlength(info.ToolboxVersion) > 0
                v = char(info.ToolboxVersion);
            end
        end
    end;
