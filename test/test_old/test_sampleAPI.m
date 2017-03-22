
% this tests the NSD code

disp(['Opening a new example NSD with reference ''exp1''']);
myExp = NSD('exp1');

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize 2 devices ''NSD_ephys_example'' and ''NSD_stimtimes_example'' ']);
dev1 = NSD_ephys_example('dev1')
dev2 = NSD_stimtimes_example('dev2')


disp(['Examining the intervals on dev1:']);
dev1_intervals = getintervals(dev1)

% need to write convert.m in both NSD_ephys_example/ and NSD_stimtimes_example to allow getdata to work

[d,t] = getdata(dev1, 0, Inf, NSD_clock(dev1,1))
[d_stimetimes,t_stimtimes] = getdata(dev2, 0, Inf, NSD_clock(dev2,1))

%[d_stimetimes_,t_stimtimes_] = getdata(dev2, 0, Inf, NSD_clock(dev1,1))



figure
plot(t,d) 