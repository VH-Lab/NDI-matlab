function folder = ndiHome(options)
% NDIHOME - the folder NDI-python's command-line tools are installed under
%
%   FOLDER = ndi.python.ndiHome() returns NDI_HOME, the per-user folder
%
%       fullfile(<user home>, '.ndi')
%
%   that ndi.python.install installs into. The installer owns only its
%   bin, python and venvs subfolders; the same folder also holds
%   ~/.ndi/NDI_Preferences.json (see ndi.preferences).
%
%   The user home is getenv('HOME') on Linux and macOS and
%   getenv('USERPROFILE') on Windows, the variables NDI-python's
%   installer reads, so both sides agree on the folder. If that variable
%   is empty, Java's user.home (what ndi.preferences uses) is the
%   fallback.
%
%   Optional Name-Value Arguments:
%     IsWindows - use the Windows variable (default ispc). For tests.
%
%   Example:
%     binFolder = fullfile(ndi.python.ndiHome(), 'bin');
%
%   See also: ndi.python.install, ndi.python.findCommand, ndi.preferences

    arguments
        options.IsWindows (1,1) logical = ispc
    end

    folder = fullfile(ndi.python.userHome('IsWindows', options.IsWindows), '.ndi');
end
