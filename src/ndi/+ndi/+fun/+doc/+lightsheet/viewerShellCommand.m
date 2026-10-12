function fullCmd = viewerShellCommand(cmd, logFile, wait, debug, isWindows)
% NDI.FUN.DOC.LIGHTSHEET.VIEWERSHELLCOMMAND - the shell line that runs a viewer with a log
%
%   FULLCMD = ndi.fun.doc.lightsheet.VIEWERSHELLCOMMAND(CMD, LOGFILE, WAIT, DEBUG, ISWINDOWS)
%
%   Wraps the viewer command CMD so that, when passed to SYSTEM:
%     * NDI_LIGHTSHEET_DEBUG=1 is set for the viewer process (if DEBUG),
%     * its stdout and stderr are APPENDED to LOGFILE, and
%     * it runs detached (unless WAIT), so MATLAB is not blocked for as
%       long as the viewer is open.
%
%   Pure: builds the string only, for either shell (ISWINDOWS picks
%   cmd.exe syntax over POSIX sh), so it can be tested anywhere.
%   ndi.fun.doc.lightsheet.launchViewer is the function that runs it.
%
%   POSIX:    NDI_LIGHTSHEET_DEBUG=1 CMD >>'LOGFILE' 2>&1 &
%   Windows:  start "napari" /min cmd /c "set NDI_LIGHTSHEET_DEBUG=1&& CMD >>"LOGFILE" 2>&1"
%
%   See also: ndi.fun.doc.lightsheet.launchViewer

    arguments
        cmd (1,:) char
        logFile (1,:) char
        wait (1,1) logical = false
        debug (1,1) logical = true
        isWindows (1,1) logical = ispc
    end

    if isWindows
        inner = sprintf('%s >>"%s" 2>&1', cmd, logFile);
        if debug
            % No space before &&: cmd.exe would keep it in the value.
            inner = ['set NDI_LIGHTSHEET_DEBUG=1&& ' inner];
        end
        if wait
            fullCmd = inner;
        else
            % cmd /c strips the outer quotes and runs the rest as typed.
            fullCmd = ['start "napari" /min cmd /c "' inner '"'];
        end
    else
        quotedLog = ['''' strrep(logFile, '''', '''\''''') ''''];
        fullCmd = [cmd ' >>' quotedLog ' 2>&1'];
        if debug
            fullCmd = ['NDI_LIGHTSHEET_DEBUG=1 ' fullCmd];
        end
        if ~wait
            fullCmd = [fullCmd ' &'];
        end
    end
end
