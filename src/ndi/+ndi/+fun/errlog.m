function errlog()
% ERRLOG - open the NDI error log
%
% ERRLOG()
%
% Opens the error log file in a terminal window.
%
% (Right now, only MacOS is supported.)
%

mylog = ndi.common.getLogger;

ndi.fun.console(mylog.error_logfile);
