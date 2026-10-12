function [status, logFile, fullCmd] = launchViewer(cmd, options)
% NDI.FUN.DOC.LIGHTSHEET.LAUNCHVIEWER - run a napari viewer command with its log kept
%
%   [STATUS, LOGFILE, FULLCMD] = ndi.fun.doc.lightsheet.LAUNCHVIEWER(CMD)
%
%   Runs CMD (a napariViewLightsheet command line, as built by
%   ndi.fun.doc.lightsheet.viewCommand) through SYSTEM with the viewer's
%   debugging lines switched on (NDI_LIGHTSHEET_DEBUG=1) and its stdout
%   and stderr appended to a log file in NDI's temporary folder:
%
%       <ndi.common.PathConstants.TempFolder>/lightsheet_YYYYMMDDHHMMSS.txt
%
%   A viewer launched from MATLAB has no terminal, so without this its
%   log -- which tiles it fetched, what failed and why -- is lost. The
%   file starts with a header (time, command) and is named by the launch
%   time, so each viewer gets its own and they sort in launch order.
%
%   STATUS is the SYSTEM status: for a detached launch (the default) it
%   says whether the launch started, not how the viewer ended. LOGFILE is
%   the full path of the log. FULLCMD is the exact shell command run.
%
%   Optional Name-Value Arguments:
%     wait    - block until the viewer exits (default false, so MATLAB
%               stays interactive while the viewer is open).
%     debug   - set NDI_LIGHTSHEET_DEBUG=1 for the viewer (default true).
%     logFile - write here instead of a new timestamped file in the NDI
%               temporary folder.
%     verbose - print the command and the log path (default true).
%
%   Example:
%     cmd = ndi.fun.doc.lightsheet.viewCommand(launcher, S.path(), id);
%     [~, logFile] = ndi.fun.doc.lightsheet.launchViewer(cmd);
%     edit(logFile)   % or: type(logFile)
%
%   See also: ndi.fun.doc.lightsheet.view, ndi.fun.doc.lightsheet.viewCommand,
%             ndi.fun.doc.lightsheet.viewerLogFile,
%             ndi.fun.doc.lightsheet.viewerShellCommand,
%             ndi.gui.app.LightsheetZarrManager

    arguments
        cmd (1,:) char
        options.wait (1,1) logical = false
        options.debug (1,1) logical = true
        options.logFile (1,:) char = ''
        options.verbose (1,1) logical = true
    end

    logFile = options.logFile;
    if isempty(logFile)
        logFile = ndi.fun.doc.lightsheet.viewerLogFile();
    end
    logDir = fileparts(logFile);
    if ~isempty(logDir) && ~isfolder(logDir)
        mkdir(logDir);
    end

    % Header first, so a log whose viewer printed nothing still says what
    % was launched and when.
    fid = fopen(logFile, 'a');
    if fid >= 0
        fprintf(fid, '=== napari lightsheet viewer: %s ===\n', ...
            char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
        fprintf(fid, 'command : %s\n', cmd);
        fprintf(fid, 'debug   : %d\n\n', options.debug);
        fclose(fid);
    end

    fullCmd = ndi.fun.doc.lightsheet.viewerShellCommand(cmd, logFile, ...
        options.wait, options.debug, ispc);
    if options.verbose
        fprintf('Executing: %s\n', fullCmd);
        fprintf('Viewer log: %s\n', logFile);
    end
    status = system(fullCmd);
end
