function [data, T] = getdata(d, t0, t1, clock)
% GETDATA - get data from a device
%
%  [DATA, T] = GETDATA(D, T0, T1, CLOCK)
%
%  Returns samples of data between T0 and T1, according to the clock CLOCK.
%

  % HERE, NEED TO CONVERT T0 AND T1 TO INTERVAL, T0, T1
t0_ = convert(d,t0,clock,sampleAPI_clock(d,1));
t1_ = convert(d,t1,clock,sampleAPI_clock(d,1));

  % now assume t0_ and t1_ are in local time of interval 1

d = load('sAPI_stimtimes_example_data.mat');

T = getintervals(d,t0_,t1_);

data = retrievedata(d,T);
