function cmd = installerCommand(scriptFile, options)
% INSTALLERCOMMAND - the shell line that runs NDI-python's installer script
%
%   CMD = ndi.python.installerCommand(SCRIPTFILE) returns the command
%   line, for SYSTEM, that runs the downloaded installer SCRIPTFILE
%   non-interactively:
%
%     Linux/macOS:  LD_LIBRARY_PATH="..." /bin/sh 'SCRIPTFILE' --yes [--uninstall] [--no-path]
%     Windows:      powershell -NoProfile -ExecutionPolicy Bypass -File "SCRIPTFILE" -Yes [-Uninstall] [-NoPath]
%
%   On Linux the installer's own downloads (curl) must load the system's
%   libraries rather than MATLAB's, so LD_LIBRARY_PATH is restored first
%   (see ndi.common.systemCurlEnvPrefix).
%
%   Pure: nothing is run. ndi.python.install runs it.
%
%   Optional Name-Value Arguments:
%     Uninstall - add --uninstall / -Uninstall (default false).
%     AddToPath - false adds --no-path / -NoPath (default true).
%     IsWindows - build the Windows form (default ispc).
%
%   See also: ndi.python.install

    arguments
        scriptFile {mustBeTextScalar, mustBeNonzeroLengthText}
        options.Uninstall (1,1) logical = false
        options.AddToPath (1,1) logical = true
        options.IsWindows (1,1) logical = ispc
    end

    quoted = ndi.python.shellQuote(scriptFile, 'IsWindows', options.IsWindows);
    if options.IsWindows
        cmd = ['powershell -NoProfile -ExecutionPolicy Bypass -File ' quoted ' -Yes'];
        if options.Uninstall
            cmd = [cmd ' -Uninstall'];
        end
        if ~options.AddToPath
            cmd = [cmd ' -NoPath'];
        end
    else
        prefix = '';
        if ~ispc
            prefix = ndi.common.systemCurlEnvPrefix();
        end
        cmd = [prefix '/bin/sh ' quoted ' --yes'];
        if options.Uninstall
            cmd = [cmd ' --uninstall'];
        end
        if ~options.AddToPath
            cmd = [cmd ' --no-path'];
        end
    end
end
