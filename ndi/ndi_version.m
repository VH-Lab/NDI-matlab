function [v, url] = ndi_version
% NDI_VERSION - return the version string for NDI
%
% [V, URL] = NDI_VERSION()
%
% Return the Git version string V for the currently installed
% version of NDI. URL is the url of the NDI distribution.
%
% Example:
%   v = ndi_version()
%

filename = which('ndi_version');

[parentdir,file,ext] = fileparts(filename);

[v,url] = git_repo_version(parentdir);
