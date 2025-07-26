function debuglog()
% DEBUGLOG - open the NDI debug log in a terminal
%
% DEBUGLOG()
%
% Opens the debug log file in a terminal window.
%
% (Right now, only MacOS is supported.)
%

mylog = ndi.common.getLogger;

ndi.fun.console(mylog.debug_logfile);
