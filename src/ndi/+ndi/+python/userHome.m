function folder = userHome(options)
% USERHOME - the current user's home folder, as NDI-python sees it
%
%   FOLDER = ndi.python.userHome() returns getenv('HOME') on Linux and
%   macOS and getenv('USERPROFILE') on Windows. When that variable is
%   empty, Java's user.home system property is used instead.
%
%   Optional Name-Value Arguments:
%     IsWindows - use the Windows variable (default ispc). For tests.
%
%   See also: ndi.python.ndiHome

    arguments
        options.IsWindows (1,1) logical = ispc
    end

    if options.IsWindows
        folder = getenv('USERPROFILE');
    else
        folder = getenv('HOME');
    end
    if isempty(folder)
        folder = char(java.lang.System.getProperty('user.home'));
    end
end
