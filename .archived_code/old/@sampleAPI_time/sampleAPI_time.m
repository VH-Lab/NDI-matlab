function t = NSD_time(clock_type, time)
% NSD_TIME - Time for the sample API, includes clock information
%
%  T = NSD_TIME(CLOCK_TYPE, TIME)
%
%  Creates a NSD_TIME object with clock equal to
%  'CLOCK_TYPE' and time value each to time. The units of time
%  depend upon the clock.
%
%  CLOCK_TYPE can be one of the following:
%  ---------------------------------------------------------------
%  'global'       | The time is the time in the same
%                 |   units as the Matlab function NOW
%  'local'        | The time is expressed in seconds in the local
%                 |   clock of the device.
%  'none'         | There is no clock, the number is meaningless.

t = class(struct('clock',clock_type,'time',time),'NSD_time');
