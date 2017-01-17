function check = setintervals(sampleAPI_clock,interval)
% GETCLOCKTYPE - update the time interval for specific device
%
%   CHECK = SETINTERVALS(SAMPLEAPI_CLOCK)  update the interval for certain
%   device and return check if the update is sucess

sampleAPI_clock.interval = interval;

if (sampleAPI_clock.interval == interval),
    check = true;
else 
    check = false;
end