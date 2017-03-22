function [data, T] = getdata(d, t0, t1, clock)
% GETDATA - get data from a device
%
%  [DATA, T] = GETDATA(D, T0, T1, CLOCK)
%
%  Returns samples of data between T0 and T1, according to the clock CLOCK.
%


d = load('NSD_ephys_example_data.mat');


  % now assume t0_ and t1_ are in interval 1

sr = 10000; % sample rate

s0 = fix(1+ t0_ *sr);
s1 = fix(1+ t1_ *sr);

 % HERE, NEED TO CONVERT T0 AND T1 TO INTERVAL, T0, T1
t0_ = convert(d,t0,clock,NSD_clock(d,1));
t1_ = convert(d,t1,clock,NSD_clock(d,1));

if s1>length(d.voltage),
	s1 = length(d.voltage);
end;
if s0<0, s0 = 1; end;

t = 0:1/sr:((length(d.voltage)-1)*sr);

data = d(s0:s1);
T = t(s0:s1);

