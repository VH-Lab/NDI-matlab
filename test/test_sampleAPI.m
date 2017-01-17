
% this tests the sampleAPI code

disp(['Opening a new example sampleAPI with reference ''exp1''']);
myExp = sampleAPI('exp1');

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize 2 devices ''sAPI_ephys_example'' and ''sAPI_stimtimes_example'' ']);
dev1 = sAPI_ephys_example('dev1')
dev2 = sAPI_stimtimes_example('dev2')


disp(['Examining the intervals on dev1:']);
dev1_intervals = getintervals(dev1)

% need to write convert.m in both sAPI_ephys_example/ and sAPI_stimtimes_example to allow getdata to work

[d,t] = getdata(dev1, 0, Inf, sampleAPI_clock(dev1,1))
[d_stimetimes,t_stimtimes] = getdata(dev2, 0, Inf, sampleAPI_clock(dev2,1))

%[d_stimetimes_,t_stimtimes_] = getdata(dev2, 0, Inf, sampleAPI_clock(dev1,1))



figure
plot(t,d) 