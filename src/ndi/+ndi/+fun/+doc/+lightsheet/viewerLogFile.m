function logFile = viewerLogFile(when)
% NDI.FUN.DOC.LIGHTSHEET.VIEWERLOGFILE - path for a new napari viewer log
%
%   LOGFILE = ndi.fun.doc.lightsheet.VIEWERLOGFILE()
%   LOGFILE = ndi.fun.doc.lightsheet.VIEWERLOGFILE(WHEN)
%
%   Returns <ndi.common.PathConstants.TempFolder>/lightsheet_YYYYMMDDHHMMSS.txt
%   for the time WHEN (a datetime; default now). Named by launch time so
%   each viewer gets its own log and a folder listing sorts them in
%   launch order. Does not create the file or the folder.
%
%   See also: ndi.fun.doc.lightsheet.launchViewer

    arguments
        when (1,1) datetime = datetime('now')
    end
    stamp = char(datetime(when, 'Format', 'yyyyMMddHHmmss'));
    logFile = fullfile(ndi.common.PathConstants.TempFolder, ...
        ['lightsheet_' stamp '.txt']);
end
