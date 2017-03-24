function [data, T] = getdata(d, t0, t1, clock)
% GETDATA - get data from a device
%
%  [DATA, T] = GETDATA(D, T0, T1, CLOCK)
%
%  Returns samples of data between T0 and T1, according to the clock CLOCK.
%


  % now assume t0_ and t1_ are in local time of interval 1

d = load('NSD_stimtimes_example_data.mat');

intervals = getintervals(d);     % add intervals to d;

  % HERE, NEED TO CONVERT T0 AND T1 TO INTERVAL, T0, T1
t0_ = convert(d,t0,clock,NSD_clock(d,1));
t1_ = convert(d,t1,clock,NSD_clock(d,1));

if t0_ < 0, t0_ = 0; end;
if t1_ > intervals(1,2), t1_ = intervals(1,2); end;

z = find(d.stim_times(:,2)>=t0_ & d.stimtimes(:,2)<=t1_);

data = d.stimtimes(z,:);

T = d.stimtimes(z,2);

