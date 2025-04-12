function syslog()
% SYSLOG - open the NDI system log
%
% SYSLOG()
%
% Opens the log file in a terminal window.
%
% (Right now, only MacOS is supported.)
%

mylog = ndi.common.getLogger;

ndi.fun.console(mylog.system_logfile);
