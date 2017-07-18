function check = setintervals(NSD_clock,interval)
% GETCLOCKTYPE - update the time interval for specific device
%
%   CHECK = SETINTERVALS(NSD_CLOCK)  update the interval for certain
%   device and return check if the update is sucess

NSD_clock.interval = interval;

if (NSD_clock.interval == interval),
    check = true;
else 
    check = false;
end
