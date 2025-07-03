function [v, url] = version
    % VERSION - return the version string for NDI
    %
    % [V, URL] = ndi.version()
    %
    % Return the Git version string V for the currently installed
    % version of NDI. URL is the url of the NDI distribution.
    %
    % Example:
    %   v = ndi.version()
    %

    filename = which('ndi.version');

    [parentdir,file,ext] = fileparts(filename);

    [v,url] = vlt.git.git_repo_version(parentdir);
