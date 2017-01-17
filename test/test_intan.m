
% this tests the intan with t00002 data sample
% the getdata, getintervals and covert still need to modified based on the
% implementataion of the intan technique

disp(['Opening a new example sampleAPI with reference ''exp1''']);
myExp = sampleAPI('exp1');

disp(['We will now display the reference:']);
reference(myExp)

disp(['Now we will initialize devices ''sAPI_intan_example'' ']);

sync_channels = readtable('vhintan_syncchannel.txt');
cg = readtable('vhintan_channelgrouping.txt');
channel_groups = cg(:,2);

dev1 = sampleAPI_device('dev_intan','','intan',channel_groups,sync_channels);

disp('Now will print all the channels :');
disp (getchannels(dev1));

disp('Now will print the channels that are synced(in use) :');
disp (getsynced(dev1));

disp('CHANNEL_TYPE values:');
disp('Value:                      | Meaning:');
disp('--------------------------------------------------------------------------');
disp('''time'', ''timestamps'', or 1  | read timestamps of samples');
disp('''amp'', ''amplifier'' or 2     | read amplifier channels');
disp('''aux'', ''aux_in'', or 3       | read auxiliary input channels');
disp('''supply'', or 4              | read supply voltages');
disp('''temp'', or 5                | read temperature sensor');
disp('''adc'', or 6                 | read analog to digital converter signals');
disp('''din'', ''digital_in'', or 7   | read digital input (a single channel of 16 bit values)');
disp('''dout'', ''digital_out'', or 8 | read digital output signal (a single channel)');


disp(['Examining the amplifier channels versus time:']);
[time,ts1,tt1] = read_Intan_RHD2000_datafile('intan_160317_131447.rhd','',1,1,0,inf);
[amp,ts2,tt2] = read_Intan_RHD2000_datafile('intan_160317_131447.rhd','',2,1,0,inf);

% work on clock and time in the future
% [d,t] = getdata(dev1, 0, Inf, sampleAPI_clock(dev1,1))

figure;
plot(time,amp) ;